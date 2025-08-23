#!/usr/bin/env bash
# gcp-interconnect-manager.sh
# Script to manage Google Cloud Interconnect

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
INTERCONNECT=""
ATTACHMENT=""
ROUTER=""
REGION=""
EDGE_AVAILABILITY_DOMAIN=""
BANDWIDTH=""
VLAN_TAG=""
CANDIDATE_SUBNETS=""
PARTNER_NAME=""
PARTNER_PORTAL_URL=""
DESCRIPTION=""
ADMIN_ENABLED=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Interconnect Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Interconnect for dedicated connectivity."
  echo "  Supports Dedicated Interconnect, Partner Interconnect, and Cross-Cloud Interconnect."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-i, --interconnect NAME\033[0m     Set interconnect name"
  echo -e "  \033[1;33m-a, --attachment NAME\033[0m       Set attachment name"
  echo -e "  \033[1;33m-r, --router ROUTER\033[0m         Set router name"
  echo -e "  \033[1;33m--region REGION\033[0m             Set region"
  echo -e "  \033[1;33m--edge-domain DOMAIN\033[0m        Set edge availability domain"
  echo -e "  \033[1;33m--bandwidth BW\033[0m              Set bandwidth (BPS_50M, BPS_100M, BPS_200M, etc.)"
  echo -e "  \033[1;33m--vlan-tag TAG\033[0m              Set VLAN tag (802.1Q)"
  echo -e "  \033[1;33m--candidate-subnets SUBNETS\033[0m Set candidate subnets"
  echo -e "  \033[1;33m--partner-name NAME\033[0m         Set partner name"
  echo -e "  \033[1;33m--partner-portal URL\033[0m        Set partner portal URL"
  echo -e "  \033[1;33m--description DESC\033[0m          Set description"
  echo -e "  \033[1;33m--admin-enabled BOOL\033[0m        Set admin enabled status"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate-interconnect\033[0m         Create dedicated interconnect"
  echo -e "  \033[1;36mcreate-attachment\033[0m           Create interconnect attachment"
  echo -e "  \033[1;36mcreate-partner-attachment\033[0m   Create partner interconnect attachment"
  echo -e "  \033[1;36mlist-interconnects\033[0m          List interconnects"
  echo -e "  \033[1;36mlist-attachments\033[0m            List interconnect attachments"
  echo -e "  \033[1;36mget-interconnect\033[0m            Get interconnect details"
  echo -e "  \033[1;36mget-attachment\033[0m              Get attachment details"
  echo -e "  \033[1;36mupdate-attachment\033[0m           Update attachment configuration"
  echo -e "  \033[1;36mdelete-attachment\033[0m           Delete interconnect attachment"
  echo -e "  \033[1;36mdelete-interconnect\033[0m         Delete interconnect"
  echo -e "  \033[1;36mlist-locations\033[0m              List interconnect locations"
  echo -e "  \033[1;36mget-location\033[0m                Get location details"
  echo -e "  \033[1;36mstatus\033[0m                      Check interconnect status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Compute Engine API"
  echo -e "  \033[1;36mget-config\033[0m                  Get interconnect configuration"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project list-locations"
  echo "  $0 -p my-project -i my-interconnect get-interconnect"
  echo "  $0 -p my-project -a my-attachment --region us-central1 get-attachment"
  echo "  $0 -p my-project --region us-central1 list-attachments"
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
      -i|--interconnect)
        if [[ -n "${2:-}" ]]; then
          INTERCONNECT="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --interconnect"
          usage
        fi
        ;;
      -a|--attachment)
        if [[ -n "${2:-}" ]]; then
          ATTACHMENT="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --attachment"
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
      --edge-domain)
        if [[ -n "${2:-}" ]]; then
          EDGE_AVAILABILITY_DOMAIN="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --edge-domain"
          usage
        fi
        ;;
      --bandwidth)
        if [[ -n "${2:-}" ]]; then
          BANDWIDTH="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --bandwidth"
          usage
        fi
        ;;
      --vlan-tag)
        if [[ -n "${2:-}" ]]; then
          VLAN_TAG="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --vlan-tag"
          usage
        fi
        ;;
      --candidate-subnets)
        if [[ -n "${2:-}" ]]; then
          CANDIDATE_SUBNETS="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --candidate-subnets"
          usage
        fi
        ;;
      --partner-name)
        if [[ -n "${2:-}" ]]; then
          PARTNER_NAME="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --partner-name"
          usage
        fi
        ;;
      --partner-portal)
        if [[ -n "${2:-}" ]]; then
          PARTNER_PORTAL_URL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --partner-portal"
          usage
        fi
        ;;
      --description)
        if [[ -n "${2:-}" ]]; then
          DESCRIPTION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --description"
          usage
        fi
        ;;
      --admin-enabled)
        if [[ -n "${2:-}" ]]; then
          ADMIN_ENABLED="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --admin-enabled"
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
# CLOUD INTERCONNECT OPERATIONS
#=====================================================================
create_interconnect() {
  format-echo "INFO" "Creating dedicated interconnect..."
  
  if [[ -z "$INTERCONNECT" ]]; then
    format-echo "ERROR" "Interconnect name is required"
    exit 1
  fi
  
  read -p "Enter interconnect location: " location
  if [[ -z "$location" ]]; then
    format-echo "ERROR" "Interconnect location is required"
    exit 1
  fi
  
  read -p "Enter link type (LINK_TYPE_ETHERNET_10G_LR or LINK_TYPE_ETHERNET_100G_LR): " link_type
  if [[ -z "$link_type" ]]; then
    link_type="LINK_TYPE_ETHERNET_10G_LR"
    format-echo "INFO" "Using default link type: $link_type"
  fi
  
  local cmd="gcloud compute interconnects create '$INTERCONNECT'"
  cmd="$cmd --interconnect-type=DEDICATED"
  cmd="$cmd --link-type='$link_type'"
  cmd="$cmd --location='$location'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  if [[ -n "$DESCRIPTION" ]]; then
    cmd="$cmd --description='$DESCRIPTION'"
  fi
  
  if [[ -n "$ADMIN_ENABLED" ]]; then
    if [[ "$ADMIN_ENABLED" == "true" ]]; then
      cmd="$cmd --admin-enabled"
    else
      cmd="$cmd --no-admin-enabled"
    fi
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "Dedicated interconnect '$INTERCONNECT' created"
  
  # Display next steps
  echo
  echo "Next steps:"
  echo "1. Contact your service provider to provision the cross-connect"
  echo "2. Provide them with the interconnect details"
  echo "3. Create interconnect attachments after the circuit is established"
}

create_attachment() {
  format-echo "INFO" "Creating interconnect attachment..."
  
  if [[ -z "$ATTACHMENT" ]] || [[ -z "$INTERCONNECT" ]] || [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Attachment name, interconnect, router, and region are required"
    exit 1
  fi
  
  local cmd="gcloud compute interconnects attachments create '$ATTACHMENT'"
  cmd="$cmd --router='$ROUTER'"
  cmd="$cmd --interconnect='$INTERCONNECT'"
  cmd="$cmd --region='$REGION'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  if [[ -n "$VLAN_TAG" ]]; then
    cmd="$cmd --vlan='$VLAN_TAG'"
  fi
  
  if [[ -n "$CANDIDATE_SUBNETS" ]]; then
    cmd="$cmd --candidate-subnets='$CANDIDATE_SUBNETS'"
  fi
  
  if [[ -n "$DESCRIPTION" ]]; then
    cmd="$cmd --description='$DESCRIPTION'"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "Interconnect attachment '$ATTACHMENT' created"
}

create_partner_attachment() {
  format-echo "INFO" "Creating partner interconnect attachment..."
  
  if [[ -z "$ATTACHMENT" ]] || [[ -z "$ROUTER" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Attachment name, router, and region are required"
    exit 1
  fi
  
  if [[ -z "$EDGE_AVAILABILITY_DOMAIN" ]]; then
    format-echo "ERROR" "Edge availability domain is required for partner attachments"
    exit 1
  fi
  
  local cmd="gcloud compute interconnects attachments partner create '$ATTACHMENT'"
  cmd="$cmd --router='$ROUTER'"
  cmd="$cmd --edge-availability-domain='$EDGE_AVAILABILITY_DOMAIN'"
  cmd="$cmd --region='$REGION'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  if [[ -n "$DESCRIPTION" ]]; then
    cmd="$cmd --description='$DESCRIPTION'"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "Partner interconnect attachment '$ATTACHMENT' created"
  
  # Display pairing key
  echo
  echo "Partner attachment created. Getting pairing key..."
  local pairing_key
  pairing_key=$(gcloud compute interconnects attachments describe "$ATTACHMENT" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(pairingKey)")
  
  format-echo "INFO" "Pairing key: $pairing_key"
  echo "Provide this pairing key to your service provider to complete the connection."
}

list_interconnects() {
  format-echo "INFO" "Listing interconnects..."
  
  print_with_separator "Interconnects"
  gcloud compute interconnects list \
    --project="$PROJECT_ID" \
    --format="table(name,interconnectType,linkType,location,operationalStatus,adminEnabled)"
  print_with_separator "End of Interconnects"
}

list_attachments() {
  format-echo "INFO" "Listing interconnect attachments..."
  
  print_with_separator "Interconnect Attachments"
  
  if [[ -n "$REGION" ]]; then
    gcloud compute interconnects attachments list \
      --project="$PROJECT_ID" \
      --filter="region:($REGION)" \
      --format="table(name,region,type,state,bandwidth,router)"
  else
    gcloud compute interconnects attachments list \
      --project="$PROJECT_ID" \
      --format="table(name,region,type,state,bandwidth,router)"
  fi
  
  print_with_separator "End of Attachments"
}

get_interconnect() {
  format-echo "INFO" "Getting interconnect details..."
  
  if [[ -z "$INTERCONNECT" ]]; then
    format-echo "ERROR" "Interconnect name is required"
    exit 1
  fi
  
  print_with_separator "Interconnect: $INTERCONNECT"
  gcloud compute interconnects describe "$INTERCONNECT" \
    --project="$PROJECT_ID"
  print_with_separator "End of Interconnect Details"
}

get_attachment() {
  format-echo "INFO" "Getting attachment details..."
  
  if [[ -z "$ATTACHMENT" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Attachment name and region are required"
    exit 1
  fi
  
  print_with_separator "Attachment: $ATTACHMENT"
  gcloud compute interconnects attachments describe "$ATTACHMENT" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  print_with_separator "End of Attachment Details"
}

update_attachment() {
  format-echo "INFO" "Updating attachment configuration..."
  
  if [[ -z "$ATTACHMENT" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Attachment name and region are required"
    exit 1
  fi
  
  local cmd="gcloud compute interconnects attachments update '$ATTACHMENT'"
  cmd="$cmd --region='$REGION'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  if [[ -n "$DESCRIPTION" ]]; then
    cmd="$cmd --description='$DESCRIPTION'"
  fi
  
  # Additional update options can be added here
  # Note: Most interconnect attachment properties cannot be updated after creation
  
  eval "$cmd"
  format-echo "SUCCESS" "Attachment '$ATTACHMENT' updated"
}

delete_attachment() {
  format-echo "INFO" "Deleting interconnect attachment..."
  
  if [[ -z "$ATTACHMENT" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Attachment name and region are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete interconnect attachment '$ATTACHMENT'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute interconnects attachments delete "$ATTACHMENT" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
  
  format-echo "SUCCESS" "Interconnect attachment '$ATTACHMENT' deleted"
}

delete_interconnect() {
  format-echo "INFO" "Deleting interconnect..."
  
  if [[ -z "$INTERCONNECT" ]]; then
    format-echo "ERROR" "Interconnect name is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete interconnect '$INTERCONNECT'"
  format-echo "WARNING" "Ensure all attachments are deleted first"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute interconnects delete "$INTERCONNECT" \
    --project="$PROJECT_ID" \
    --quiet
  
  format-echo "SUCCESS" "Interconnect '$INTERCONNECT' deleted"
}

list_locations() {
  format-echo "INFO" "Listing interconnect locations..."
  
  print_with_separator "Interconnect Locations"
  gcloud compute interconnects locations list \
    --project="$PROJECT_ID" \
    --format="table(name,address,availabilityZone,city,continent,facilityProvider)"
  print_with_separator "End of Locations"
}

get_location() {
  format-echo "INFO" "Getting location details..."
  
  read -p "Enter location name: " location_name
  if [[ -z "$location_name" ]]; then
    format-echo "ERROR" "Location name is required"
    exit 1
  fi
  
  print_with_separator "Location: $location_name"
  gcloud compute interconnects locations describe "$location_name" \
    --project="$PROJECT_ID"
  print_with_separator "End of Location Details"
}

check_status() {
  format-echo "INFO" "Checking interconnect status..."
  
  print_with_separator "Cloud Interconnect Status"
  
  # Check if Compute Engine API is enabled
  if gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q "compute"; then
    format-echo "SUCCESS" "Compute Engine API is enabled"
  else
    format-echo "WARNING" "Compute Engine API is not enabled"
  fi
  
  # Count interconnects
  local interconnect_count
  interconnect_count=$(gcloud compute interconnects list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Total interconnects: $interconnect_count"
  
  # Count attachments
  local attachment_count
  attachment_count=$(gcloud compute interconnects attachments list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Total attachments: $attachment_count"
  
  # Count active attachments
  local active_attachments
  active_attachments=$(gcloud compute interconnects attachments list --project="$PROJECT_ID" --filter="state=ACTIVE" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Active attachments: $active_attachments"
  
  # Show interconnect status summary
  if [[ "$interconnect_count" -gt 0 ]]; then
    echo
    echo "Interconnect Status Summary:"
    gcloud compute interconnects list \
      --project="$PROJECT_ID" \
      --format="table(name,operationalStatus,adminEnabled,linkType)" 2>/dev/null || true
  fi
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling Compute Engine API..."
  enable_apis
  format-echo "SUCCESS" "Compute Engine API enabled"
}

get_config() {
  format-echo "INFO" "Getting interconnect configuration..."
  
  print_with_separator "Cloud Interconnect Configuration"
  
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
  echo "Interconnect Types:"
  echo "- Dedicated Interconnect: Direct physical connection"
  echo "- Partner Interconnect: Connection through a service provider"
  echo "- Cross-Cloud Interconnect: Multi-cloud connectivity"
  echo
  echo "Supported Bandwidths:"
  echo "- Partner: 50 Mbps to 50 Gbps"
  echo "- Dedicated: 10 Gbps or 100 Gbps"
  echo
  echo "Link Types:"
  echo "- LINK_TYPE_ETHERNET_10G_LR: 10 Gbps"
  echo "- LINK_TYPE_ETHERNET_100G_LR: 100 Gbps"
  echo
  echo "Routing:"
  echo "- BGP sessions for dynamic routing"
  echo "- VLAN 802.1Q tagging support"
  echo "- Multiple attachments per interconnect"
  echo
  echo "Cloud Interconnect Console URL:"
  echo "https://console.cloud.google.com/hybrid/interconnect/list?project=$PROJECT_ID"
  
  print_with_separator "End of Configuration"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    create-interconnect)
      enable_apis
      create_interconnect
      ;;
    create-attachment)
      create_attachment
      ;;
    create-partner-attachment)
      create_partner_attachment
      ;;
    list-interconnects)
      list_interconnects
      ;;
    list-attachments)
      list_attachments
      ;;
    get-interconnect)
      get_interconnect
      ;;
    get-attachment)
      get_attachment
      ;;
    update-attachment)
      update_attachment
      ;;
    delete-attachment)
      delete_attachment
      ;;
    delete-interconnect)
      delete_interconnect
      ;;
    list-locations)
      list_locations
      ;;
    get-location)
      get_location
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
  
  print_with_separator "GCP Cloud Interconnect Manager"
  format-echo "INFO" "Starting Cloud Interconnect management operations..."
  
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
  format-echo "SUCCESS" "Cloud Interconnect management operation completed successfully."
  print_with_separator "End of GCP Cloud Interconnect Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
