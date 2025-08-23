#!/usr/bin/env bash
# gcp-vpn-manager.sh
# Script to manage Google Cloud VPN

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
VPN_GATEWAY=""
VPN_TUNNEL=""
REGION=""
NETWORK=""
ROUTER=""
PEER_IP=""
PEER_ASN=""
LOCAL_ASN=""
SHARED_SECRET=""
IKE_VERSION=""
TARGET_VPN_GATEWAY=""
FORWARDING_RULE=""
ESP_RULE=""
UDP500_RULE=""
UDP4500_RULE=""
ROUTE_PRIORITY=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud VPN Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud VPN for secure connectivity."
  echo "  Supports both Classic VPN and HA VPN configurations."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-g, --vpn-gateway NAME\033[0m      Set VPN gateway name"
  echo -e "  \033[1;33m-t, --vpn-tunnel NAME\033[0m       Set VPN tunnel name"
  echo -e "  \033[1;33m--region REGION\033[0m             Set region"
  echo -e "  \033[1;33m--network NETWORK\033[0m           Set network name"
  echo -e "  \033[1;33m-r, --router ROUTER\033[0m         Set router name"
  echo -e "  \033[1;33m--peer-ip IP\033[0m                Set peer gateway IP address"
  echo -e "  \033[1;33m--peer-asn ASN\033[0m              Set peer ASN for BGP"
  echo -e "  \033[1;33m--local-asn ASN\033[0m             Set local ASN for BGP"
  echo -e "  \033[1;33m--shared-secret SECRET\033[0m      Set shared secret for VPN"
  echo -e "  \033[1;33m--ike-version VERSION\033[0m       Set IKE version (1 or 2)"
  echo -e "  \033[1;33m--target-gateway NAME\033[0m       Set target VPN gateway name"
  echo -e "  \033[1;33m--route-priority PRIORITY\033[0m   Set route priority"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate-ha-vpn-gateway\033[0m       Create HA VPN gateway"
  echo -e "  \033[1;36mcreate-classic-vpn-gateway\033[0m  Create Classic VPN gateway"
  echo -e "  \033[1;36mcreate-vpn-tunnel\033[0m           Create VPN tunnel"
  echo -e "  \033[1;36mlist-vpn-gateways\033[0m           List VPN gateways"
  echo -e "  \033[1;36mlist-vpn-tunnels\033[0m            List VPN tunnels"
  echo -e "  \033[1;36mget-vpn-gateway\033[0m             Get VPN gateway details"
  echo -e "  \033[1;36mget-vpn-tunnel\033[0m              Get VPN tunnel details"
  echo -e "  \033[1;36mget-tunnel-status\033[0m           Get VPN tunnel status"
  echo -e "  \033[1;36mdelete-vpn-tunnel\033[0m           Delete VPN tunnel"
  echo -e "  \033[1;36mdelete-vpn-gateway\033[0m          Delete VPN gateway"
  echo -e "  \033[1;36mcreate-forwarding-rules\033[0m     Create forwarding rules for Classic VPN"
  echo -e "  \033[1;36mlist-forwarding-rules\033[0m       List VPN forwarding rules"
  echo -e "  \033[1;36mstatus\033[0m                      Check VPN status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Compute Engine API"
  echo -e "  \033[1;36mget-config\033[0m                  Get VPN configuration"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project --region us-central1 --network my-vpc create-ha-vpn-gateway"
  echo "  $0 -p my-project -g my-vpn-gw --region us-central1 get-vpn-gateway"
  echo "  $0 -p my-project -t my-tunnel --region us-central1 get-tunnel-status"
  echo "  $0 -p my-project --region us-central1 list-vpn-tunnels"
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
      -g|--vpn-gateway)
        if [[ -n "${2:-}" ]]; then
          VPN_GATEWAY="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --vpn-gateway"
          usage
        fi
        ;;
      -t|--vpn-tunnel)
        if [[ -n "${2:-}" ]]; then
          VPN_TUNNEL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --vpn-tunnel"
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
      -r|--router)
        if [[ -n "${2:-}" ]]; then
          ROUTER="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --router"
          usage
        fi
        ;;
      --peer-ip)
        if [[ -n "${2:-}" ]]; then
          PEER_IP="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --peer-ip"
          usage
        fi
        ;;
      --peer-asn)
        if [[ -n "${2:-}" ]]; then
          PEER_ASN="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --peer-asn"
          usage
        fi
        ;;
      --local-asn)
        if [[ -n "${2:-}" ]]; then
          LOCAL_ASN="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --local-asn"
          usage
        fi
        ;;
      --shared-secret)
        if [[ -n "${2:-}" ]]; then
          SHARED_SECRET="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --shared-secret"
          usage
        fi
        ;;
      --ike-version)
        if [[ -n "${2:-}" ]]; then
          IKE_VERSION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --ike-version"
          usage
        fi
        ;;
      --target-gateway)
        if [[ -n "${2:-}" ]]; then
          TARGET_VPN_GATEWAY="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --target-gateway"
          usage
        fi
        ;;
      --route-priority)
        if [[ -n "${2:-}" ]]; then
          ROUTE_PRIORITY="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --route-priority"
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
# CLOUD VPN OPERATIONS
#=====================================================================
create_ha_vpn_gateway() {
  format-echo "INFO" "Creating HA VPN gateway..."
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required"
    exit 1
  fi
  
  if [[ -z "$VPN_GATEWAY" ]]; then
    VPN_GATEWAY="ha-vpn-gateway-$(date +%s)"
    format-echo "INFO" "Using default gateway name: $VPN_GATEWAY"
  fi
  
  if [[ -z "$NETWORK" ]]; then
    NETWORK="default"
    format-echo "INFO" "Using default network: $NETWORK"
  fi
  
  gcloud compute vpn-gateways create "$VPN_GATEWAY" \
    --network="$NETWORK" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "HA VPN gateway '$VPN_GATEWAY' created in region '$REGION'"
  
  # Display gateway IP addresses
  echo
  echo "Gateway IP addresses:"
  gcloud compute vpn-gateways describe "$VPN_GATEWAY" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="table(vpnInterfaces[].ipAddress:label=IP_ADDRESS)"
}

create_classic_vpn_gateway() {
  format-echo "INFO" "Creating Classic VPN gateway..."
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required"
    exit 1
  fi
  
  if [[ -z "$TARGET_VPN_GATEWAY" ]]; then
    TARGET_VPN_GATEWAY="classic-vpn-gateway-$(date +%s)"
    format-echo "INFO" "Using default gateway name: $TARGET_VPN_GATEWAY"
  fi
  
  if [[ -z "$NETWORK" ]]; then
    NETWORK="default"
    format-echo "INFO" "Using default network: $NETWORK"
  fi
  
  gcloud compute target-vpn-gateways create "$TARGET_VPN_GATEWAY" \
    --network="$NETWORK" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Classic VPN gateway '$TARGET_VPN_GATEWAY' created in region '$REGION'"
}

create_vpn_tunnel() {
  format-echo "INFO" "Creating VPN tunnel..."
  
  if [[ -z "$VPN_TUNNEL" ]] || [[ -z "$REGION" ]] || [[ -z "$PEER_IP" ]]; then
    format-echo "ERROR" "VPN tunnel name, region, and peer IP are required"
    exit 1
  fi
  
  if [[ -z "$SHARED_SECRET" ]]; then
    # Generate a random shared secret
    SHARED_SECRET=$(openssl rand -base64 32 | tr -d '\n')
    format-echo "INFO" "Generated shared secret: $SHARED_SECRET"
  fi
  
  local cmd="gcloud compute vpn-tunnels create '$VPN_TUNNEL'"
  cmd="$cmd --peer-address='$PEER_IP'"
  cmd="$cmd --shared-secret='$SHARED_SECRET'"
  cmd="$cmd --region='$REGION'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  # Configure for HA VPN or Classic VPN
  if [[ -n "$VPN_GATEWAY" ]]; then
    # HA VPN tunnel
    cmd="$cmd --vpn-gateway='$VPN_GATEWAY'"
    cmd="$cmd --vpn-gateway-interface=0"
    
    if [[ -n "$ROUTER" ]]; then
      cmd="$cmd --router='$ROUTER'"
    fi
  elif [[ -n "$TARGET_VPN_GATEWAY" ]]; then
    # Classic VPN tunnel
    cmd="$cmd --target-vpn-gateway='$TARGET_VPN_GATEWAY'"
  else
    format-echo "ERROR" "Either VPN gateway (HA VPN) or target VPN gateway (Classic VPN) is required"
    exit 1
  fi
  
  # Set IKE version
  if [[ -n "$IKE_VERSION" ]]; then
    cmd="$cmd --ike-version='$IKE_VERSION'"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "VPN tunnel '$VPN_TUNNEL' created"
}

list_vpn_gateways() {
  format-echo "INFO" "Listing VPN gateways..."
  
  print_with_separator "VPN Gateways"
  
  echo "HA VPN Gateways:"
  if [[ -n "$REGION" ]]; then
    gcloud compute vpn-gateways list \
      --project="$PROJECT_ID" \
      --filter="region:($REGION)" \
      --format="table(name,region,network)"
  else
    gcloud compute vpn-gateways list \
      --project="$PROJECT_ID" \
      --format="table(name,region,network)"
  fi
  
  echo
  echo "Classic VPN Gateways:"
  if [[ -n "$REGION" ]]; then
    gcloud compute target-vpn-gateways list \
      --project="$PROJECT_ID" \
      --filter="region:($REGION)" \
      --format="table(name,region,network)"
  else
    gcloud compute target-vpn-gateways list \
      --project="$PROJECT_ID" \
      --format="table(name,region,network)"
  fi
  
  print_with_separator "End of VPN Gateways"
}

list_vpn_tunnels() {
  format-echo "INFO" "Listing VPN tunnels..."
  
  print_with_separator "VPN Tunnels"
  
  if [[ -n "$REGION" ]]; then
    gcloud compute vpn-tunnels list \
      --project="$PROJECT_ID" \
      --filter="region:($REGION)" \
      --format="table(name,region,peerIp,status,detailedStatus)"
  else
    gcloud compute vpn-tunnels list \
      --project="$PROJECT_ID" \
      --format="table(name,region,peerIp,status,detailedStatus)"
  fi
  
  print_with_separator "End of VPN Tunnels"
}

get_vpn_gateway() {
  format-echo "INFO" "Getting VPN gateway details..."
  
  if [[ -z "$VPN_GATEWAY" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "VPN gateway name and region are required"
    exit 1
  fi
  
  print_with_separator "VPN Gateway: $VPN_GATEWAY"
  
  # Try HA VPN gateway first
  if gcloud compute vpn-gateways describe "$VPN_GATEWAY" --region="$REGION" --project="$PROJECT_ID" 2>/dev/null; then
    echo
  elif gcloud compute target-vpn-gateways describe "$VPN_GATEWAY" --region="$REGION" --project="$PROJECT_ID" 2>/dev/null; then
    echo
  else
    format-echo "ERROR" "VPN gateway '$VPN_GATEWAY' not found"
    exit 1
  fi
  
  print_with_separator "End of VPN Gateway Details"
}

get_vpn_tunnel() {
  format-echo "INFO" "Getting VPN tunnel details..."
  
  if [[ -z "$VPN_TUNNEL" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "VPN tunnel name and region are required"
    exit 1
  fi
  
  print_with_separator "VPN Tunnel: $VPN_TUNNEL"
  gcloud compute vpn-tunnels describe "$VPN_TUNNEL" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  print_with_separator "End of VPN Tunnel Details"
}

get_tunnel_status() {
  format-echo "INFO" "Getting VPN tunnel status..."
  
  if [[ -z "$VPN_TUNNEL" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "VPN tunnel name and region are required"
    exit 1
  fi
  
  print_with_separator "VPN Tunnel Status: $VPN_TUNNEL"
  
  local status
  status=$(gcloud compute vpn-tunnels describe "$VPN_TUNNEL" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(status)")
  
  local detailed_status
  detailed_status=$(gcloud compute vpn-tunnels describe "$VPN_TUNNEL" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(detailedStatus)")
  
  format-echo "INFO" "Status: $status"
  format-echo "INFO" "Detailed Status: $detailed_status"
  
  # Show tunnel statistics
  echo
  echo "Tunnel Details:"
  gcloud compute vpn-tunnels describe "$VPN_TUNNEL" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="table(
      name,
      status,
      peerIp,
      sharedSecretHash,
      ikeVersion
    )"
  
  print_with_separator "End of VPN Tunnel Status"
}

delete_vpn_tunnel() {
  format-echo "INFO" "Deleting VPN tunnel..."
  
  if [[ -z "$VPN_TUNNEL" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "VPN tunnel name and region are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete VPN tunnel '$VPN_TUNNEL'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute vpn-tunnels delete "$VPN_TUNNEL" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
  
  format-echo "SUCCESS" "VPN tunnel '$VPN_TUNNEL' deleted"
}

delete_vpn_gateway() {
  format-echo "INFO" "Deleting VPN gateway..."
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required"
    exit 1
  fi
  
  local gateway_name="${VPN_GATEWAY:-$TARGET_VPN_GATEWAY}"
  if [[ -z "$gateway_name" ]]; then
    format-echo "ERROR" "VPN gateway name is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete VPN gateway '$gateway_name'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  # Try deleting as HA VPN gateway first, then as Classic VPN gateway
  if gcloud compute vpn-gateways delete "$gateway_name" --region="$REGION" --project="$PROJECT_ID" --quiet 2>/dev/null; then
    format-echo "SUCCESS" "HA VPN gateway '$gateway_name' deleted"
  elif gcloud compute target-vpn-gateways delete "$gateway_name" --region="$REGION" --project="$PROJECT_ID" --quiet 2>/dev/null; then
    format-echo "SUCCESS" "Classic VPN gateway '$gateway_name' deleted"
  else
    format-echo "ERROR" "Failed to delete VPN gateway '$gateway_name'"
    exit 1
  fi
}

create_forwarding_rules() {
  format-echo "INFO" "Creating forwarding rules for Classic VPN..."
  
  if [[ -z "$TARGET_VPN_GATEWAY" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Target VPN gateway name and region are required"
    exit 1
  fi
  
  # Reserve static IP for VPN gateway
  local static_ip_name="${TARGET_VPN_GATEWAY}-ip"
  format-echo "INFO" "Creating static IP: $static_ip_name"
  
  gcloud compute addresses create "$static_ip_name" \
    --region="$REGION" \
    --project="$PROJECT_ID" || true
  
  local static_ip
  static_ip=$(gcloud compute addresses describe "$static_ip_name" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(address)")
  
  # Create forwarding rules
  local esp_rule="${TARGET_VPN_GATEWAY}-esp"
  local udp500_rule="${TARGET_VPN_GATEWAY}-udp500"
  local udp4500_rule="${TARGET_VPN_GATEWAY}-udp4500"
  
  format-echo "INFO" "Creating ESP forwarding rule..."
  gcloud compute forwarding-rules create "$esp_rule" \
    --address="$static_ip" \
    --ip-protocol=ESP \
    --target-vpn-gateway="$TARGET_VPN_GATEWAY" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  
  format-echo "INFO" "Creating UDP 500 forwarding rule..."
  gcloud compute forwarding-rules create "$udp500_rule" \
    --address="$static_ip" \
    --ip-protocol=UDP \
    --ports=500 \
    --target-vpn-gateway="$TARGET_VPN_GATEWAY" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  
  format-echo "INFO" "Creating UDP 4500 forwarding rule..."
  gcloud compute forwarding-rules create "$udp4500_rule" \
    --address="$static_ip" \
    --ip-protocol=UDP \
    --ports=4500 \
    --target-vpn-gateway="$TARGET_VPN_GATEWAY" \
    --region="$REGION" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Forwarding rules created for Classic VPN gateway"
  format-echo "INFO" "Static IP address: $static_ip"
}

list_forwarding_rules() {
  format-echo "INFO" "Listing VPN forwarding rules..."
  
  print_with_separator "VPN Forwarding Rules"
  
  if [[ -n "$REGION" ]]; then
    gcloud compute forwarding-rules list \
      --project="$PROJECT_ID" \
      --filter="region:($REGION) AND target~vpn" \
      --format="table(name,IPAddress,IPProtocol,ports,target)"
  else
    gcloud compute forwarding-rules list \
      --project="$PROJECT_ID" \
      --filter="target~vpn" \
      --format="table(name,region,IPAddress,IPProtocol,ports,target)"
  fi
  
  print_with_separator "End of Forwarding Rules"
}

check_status() {
  format-echo "INFO" "Checking VPN status..."
  
  print_with_separator "Cloud VPN Status"
  
  # Check if Compute Engine API is enabled
  if gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q "compute"; then
    format-echo "SUCCESS" "Compute Engine API is enabled"
  else
    format-echo "WARNING" "Compute Engine API is not enabled"
  fi
  
  # Count VPN gateways
  local ha_vpn_count
  ha_vpn_count=$(gcloud compute vpn-gateways list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "HA VPN gateways: $ha_vpn_count"
  
  local classic_vpn_count
  classic_vpn_count=$(gcloud compute target-vpn-gateways list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Classic VPN gateways: $classic_vpn_count"
  
  # Count VPN tunnels
  local tunnel_count
  tunnel_count=$(gcloud compute vpn-tunnels list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "VPN tunnels: $tunnel_count"
  
  # Count active tunnels
  local active_tunnels
  active_tunnels=$(gcloud compute vpn-tunnels list --project="$PROJECT_ID" --filter="status=ESTABLISHED" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Active tunnels: $active_tunnels"
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling Compute Engine API..."
  enable_apis
  format-echo "SUCCESS" "Compute Engine API enabled"
}

get_config() {
  format-echo "INFO" "Getting VPN configuration..."
  
  print_with_separator "Cloud VPN Configuration"
  
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
  echo "VPN Types:"
  echo "- HA VPN: High availability with 99.99% SLA"
  echo "- Classic VPN: Standard VPN with 99.9% SLA"
  echo
  echo "Supported Features:"
  echo "- IPsec tunnel encryption"
  echo "- IKE v1 and v2 protocols"
  echo "- BGP dynamic routing (HA VPN)"
  echo "- Static routing (Classic VPN)"
  echo "- Multiple tunnels per gateway"
  echo
  echo "Encryption:"
  echo "- AES-256-GCM or AES-256-CBC"
  echo "- SHA-256 or SHA-1 authentication"
  echo "- DH groups 14, 15, 16, 19, 20, 21"
  echo
  echo "Cloud VPN Console URL:"
  echo "https://console.cloud.google.com/hybrid/vpn/list?project=$PROJECT_ID"
  
  print_with_separator "End of Configuration"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    create-ha-vpn-gateway)
      enable_apis
      create_ha_vpn_gateway
      ;;
    create-classic-vpn-gateway)
      enable_apis
      create_classic_vpn_gateway
      ;;
    create-vpn-tunnel)
      create_vpn_tunnel
      ;;
    list-vpn-gateways)
      list_vpn_gateways
      ;;
    list-vpn-tunnels)
      list_vpn_tunnels
      ;;
    get-vpn-gateway)
      get_vpn_gateway
      ;;
    get-vpn-tunnel)
      get_vpn_tunnel
      ;;
    get-tunnel-status)
      get_tunnel_status
      ;;
    delete-vpn-tunnel)
      delete_vpn_tunnel
      ;;
    delete-vpn-gateway)
      delete_vpn_gateway
      ;;
    create-forwarding-rules)
      create_forwarding_rules
      ;;
    list-forwarding-rules)
      list_forwarding_rules
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
  
  print_with_separator "GCP Cloud VPN Manager"
  format-echo "INFO" "Starting Cloud VPN management operations..."
  
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
  format-echo "SUCCESS" "Cloud VPN management operation completed successfully."
  print_with_separator "End of GCP Cloud VPN Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
