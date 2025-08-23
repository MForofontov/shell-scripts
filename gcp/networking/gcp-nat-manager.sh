#!/usr/bin/env bash
# gcp-nat-manager.sh
# Script to manage Google Cloud NAT

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"

#=====================================================================
# DEFAULT VALUES
#=====================================================================
PROJECT_ID=""
COMMAND=""
NAT_GATEWAY=""
ROUTER=""
REGION=""
NETWORK=""
SUBNET=""
NAT_IP_ALLOCATE_OPTION=""
NAT_IPS=""
MIN_PORTS_PER_VM=""
MAX_PORTS_PER_VM=""
UDP_IDLE_TIMEOUT=""
TCP_ESTABLISHED_IDLE_TIMEOUT=""
ICMP_IDLE_TIMEOUT=""
LOG_CONFIG=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud NAT Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud NAT for network address translation."
  echo "  Provides capabilities for managing NAT gateways, routers, and NAT policies."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-n, --nat-gateway NAME\033[0m      Set NAT gateway name"
  echo -e "  \033[1;33m-r, --router ROUTER\033[0m         Set router name"
  echo -e "  \033[1;33m--region REGION\033[0m             Set region"
  echo -e "  \033[1;33m--network NETWORK\033[0m           Set network name"
  echo -e "  \033[1;33m--subnet SUBNET\033[0m             Set subnet name"
  echo -e "  \033[1;33m--nat-ip-allocate OPTION\033[0m    Set NAT IP allocation (AUTO_ONLY, MANUAL_ONLY)"
  echo -e "  \033[1;33m--nat-ips IPS\033[0m               Set comma-separated list of NAT IP addresses"
  echo -e "  \033[1;33m--min-ports-per-vm NUM\033[0m      Set minimum ports per VM"
  echo -e "  \033[1;33m--max-ports-per-vm NUM\033[0m      Set maximum ports per VM"
  echo -e "  \033[1;33m--udp-idle-timeout SEC\033[0m      Set UDP idle timeout"
  echo -e "  \033[1;33m--tcp-idle-timeout SEC\033[0m      Set TCP established idle timeout"
  echo -e "  \033[1;33m--icmp-idle-timeout SEC\033[0m     Set ICMP idle timeout"
  echo -e "  \033[1;33m--log-config CONFIG\033[0m         Set logging configuration"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate-router\033[0m               Create Cloud Router"
  echo -e "  \033[1;36mcreate-nat\033[0m                  Create NAT gateway"
  echo -e "  \033[1;36mlist-routers\033[0m                List Cloud Routers"
  echo -e "  \033[1;36mlist-nats\033[0m                   List NAT gateways"
  echo -e "  \033[1;36mget-router\033[0m                  Get router details"
  echo -e "  \033[1;36mget-nat\033[0m                     Get NAT gateway details"
  echo -e "  \033[1;36mupdate-nat\033[0m                  Update NAT gateway configuration"
  echo -e "  \033[1;36mdelete-nat\033[0m                  Delete NAT gateway"
  echo -e "  \033[1;36mdelete-router\033[0m               Delete Cloud Router"
  echo -e "  \033[1;36mget-nat-mapping\033[0m             Get NAT IP mapping information"
  echo -e "  \033[1;36mget-nat-stats\033[0m               Get NAT usage statistics"
  echo -e "  \033[1;36mstatus\033[0m                      Check NAT status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Compute Engine API"
  echo -e "  \033[1;36mget-config\033[0m                  Get NAT configuration"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project --region us-central1 --network my-vpc create-router"
  echo "  $0 -p my-project -r my-router --region us-central1 create-nat"
  echo "  $0 -p my-project --region us-central1 list-nats"
  echo "  $0 -p my-project -n my-nat -r my-router --region us-central1 get-nat"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -p|--project)
        if [[ -n "${2:-}" ]]; then
          PROJECT_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --project"
          usage
        fi
        ;;
      -n|--nat-gateway)
        if [[ -n "${2:-}" ]]; then
          NAT_GATEWAY="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --nat-gateway"
          usage
        fi
        ;;
      -r|--router)
        if [[ -n "${2:-}" ]]; then
          ROUTER="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --router"
          usage
        fi
        ;;
      --region)
        if [[ -n "${2:-}" ]]; then
          REGION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --region"
          usage
        fi
        ;;
      --network)
        if [[ -n "${2:-}" ]]; then
          NETWORK="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --network"
          usage
        fi
        ;;
      --subnet)
        if [[ -n "${2:-}" ]]; then
          SUBNET="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --subnet"
          usage
        fi
        ;;
      --nat-ip-allocate)
        if [[ -n "${2:-}" ]]; then
          NAT_IP_ALLOCATE_OPTION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --nat-ip-allocate"
          usage
        fi
        ;;
      --nat-ips)
        if [[ -n "${2:-}" ]]; then
          NAT_IPS="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --nat-ips"
          usage
        fi
        ;;
      --min-ports-per-vm)
        if [[ -n "${2:-}" ]]; then
          MIN_PORTS_PER_VM="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --min-ports-per-vm"
          usage
        fi
        ;;
      --max-ports-per-vm)
        if [[ -n "${2:-}" ]]; then
          MAX_PORTS_PER_VM="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --max-ports-per-vm"
          usage
        fi
        ;;
      --udp-idle-timeout)
        if [[ -n "${2:-}" ]]; then
          UDP_IDLE_TIMEOUT="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --udp-idle-timeout"
          usage
        fi
        ;;
      --tcp-idle-timeout)
        if [[ -n "${2:-}" ]]; then
          TCP_ESTABLISHED_IDLE_TIMEOUT="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --tcp-idle-timeout"
          usage
        fi
        ;;
      --icmp-idle-timeout)
        if [[ -n "${2:-}" ]]; then
          ICMP_IDLE_TIMEOUT="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --icmp-idle-timeout"
          usage
        fi
        ;;
      --log-config)
        if [[ -n "${2:-}" ]]; then
          LOG_CONFIG="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --log-config"
          usage
        fi
        ;;
      -h|--help)
        usage
        ;;
      *)
        if [[ -z "$COMMAND" ]]; then
          COMMAND="$1"
          shift
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

#=====================================================================
# AUTHENTICATION AND PROJECT SETUP
#=====================================================================
check_auth() {
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    format-echo "ERROR" "Not authenticated with gcloud. Please run 'gcloud auth login'"
    exit 1
  fi
}

set_project() {
  if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [[ -z "$PROJECT_ID" ]]; then
      format-echo "ERROR" "No project set. Use -p flag or run 'gcloud config set project PROJECT_ID'"
      exit 1
    fi
  fi
  
  format-echo "INFO" "Using project: $PROJECT_ID"
  gcloud config set project "$PROJECT_ID" >/dev/null 2>&1
}

enable_apis() {
  format-echo "INFO" "Enabling required APIs..."
  
  local apis=(
    "compute.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# CLOUD NAT OPERATIONS
#=====================================================================
create_router() {
  format-echo "INFO" "Creating Cloud Router..."
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required"
    exit 1
  fi
  
  if [[ -z "$ROUTER" ]]; then
    ROUTER="nat-router-$(date +%s)"
    format-echo "INFO" "Using default router name: $ROUTER"
  fi
  
  if [[ -z "$NETWORK" ]]; then
    NETWORK="default"
    format-echo "INFO" "Using default network: $NETWORK"
  fi
  
  gcloud compute routers create "$ROUTER" \
    --network="$NETWORK" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Cloud Router '$ROUTER' created in region '$REGION'"
}

create_nat() {
  format-echo "INFO" "Creating NAT gateway..."
  
  if [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Router name and region are required"
    exit 1
  fi
  
  if [[ -z "$NAT_GATEWAY" ]]; then
    NAT_GATEWAY="nat-gateway-$(date +%s)"
    format-echo "INFO" "Using default NAT gateway name: $NAT_GATEWAY"
  fi
  
  local cmd="gcloud compute routers nats create '$NAT_GATEWAY'"
  cmd="$cmd --router='$ROUTER'"
  cmd="$cmd --region='$REGION'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  # Configure NAT IP allocation
  if [[ -n "$NAT_IP_ALLOCATE_OPTION" ]]; then
    cmd="$cmd --nat-external-ip-pool='$NAT_IP_ALLOCATE_OPTION'"
  else
    cmd="$cmd --nat-external-ip-pool=AUTO_ONLY"
  fi
  
  # Add specific NAT IPs if provided
  if [[ -n "$NAT_IPS" ]]; then
    cmd="$cmd --nat-external-ip-pool=MANUAL_ONLY"
    cmd="$cmd --nat-external-ips='$NAT_IPS'"
  fi
  
  # Configure subnet settings
  if [[ -n "$SUBNET" ]]; then
    cmd="$cmd --nat-custom-subnet-ip-ranges='$SUBNET'"
  else
    cmd="$cmd --nat-all-subnet-ip-ranges"
  fi
  
  # Configure port allocation
  if [[ -n "$MIN_PORTS_PER_VM" ]]; then
    cmd="$cmd --min-ports-per-vm='$MIN_PORTS_PER_VM'"
  fi
  
  if [[ -n "$MAX_PORTS_PER_VM" ]]; then
    cmd="$cmd --max-ports-per-vm='$MAX_PORTS_PER_VM'"
  fi
  
  # Configure timeouts
  if [[ -n "$UDP_IDLE_TIMEOUT" ]]; then
    cmd="$cmd --udp-idle-timeout='$UDP_IDLE_TIMEOUT'"
  fi
  
  if [[ -n "$TCP_ESTABLISHED_IDLE_TIMEOUT" ]]; then
    cmd="$cmd --tcp-established-idle-timeout='$TCP_ESTABLISHED_IDLE_TIMEOUT'"
  fi
  
  if [[ -n "$ICMP_IDLE_TIMEOUT" ]]; then
    cmd="$cmd --icmp-idle-timeout='$ICMP_IDLE_TIMEOUT'"
  fi
  
  # Configure logging
  if [[ -n "$LOG_CONFIG" ]]; then
    cmd="$cmd --enable-logging"
    cmd="$cmd --log-filter='$LOG_CONFIG'"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "NAT gateway '$NAT_GATEWAY' created on router '$ROUTER'"
}

list_routers() {
  format-echo "INFO" "Listing Cloud Routers..."
  
  print_with_separator "Cloud Routers"
  
  if [[ -n "$REGION" ]]; then
    gcloud compute routers list \
      --project="$PROJECT_ID" \
      --filter="region:($REGION)" \
      --format="table(name,region,network)"
  else
    gcloud compute routers list \
      --project="$PROJECT_ID" \
      --format="table(name,region,network)"
  fi
  
  print_with_separator "End of Routers"
}

list_nats() {
  format-echo "INFO" "Listing NAT gateways..."
  
  print_with_separator "NAT Gateways"
  
  if [[ -n "$REGION" ]]; then
    if [[ -n "$ROUTER" ]]; then
      gcloud compute routers nats list \
        --router="$ROUTER" \
        --region="$REGION" \
        --project="$PROJECT_ID"
    else
      # List all routers in region and their NATs
      local routers
      routers=$(gcloud compute routers list --project="$PROJECT_ID" --filter="region:($REGION)" --format="value(name)")
      for router in $routers; do
        echo "Router: $router"
        gcloud compute routers nats list \
          --router="$router" \
          --region="$REGION" \
          --project="$PROJECT_ID" \
          --format="table(name,natIpAllocateOption,sourceSubnetworkIpRangesToNat)" || true
        echo
      done
    fi
  else
    format-echo "ERROR" "Region is required to list NAT gateways"
    exit 1
  fi
  
  print_with_separator "End of NAT Gateways"
}

get_router() {
  format-echo "INFO" "Getting router details..."
  
  if [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Router name and region are required"
    exit 1
  fi
  
  print_with_separator "Router: $ROUTER"
  gcloud compute routers describe "$ROUTER" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  print_with_separator "End of Router Details"
}

get_nat() {
  format-echo "INFO" "Getting NAT gateway details..."
  
  if [[ -z "$NAT_GATEWAY" ]] || [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "NAT gateway name, router name, and region are required"
    exit 1
  fi
  
  print_with_separator "NAT Gateway: $NAT_GATEWAY"
  gcloud compute routers nats describe "$NAT_GATEWAY" \
    --router="$ROUTER" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  print_with_separator "End of NAT Gateway Details"
}

update_nat() {
  format-echo "INFO" "Updating NAT gateway configuration..."
  
  if [[ -z "$NAT_GATEWAY" ]] || [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "NAT gateway name, router name, and region are required"
    exit 1
  fi
  
  local cmd="gcloud compute routers nats update '$NAT_GATEWAY'"
  cmd="$cmd --router='$ROUTER'"
  cmd="$cmd --region='$REGION'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  # Update port allocation if specified
  if [[ -n "$MIN_PORTS_PER_VM" ]]; then
    cmd="$cmd --min-ports-per-vm='$MIN_PORTS_PER_VM'"
  fi
  
  if [[ -n "$MAX_PORTS_PER_VM" ]]; then
    cmd="$cmd --max-ports-per-vm='$MAX_PORTS_PER_VM'"
  fi
  
  # Update timeouts if specified
  if [[ -n "$UDP_IDLE_TIMEOUT" ]]; then
    cmd="$cmd --udp-idle-timeout='$UDP_IDLE_TIMEOUT'"
  fi
  
  if [[ -n "$TCP_ESTABLISHED_IDLE_TIMEOUT" ]]; then
    cmd="$cmd --tcp-established-idle-timeout='$TCP_ESTABLISHED_IDLE_TIMEOUT'"
  fi
  
  if [[ -n "$ICMP_IDLE_TIMEOUT" ]]; then
    cmd="$cmd --icmp-idle-timeout='$ICMP_IDLE_TIMEOUT'"
  fi
  
  # Update logging if specified
  if [[ -n "$LOG_CONFIG" ]]; then
    cmd="$cmd --enable-logging"
    cmd="$cmd --log-filter='$LOG_CONFIG'"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "NAT gateway '$NAT_GATEWAY' updated"
}

delete_nat() {
  format-echo "INFO" "Deleting NAT gateway..."
  
  if [[ -z "$NAT_GATEWAY" ]] || [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "NAT gateway name, router name, and region are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete NAT gateway '$NAT_GATEWAY'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute routers nats delete "$NAT_GATEWAY" \
    --router="$ROUTER" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
  
  format-echo "SUCCESS" "NAT gateway '$NAT_GATEWAY' deleted"
}

delete_router() {
  format-echo "INFO" "Deleting Cloud Router..."
  
  if [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Router name and region are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete router '$ROUTER' and all associated NAT gateways"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute routers delete "$ROUTER" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
  
  format-echo "SUCCESS" "Cloud Router '$ROUTER' deleted"
}

get_nat_mapping() {
  format-echo "INFO" "Getting NAT IP mapping information..."
  
  if [[ -z "$NAT_GATEWAY" ]] || [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "NAT gateway name, router name, and region are required"
    exit 1
  fi
  
  print_with_separator "NAT IP Mapping: $NAT_GATEWAY"
  
  # Get NAT gateway details to show IP mappings
  gcloud compute routers nats describe "$NAT_GATEWAY" \
    --router="$ROUTER" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="yaml(natIps,natIpAllocateOption)"
  
  print_with_separator "End of NAT IP Mapping"
}

get_nat_stats() {
  format-echo "INFO" "Getting NAT usage statistics..."
  
  if [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Router name and region are required"
    exit 1
  fi
  
  print_with_separator "NAT Usage Statistics"
  
  # Note: Detailed NAT statistics are available through Cloud Monitoring
  format-echo "INFO" "Router: $ROUTER"
  format-echo "INFO" "Region: $REGION"
  
  echo
  echo "To view detailed NAT statistics:"
  echo "1. Go to Cloud Monitoring: https://console.cloud.google.com/monitoring"
  echo "2. Navigate to Metrics Explorer"
  echo "3. Select resource type: NAT Gateway"
  echo "4. Select metrics:"
  echo "   - router.googleapis.com/nat/allocated_ports"
  echo "   - router.googleapis.com/nat/port_usage"
  echo "   - router.googleapis.com/nat/dropped_sent_packets_count"
  echo "   - router.googleapis.com/nat/received_packets_count"
  echo "   - router.googleapis.com/nat/sent_packets_count"
  
  # Show current NAT gateway configuration
  if [[ -n "$NAT_GATEWAY" ]]; then
    echo
    echo "Current NAT Gateway Configuration:"
    gcloud compute routers nats describe "$NAT_GATEWAY" \
      --router="$ROUTER" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --format="table(name,minPortsPerVm,maxPortsPerVm,udpIdleTimeoutSec,tcpEstablishedIdleTimeoutSec)" || true
  fi
  
  print_with_separator "End of NAT Statistics"
}

check_status() {
  format-echo "INFO" "Checking NAT status..."
  
  print_with_separator "Cloud NAT Status"
  
  # Check if Compute Engine API is enabled
  if gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q "compute"; then
    format-echo "SUCCESS" "Compute Engine API is enabled"
  else
    format-echo "WARNING" "Compute Engine API is not enabled"
  fi
  
  # Count routers
  local router_count
  router_count=$(gcloud compute routers list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Total routers: $router_count"
  
  # Count NAT gateways by region
  if [[ -n "$REGION" ]]; then
    local nat_count=0
    local routers
    routers=$(gcloud compute routers list --project="$PROJECT_ID" --filter="region:($REGION)" --format="value(name)" 2>/dev/null)
    for router in $routers; do
      local router_nats
      router_nats=$(gcloud compute routers nats list --router="$router" --region="$REGION" --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | wc -l || echo "0")
      nat_count=$((nat_count + router_nats))
    done
    format-echo "INFO" "NAT gateways in $REGION: $nat_count"
  fi
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling Compute Engine API..."
  enable_apis
  format-echo "SUCCESS" "Compute Engine API enabled"
}

get_config() {
  format-echo "INFO" "Getting NAT configuration..."
  
  print_with_separator "Cloud NAT Configuration"
  
  # Display project info
  format-echo "INFO" "Project: $PROJECT_ID"
  
  # Check API status
  if gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q "compute"; then
    format-echo "SUCCESS" "API Status: Enabled"
  else
    format-echo "WARNING" "API Status: Disabled"
  fi
  
  # Display configuration info
  echo
  echo "NAT Configuration Options:"
  echo "- NAT IP Allocation: AUTO_ONLY, MANUAL_ONLY"
  echo "- Port Allocation: Min/Max ports per VM"
  echo "- Timeout Settings: UDP, TCP, ICMP idle timeouts"
  echo "- Subnet Configuration: All subnets or specific subnets"
  echo "- Logging: Enable/disable NAT gateway logging"
  echo
  echo "Default Settings:"
  echo "- Min Ports per VM: 64"
  echo "- Max Ports per VM: 65536"
  echo "- UDP Idle Timeout: 30s"
  echo "- TCP Established Idle Timeout: 1200s"
  echo "- ICMP Idle Timeout: 30s"
  echo
  echo "Cloud NAT Console URL:"
  echo "https://console.cloud.google.com/net-services/nat/list?project=$PROJECT_ID"
  
  print_with_separator "End of Configuration"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    create-router)
      enable_apis
      create_router
      ;;
    create-nat)
      create_nat
      ;;
    list-routers)
      list_routers
      ;;
    list-nats)
      list_nats
      ;;
    get-router)
      get_router
      ;;
    get-nat)
      get_nat
      ;;
    update-nat)
      update_nat
      ;;
    delete-nat)
      delete_nat
      ;;
    delete-router)
      delete_router
      ;;
    get-nat-mapping)
      get_nat_mapping
      ;;
    get-nat-stats)
      get_nat_stats
      ;;
    status)
      check_status
      ;;
    enable-api)
      enable_api
      ;;
    get-config)
      get_config
      ;;
    *)
      format-echo "ERROR" "Unknown command: $COMMAND"
      format-echo "INFO" "Use --help to see available commands"
      exit 1
      ;;
  esac
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"
  
  print_with_separator "GCP Cloud NAT Manager"
  format-echo "INFO" "Starting Cloud NAT management operations..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  if [[ -z "$COMMAND" ]]; then
    format-echo "ERROR" "Command is required."
    usage
  fi
  
  #---------------------------------------------------------------------
  # AUTHENTICATION AND SETUP
  #---------------------------------------------------------------------
  check_auth
  set_project
  
  #---------------------------------------------------------------------
  # COMMAND EXECUTION
  #---------------------------------------------------------------------
  execute_command
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "Cloud NAT management operation completed successfully."
  print_with_separator "End of GCP Cloud NAT Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
