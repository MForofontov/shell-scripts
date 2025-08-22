#!/usr/bin/env bash
# gcp-dns-manager.sh
# Script to manage GCP Cloud DNS zones, records, and DNS operations.

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
ZONE_NAME=""
ZONE_DNS_NAME=""
ZONE_DESCRIPTION=""
RECORD_NAME=""
RECORD_TYPE="A"
RECORD_TTL="300"
RECORD_DATA=""
RECORD_SET_IDENTIFIER=""
POLICY_NAME=""
NETWORK_NAME=""
VISIBILITY="public"
DNSSEC_STATE="off"
FORWARDING_PATH=""
ALTERNATE_NAME_SERVERS=""
PEERING_ZONE=""
TARGET_NETWORK=""
SOURCE_RANGE=""
TARGET_NAME_SERVERS=""
ROUTING_POLICY=""
GEO_LOCATION=""
WEIGHTED_ROUTING_POLICY=""
BACKUP_FILE=""
TRANSACTION_FILE=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud DNS Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Cloud DNS zones, records, and DNS operations."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-zone\033[0m              Create a DNS zone"
  echo -e "  \033[1;33mdelete-zone\033[0m              Delete a DNS zone"
  echo -e "  \033[1;33mlist-zones\033[0m               List all DNS zones"
  echo -e "  \033[1;33mget-zone\033[0m                 Get DNS zone details"
  echo -e "  \033[1;33mupdate-zone\033[0m              Update DNS zone settings"
  echo -e "  \033[1;33mcreate-record\033[0m            Create a DNS record"
  echo -e "  \033[1;33mupdate-record\033[0m            Update a DNS record"
  echo -e "  \033[1;33mdelete-record\033[0m            Delete a DNS record"
  echo -e "  \033[1;33mlist-records\033[0m             List all records in zone"
  echo -e "  \033[1;33mget-record\033[0m               Get specific DNS record"
  echo -e "  \033[1;33mimport-zone-file\033[0m         Import records from zone file"
  echo -e "  \033[1;33mexport-zone-file\033[0m         Export zone to zone file"
  echo -e "  \033[1;33mstart-transaction\033[0m        Start DNS transaction"
  echo -e "  \033[1;33mcommit-transaction\033[0m       Commit DNS transaction"
  echo -e "  \033[1;33mabort-transaction\033[0m        Abort DNS transaction"
  echo -e "  \033[1;33mcreate-policy\033[0m            Create DNS policy"
  echo -e "  \033[1;33mdelete-policy\033[0m            Delete DNS policy"
  echo -e "  \033[1;33mlist-policies\033[0m            List DNS policies"
  echo -e "  \033[1;33mget-policy\033[0m               Get DNS policy details"
  echo -e "  \033[1;33mcreate-forwarding-zone\033[0m   Create DNS forwarding zone"
  echo -e "  \033[1;33mcreate-peering-zone\033[0m      Create DNS peering zone"
  echo -e "  \033[1;33menable-dnssec\033[0m            Enable DNSSEC for zone"
  echo -e "  \033[1;33mdisable-dnssec\033[0m           Disable DNSSEC for zone"
  echo -e "  \033[1;33mvalidate-zone\033[0m            Validate DNS zone configuration"
  echo -e "  \033[1;33mbackup-zone\033[0m              Backup DNS zone records"
  echo -e "  \033[1;33mrestore-zone\033[0m             Restore DNS zone from backup"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--zone <name>\033[0m                    (Required for zone actions) DNS zone name"
  echo -e "  \033[1;33m--dns-name <name>\033[0m                (Required for zone creation) DNS zone domain name"
  echo -e "  \033[1;33m--description <desc>\033[0m             (Optional) Zone description"
  echo -e "  \033[1;33m--record-name <name>\033[0m             (Required for record actions) Record name"
  echo -e "  \033[1;33m--record-type <type>\033[0m             (Optional) Record type: A, AAAA, CNAME, MX, TXT, etc. (default: A)"
  echo -e "  \033[1;33m--record-ttl <seconds>\033[0m           (Optional) Record TTL in seconds (default: 300)"
  echo -e "  \033[1;33m--record-data <data>\033[0m             (Required for record creation) Record data"
  echo -e "  \033[1;33m--visibility <type>\033[0m              (Optional) Zone visibility: public, private (default: public)"
  echo -e "  \033[1;33m--network <network>\033[0m              (Optional) VPC network for private zones"
  echo -e "  \033[1;33m--policy <name>\033[0m                  (Required for policy actions) DNS policy name"
  echo -e "  \033[1;33m--enable-dnssec\033[0m                  (Optional) Enable DNSSEC for zone"
  echo -e "  \033[1;33m--forwarding-path <path>\033[0m         (Optional) Forwarding path for forwarding zones"
  echo -e "  \033[1;33m--target-name-servers <servers>\033[0m  (Optional) Target name servers (comma-separated)"
  echo -e "  \033[1;33m--peering-zone <zone>\033[0m            (Optional) Peering zone name"
  echo -e "  \033[1;33m--target-network <network>\033[0m       (Optional) Target network for peering"
  echo -e "  \033[1;33m--source-range <range>\033[0m           (Optional) Source IP range for policy"
  echo -e "  \033[1;33m--geo-location <location>\033[0m        (Optional) Geographic location for routing"
  echo -e "  \033[1;33m--backup-file <file>\033[0m             (Optional) Backup file path"
  echo -e "  \033[1;33m--transaction-file <file>\033[0m        (Optional) Transaction file path"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mRecord Types:\033[0m"
  echo "  A, AAAA, CNAME, MX, NS, PTR, SOA, SPF, SRV, TXT"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-zones --project my-project"
  echo "  $0 create-zone --project my-project --zone my-zone --dns-name example.com. --description 'Example domain'"
  echo "  $0 create-record --project my-project --zone my-zone --record-name www.example.com. --record-type A --record-data 1.2.3.4"
  echo "  $0 create-policy --project my-project --policy my-policy --network default"
  echo "  $0 backup-zone --project my-project --zone my-zone --backup-file zone-backup.txt"
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
      --zone)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No zone name provided after --zone."
          usage
        fi
        ZONE_NAME="$2"
        shift 2
        ;;
      --dns-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No DNS name provided after --dns-name."
          usage
        fi
        ZONE_DNS_NAME="$2"
        shift 2
        ;;
      --description)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No description provided after --description."
          usage
        fi
        ZONE_DESCRIPTION="$2"
        shift 2
        ;;
      --record-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No record name provided after --record-name."
          usage
        fi
        RECORD_NAME="$2"
        shift 2
        ;;
      --record-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No record type provided after --record-type."
          usage
        fi
        RECORD_TYPE="$2"
        shift 2
        ;;
      --record-ttl)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No record TTL provided after --record-ttl."
          usage
        fi
        RECORD_TTL="$2"
        shift 2
        ;;
      --record-data)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No record data provided after --record-data."
          usage
        fi
        RECORD_DATA="$2"
        shift 2
        ;;
      --visibility)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No visibility provided after --visibility."
          usage
        fi
        VISIBILITY="$2"
        shift 2
        ;;
      --network)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No network provided after --network."
          usage
        fi
        NETWORK_NAME="$2"
        shift 2
        ;;
      --policy)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No policy name provided after --policy."
          usage
        fi
        POLICY_NAME="$2"
        shift 2
        ;;
      --target-name-servers)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No target name servers provided after --target-name-servers."
          usage
        fi
        TARGET_NAME_SERVERS="$2"
        shift 2
        ;;
      --peering-zone)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No peering zone provided after --peering-zone."
          usage
        fi
        PEERING_ZONE="$2"
        shift 2
        ;;
      --target-network)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No target network provided after --target-network."
          usage
        fi
        TARGET_NETWORK="$2"
        shift 2
        ;;
      --source-range)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source range provided after --source-range."
          usage
        fi
        SOURCE_RANGE="$2"
        shift 2
        ;;
      --geo-location)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No geo location provided after --geo-location."
          usage
        fi
        GEO_LOCATION="$2"
        shift 2
        ;;
      --backup-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No backup file provided after --backup-file."
          usage
        fi
        BACKUP_FILE="$2"
        shift 2
        ;;
      --transaction-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No transaction file provided after --transaction-file."
          usage
        fi
        TRANSACTION_FILE="$2"
        shift 2
        ;;
      --enable-dnssec)
        DNSSEC_STATE="on"
        shift
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

# Function to validate DNS name format
validate_dns_name() {
  local dns_name="$1"
  
  if [[ ! "$dns_name" =~ \.$  ]]; then
    format-echo "ERROR" "DNS name must end with a dot (.): $dns_name"
    return 1
  fi
  
  return 0
}

#=====================================================================
# ZONE MANAGEMENT
#=====================================================================
# Function to create DNS zone
create_zone() {
  local project="$1"
  local zone_name="$2"
  local dns_name="$3"
  
  format-echo "INFO" "Creating DNS zone: $zone_name"
  
  if ! validate_dns_name "$dns_name"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create DNS zone:"
    format-echo "INFO" "  Zone name: $zone_name"
    format-echo "INFO" "  DNS name: $dns_name"
    format-echo "INFO" "  Visibility: $VISIBILITY"
    return 0
  fi
  
  local create_cmd="gcloud dns managed-zones create $zone_name"
  create_cmd+=" --project=$project"
  create_cmd+=" --dns-name=$dns_name"
  create_cmd+=" --visibility=$VISIBILITY"
  
  if [ -n "$ZONE_DESCRIPTION" ]; then
    create_cmd+=" --description=\"$ZONE_DESCRIPTION\""
  fi
  
  if [ "$VISIBILITY" = "private" ] && [ -n "$NETWORK_NAME" ]; then
    create_cmd+=" --networks=$NETWORK_NAME"
  fi
  
  if [ "$DNSSEC_STATE" = "on" ]; then
    create_cmd+=" --dnssec-state=on"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create DNS zone: $zone_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created DNS zone: $zone_name"
  return 0
}

# Function to delete DNS zone
delete_zone() {
  local project="$1"
  local zone_name="$2"
  
  format-echo "INFO" "Deleting DNS zone: $zone_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete DNS zone: $zone_name"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the DNS zone '$zone_name' and all its records."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud dns managed-zones delete "$zone_name" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete DNS zone: $zone_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted DNS zone: $zone_name"
  return 0
}

# Function to list DNS zones
list_zones() {
  local project="$1"
  
  format-echo "INFO" "Listing DNS zones"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list DNS zones"
    return 0
  fi
  
  if ! gcloud dns managed-zones list \
    --project="$project" \
    --format="table(name,dnsName,visibility,dnssecConfig.state)"; then
    format-echo "ERROR" "Failed to list DNS zones"
    return 1
  fi
  
  return 0
}

# Function to get DNS zone details
get_zone() {
  local project="$1"
  local zone_name="$2"
  
  format-echo "INFO" "Getting details for DNS zone: $zone_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get DNS zone details: $zone_name"
    return 0
  fi
  
  if ! gcloud dns managed-zones describe "$zone_name" \
    --project="$project"; then
    format-echo "ERROR" "Failed to get DNS zone details: $zone_name"
    return 1
  fi
  
  return 0
}

#=====================================================================
# RECORD MANAGEMENT
#=====================================================================
# Function to create DNS record
create_record() {
  local project="$1"
  local zone_name="$2"
  local record_name="$3"
  local record_type="$4"
  local record_data="$5"
  
  format-echo "INFO" "Creating DNS record: $record_name"
  
  if ! validate_dns_name "$record_name"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create DNS record:"
    format-echo "INFO" "  Name: $record_name"
    format-echo "INFO" "  Type: $record_type"
    format-echo "INFO" "  Data: $record_data"
    format-echo "INFO" "  TTL: $RECORD_TTL"
    return 0
  fi
  
  if ! gcloud dns record-sets create "$record_name" \
    --project="$project" \
    --zone="$zone_name" \
    --type="$record_type" \
    --ttl="$RECORD_TTL" \
    --rrdatas="$record_data"; then
    format-echo "ERROR" "Failed to create DNS record: $record_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created DNS record: $record_name"
  return 0
}

# Function to update DNS record
update_record() {
  local project="$1"
  local zone_name="$2"
  local record_name="$3"
  local record_type="$4"
  local old_data="$5"
  local new_data="$6"
  
  format-echo "INFO" "Updating DNS record: $record_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would update DNS record:"
    format-echo "INFO" "  Name: $record_name"
    format-echo "INFO" "  Type: $record_type"
    format-echo "INFO" "  Old data: $old_data"
    format-echo "INFO" "  New data: $new_data"
    return 0
  fi
  
  # Start transaction
  if ! gcloud dns record-sets transaction start \
    --project="$project" \
    --zone="$zone_name"; then
    format-echo "ERROR" "Failed to start DNS transaction"
    return 1
  fi
  
  # Remove old record
  if ! gcloud dns record-sets transaction remove \
    --project="$project" \
    --zone="$zone_name" \
    --name="$record_name" \
    --type="$record_type" \
    --ttl="$RECORD_TTL" \
    "$old_data"; then
    format-echo "ERROR" "Failed to remove old record"
    gcloud dns record-sets transaction abort --project="$project" --zone="$zone_name" 2>/dev/null
    return 1
  fi
  
  # Add new record
  if ! gcloud dns record-sets transaction add \
    --project="$project" \
    --zone="$zone_name" \
    --name="$record_name" \
    --type="$record_type" \
    --ttl="$RECORD_TTL" \
    "$new_data"; then
    format-echo "ERROR" "Failed to add new record"
    gcloud dns record-sets transaction abort --project="$project" --zone="$zone_name" 2>/dev/null
    return 1
  fi
  
  # Execute transaction
  if ! gcloud dns record-sets transaction execute \
    --project="$project" \
    --zone="$zone_name"; then
    format-echo "ERROR" "Failed to execute DNS transaction"
    return 1
  fi
  
  format-echo "SUCCESS" "Updated DNS record: $record_name"
  return 0
}

# Function to delete DNS record
delete_record() {
  local project="$1"
  local zone_name="$2"
  local record_name="$3"
  local record_type="$4"
  local record_data="$5"
  
  format-echo "INFO" "Deleting DNS record: $record_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete DNS record: $record_name"
    return 0
  fi
  
  if ! gcloud dns record-sets delete "$record_name" \
    --project="$project" \
    --zone="$zone_name" \
    --type="$record_type"; then
    format-echo "ERROR" "Failed to delete DNS record: $record_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted DNS record: $record_name"
  return 0
}

# Function to list DNS records
list_records() {
  local project="$1"
  local zone_name="$2"
  
  format-echo "INFO" "Listing DNS records for zone: $zone_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list DNS records for zone: $zone_name"
    return 0
  fi
  
  if ! gcloud dns record-sets list \
    --project="$project" \
    --zone="$zone_name" \
    --format="table(name,type,ttl,rrdatas.list():label=DATA)"; then
    format-echo "ERROR" "Failed to list DNS records"
    return 1
  fi
  
  return 0
}

# Function to backup zone
backup_zone() {
  local project="$1"
  local zone_name="$2"
  local backup_file="$3"
  
  format-echo "INFO" "Backing up DNS zone: $zone_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would backup zone to: $backup_file"
    return 0
  fi
  
  if ! gcloud dns record-sets export "$backup_file" \
    --project="$project" \
    --zone="$zone_name" \
    --zone-file-format; then
    format-echo "ERROR" "Failed to backup DNS zone: $zone_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Backed up DNS zone to: $backup_file"
  return 0
}

# Function to restore zone
restore_zone() {
  local project="$1"
  local zone_name="$2"
  local backup_file="$3"
  
  format-echo "INFO" "Restoring DNS zone: $zone_name"
  
  if [ ! -f "$backup_file" ]; then
    format-echo "ERROR" "Backup file not found: $backup_file"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would restore zone from: $backup_file"
    return 0
  fi
  
  if ! gcloud dns record-sets import "$backup_file" \
    --project="$project" \
    --zone="$zone_name" \
    --zone-file-format \
    --delete-all-existing; then
    format-echo "ERROR" "Failed to restore DNS zone: $zone_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Restored DNS zone from: $backup_file"
  return 0
}

#=====================================================================
# POLICY MANAGEMENT
#=====================================================================
# Function to create DNS policy
create_policy() {
  local project="$1"
  local policy_name="$2"
  
  format-echo "INFO" "Creating DNS policy: $policy_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create DNS policy: $policy_name"
    return 0
  fi
  
  local create_cmd="gcloud dns policies create $policy_name"
  create_cmd+=" --project=$project"
  
  if [ -n "$NETWORK_NAME" ]; then
    create_cmd+=" --networks=$NETWORK_NAME"
  fi
  
  if [ -n "$TARGET_NAME_SERVERS" ]; then
    create_cmd+=" --alternative-name-servers=$TARGET_NAME_SERVERS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create DNS policy: $policy_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created DNS policy: $policy_name"
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
  
  print_with_separator "GCP Cloud DNS Manager Script"
  format-echo "INFO" "Starting GCP Cloud DNS Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Cloud DNS Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Cloud DNS Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Cloud DNS Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-zone)
      if [ -z "$ZONE_NAME" ] || [ -z "$ZONE_DNS_NAME" ]; then
        format-echo "ERROR" "Zone name and DNS name are required for action: $ACTION"
        exit 1
      fi
      ;;
    delete-zone|get-zone|list-records|backup-zone|restore-zone)
      if [ -z "$ZONE_NAME" ]; then
        format-echo "ERROR" "Zone name is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-record|update-record|delete-record)
      if [ -z "$ZONE_NAME" ] || [ -z "$RECORD_NAME" ]; then
        format-echo "ERROR" "Zone name and record name are required for action: $ACTION"
        exit 1
      fi
      if [ "$ACTION" = "create-record" ] && [ -z "$RECORD_DATA" ]; then
        format-echo "ERROR" "Record data is required for record creation"
        exit 1
      fi
      ;;
    backup-zone)
      if [ -z "$BACKUP_FILE" ]; then
        BACKUP_FILE="zone-${ZONE_NAME}-$(date +%Y%m%d-%H%M%S).txt"
      fi
      ;;
    restore-zone)
      if [ -z "$BACKUP_FILE" ]; then
        format-echo "ERROR" "Backup file is required for zone restoration"
        exit 1
      fi
      ;;
    list-zones|list-policies)
      # No additional requirements for these actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-zone, delete-zone, list-zones, create-record, update-record, delete-record, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-zone)
      if create_zone "$PROJECT_ID" "$ZONE_NAME" "$ZONE_DNS_NAME"; then
        format-echo "SUCCESS" "DNS zone creation completed successfully"
      else
        format-echo "ERROR" "Failed to create DNS zone"
        exit 1
      fi
      ;;
    delete-zone)
      if delete_zone "$PROJECT_ID" "$ZONE_NAME"; then
        format-echo "SUCCESS" "DNS zone deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete DNS zone"
        exit 1
      fi
      ;;
    list-zones)
      if list_zones "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed DNS zones successfully"
      else
        format-echo "ERROR" "Failed to list DNS zones"
        exit 1
      fi
      ;;
    get-zone)
      if get_zone "$PROJECT_ID" "$ZONE_NAME"; then
        format-echo "SUCCESS" "Retrieved DNS zone details successfully"
      else
        format-echo "ERROR" "Failed to get DNS zone details"
        exit 1
      fi
      ;;
    create-record)
      if create_record "$PROJECT_ID" "$ZONE_NAME" "$RECORD_NAME" "$RECORD_TYPE" "$RECORD_DATA"; then
        format-echo "SUCCESS" "DNS record creation completed successfully"
      else
        format-echo "ERROR" "Failed to create DNS record"
        exit 1
      fi
      ;;
    delete-record)
      if delete_record "$PROJECT_ID" "$ZONE_NAME" "$RECORD_NAME" "$RECORD_TYPE" "$RECORD_DATA"; then
        format-echo "SUCCESS" "DNS record deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete DNS record"
        exit 1
      fi
      ;;
    list-records)
      if list_records "$PROJECT_ID" "$ZONE_NAME"; then
        format-echo "SUCCESS" "Listed DNS records successfully"
      else
        format-echo "ERROR" "Failed to list DNS records"
        exit 1
      fi
      ;;
    backup-zone)
      if backup_zone "$PROJECT_ID" "$ZONE_NAME" "$BACKUP_FILE"; then
        format-echo "SUCCESS" "DNS zone backup completed successfully"
      else
        format-echo "ERROR" "Failed to backup DNS zone"
        exit 1
      fi
      ;;
    restore-zone)
      if restore_zone "$PROJECT_ID" "$ZONE_NAME" "$BACKUP_FILE"; then
        format-echo "SUCCESS" "DNS zone restoration completed successfully"
      else
        format-echo "ERROR" "Failed to restore DNS zone"
        exit 1
      fi
      ;;
    create-policy)
      if create_policy "$PROJECT_ID" "$POLICY_NAME"; then
        format-echo "SUCCESS" "DNS policy creation completed successfully"
      else
        format-echo "ERROR" "Failed to create DNS policy"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Cloud DNS Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
