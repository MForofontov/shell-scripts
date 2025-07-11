#!/usr/bin/env bash
# firewall_configurator.sh
# Script to configure basic firewall rules using UFW.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
ADDITIONAL_PORTS=()
LOG_FILE="/dev/null"
DRY_RUN=false
FORCE_YES=false
DEFAULT_SSH_PORT=22
ENABLE_LOGGING=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Firewall Configurator Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script configures basic firewall rules using UFW."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--dry-run] [--yes] [--enable-logging] [additional_ports]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--dry-run\033[0m           (Optional) Show commands without executing them."
  echo -e "  \033[1;33m--yes\033[0m               (Optional) Apply changes without confirmation."
  echo -e "  \033[1;33m--enable-logging\033[0m    (Optional) Enable UFW logging."
  echo -e "  \033[1;36m[additional_ports]\033[0m  (Optional) Space-separated list of additional ports to allow."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log firewall.log 8080 3306"
  echo "  $0 --dry-run 8080"
  echo "  $0 --yes --enable-logging"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --yes)
        FORCE_YES=true
        shift
        ;;
      --enable-logging)
        ENABLE_LOGGING=true
        shift
        ;;
      *)
        if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then
          ADDITIONAL_PORTS+=("$1")
          shift
        else
          format-echo "ERROR" "Invalid argument: $1"
          usage
        fi
        ;;
    esac
  done
}

#=====================================================================
# FIREWALL FUNCTIONS
#=====================================================================
# Function to check if the user has sudo privileges
check_sudo() {
  if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
      format-echo "ERROR" "This script must be run as root or with sudo privileges."
      return 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
      format-echo "ERROR" "This script requires sudo privileges."
      format-echo "INFO" "Please run with: sudo $0 $*"
      return 1
    fi
  fi
  return 0
}

# Function to execute UFW commands (or just print them in dry-run mode)
run_ufw_cmd() {
  if [ "$DRY_RUN" = true ]; then
    format-echo "DRY-RUN" "Would execute: $*"
    return 0
  else
    if [ "$EUID" -ne 0 ]; then
      if ! sudo "$@"; then
        format-echo "ERROR" "Failed to execute: sudo $*"
        return 1
      fi
    else
      if ! "$@"; then
        format-echo "ERROR" "Failed to execute: $*"
        return 1
      fi
    fi
  fi
  return 0
}

# Function to show UFW status in a formatted way
show_ufw_status() {
  print_with_separator "Current Firewall Status"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "DRY-RUN" "Would check UFW status"
    return 0
  fi
  
  if [ "$EUID" -ne 0 ]; then
    sudo ufw status verbose
  else
    ufw status verbose
  fi
  
  print_with_separator
}

# Function to prompt for confirmation
confirm_action() {
  local message="$1"
  local default="$2"
  
  if [ "$FORCE_YES" = true ]; then
    return 0
  fi
  
  local prompt
  local response
  
  if [ "$default" = "y" ]; then
    prompt="$message [Y/n]: "
  else
    prompt="$message [y/N]: "
  fi
  
  read -p "$prompt" response
  response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
  
  if [ -z "$response" ]; then
    response="$default"
  fi
  
  if [ "$response" = "y" ]; then
    return 0
  else
    return 1
  fi
}

# Apply firewall rules
apply_firewall_rules() {
  # Reset UFW to default state
  format-echo "INFO" "Resetting UFW to default state..."
  run_ufw_cmd ufw --force reset
  
  # Set default policies
  format-echo "INFO" "Setting default policies..."
  run_ufw_cmd ufw default deny incoming
  run_ufw_cmd ufw default allow outgoing
  
  # Essential services
  format-echo "INFO" "Allowing essential services..."
  run_ufw_cmd ufw allow "$DEFAULT_SSH_PORT/tcp" comment "SSH"
  run_ufw_cmd ufw allow 80/tcp comment "HTTP"
  run_ufw_cmd ufw allow 443/tcp comment "HTTPS"
  
  # Additional ports
  if [ ${#ADDITIONAL_PORTS[@]} -gt 0 ]; then
    format-echo "INFO" "Allowing additional ports..."
    for port in "${ADDITIONAL_PORTS[@]}"; do
      local service=$(get_service_name "$port")
      if [ "$service" != "Unknown" ]; then
        run_ufw_cmd ufw allow "$port/tcp" comment "$service"
        format-echo "INFO" "Allowed port $port ($service)."
      else
        run_ufw_cmd ufw allow "$port/tcp" comment "Custom"
        format-echo "INFO" "Allowed port $port (Custom)."
      fi
    done
  fi
  
  # Enable logging if requested
  if [ "$ENABLE_LOGGING" = true ]; then
    format-echo "INFO" "Enabling UFW logging..."
    run_ufw_cmd ufw logging on
  fi
  
  # Enable UFW
  format-echo "INFO" "Enabling UFW..."
  if [ "$DRY_RUN" = true ]; then
    format-echo "DRY-RUN" "Would enable UFW"
  else
    if confirm_action "Do you want to enable the firewall with these settings?" "y"; then
      run_ufw_cmd ufw --force enable
      format-echo "SUCCESS" "Firewall enabled successfully."
    else
      format-echo "WARNING" "Firewall configuration aborted by user."
      return 1
    fi
  fi
  
  return 0
}

# Get service name for common port numbers
get_service_name() {
  local port="$1"
  
  case "$port" in
    # FTP related
    20) echo "FTP-data" ;;
    21) echo "FTP" ;;
    989) echo "FTPS-data" ;;
    990) echo "FTPS" ;;
    
    # SSH related
    22) echo "SSH" ;;
    2222) echo "SSH-Alt" ;;
    
    # Telnet related
    23) echo "Telnet" ;;
    992) echo "Telnet-SSL" ;;
    
    # Mail related
    25) echo "SMTP" ;;
    110) echo "POP3" ;;
    143) echo "IMAP" ;;
    465) echo "SMTPS" ;;
    587) echo "SMTP Submission" ;;
    993) echo "IMAPS" ;;
    995) echo "POP3S" ;;
    2525) echo "SMTP-Alt" ;;
    
    # DNS related
    53) echo "DNS" ;;
    5353) echo "mDNS" ;;
    853) echo "DNS-over-TLS" ;;
    
    # Web related
    80) echo "HTTP" ;;
    443) echo "HTTPS" ;;
    591) echo "FileMaker" ;;
    8008) echo "HTTP-Alt" ;;
    8080) echo "HTTP-Proxy" ;;
    8443) echo "HTTPS-Alt" ;;
    8888) echo "HTTP-Alt2" ;;
    
    # Database related
    1433) echo "MS SQL" ;;
    1434) echo "MS SQL Monitor" ;;
    1521) echo "Oracle" ;;
    1830) echo "Oracle-DB" ;;
    3306) echo "MySQL/MariaDB" ;;
    5432) echo "PostgreSQL" ;;
    6379) echo "Redis" ;;
    7199) echo "Cassandra" ;;
    7474) echo "Neo4j" ;;
    9042) echo "Cassandra-Client" ;;
    11211) echo "Memcached" ;;
    27017) echo "MongoDB" ;;
    27018) echo "MongoDB-Shard" ;;
    27019) echo "MongoDB-Config" ;;
    
    # File sharing
    137) echo "NetBIOS Name" ;;
    138) echo "NetBIOS Datagram" ;;
    139) echo "NetBIOS Session" ;;
    445) echo "SMB" ;;
    548) echo "AFP" ;;
    2049) echo "NFS" ;;
    3690) echo "SVN" ;;
    
    # Remote access
    3389) echo "RDP" ;;
    5500) echo "VNC" ;;
    5800) echo "VNC-Web" ;;
    5900) echo "VNC" ;;
    5901) echo "VNC-1" ;;
    5902) echo "VNC-2" ;;
    5903) echo "VNC-3" ;;
    
    # CI/CD and DevOps
    8081) echo "Jenkins/Nexus" ;;
    8085) echo "Jenkins-Alt" ;;
    8086) echo "InfluxDB" ;;
    9000) echo "SonarQube/Prometheus" ;;
    9090) echo "Prometheus" ;;
    9091) echo "Prometheus-Push" ;;
    9092) echo "Prometheus-Alt" ;;
    9093) echo "Alertmanager" ;;
    9100) echo "Node-Exporter" ;;
    9200) echo "Elasticsearch" ;;
    9300) echo "Elasticsearch-Nodes" ;;
    9418) echo "Git" ;;
    
    # Miscellaneous
    111) echo "RPC" ;;
    123) echo "NTP" ;;
    135) echo "RPC/DCOM" ;;
    161) echo "SNMP" ;;
    162) echo "SNMP Trap" ;;
    389) echo "LDAP" ;;
    500) echo "IKE/ISAKMP" ;;
    514) echo "Syslog" ;;
    520) echo "RIP" ;;
    546) echo "DHCPv6-Client" ;;
    547) echo "DHCPv6-Server" ;;
    636) echo "LDAPS" ;;
    873) echo "rsync" ;;
    989) echo "FTPS-data" ;;
    990) echo "FTPS" ;;
    1194) echo "OpenVPN" ;;
    1701) echo "L2TP" ;;
    1723) echo "PPTP" ;;
    1812) echo "RADIUS" ;;
    1813) echo "RADIUS Accounting" ;;
    2181) echo "ZooKeeper" ;;
    3000) echo "Grafana/Dev Server" ;;
    3001) echo "Dev Server Alt" ;;
    4369) echo "Erlang Port Mapper" ;;
    5000) echo "Dev Server/UPnP" ;;
    5001) echo "Dev Server Alt" ;;
    5222) echo "XMPP" ;;
    5269) echo "XMPP Server" ;;
    5353) echo "mDNS" ;;
    5355) echo "LLMNR" ;;
    5432) echo "PostgreSQL" ;;
    5672) echo "AMQP" ;;
    5683) echo "CoAP" ;;
    5684) echo "CoAPS" ;;
    6000) echo "X11" ;;
    6443) echo "Kubernetes API" ;;
    6514) echo "Syslog-TLS" ;;
    6783) echo "Weave Net" ;;
    7000) echo "Cassandra Internode" ;;
    7001) echo "Cassandra JMX" ;;
    7077) echo "Spark Master" ;;
    8000) echo "Dev HTTP" ;;
    8089) echo "Splunk" ;;
    8472) echo "Flannel/VXLAN" ;;
    10000) echo "Webmin" ;;
    10250) echo "Kubelet API" ;;
    10255) echo "Kubelet Read-Only" ;;
    10256) echo "kube-proxy" ;;
    
    # Voice/Video
    1720) echo "H.323" ;;
    1935) echo "RTMP" ;;
    3478) echo "STUN" ;;
    3479) echo "STUN-TLS" ;;
    5004) echo "RTP" ;;
    5005) echo "RTP" ;;
    5060) echo "SIP" ;;
    5061) echo "SIPS" ;;
    8056) echo "Pexip" ;;
    
    # Messaging
    1883) echo "MQTT" ;;
    4222) echo "NATS" ;;
    5222) echo "XMPP Client" ;;
    5223) echo "XMPP Client SSL" ;;
    5269) echo "XMPP Server" ;;
    5671) echo "AMQP-TLS" ;;
    5672) echo "AMQP" ;;
    6379) echo "Redis" ;;
    6667) echo "IRC" ;;
    8883) echo "MQTT-TLS" ;;
    9092) echo "Kafka" ;;
    15672) echo "RabbitMQ Management" ;;
    61613) echo "STOMP" ;;
    61614) echo "STOMP-TLS" ;;
    
    # Game servers
    25565) echo "Minecraft" ;;
    27015) echo "Source Engine" ;;
    27016) echo "Source HLTV" ;;
    27017) echo "Source TV" ;;
    27031) echo "Steam In-Home" ;;
    27036) echo "Steam" ;;
    3724) echo "World of Warcraft" ;;
    6112) echo "Battle.net" ;;
    6113) echo "Battle.net Chat" ;;
    8086) echo "FACEIT" ;;
    9987) echo "TeamSpeak 3" ;;
    30000) echo "Minecraft Bedrock" ;;
    
    # IoT and Smart Home
    5683) echo "CoAP" ;;
    8123) echo "Home Assistant" ;;
    8888) echo "SmartThings" ;;
    8889) echo "Homey" ;;
    9001) echo "Phillips Hue" ;;
    
    # Default case
    *) echo "Unknown" ;;
  esac
}

# Summarize the applied rules
summarize_rules() {
  print_with_separator "Firewall Rules Summary"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "DRY-RUN" "Would show configured rules"
    
    echo "Default policies:"
    echo "- Incoming traffic: DENY"
    echo "- Outgoing traffic: ALLOW"
    
    echo "Allowed services:"
    echo "- SSH (port $DEFAULT_SSH_PORT)"
    echo "- HTTP (port 80)"
    echo "- HTTPS (port 443)"
    
    if [ ${#ADDITIONAL_PORTS[@]} -gt 0 ]; then
      echo "Additional allowed ports:"
      for port in "${ADDITIONAL_PORTS[@]}"; do
        local service=$(get_service_name "$port")
        if [ "$service" != "Unknown" ]; then
          echo "- $port ($service)"
        else
          echo "- $port (Custom)"
        fi
      done
    fi
    
    if [ "$ENABLE_LOGGING" = true ]; then
      echo "UFW logging: ENABLED"
    else
      echo "UFW logging: DISABLED"
    fi
  else
    show_ufw_status
  fi
  
  print_with_separator
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Firewall Configurator Script"
  format-echo "INFO" "Starting Firewall Configurator Script..."
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "WARNING" "Running in DRY-RUN mode. No changes will be applied."
  fi

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if running with necessary permissions
  if ! check_sudo "$@"; then
    print_with_separator "End of Firewall Configurator Script"
    exit 1
  fi

  # Check if UFW is installed
  if ! command -v ufw &> /dev/null; then
    format-echo "ERROR" "UFW is not installed. Please install it and try again."
    format-echo "INFO" "On Debian/Ubuntu: sudo apt-get install ufw"
    format-echo "INFO" "On CentOS/RHEL: sudo yum install ufw"
    print_with_separator "End of Firewall Configurator Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # FIREWALL CONFIGURATION
  #---------------------------------------------------------------------
  # Show current firewall status
  format-echo "INFO" "Checking current firewall status..."
  show_ufw_status
  
  # Apply the firewall rules
  if apply_firewall_rules; then
    format-echo "SUCCESS" "Firewall rules applied successfully."
  else
    if [ "$DRY_RUN" = true ]; then
      format-echo "INFO" "Dry run completed. No changes were made."
    else
      format-echo "WARNING" "Firewall configuration was not completed."
    fi
    print_with_separator "End of Firewall Configurator Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  # Summarize the applied rules
  summarize_rules
  
  print_with_separator "End of Firewall Configurator Script"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "SUCCESS" "Dry run completed. No changes were made."
  else
    format-echo "SUCCESS" "Firewall configuration completed successfully."
  fi
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
