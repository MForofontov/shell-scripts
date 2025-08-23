#!/usr/bin/env bash
# gcp-traffic-director-manager.sh
# Script to manage Google Cloud Traffic Director

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
SERVICE_MESH=""
URL_MAP=""
TARGET_PROXY=""
FORWARDING_RULE=""
BACKEND_SERVICE=""
HEALTH_CHECK=""
REGION=""
NETWORK=""
SUBNET=""
PORT=""
PROTOCOL=""
LOAD_BALANCING_SCHEME=""
IP_PROTOCOL=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Traffic Director Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Traffic Director for service mesh traffic management."
  echo "  Provides capabilities for advanced load balancing, traffic routing, and service mesh control."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m--service-mesh NAME\033[0m         Set service mesh name"
  echo -e "  \033[1;33m--url-map NAME\033[0m              Set URL map name"
  echo -e "  \033[1;33m--target-proxy NAME\033[0m         Set target proxy name"
  echo -e "  \033[1;33m--forwarding-rule NAME\033[0m      Set forwarding rule name"
  echo -e "  \033[1;33m--backend-service NAME\033[0m      Set backend service name"
  echo -e "  \033[1;33m--health-check NAME\033[0m         Set health check name"
  echo -e "  \033[1;33m--region REGION\033[0m             Set region"
  echo -e "  \033[1;33m--network NETWORK\033[0m           Set network name"
  echo -e "  \033[1;33m--subnet SUBNET\033[0m             Set subnet name"
  echo -e "  \033[1;33m--port PORT\033[0m                 Set port number"
  echo -e "  \033[1;33m--protocol PROTOCOL\033[0m         Set protocol (HTTP, HTTPS, HTTP2, GRPC)"
  echo -e "  \033[1;33m--load-balancing-scheme SCHEME\033[0m Set load balancing scheme"
  echo -e "  \033[1;33m--ip-protocol PROTOCOL\033[0m      Set IP protocol (TCP, UDP)"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate-health-check\033[0m         Create health check"
  echo -e "  \033[1;36mcreate-backend-service\033[0m      Create backend service"
  echo -e "  \033[1;36mcreate-url-map\033[0m              Create URL map"
  echo -e "  \033[1;36mcreate-target-proxy\033[0m         Create target proxy"
  echo -e "  \033[1;36mcreate-forwarding-rule\033[0m      Create global forwarding rule"
  echo -e "  \033[1;36mlist-backend-services\033[0m       List backend services"
  echo -e "  \033[1;36mlist-url-maps\033[0m               List URL maps"
  echo -e "  \033[1;36mlist-target-proxies\033[0m         List target proxies"
  echo -e "  \033[1;36mlist-forwarding-rules\033[0m       List forwarding rules"
  echo -e "  \033[1;36mlist-health-checks\033[0m          List health checks"
  echo -e "  \033[1;36mget-backend-service\033[0m         Get backend service details"
  echo -e "  \033[1;36mget-url-map\033[0m                 Get URL map details"
  echo -e "  \033[1;36mget-target-proxy\033[0m            Get target proxy details"
  echo -e "  \033[1;36mget-forwarding-rule\033[0m         Get forwarding rule details"
  echo -e "  \033[1;36mget-health-check\033[0m            Get health check details"
  echo -e "  \033[1;36mupdate-backend-service\033[0m      Update backend service"
  echo -e "  \033[1;36mupdate-url-map\033[0m              Update URL map"
  echo -e "  \033[1;36mdelete-forwarding-rule\033[0m      Delete forwarding rule"
  echo -e "  \033[1;36mdelete-target-proxy\033[0m         Delete target proxy"
  echo -e "  \033[1;36mdelete-url-map\033[0m              Delete URL map"
  echo -e "  \033[1;36mdelete-backend-service\033[0m      Delete backend service"
  echo -e "  \033[1;36mdelete-health-check\033[0m         Delete health check"
  echo -e "  \033[1;36mstatus\033[0m                      Check Traffic Director status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Compute Engine API"
  echo -e "  \033[1;36mget-config\033[0m                  Get Traffic Director configuration"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project --health-check my-health-check create-health-check"
  echo "  $0 -p my-project --backend-service my-backend create-backend-service"
  echo "  $0 -p my-project list-backend-services"
  echo "  $0 -p my-project --url-map my-url-map get-url-map"
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
      --service-mesh)
        if [[ -n "${2:-}" ]]; then
          SERVICE_MESH="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --service-mesh"
          usage
        fi
        ;;
      --url-map)
        if [[ -n "${2:-}" ]]; then
          URL_MAP="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --url-map"
          usage
        fi
        ;;
      --target-proxy)
        if [[ -n "${2:-}" ]]; then
          TARGET_PROXY="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --target-proxy"
          usage
        fi
        ;;
      --forwarding-rule)
        if [[ -n "${2:-}" ]]; then
          FORWARDING_RULE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --forwarding-rule"
          usage
        fi
        ;;
      --backend-service)
        if [[ -n "${2:-}" ]]; then
          BACKEND_SERVICE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --backend-service"
          usage
        fi
        ;;
      --health-check)
        if [[ -n "${2:-}" ]]; then
          HEALTH_CHECK="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --health-check"
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
      --port)
        if [[ -n "${2:-}" ]]; then
          PORT="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --port"
          usage
        fi
        ;;
      --protocol)
        if [[ -n "${2:-}" ]]; then
          PROTOCOL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --protocol"
          usage
        fi
        ;;
      --load-balancing-scheme)
        if [[ -n "${2:-}" ]]; then
          LOAD_BALANCING_SCHEME="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --load-balancing-scheme"
          usage
        fi
        ;;
      --ip-protocol)
        if [[ -n "${2:-}" ]]; then
          IP_PROTOCOL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --ip-protocol"
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
    "networkservices.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# TRAFFIC DIRECTOR OPERATIONS
#=====================================================================
create_health_check() {
  format-echo "INFO" "Creating health check..."
  
  if [[ -z "$HEALTH_CHECK" ]]; then
    HEALTH_CHECK="health-check-$(date +%s)"
    format-echo "INFO" "Using default health check name: $HEALTH_CHECK"
  fi
  
  local protocol="${PROTOCOL:-HTTP}"
  local port="${PORT:-80}"
  
  local cmd="gcloud compute health-checks create $protocol '$HEALTH_CHECK'"
  cmd="$cmd --port='$port'"
  cmd="$cmd --project='$PROJECT_ID'"
  cmd="$cmd --global"
  
  # Add protocol-specific options
  case "$protocol" in
    HTTP)
      cmd="$cmd --request-path='/health'"
      ;;
    HTTPS)
      cmd="$cmd --request-path='/health'"
      ;;
    HTTP2)
      cmd="$cmd --request-path='/health'"
      ;;
    GRPC)
      cmd="$cmd --grpc-service-name='health'"
      ;;
  esac
  
  eval "$cmd"
  format-echo "SUCCESS" "Health check '$HEALTH_CHECK' created"
}

create_backend_service() {
  format-echo "INFO" "Creating backend service..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    BACKEND_SERVICE="backend-service-$(date +%s)"
    format-echo "INFO" "Using default backend service name: $BACKEND_SERVICE"
  fi
  
  if [[ -z "$HEALTH_CHECK" ]]; then
    format-echo "ERROR" "Health check name is required"
    exit 1
  fi
  
  local protocol="${PROTOCOL:-HTTP}"
  local load_balancing_scheme="${LOAD_BALANCING_SCHEME:-INTERNAL_SELF_MANAGED}"
  
  local cmd="gcloud compute backend-services create '$BACKEND_SERVICE'"
  cmd="$cmd --protocol='$protocol'"
  cmd="$cmd --health-checks='$HEALTH_CHECK'"
  cmd="$cmd --load-balancing-scheme='$load_balancing_scheme'"
  cmd="$cmd --project='$PROJECT_ID'"
  cmd="$cmd --global"
  
  eval "$cmd"
  format-echo "SUCCESS" "Backend service '$BACKEND_SERVICE' created"
}

create_url_map() {
  format-echo "INFO" "Creating URL map..."
  
  if [[ -z "$URL_MAP" ]]; then
    URL_MAP="url-map-$(date +%s)"
    format-echo "INFO" "Using default URL map name: $URL_MAP"
  fi
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  gcloud compute url-maps create "$URL_MAP" \
    --default-service="$BACKEND_SERVICE" \
    --project="$PROJECT_ID" \
    --global
  
  format-echo "SUCCESS" "URL map '$URL_MAP' created"
}

create_target_proxy() {
  format-echo "INFO" "Creating target proxy..."
  
  if [[ -z "$TARGET_PROXY" ]]; then
    TARGET_PROXY="target-proxy-$(date +%s)"
    format-echo "INFO" "Using default target proxy name: $TARGET_PROXY"
  fi
  
  if [[ -z "$URL_MAP" ]]; then
    format-echo "ERROR" "URL map name is required"
    exit 1
  fi
  
  local protocol="${PROTOCOL:-HTTP}"
  
  case "$protocol" in
    HTTP)
      gcloud compute target-http-proxies create "$TARGET_PROXY" \
        --url-map="$URL_MAP" \
        --project="$PROJECT_ID" \
        --global
      ;;
    HTTPS)
      read -p "Enter SSL certificate name: " ssl_cert
      if [[ -z "$ssl_cert" ]]; then
        format-echo "ERROR" "SSL certificate is required for HTTPS"
        exit 1
      fi
      gcloud compute target-https-proxies create "$TARGET_PROXY" \
        --url-map="$URL_MAP" \
        --ssl-certificates="$ssl_cert" \
        --project="$PROJECT_ID" \
        --global
      ;;
    GRPC)
      gcloud compute target-grpc-proxies create "$TARGET_PROXY" \
        --url-map="$URL_MAP" \
        --project="$PROJECT_ID" \
        --global
      ;;
    *)
      format-echo "ERROR" "Unsupported protocol for target proxy: $protocol"
      exit 1
      ;;
  esac
  
  format-echo "SUCCESS" "Target proxy '$TARGET_PROXY' created"
}

create_forwarding_rule() {
  format-echo "INFO" "Creating global forwarding rule..."
  
  if [[ -z "$FORWARDING_RULE" ]]; then
    FORWARDING_RULE="forwarding-rule-$(date +%s)"
    format-echo "INFO" "Using default forwarding rule name: $FORWARDING_RULE"
  fi
  
  if [[ -z "$TARGET_PROXY" ]]; then
    format-echo "ERROR" "Target proxy name is required"
    exit 1
  fi
  
  local port="${PORT:-80}"
  local load_balancing_scheme="${LOAD_BALANCING_SCHEME:-INTERNAL_SELF_MANAGED}"
  local network="${NETWORK:-default}"
  
  local cmd="gcloud compute forwarding-rules create '$FORWARDING_RULE'"
  cmd="$cmd --load-balancing-scheme='$load_balancing_scheme'"
  cmd="$cmd --network='$network'"
  cmd="$cmd --ports='$port'"
  cmd="$cmd --project='$PROJECT_ID'"
  cmd="$cmd --global"
  
  # Set target based on protocol
  local protocol="${PROTOCOL:-HTTP}"
  case "$protocol" in
    HTTP)
      cmd="$cmd --target-http-proxy='$TARGET_PROXY'"
      ;;
    HTTPS)
      cmd="$cmd --target-https-proxy='$TARGET_PROXY'"
      ;;
    GRPC)
      cmd="$cmd --target-grpc-proxy='$TARGET_PROXY'"
      ;;
    *)
      format-echo "ERROR" "Unsupported protocol for forwarding rule: $protocol"
      exit 1
      ;;
  esac
  
  eval "$cmd"
  format-echo "SUCCESS" "Forwarding rule '$FORWARDING_RULE' created"
}

list_backend_services() {
  format-echo "INFO" "Listing backend services..."
  
  print_with_separator "Backend Services"
  gcloud compute backend-services list \
    --project="$PROJECT_ID" \
    --global \
    --format="table(name,protocol,loadBalancingScheme,backends.group:label=BACKENDS)"
  print_with_separator "End of Backend Services"
}

list_url_maps() {
  format-echo "INFO" "Listing URL maps..."
  
  print_with_separator "URL Maps"
  gcloud compute url-maps list \
    --project="$PROJECT_ID" \
    --global \
    --format="table(name,defaultService)"
  print_with_separator "End of URL Maps"
}

list_target_proxies() {
  format-echo "INFO" "Listing target proxies..."
  
  print_with_separator "Target Proxies"
  
  echo "HTTP Proxies:"
  gcloud compute target-http-proxies list \
    --project="$PROJECT_ID" \
    --global \
    --format="table(name,urlMap)" 2>/dev/null || echo "None"
  
  echo
  echo "HTTPS Proxies:"
  gcloud compute target-https-proxies list \
    --project="$PROJECT_ID" \
    --global \
    --format="table(name,urlMap,sslCertificates[].basename():label=SSL_CERTS)" 2>/dev/null || echo "None"
  
  echo
  echo "gRPC Proxies:"
  gcloud compute target-grpc-proxies list \
    --project="$PROJECT_ID" \
    --global \
    --format="table(name,urlMap)" 2>/dev/null || echo "None"
  
  print_with_separator "End of Target Proxies"
}

list_forwarding_rules() {
  format-echo "INFO" "Listing forwarding rules..."
  
  print_with_separator "Forwarding Rules"
  gcloud compute forwarding-rules list \
    --project="$PROJECT_ID" \
    --global \
    --format="table(name,IPAddress,target,loadBalancingScheme,ports)"
  print_with_separator "End of Forwarding Rules"
}

list_health_checks() {
  format-echo "INFO" "Listing health checks..."
  
  print_with_separator "Health Checks"
  gcloud compute health-checks list \
    --project="$PROJECT_ID" \
    --global \
    --format="table(name,type,port,requestPath)"
  print_with_separator "End of Health Checks"
}

get_backend_service() {
  format-echo "INFO" "Getting backend service details..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  print_with_separator "Backend Service: $BACKEND_SERVICE"
  gcloud compute backend-services describe "$BACKEND_SERVICE" \
    --project="$PROJECT_ID" \
    --global
  print_with_separator "End of Backend Service Details"
}

get_url_map() {
  format-echo "INFO" "Getting URL map details..."
  
  if [[ -z "$URL_MAP" ]]; then
    format-echo "ERROR" "URL map name is required"
    exit 1
  fi
  
  print_with_separator "URL Map: $URL_MAP"
  gcloud compute url-maps describe "$URL_MAP" \
    --project="$PROJECT_ID" \
    --global
  print_with_separator "End of URL Map Details"
}

get_target_proxy() {
  format-echo "INFO" "Getting target proxy details..."
  
  if [[ -z "$TARGET_PROXY" ]]; then
    format-echo "ERROR" "Target proxy name is required"
    exit 1
  fi
  
  print_with_separator "Target Proxy: $TARGET_PROXY"
  
  local protocol="${PROTOCOL:-HTTP}"
  case "$protocol" in
    HTTP)
      gcloud compute target-http-proxies describe "$TARGET_PROXY" \
        --project="$PROJECT_ID" \
        --global
      ;;
    HTTPS)
      gcloud compute target-https-proxies describe "$TARGET_PROXY" \
        --project="$PROJECT_ID" \
        --global
      ;;
    GRPC)
      gcloud compute target-grpc-proxies describe "$TARGET_PROXY" \
        --project="$PROJECT_ID" \
        --global
      ;;
    *)
      format-echo "ERROR" "Protocol must be specified to describe target proxy"
      exit 1
      ;;
  esac
  
  print_with_separator "End of Target Proxy Details"
}

get_forwarding_rule() {
  format-echo "INFO" "Getting forwarding rule details..."
  
  if [[ -z "$FORWARDING_RULE" ]]; then
    format-echo "ERROR" "Forwarding rule name is required"
    exit 1
  fi
  
  print_with_separator "Forwarding Rule: $FORWARDING_RULE"
  gcloud compute forwarding-rules describe "$FORWARDING_RULE" \
    --project="$PROJECT_ID" \
    --global
  print_with_separator "End of Forwarding Rule Details"
}

get_health_check() {
  format-echo "INFO" "Getting health check details..."
  
  if [[ -z "$HEALTH_CHECK" ]]; then
    format-echo "ERROR" "Health check name is required"
    exit 1
  fi
  
  print_with_separator "Health Check: $HEALTH_CHECK"
  gcloud compute health-checks describe "$HEALTH_CHECK" \
    --project="$PROJECT_ID" \
    --global
  print_with_separator "End of Health Check Details"
}

update_backend_service() {
  format-echo "INFO" "Updating backend service..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  format-echo "INFO" "Use the following command to add backends:"
  echo "gcloud compute backend-services add-backend $BACKEND_SERVICE \\"
  echo "  --instance-group=INSTANCE_GROUP \\"
  echo "  --instance-group-zone=ZONE \\"
  echo "  --global \\"
  echo "  --project=$PROJECT_ID"
  
  format-echo "INFO" "Backend service is ready for backend configuration"
}

update_url_map() {
  format-echo "INFO" "Updating URL map..."
  
  if [[ -z "$URL_MAP" ]]; then
    format-echo "ERROR" "URL map name is required"
    exit 1
  fi
  
  format-echo "INFO" "URL map '$URL_MAP' can be updated through the console or gcloud commands"
  format-echo "INFO" "Use 'gcloud compute url-maps edit $URL_MAP --global' to modify routing rules"
}

delete_forwarding_rule() {
  format-echo "INFO" "Deleting forwarding rule..."
  
  if [[ -z "$FORWARDING_RULE" ]]; then
    format-echo "ERROR" "Forwarding rule name is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete forwarding rule '$FORWARDING_RULE'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute forwarding-rules delete "$FORWARDING_RULE" \
    --project="$PROJECT_ID" \
    --global \
    --quiet
  
  format-echo "SUCCESS" "Forwarding rule '$FORWARDING_RULE' deleted"
}

delete_target_proxy() {
  format-echo "INFO" "Deleting target proxy..."
  
  if [[ -z "$TARGET_PROXY" ]]; then
    format-echo "ERROR" "Target proxy name is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete target proxy '$TARGET_PROXY'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  local protocol="${PROTOCOL:-HTTP}"
  case "$protocol" in
    HTTP)
      gcloud compute target-http-proxies delete "$TARGET_PROXY" \
        --project="$PROJECT_ID" \
        --global \
        --quiet
      ;;
    HTTPS)
      gcloud compute target-https-proxies delete "$TARGET_PROXY" \
        --project="$PROJECT_ID" \
        --global \
        --quiet
      ;;
    GRPC)
      gcloud compute target-grpc-proxies delete "$TARGET_PROXY" \
        --project="$PROJECT_ID" \
        --global \
        --quiet
      ;;
    *)
      format-echo "ERROR" "Protocol must be specified to delete target proxy"
      exit 1
      ;;
  esac
  
  format-echo "SUCCESS" "Target proxy '$TARGET_PROXY' deleted"
}

delete_url_map() {
  format-echo "INFO" "Deleting URL map..."
  
  if [[ -z "$URL_MAP" ]]; then
    format-echo "ERROR" "URL map name is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete URL map '$URL_MAP'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute url-maps delete "$URL_MAP" \
    --project="$PROJECT_ID" \
    --global \
    --quiet
  
  format-echo "SUCCESS" "URL map '$URL_MAP' deleted"
}

delete_backend_service() {
  format-echo "INFO" "Deleting backend service..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete backend service '$BACKEND_SERVICE'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute backend-services delete "$BACKEND_SERVICE" \
    --project="$PROJECT_ID" \
    --global \
    --quiet
  
  format-echo "SUCCESS" "Backend service '$BACKEND_SERVICE' deleted"
}

delete_health_check() {
  format-echo "INFO" "Deleting health check..."
  
  if [[ -z "$HEALTH_CHECK" ]]; then
    format-echo "ERROR" "Health check name is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete health check '$HEALTH_CHECK'"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud compute health-checks delete "$HEALTH_CHECK" \
    --project="$PROJECT_ID" \
    --global \
    --quiet
  
  format-echo "SUCCESS" "Health check '$HEALTH_CHECK' deleted"
}

check_status() {
  format-echo "INFO" "Checking Traffic Director status..."
  
  print_with_separator "Traffic Director Status"
  
  # Check if APIs are enabled
  if gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q "compute"; then
    format-echo "SUCCESS" "Compute Engine API is enabled"
  else
    format-echo "WARNING" "Compute Engine API is not enabled"
  fi
  
  if gcloud services list --enabled --filter="name:networkservices.googleapis.com" --format="value(name)" | grep -q "networkservices"; then
    format-echo "SUCCESS" "Network Services API is enabled"
  else
    format-echo "WARNING" "Network Services API is not enabled"
  fi
  
  # Count resources
  local backend_services_count
  backend_services_count=$(gcloud compute backend-services list --project="$PROJECT_ID" --global --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Backend services: $backend_services_count"
  
  local url_maps_count
  url_maps_count=$(gcloud compute url-maps list --project="$PROJECT_ID" --global --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "URL maps: $url_maps_count"
  
  local forwarding_rules_count
  forwarding_rules_count=$(gcloud compute forwarding-rules list --project="$PROJECT_ID" --global --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Global forwarding rules: $forwarding_rules_count"
  
  local health_checks_count
  health_checks_count=$(gcloud compute health-checks list --project="$PROJECT_ID" --global --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Health checks: $health_checks_count"
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling required APIs..."
  enable_apis
  format-echo "SUCCESS" "Required APIs enabled"
}

get_config() {
  format-echo "INFO" "Getting Traffic Director configuration..."
  
  print_with_separator "Traffic Director Configuration"
  
  # Display project info
  format-echo "INFO" "Project: $PROJECT_ID"
  
  # Check API status
  if gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q "compute"; then
    format-echo "SUCCESS" "Compute Engine API: Enabled"
  else
    format-echo "WARNING" "Compute Engine API: Disabled"
  fi
  
  if gcloud services list --enabled --filter="name:networkservices.googleapis.com" --format="value(name)" | grep -q "networkservices"; then
    format-echo "SUCCESS" "Network Services API: Enabled"
  else
    format-echo "WARNING" "Network Services API: Disabled"
  fi
  
  # Display configuration info
  echo
  echo "Traffic Director Features:"
  echo "- Global load balancing"
  echo "- Advanced traffic routing"
  echo "- Service mesh traffic management"
  echo "- gRPC load balancing"
  echo "- Circuit breaking and retries"
  echo "- Observability and monitoring"
  echo
  echo "Supported Protocols:"
  echo "- HTTP/1.1"
  echo "- HTTP/2"
  echo "- gRPC"
  echo
  echo "Load Balancing Schemes:"
  echo "- INTERNAL_SELF_MANAGED: For service mesh"
  echo "- EXTERNAL: For external traffic"
  echo
  echo "Traffic Director Console URL:"
  echo "https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?project=$PROJECT_ID"
  
  print_with_separator "End of Configuration"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    create-health-check)
      enable_apis
      create_health_check
      ;;
    create-backend-service)
      create_backend_service
      ;;
    create-url-map)
      create_url_map
      ;;
    create-target-proxy)
      create_target_proxy
      ;;
    create-forwarding-rule)
      create_forwarding_rule
      ;;
    list-backend-services)
      list_backend_services
      ;;
    list-url-maps)
      list_url_maps
      ;;
    list-target-proxies)
      list_target_proxies
      ;;
    list-forwarding-rules)
      list_forwarding_rules
      ;;
    list-health-checks)
      list_health_checks
      ;;
    get-backend-service)
      get_backend_service
      ;;
    get-url-map)
      get_url_map
      ;;
    get-target-proxy)
      get_target_proxy
      ;;
    get-forwarding-rule)
      get_forwarding_rule
      ;;
    get-health-check)
      get_health_check
      ;;
    update-backend-service)
      update_backend_service
      ;;
    update-url-map)
      update_url_map
      ;;
    delete-forwarding-rule)
      delete_forwarding_rule
      ;;
    delete-target-proxy)
      delete_target_proxy
      ;;
    delete-url-map)
      delete_url_map
      ;;
    delete-backend-service)
      delete_backend_service
      ;;
    delete-health-check)
      delete_health_check
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
  
  print_with_separator "GCP Traffic Director Manager"
  format-echo "INFO" "Starting Traffic Director management operations..."
  
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
  format-echo "SUCCESS" "Traffic Director management operation completed successfully."
  print_with_separator "End of GCP Traffic Director Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
