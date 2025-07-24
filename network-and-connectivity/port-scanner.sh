#!/bin/bash
# port-scanner.sh
# Script to scan open ports on a specified server

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
SERVER=""
START_PORT=1
END_PORT=65535
OUTPUT_FILE=""
LOG_FILE="/dev/null"
TIMEOUT=1
VERBOSE=false
COMMON_PORTS_ONLY=false
SHOW_PROGRESS=true

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Port Scanner Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scans open ports on a specified server."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <server> [--start <start_port>] [--end <end_port>] [--output <output_file>] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<server>\033[0m                  (Required) The server to scan."
  echo -e "  \033[1;33m--start <start_port>\033[0m      (Optional) Start port (default: 1)."
  echo -e "  \033[1;33m--end <end_port>\033[0m          (Optional) End port (default: 65535)."
  echo -e "  \033[1;33m--timeout <seconds>\033[0m       (Optional) Connection timeout in seconds (default: 1)."
  echo -e "  \033[1;33m--common-ports\033[0m            (Optional) Scan only common ports."
  echo -e "  \033[1;33m--no-progress\033[0m             (Optional) Don't show progress indicator."
  echo -e "  \033[1;33m--verbose\033[0m                 (Optional) Show more detailed output."
  echo -e "  \033[1;33m--output <output_file>\033[0m    (Optional) File to save the scan results."
  echo -e "  \033[1;33m--log <log_file>\033[0m          (Optional) File to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 example.com --start 1 --end 1000 --output scan_results.txt"
  echo "  $0 example.com --common-ports --verbose"
  echo "  $0 192.168.1.1 --timeout 2 --log scan_log.txt"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "Log file name is required after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --help)
        usage
        ;;
      --start)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
          format-echo "ERROR" "Invalid start port: $2"
          usage
        fi
        START_PORT="$2"
        shift 2
        ;;
      --end)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
          format-echo "ERROR" "Invalid end port: $2"
          usage
        fi
        END_PORT="$2"
        shift 2
        ;;
      --timeout)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ]; then
          format-echo "ERROR" "Invalid timeout value: $2"
          usage
        fi
        TIMEOUT="$2"
        shift 2
        ;;
      --output)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "Output file name is required after --output."
          usage
        fi
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --common-ports)
        COMMON_PORTS_ONLY=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --no-progress)
        SHOW_PROGRESS=false
        shift
        ;;
      *)
        if [ -z "$SERVER" ]; then
          SERVER="$1"
          shift
        else
          format-echo "ERROR" "Unknown option: $1"
          usage
        fi
        ;;
    esac
  done
}

#=====================================================================
# PORT SCANNING FUNCTIONS
#=====================================================================
# Common ports list
get_common_ports() {
  # Common ports for various services
  echo "20 21 22 23 25 53 80 110 111 135 139 143 443 445 993 995 1723 3306 3389 5900 8080"
}

# Check if a single port is open
check_port() {
  local server="$1"
  local port="$2"
  local timeout="$3"
  
  if timeout "$timeout" bash -c "echo > /dev/tcp/$server/$port" &>/dev/null; then
    echo "open"
  else
    echo "closed"
  fi
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
    2049) echo "NFS" ;;
    548) echo "AFP" ;;
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

# Main port scanning function
scan_ports() {
  local open_count=0
  local total_ports=0
  local ports_to_scan
  
  # Determine which ports to scan
  if [[ "$COMMON_PORTS_ONLY" == true ]]; then
    ports_to_scan=$(get_common_ports)
    format-echo "INFO" "Scanning common ports only..."
  else
    ports_to_scan=$(seq "$START_PORT" "$END_PORT")
    format-echo "INFO" "Scanning all ports from $START_PORT to $END_PORT..."
  fi
  
  # Count total ports for progress reporting
  total_ports=$(echo "$ports_to_scan" | wc -w | tr -d ' ')
  format-echo "INFO" "Total ports to scan: $total_ports"
  
  # Initialize results arrays for summary
  declare -a open_ports
  declare -a open_services
  
  # Create or clear output file if specified
  if [ -n "$OUTPUT_FILE" ]; then
    echo "# Port scan results for $SERVER" > "$OUTPUT_FILE"
    echo "# Scan started at $(date)" >> "$OUTPUT_FILE"
    echo "# Port | Status | Service" >> "$OUTPUT_FILE"
    echo "# ---- | ------ | -------" >> "$OUTPUT_FILE"
  fi
  
  local port_count=0
  for PORT in $ports_to_scan; do
    port_count=$((port_count + 1))
    
    # Show progress if enabled
    if [[ "$SHOW_PROGRESS" == true ]]; then
      if [[ "$port_count" -lt "$total_ports" ]]; then
        printf "\rScanning port %d/%d (%d%%)" "$port_count" "$total_ports" "$((port_count * 100 / total_ports))"
      fi
    fi
    
    # Check if port is open
    local status
    status=$(check_port "$SERVER" "$PORT" "$TIMEOUT")
    
    if [[ "$status" == "open" ]]; then
      local service
      service=$(get_service_name "$PORT")
      
      # Store the result
      open_ports+=("$PORT")
      open_services+=("$service")
      open_count=$((open_count + 1))
      
      # Print result during scan only if verbose mode is enabled
      if [[ "$VERBOSE" == true ]]; then
        printf "\r" # Clear progress line
        format-echo "SUCCESS" "Port $PORT is open (Service: $service)"
      fi
      
      # Save to output file if specified
      if [ -n "$OUTPUT_FILE" ]; then
        echo "$PORT | OPEN | $service" >> "$OUTPUT_FILE"
      fi
    elif [[ "$VERBOSE" == true ]]; then
      printf "\r" # Clear progress line
      format-echo "INFO" "Port $PORT is closed"
      
      # Save to output file if verbose mode and output file specified
      if [ -n "$OUTPUT_FILE" ]; then
        echo "$PORT | CLOSED | -" >> "$OUTPUT_FILE"
      fi
    fi
  done
  
  # Clear progress line
  if [[ "$SHOW_PROGRESS" == true ]]; then
    printf "\r%*s\r" "$(tput cols)" ""
  fi
  
  # Display detailed table of open ports in console (always shown)
  if [ ${#open_ports[@]} -gt 0 ]; then
    print_with_separator "Open Ports Detail"
    printf "%-10s %-20s %-20s\n" "PORT" "STATUS" "SERVICE"
    echo "----------------------------------------------------------------------------------------"
    
    for i in "${!open_ports[@]}"; do
      printf "%-10s %-20s %-20s\n" "${open_ports[$i]}" "OPEN" "${open_services[$i]}"
    done
    
    echo "----------------------------------------------------------------------------------------"
  fi
  
  # Print summary
  print_with_separator "Scan Results Summary"
  echo "Server: $SERVER"
  echo "Ports scanned: $total_ports"
  echo "Open ports found: $open_count"
  
  if [ ${#open_ports[@]} -gt 0 ]; then
    echo -n "Open ports: "
    for i in "${!open_ports[@]}"; do
      if [ "$i" -gt 0 ]; then
        echo -n ", "
      fi
      echo -n "${open_ports[$i]} (${open_services[$i]})"
    done
    echo ""
  else
    echo "No open ports found."
  fi
  
  # Append summary to output file if specified
  if [ -n "$OUTPUT_FILE" ]; then
    echo "" >> "$OUTPUT_FILE"
    echo "# Summary" >> "$OUTPUT_FILE"
    echo "# -------" >> "$OUTPUT_FILE"
    echo "# Server: $SERVER" >> "$OUTPUT_FILE"
    echo "# Ports scanned: $total_ports" >> "$OUTPUT_FILE"
    echo "# Open ports found: $open_count" >> "$OUTPUT_FILE"
    
    if [ ${#open_ports[@]} -gt 0 ]; then
      echo -n "# Open ports: " >> "$OUTPUT_FILE"
      for i in "${!open_ports[@]}"; do
        if [ "$i" -gt 0 ]; then
          echo -n ", " >> "$OUTPUT_FILE"
        fi
        echo -n "${open_ports[$i]} (${open_services[$i]})" >> "$OUTPUT_FILE"
      done
      echo "" >> "$OUTPUT_FILE"
    else
      echo "# No open ports found." >> "$OUTPUT_FILE"
    fi
    
    echo "# Scan completed at $(date)" >> "$OUTPUT_FILE"
  fi
  
  return 0
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  setup_log_file

  print_with_separator "Port Scanner Script"
  format-echo "INFO" "Starting Port Scanner Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate server
  if [ -z "$SERVER" ]; then
    format-echo "ERROR" "Server is required."
    print_with_separator "End of Port Scanner Script"
    usage
  fi

  format-echo "INFO" "Checking if server $SERVER is reachable..."
  if ! ping -c 1 -W 1 "$SERVER" &> /dev/null; then
    format-echo "WARNING" "Cannot ping server $SERVER. Will attempt to scan anyway."
  else
    format-echo "SUCCESS" "Server $SERVER is reachable."
  fi

  # Validate port range
  if [ "$START_PORT" -gt "$END_PORT" ]; then
    format-echo "ERROR" "Start port ($START_PORT) is greater than end port ($END_PORT)."
    print_with_separator "End of Port Scanner Script"
    usage
  fi

  # Validate output file if provided
  if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
      format-echo "ERROR" "Cannot write to output file $OUTPUT_FILE."
      print_with_separator "End of Port Scanner Script"
      exit 1
    fi
    format-echo "INFO" "Scan results will be saved to $OUTPUT_FILE."
  fi

  #---------------------------------------------------------------------
  # PORT SCANNING OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Starting port scan on $SERVER..."
  
  if scan_ports; then
    if [ -n "$OUTPUT_FILE" ]; then
      format-echo "SUCCESS" "Port scan completed. Results have been written to $OUTPUT_FILE."
    else
      format-echo "SUCCESS" "Port scan completed. Results displayed above."
    fi
  else
    format-echo "ERROR" "Failed to scan ports on $SERVER."
    print_with_separator "End of Port Scanner Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Port scanning operation completed."
  print_with_separator "End of Port Scanner Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
