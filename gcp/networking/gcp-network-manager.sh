#!/usr/bin/env bash
# gcp-network-manager.sh
# Script to manage GCP networking resources - VPCs, subnets, firewall rules, and load balancers.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
PROJECT_ID=""
NETWORK_NAME=""
SUBNET_NAME=""
REGION="us-central1"
IP_RANGE=""
FIREWALL_RULE=""
SOURCE_RANGES=""
TARGET_TAGS=""
PORTS=""
PROTOCOL="tcp"
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Network Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP networking resources - VPCs, subnets, firewall rules."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-vpc\033[0m        Create a new VPC network"
  echo -e "  \033[1;33mdelete-vpc\033[0m        Delete a VPC network"
  echo -e "  \033[1;33mcreate-subnet\033[0m     Create a new subnet"
  echo -e "  \033[1;33mdelete-subnet\033[0m     Delete a subnet"
  echo -e "  \033[1;33mcreate-firewall\033[0m   Create a firewall rule"
  echo -e "  \033[1;33mdelete-firewall\033[0m   Delete a firewall rule"
  echo -e "  \033[1;33mlist-networks\033[0m     List all VPC networks"
  echo -e "  \033[1;33mlist-subnets\033[0m      List all subnets"
  echo -e "  \033[1;33mlist-firewall\033[0m     List all firewall rules"
  echo -e "  \033[1;33mnetwork-info\033[0m      Show detailed network information"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--network <name>\033[0m             (Required for most actions) VPC network name"
  echo -e "  \033[1;33m--subnet <name>\033[0m              (Required for subnet actions) Subnet name"
  echo -e "  \033[1;33m--region <region>\033[0m            (Optional) Region (default: us-central1)"
  echo -e "  \033[1;33m--ip-range <cidr>\033[0m            (Required for subnet) IP range in CIDR notation"
  echo -e "  \033[1;33m--firewall-rule <name>\033[0m       (Required for firewall actions) Firewall rule name"
  echo -e "  \033[1;33m--source-ranges <ranges>\033[0m     (Optional) Source IP ranges (comma-separated)"
  echo -e "  \033[1;33m--target-tags <tags>\033[0m         (Optional) Target tags (comma-separated)"
  echo -e "  \033[1;33m--ports <ports>\033[0m              (Optional) Ports (comma-separated)"
  echo -e "  \033[1;33m--protocol <protocol>\033[0m        (Optional) Protocol: tcp, udp, icmp (default: tcp)"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force deletion without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-networks --project my-project"
  echo "  $0 create-vpc --project my-project --network my-vpc"
  echo "  $0 create-subnet --project my-project --network my-vpc --subnet my-subnet --region us-west1 --ip-range 10.0.1.0/24"
  echo "  $0 create-firewall --project my-project --network my-vpc --firewall-rule allow-http --ports 80,443 --source-ranges 0.0.0.0/0"
  echo "  $0 delete-vpc --project my-project --network my-vpc --force"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  if [[ "$#" -eq 0 ]]; then
    usage
  fi
  
  ACTION="$1"
  shift
  
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
      --project)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No project ID provided after --project."
          usage
        fi
        PROJECT_ID="$2"
        shift 2
        ;;
      --network)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No network name provided after --network."
          usage
        fi
        NETWORK_NAME="$2"
        shift 2
        ;;
      --subnet)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No subnet name provided after --subnet."
          usage
        fi
        SUBNET_NAME="$2"
        shift 2
        ;;
      --region)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No region provided after --region."
          usage
        fi
        REGION="$2"
        shift 2
        ;;
      --ip-range)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No IP range provided after --ip-range."
          usage
        fi
        IP_RANGE="$2"
        shift 2
        ;;
      --firewall-rule)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No firewall rule name provided after --firewall-rule."
          usage
        fi
        FIREWALL_RULE="$2"
        shift 2
        ;;
      --source-ranges)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source ranges provided after --source-ranges."
          usage
        fi
        SOURCE_RANGES="$2"
        shift 2
        ;;
      --target-tags)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No target tags provided after --target-tags."
          usage
        fi
        TARGET_TAGS="$2"
        shift 2
        ;;
      --ports)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No ports provided after --ports."
          usage
        fi
        PORTS="$2"
        shift 2
        ;;
      --protocol)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No protocol provided after --protocol."
          usage
        fi
        PROTOCOL="$2"
        shift 2
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Function to check dependencies
check_dependencies() {
  if ! command_exists gcloud; then
    format-echo "ERROR" "gcloud CLI is required but not installed."
    format-echo "INFO" "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  return 0
}

# Function to validate authentication
validate_auth() {
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    format-echo "ERROR" "No active GCP authentication found."
    format-echo "INFO" "Please run: gcloud auth login"
    return 1
  fi
  return 0
}

#=====================================================================
# VPC FUNCTIONS
#=====================================================================
# Function to create VPC
create_vpc() {
  local project="$1"
  local network="$2"
  
  format-echo "INFO" "Creating VPC network: $network"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create VPC network: $network"
    return 0
  fi
  
  if ! gcloud compute networks create "$network" \
    --project="$project" \
    --subnet-mode=custom \
    --bgp-routing-mode=regional; then
    format-echo "ERROR" "Failed to create VPC network: $network"
    return 1
  fi
  
  format-echo "SUCCESS" "Created VPC network: $network"
  return 0
}

# Function to delete VPC
delete_vpc() {
  local project="$1"
  local network="$2"
  
  # Confirmation unless forced
  if [ "$FORCE" = false ]; then
    echo
    format-echo "WARNING" "This will permanently delete VPC network: $network"
    format-echo "WARNING" "All subnets and resources in this network will be affected!"
    echo
    read -p "Are you sure you want to delete this VPC? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      format-echo "INFO" "VPC deletion cancelled"
      return 0
    fi
  fi
  
  format-echo "INFO" "Deleting VPC network: $network"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete VPC network: $network"
    return 0
  fi
  
  if ! gcloud compute networks delete "$network" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete VPC network: $network"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted VPC network: $network"
  return 0
}

# Function to list networks
list_networks() {
  local project="$1"
  
  format-echo "INFO" "Listing VPC networks in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list VPC networks"
    return 0
  fi
  
  if ! gcloud compute networks list \
    --project="$project" \
    --format="table(name,subnet_mode,bgp_routing_mode,IPV4_RANGE)"; then
    format-echo "ERROR" "Failed to list VPC networks"
    return 1
  fi
  
  return 0
}

#=====================================================================
# SUBNET FUNCTIONS
#=====================================================================
# Function to create subnet
create_subnet() {
  local project="$1"
  local network="$2"
  local subnet="$3"
  local region="$4"
  local ip_range="$5"
  
  format-echo "INFO" "Creating subnet: $subnet in network: $network"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create subnet:"
    format-echo "INFO" "  Name: $subnet"
    format-echo "INFO" "  Network: $network"
    format-echo "INFO" "  Region: $region"
    format-echo "INFO" "  IP Range: $ip_range"
    return 0
  fi
  
  if ! gcloud compute networks subnets create "$subnet" \
    --project="$project" \
    --network="$network" \
    --region="$region" \
    --range="$ip_range"; then
    format-echo "ERROR" "Failed to create subnet: $subnet"
    return 1
  fi
  
  format-echo "SUCCESS" "Created subnet: $subnet"
  return 0
}

# Function to delete subnet
delete_subnet() {
  local project="$1"
  local subnet="$2"
  local region="$3"
  
  format-echo "INFO" "Deleting subnet: $subnet"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete subnet: $subnet"
    return 0
  fi
  
  if ! gcloud compute networks subnets delete "$subnet" \
    --project="$project" \
    --region="$region" \
    --quiet; then
    format-echo "ERROR" "Failed to delete subnet: $subnet"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted subnet: $subnet"
  return 0
}

# Function to list subnets
list_subnets() {
  local project="$1"
  
  format-echo "INFO" "Listing subnets in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list subnets"
    return 0
  fi
  
  if ! gcloud compute networks subnets list \
    --project="$project" \
    --format="table(name,region,network,RANGE)"; then
    format-echo "ERROR" "Failed to list subnets"
    return 1
  fi
  
  return 0
}

#=====================================================================
# FIREWALL FUNCTIONS
#=====================================================================
# Function to create firewall rule
create_firewall() {
  local project="$1"
  local network="$2"
  local rule="$3"
  
  format-echo "INFO" "Creating firewall rule: $rule"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create firewall rule:"
    format-echo "INFO" "  Name: $rule"
    format-echo "INFO" "  Network: $network"
    format-echo "INFO" "  Protocol: $PROTOCOL"
    [ -n "$PORTS" ] && format-echo "INFO" "  Ports: $PORTS"
    [ -n "$SOURCE_RANGES" ] && format-echo "INFO" "  Source Ranges: $SOURCE_RANGES"
    [ -n "$TARGET_TAGS" ] && format-echo "INFO" "  Target Tags: $TARGET_TAGS"
    return 0
  fi
  
  # Build firewall create command
  local fw_cmd="gcloud compute firewall-rules create $rule"
  fw_cmd+=" --project=$project"
  fw_cmd+=" --network=$network"
  fw_cmd+=" --action=ALLOW"
  fw_cmd+=" --rules=$PROTOCOL"
  
  if [ -n "$PORTS" ]; then
    fw_cmd+=":$PORTS"
  fi
  
  if [ -n "$SOURCE_RANGES" ]; then
    fw_cmd+=" --source-ranges=$SOURCE_RANGES"
  fi
  
  if [ -n "$TARGET_TAGS" ]; then
    fw_cmd+=" --target-tags=$TARGET_TAGS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $fw_cmd"
  fi
  
  if ! eval "$fw_cmd"; then
    format-echo "ERROR" "Failed to create firewall rule: $rule"
    return 1
  fi
  
  format-echo "SUCCESS" "Created firewall rule: $rule"
  return 0
}

# Function to delete firewall rule
delete_firewall() {
  local project="$1"
  local rule="$2"
  
  format-echo "INFO" "Deleting firewall rule: $rule"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete firewall rule: $rule"
    return 0
  fi
  
  if ! gcloud compute firewall-rules delete "$rule" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete firewall rule: $rule"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted firewall rule: $rule"
  return 0
}

# Function to list firewall rules
list_firewall() {
  local project="$1"
  
  format-echo "INFO" "Listing firewall rules in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list firewall rules"
    return 0
  fi
  
  if ! gcloud compute firewall-rules list \
    --project="$project" \
    --format="table(name,network,direction,priority,sourceRanges:label=SRC_RANGES,allowed[].map().firewall_rule().list():label=ALLOW,targetTags.list():label=TARGET_TAGS)"; then
    format-echo "ERROR" "Failed to list firewall rules"
    return 1
  fi
  
  return 0
}

# Function to show network information
show_network_info() {
  local project="$1"
  local network="$2"
  
  format-echo "INFO" "Getting information for network: $network"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would show info for network: $network"
    return 0
  fi
  
  # Network details
  echo
  format-echo "INFO" "Network Details:"
  if ! gcloud compute networks describe "$network" --project="$project"; then
    format-echo "ERROR" "Failed to get network details"
    return 1
  fi
  
  # Associated subnets
  echo
  format-echo "INFO" "Associated Subnets:"
  if ! gcloud compute networks subnets list \
    --project="$project" \
    --filter="network:$network" \
    --format="table(name,region,RANGE)"; then
    format-echo "WARNING" "Could not list subnets for network"
  fi
  
  # Associated firewall rules
  if [ "$VERBOSE" = true ]; then
    echo
    format-echo "INFO" "Associated Firewall Rules:"
    if ! gcloud compute firewall-rules list \
      --project="$project" \
      --filter="network:$network" \
      --format="table(name,direction,priority,sourceRanges.list():label=SRC_RANGES,allowed[].map().firewall_rule().list():label=ALLOW)"; then
      format-echo "WARNING" "Could not list firewall rules for network"
    fi
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
  
  print_with_separator "GCP Network Manager Script"
  format-echo "INFO" "Starting GCP Network Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Network Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Network Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Network Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-vpc|delete-vpc|network-info)
      if [ -z "$NETWORK_NAME" ]; then
        format-echo "ERROR" "Network name is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-subnet|delete-subnet)
      if [ -z "$NETWORK_NAME" ] || [ -z "$SUBNET_NAME" ]; then
        format-echo "ERROR" "Network and subnet names are required for action: $ACTION"
        exit 1
      fi
      if [[ "$ACTION" == "create-subnet" && -z "$IP_RANGE" ]]; then
        format-echo "ERROR" "IP range is required for creating subnet"
        exit 1
      fi
      ;;
    create-firewall|delete-firewall)
      if [ -z "$FIREWALL_RULE" ]; then
        format-echo "ERROR" "Firewall rule name is required for action: $ACTION"
        exit 1
      fi
      if [[ "$ACTION" == "create-firewall" && -z "$NETWORK_NAME" ]]; then
        format-echo "ERROR" "Network name is required for creating firewall rule"
        exit 1
      fi
      ;;
    list-networks|list-subnets|list-firewall)
      # No additional requirements for list actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-vpc, delete-vpc, create-subnet, delete-subnet, create-firewall, delete-firewall, list-networks, list-subnets, list-firewall, network-info"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-vpc)
      if create_vpc "$PROJECT_ID" "$NETWORK_NAME"; then
        format-echo "SUCCESS" "VPC management completed successfully"
      else
        format-echo "ERROR" "Failed to create VPC"
        exit 1
      fi
      ;;
    delete-vpc)
      if delete_vpc "$PROJECT_ID" "$NETWORK_NAME"; then
        format-echo "SUCCESS" "VPC management completed successfully"
      else
        format-echo "ERROR" "Failed to delete VPC"
        exit 1
      fi
      ;;
    create-subnet)
      if create_subnet "$PROJECT_ID" "$NETWORK_NAME" "$SUBNET_NAME" "$REGION" "$IP_RANGE"; then
        format-echo "SUCCESS" "Subnet management completed successfully"
      else
        format-echo "ERROR" "Failed to create subnet"
        exit 1
      fi
      ;;
    delete-subnet)
      if delete_subnet "$PROJECT_ID" "$SUBNET_NAME" "$REGION"; then
        format-echo "SUCCESS" "Subnet management completed successfully"
      else
        format-echo "ERROR" "Failed to delete subnet"
        exit 1
      fi
      ;;
    create-firewall)
      if create_firewall "$PROJECT_ID" "$NETWORK_NAME" "$FIREWALL_RULE"; then
        format-echo "SUCCESS" "Firewall management completed successfully"
      else
        format-echo "ERROR" "Failed to create firewall rule"
        exit 1
      fi
      ;;
    delete-firewall)
      if delete_firewall "$PROJECT_ID" "$FIREWALL_RULE"; then
        format-echo "SUCCESS" "Firewall management completed successfully"
      else
        format-echo "ERROR" "Failed to delete firewall rule"
        exit 1
      fi
      ;;
    list-networks)
      if list_networks "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed networks successfully"
      else
        format-echo "ERROR" "Failed to list networks"
        exit 1
      fi
      ;;
    list-subnets)
      if list_subnets "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed subnets successfully"
      else
        format-echo "ERROR" "Failed to list subnets"
        exit 1
      fi
      ;;
    list-firewall)
      if list_firewall "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed firewall rules successfully"
      else
        format-echo "ERROR" "Failed to list firewall rules"
        exit 1
      fi
      ;;
    network-info)
      if show_network_info "$PROJECT_ID" "$NETWORK_NAME"; then
        format-echo "SUCCESS" "Retrieved network information successfully"
      else
        format-echo "ERROR" "Failed to get network information"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Network Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
