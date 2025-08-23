#!/usr/bin/env bash
# gcp-cdn-manager.sh
# Script to manage Google Cloud CDN

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
BACKEND_SERVICE=""
LOAD_BALANCER=""
CACHE_MODE=""
DEFAULT_TTL=""
MAX_TTL=""
CLIENT_TTL=""
NEGATIVE_CACHING=""
CACHE_KEY_POLICY=""
REGION=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud CDN Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud CDN for content delivery network services."
  echo "  Provides capabilities for managing CDN configurations, cache policies, and performance optimization."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-b, --backend-service NAME\033[0m   Set backend service name"
  echo -e "  \033[1;33m-l, --load-balancer NAME\033[0m     Set load balancer name"
  echo -e "  \033[1;33m-m, --cache-mode MODE\033[0m        Set cache mode (CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL)"
  echo -e "  \033[1;33m--default-ttl TTL\033[0m            Set default TTL in seconds"
  echo -e "  \033[1;33m--max-ttl TTL\033[0m                Set maximum TTL in seconds"
  echo -e "  \033[1;33m--client-ttl TTL\033[0m             Set client TTL in seconds"
  echo -e "  \033[1;33m--negative-caching BOOL\033[0m      Enable/disable negative caching"
  echo -e "  \033[1;33m--cache-key-policy POLICY\033[0m    Set cache key policy"
  echo -e "  \033[1;33m-r, --region REGION\033[0m          Set region for regional resources"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36menable-cdn\033[0m                  Enable CDN for backend service"
  echo -e "  \033[1;36mdisable-cdn\033[0m                 Disable CDN for backend service"
  echo -e "  \033[1;36mlist-backend-services\033[0m       List backend services with CDN"
  echo -e "  \033[1;36mget-cdn-config\033[0m              Get CDN configuration"
  echo -e "  \033[1;36mupdate-cache-policy\033[0m         Update cache policy"
  echo -e "  \033[1;36minvalidate-cache\033[0m            Invalidate CDN cache"
  echo -e "  \033[1;36mlist-cache-invalidations\033[0m    List cache invalidation operations"
  echo -e "  \033[1;36mget-cache-stats\033[0m             Get CDN cache statistics"
  echo -e "  \033[1;36mcreate-signed-url\033[0m           Create signed URL for private content"
  echo -e "  \033[1;36mlist-edge-locations\033[0m         List CDN edge locations"
  echo -e "  \033[1;36mstatus\033[0m                      Check CDN status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Compute Engine API"
  echo -e "  \033[1;36mget-config\033[0m                  Get CDN configuration"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project -b my-backend-service enable-cdn"
  echo "  $0 -p my-project -b my-backend-service get-cdn-config"
  echo "  $0 -p my-project -b my-backend-service -m CACHE_ALL_STATIC update-cache-policy"
  echo "  $0 -p my-project -b my-backend-service invalidate-cache"
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
      -b|--backend-service)
        if [[ -n "${2:-}" ]]; then
          BACKEND_SERVICE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --backend-service"
          usage
        fi
        ;;
      -l|--load-balancer)
        if [[ -n "${2:-}" ]]; then
          LOAD_BALANCER="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --load-balancer"
          usage
        fi
        ;;
      -m|--cache-mode)
        if [[ -n "${2:-}" ]]; then
          CACHE_MODE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --cache-mode"
          usage
        fi
        ;;
      --default-ttl)
        if [[ -n "${2:-}" ]]; then
          DEFAULT_TTL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --default-ttl"
          usage
        fi
        ;;
      --max-ttl)
        if [[ -n "${2:-}" ]]; then
          MAX_TTL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --max-ttl"
          usage
        fi
        ;;
      --client-ttl)
        if [[ -n "${2:-}" ]]; then
          CLIENT_TTL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --client-ttl"
          usage
        fi
        ;;
      --negative-caching)
        if [[ -n "${2:-}" ]]; then
          NEGATIVE_CACHING="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --negative-caching"
          usage
        fi
        ;;
      --cache-key-policy)
        if [[ -n "${2:-}" ]]; then
          CACHE_KEY_POLICY="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --cache-key-policy"
          usage
        fi
        ;;
      -r|--region)
        if [[ -n "${2:-}" ]]; then
          REGION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --region"
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
# CLOUD CDN OPERATIONS
#=====================================================================
enable_cdn() {
  format-echo "INFO" "Enabling CDN for backend service..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  local cmd="gcloud compute backend-services update '$BACKEND_SERVICE'"
  cmd="$cmd --enable-cdn"
  cmd="$cmd --project='$PROJECT_ID'"
  
  # Add region if specified (for regional backend services)
  if [[ -n "$REGION" ]]; then
    cmd="$cmd --region='$REGION'"
  else
    cmd="$cmd --global"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "CDN enabled for backend service '$BACKEND_SERVICE'"
}

disable_cdn() {
  format-echo "INFO" "Disabling CDN for backend service..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  local cmd="gcloud compute backend-services update '$BACKEND_SERVICE'"
  cmd="$cmd --no-enable-cdn"
  cmd="$cmd --project='$PROJECT_ID'"
  
  # Add region if specified
  if [[ -n "$REGION" ]]; then
    cmd="$cmd --region='$REGION'"
  else
    cmd="$cmd --global"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "CDN disabled for backend service '$BACKEND_SERVICE'"
}

list_backend_services() {
  format-echo "INFO" "Listing backend services with CDN..."
  
  print_with_separator "Backend Services with CDN"
  
  # List global backend services
  echo "Global backend services:"
  gcloud compute backend-services list \
    --project="$PROJECT_ID" \
    --global \
    --filter="enableCDN=true" \
    --format="table(name,enableCDN,cdnPolicy.cacheMode)"
  
  echo
  echo "Regional backend services:"
  gcloud compute backend-services list \
    --project="$PROJECT_ID" \
    --filter="enableCDN=true AND region:*" \
    --format="table(name,region,enableCDN,cdnPolicy.cacheMode)"
  
  print_with_separator "End of Backend Services"
}

get_cdn_config() {
  format-echo "INFO" "Getting CDN configuration..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  print_with_separator "CDN Configuration: $BACKEND_SERVICE"
  
  local cmd="gcloud compute backend-services describe '$BACKEND_SERVICE'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  if [[ -n "$REGION" ]]; then
    cmd="$cmd --region='$REGION'"
  else
    cmd="$cmd --global"
  fi
  
  cmd="$cmd --format='yaml(enableCDN,cdnPolicy)'"
  
  eval "$cmd"
  print_with_separator "End of CDN Configuration"
}

update_cache_policy() {
  format-echo "INFO" "Updating cache policy..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  local cmd="gcloud compute backend-services update '$BACKEND_SERVICE'"
  cmd="$cmd --project='$PROJECT_ID'"
  
  # Add region if specified
  if [[ -n "$REGION" ]]; then
    cmd="$cmd --region='$REGION'"
  else
    cmd="$cmd --global"
  fi
  
  # Add cache policy options
  if [[ -n "$CACHE_MODE" ]]; then
    cmd="$cmd --cache-mode='$CACHE_MODE'"
  fi
  
  if [[ -n "$DEFAULT_TTL" ]]; then
    cmd="$cmd --default-ttl='$DEFAULT_TTL'"
  fi
  
  if [[ -n "$MAX_TTL" ]]; then
    cmd="$cmd --max-ttl='$MAX_TTL'"
  fi
  
  if [[ -n "$CLIENT_TTL" ]]; then
    cmd="$cmd --client-ttl='$CLIENT_TTL'"
  fi
  
  if [[ -n "$NEGATIVE_CACHING" ]]; then
    if [[ "$NEGATIVE_CACHING" == "true" ]]; then
      cmd="$cmd --enable-negative-caching"
    else
      cmd="$cmd --no-enable-negative-caching"
    fi
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "Cache policy updated for '$BACKEND_SERVICE'"
}

invalidate_cache() {
  format-echo "INFO" "Invalidating CDN cache..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  read -p "Enter cache invalidation path (e.g., /*, /images/*): " cache_path
  if [[ -z "$cache_path" ]]; then
    format-echo "ERROR" "Cache path is required"
    exit 1
  fi
  
  # Get URL map associated with the backend service
  local url_map
  url_map=$(gcloud compute url-maps list \
    --project="$PROJECT_ID" \
    --filter="defaultService:$BACKEND_SERVICE OR pathMatchers.defaultService:$BACKEND_SERVICE" \
    --format="value(name)" \
    --limit=1)
  
  if [[ -z "$url_map" ]]; then
    format-echo "ERROR" "No URL map found for backend service '$BACKEND_SERVICE'"
    exit 1
  fi
  
  format-echo "INFO" "Found URL map: $url_map"
  format-echo "INFO" "Invalidating path: $cache_path"
  
  gcloud compute url-maps invalidate-cdn-cache "$url_map" \
    --path="$cache_path" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Cache invalidation initiated for path '$cache_path'"
}

list_cache_invalidations() {
  format-echo "INFO" "Listing cache invalidation operations..."
  
  print_with_separator "Cache Invalidation Operations"
  gcloud compute operations list \
    --project="$PROJECT_ID" \
    --filter="operationType=invalidateCache" \
    --format="table(name,status,progress,insertTime,endTime)"
  print_with_separator "End of Cache Invalidations"
}

get_cache_stats() {
  format-echo "INFO" "Getting CDN cache statistics..."
  
  if [[ -z "$BACKEND_SERVICE" ]]; then
    format-echo "ERROR" "Backend service name is required"
    exit 1
  fi
  
  print_with_separator "CDN Cache Statistics"
  
  # Note: Cache statistics are available through Cloud Monitoring
  format-echo "INFO" "Cache statistics are available in Cloud Monitoring"
  format-echo "INFO" "Backend Service: $BACKEND_SERVICE"
  
  echo
  echo "To view detailed cache statistics:"
  echo "1. Go to Cloud Monitoring: https://console.cloud.google.com/monitoring"
  echo "2. Navigate to Metrics Explorer"
  echo "3. Select resource type: HTTPS/HTTP Load Balancer"
  echo "4. Select metrics:"
  echo "   - compute.googleapis.com/https/backend_request_count"
  echo "   - compute.googleapis.com/https/total_latencies"
  echo "   - loadbalancing.googleapis.com/https/cache_hit_count"
  echo "   - loadbalancing.googleapis.com/https/cache_miss_count"
  
  print_with_separator "End of Cache Statistics"
}

create_signed_url() {
  format-echo "INFO" "Creating signed URL for private content..."
  
  read -p "Enter the URL to sign: " url_to_sign
  if [[ -z "$url_to_sign" ]]; then
    format-echo "ERROR" "URL is required"
    exit 1
  fi
  
  read -p "Enter key name: " key_name
  if [[ -z "$key_name" ]]; then
    format-echo "ERROR" "Key name is required"
    exit 1
  fi
  
  read -p "Enter private key file path: " private_key_file
  if [[ -z "$private_key_file" ]] || [[ ! -f "$private_key_file" ]]; then
    format-echo "ERROR" "Valid private key file path is required"
    exit 1
  fi
  
  read -p "Enter expiration time (e.g., 2024-12-31T23:59:59Z): " expiration
  if [[ -z "$expiration" ]]; then
    format-echo "ERROR" "Expiration time is required"
    exit 1
  fi
  
  gcloud compute sign-url "$url_to_sign" \
    --key-name="$key_name" \
    --key-file="$private_key_file" \
    --expires="$expiration" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Signed URL created"
}

list_edge_locations() {
  format-echo "INFO" "Listing CDN edge locations..."
  
  print_with_separator "CDN Edge Locations"
  
  echo "Google Cloud CDN has edge locations worldwide including:"
  echo
  echo "North America:"
  echo "- United States (multiple locations)"
  echo "- Canada"
  echo
  echo "Europe:"
  echo "- United Kingdom"
  echo "- Germany"
  echo "- France"
  echo "- Netherlands"
  echo "- Belgium"
  echo "- And more..."
  echo
  echo "Asia Pacific:"
  echo "- Japan"
  echo "- Singapore"
  echo "- Australia"
  echo "- South Korea"
  echo "- And more..."
  echo
  echo "For the most current list of edge locations:"
  echo "https://cloud.google.com/cdn/docs/locations"
  
  print_with_separator "End of Edge Locations"
}

check_status() {
  format-echo "INFO" "Checking CDN status..."
  
  print_with_separator "Cloud CDN Status"
  
  # Check if Compute Engine API is enabled
  if gcloud services list --enabled --filter="name:compute.googleapis.com" --format="value(name)" | grep -q "compute"; then
    format-echo "SUCCESS" "Compute Engine API is enabled"
  else
    format-echo "WARNING" "Compute Engine API is not enabled"
  fi
  
  # Count backend services with CDN enabled
  local cdn_services_count
  cdn_services_count=$(gcloud compute backend-services list --project="$PROJECT_ID" --filter="enableCDN=true" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Backend services with CDN enabled: $cdn_services_count"
  
  # List active invalidation operations
  local active_invalidations
  active_invalidations=$(gcloud compute operations list --project="$PROJECT_ID" --filter="operationType=invalidateCache AND status=RUNNING" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Active cache invalidations: $active_invalidations"
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling Compute Engine API..."
  enable_apis
  format-echo "SUCCESS" "Compute Engine API enabled"
}

get_config() {
  format-echo "INFO" "Getting CDN configuration..."
  
  print_with_separator "Cloud CDN Configuration"
  
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
  echo "CDN Configuration Options:"
  echo "- Cache Modes: CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL"
  echo "- TTL Settings: Default, Maximum, Client TTL"
  echo "- Negative Caching: For error responses"
  echo "- Cache Key Policies: Include/exclude query parameters"
  echo "- Signed URLs: For private content access"
  echo
  echo "CDN Console URL:"
  echo "https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers?project=$PROJECT_ID"
  
  print_with_separator "End of Configuration"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    enable-cdn)
      enable_apis
      enable_cdn
      ;;
    disable-cdn)
      disable_cdn
      ;;
    list-backend-services)
      list_backend_services
      ;;
    get-cdn-config)
      get_cdn_config
      ;;
    update-cache-policy)
      update_cache_policy
      ;;
    invalidate-cache)
      invalidate_cache
      ;;
    list-cache-invalidations)
      list_cache_invalidations
      ;;
    get-cache-stats)
      get_cache_stats
      ;;
    create-signed-url)
      create_signed_url
      ;;
    list-edge-locations)
      list_edge_locations
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
  
  print_with_separator "GCP Cloud CDN Manager"
  format-echo "INFO" "Starting Cloud CDN management operations..."
  
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
  format-echo "SUCCESS" "Cloud CDN management operation completed successfully."
  print_with_separator "End of GCP Cloud CDN Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
