#!/usr/bin/env bash
# gcp-appengine-manager.sh
# Script to manage GCP App Engine applications, services, and deployments.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"

#=====================================================================
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
PROJECT_ID=""
REGION="us-central"
SERVICE=""
VERSION=""
RUNTIME=""
APP_YAML="app.yaml"
CRON_YAML="cron.yaml"
DISPATCH_YAML="dispatch.yaml"
INDEX_YAML="index.yaml"
QUEUE_YAML="queue.yaml"
SOURCE_DIR="."
IMAGE_URL=""
PROMOTE=true
STOP_PREVIOUS_VERSION=false
NO_CACHE=false
BUCKET=""
ENV_VARS=""
SERVICE_ACCOUNT=""
MEMORY=""
CPU=""
INSTANCES=""
SCALING=""
MIN_INSTANCES="1"
MAX_INSTANCES="10"
TARGET_CPU_UTILIZATION="0.6"
TARGET_THROUGHPUT_UTILIZATION="0.6"
MAX_CONCURRENT_REQUESTS="80"
MAX_IDLE_INSTANCES="automatic"
MIN_IDLE_INSTANCES="automatic"
MIN_PENDING_LATENCY="automatic"
MAX_PENDING_LATENCY="automatic"
TRAFFIC_ALLOCATION=""
SPLIT_BY=""
MIGRATE_TRAFFIC=false
LOGS_LEVEL="info"
TIMEOUT="20m"
NETWORK=""
SUBNETWORK=""
TAGS=""
DESCRIPTION=""
QUIET=false
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP App Engine Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP App Engine applications, services, versions, and traffic."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mApplication Actions:\033[0m"
  echo -e "  \033[1;33mcreate-app\033[0m                Create App Engine application"
  echo -e "  \033[1;33mdescribe-app\033[0m              Describe App Engine application"
  echo -e "  \033[1;33mupdate-app\033[0m                Update application settings"
  echo -e "  \033[1;33mbrowse\033[0m                    Open application in browser"
  echo
  echo -e "\033[1;34mDeployment Actions:\033[0m"
  echo -e "  \033[1;33mdeploy\033[0m                    Deploy application"
  echo -e "  \033[1;33mdeploy-cron\033[0m               Deploy cron configuration"
  echo -e "  \033[1;33mdeploy-dispatch\033[0m           Deploy dispatch configuration"
  echo -e "  \033[1;33mdeploy-index\033[0m              Deploy index configuration"
  echo -e "  \033[1;33mdeploy-queue\033[0m              Deploy queue configuration"
  echo
  echo -e "\033[1;34mService Actions:\033[0m"
  echo -e "  \033[1;33mlist-services\033[0m             List services"
  echo -e "  \033[1;33mdescribe-service\033[0m          Describe a service"
  echo -e "  \033[1;33mdelete-service\033[0m            Delete a service"
  echo -e "  \033[1;33mbrowse-service\033[0m            Open service in browser"
  echo
  echo -e "\033[1;34mVersion Actions:\033[0m"
  echo -e "  \033[1;33mlist-versions\033[0m             List versions"
  echo -e "  \033[1;33mdescribe-version\033[0m          Describe a version"
  echo -e "  \033[1;33mdelete-version\033[0m            Delete a version"
  echo -e "  \033[1;33mstart-version\033[0m             Start a version"
  echo -e "  \033[1;33mstop-version\033[0m              Stop a version"
  echo -e "  \033[1;33mmigrate-traffic\033[0m           Migrate traffic to version"
  echo -e "  \033[1;33msplit-traffic\033[0m             Split traffic between versions"
  echo
  echo -e "\033[1;34mTraffic Management:\033[0m"
  echo -e "  \033[1;33mget-traffic\033[0m               Get traffic allocation"
  echo -e "  \033[1;33mset-traffic\033[0m               Set traffic allocation"
  echo -e "  \033[1;33mstop-traffic\033[0m              Stop traffic to version"
  echo
  echo -e "\033[1;34mInstance Management:\033[0m"
  echo -e "  \033[1;33mlist-instances\033[0m            List instances"
  echo -e "  \033[1;33mdescribe-instance\033[0m         Describe an instance"
  echo -e "  \033[1;33mdelete-instance\033[0m           Delete an instance"
  echo -e "  \033[1;33mdebug-instance\033[0m            Connect to instance for debugging"
  echo
  echo -e "\033[1;34mLogs & Monitoring:\033[0m"
  echo -e "  \033[1;33mget-logs\033[0m                  Get application logs"
  echo -e "  \033[1;33mstream-logs\033[0m               Stream application logs"
  echo -e "  \033[1;33mget-operations\033[0m            Get deployment operations"
  echo -e "  \033[1;33mget-operation\033[0m             Get specific operation"
  echo -e "  \033[1;33mcancel-operation\033[0m          Cancel operation"
  echo
  echo -e "\033[1;34mConfiguration Actions:\033[0m"
  echo -e "  \033[1;33mgenerate-config\033[0m           Generate sample app.yaml"
  echo -e "  \033[1;33mvalidate-config\033[0m           Validate configuration files"
  echo -e "  \033[1;33mgen-repo-info-file\033[0m        Generate repository info file"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--region <region>\033[0m                (Optional) App Engine region (default: us-central)"
  echo -e "  \033[1;33m--service <name>\033[0m                 (Optional) Service name (default: default)"
  echo -e "  \033[1;33m--version <version>\033[0m              (Optional) Version name"
  echo -e "  \033[1;33m--runtime <runtime>\033[0m              (Optional) Runtime environment"
  echo -e "  \033[1;33m--app-yaml <file>\033[0m                (Optional) App configuration file (default: app.yaml)"
  echo -e "  \033[1;33m--source-dir <dir>\033[0m               (Optional) Source directory (default: current)"
  echo -e "  \033[1;33m--image-url <url>\033[0m                (Optional) Container image URL"
  echo -e "  \033[1;33m--env-vars <vars>\033[0m                (Optional) Environment variables (KEY=VALUE,KEY2=VALUE2)"
  echo -e "  \033[1;33m--service-account <email>\033[0m        (Optional) Service account email"
  echo -e "  \033[1;33m--memory <size>\033[0m                  (Optional) Memory allocation"
  echo -e "  \033[1;33m--cpu <cores>\033[0m                    (Optional) CPU allocation"
  echo -e "  \033[1;33m--instances <count>\033[0m              (Optional) Number of instances"
  echo -e "  \033[1;33m--min-instances <count>\033[0m          (Optional) Minimum instances"
  echo -e "  \033[1;33m--max-instances <count>\033[0m          (Optional) Maximum instances"
  echo -e "  \033[1;33m--traffic <allocation>\033[0m           (Optional) Traffic allocation percentage"
  echo -e "  \033[1;33m--split-by <method>\033[0m              (Optional) Traffic split method: ip, cookie, random"
  echo -e "  \033[1;33m--timeout <duration>\033[0m             (Optional) Operation timeout (default: 20m)"
  echo -e "  \033[1;33m--promote\033[0m                        (Optional) Promote version to receive traffic"
  echo -e "  \033[1;33m--no-promote\033[0m                     (Optional) Do not promote version"
  echo -e "  \033[1;33m--stop-previous-version\033[0m          (Optional) Stop previous version after deployment"
  echo -e "  \033[1;33m--no-cache\033[0m                       (Optional) Disable build cache"
  echo -e "  \033[1;33m--migrate-traffic\033[0m                (Optional) Migrate traffic gradually"
  echo -e "  \033[1;33m--quiet\033[0m                          (Optional) Suppress non-essential output"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 create-app --project my-project --region us-central"
  echo "  $0 deploy --project my-project --app-yaml app.yaml --promote"
  echo "  $0 deploy --project my-project --service api --version v2 --no-promote"
  echo "  $0 split-traffic --project my-project --service default --traffic v1=50,v2=50"
  echo "  $0 get-logs --project my-project --service default --version v1"
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
      --region)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No region provided after --region."
          usage
        fi
        REGION="$2"
        shift 2
        ;;
      --service)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No service name provided after --service."
          usage
        fi
        SERVICE="$2"
        shift 2
        ;;
      --version)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No version provided after --version."
          usage
        fi
        VERSION="$2"
        shift 2
        ;;
      --runtime)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No runtime provided after --runtime."
          usage
        fi
        RUNTIME="$2"
        shift 2
        ;;
      --app-yaml)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No app.yaml file provided after --app-yaml."
          usage
        fi
        APP_YAML="$2"
        shift 2
        ;;
      --source-dir)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source directory provided after --source-dir."
          usage
        fi
        SOURCE_DIR="$2"
        shift 2
        ;;
      --image-url)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No image URL provided after --image-url."
          usage
        fi
        IMAGE_URL="$2"
        shift 2
        ;;
      --env-vars)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No environment variables provided after --env-vars."
          usage
        fi
        ENV_VARS="$2"
        shift 2
        ;;
      --service-account)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No service account provided after --service-account."
          usage
        fi
        SERVICE_ACCOUNT="$2"
        shift 2
        ;;
      --memory)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No memory size provided after --memory."
          usage
        fi
        MEMORY="$2"
        shift 2
        ;;
      --cpu)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No CPU specification provided after --cpu."
          usage
        fi
        CPU="$2"
        shift 2
        ;;
      --instances)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No instances count provided after --instances."
          usage
        fi
        INSTANCES="$2"
        shift 2
        ;;
      --min-instances)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No minimum instances provided after --min-instances."
          usage
        fi
        MIN_INSTANCES="$2"
        shift 2
        ;;
      --max-instances)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No maximum instances provided after --max-instances."
          usage
        fi
        MAX_INSTANCES="$2"
        shift 2
        ;;
      --traffic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No traffic allocation provided after --traffic."
          usage
        fi
        TRAFFIC_ALLOCATION="$2"
        shift 2
        ;;
      --split-by)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No split method provided after --split-by."
          usage
        fi
        SPLIT_BY="$2"
        shift 2
        ;;
      --timeout)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No timeout provided after --timeout."
          usage
        fi
        TIMEOUT="$2"
        shift 2
        ;;
      --promote)
        PROMOTE=true
        shift
        ;;
      --no-promote)
        PROMOTE=false
        shift
        ;;
      --stop-previous-version)
        STOP_PREVIOUS_VERSION=true
        shift
        ;;
      --no-cache)
        NO_CACHE=true
        shift
        ;;
      --migrate-traffic)
        MIGRATE_TRAFFIC=true
        shift
        ;;
      --quiet)
        QUIET=true
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
  local missing_deps=()
  
  if ! command_exists gcloud; then
    missing_deps+=("gcloud")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    format-echo "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    format-echo "INFO" "Please install Google Cloud SDK"
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

# Function to generate sample app.yaml
generate_sample_app_yaml() {
  local runtime="$1"
  
  case "$runtime" in
    python38|python39|python310|python311)
      cat << 'EOF'
runtime: python39
instance_class: F2

# Basic scaling configuration
automatic_scaling:
  min_instances: 1
  max_instances: 10
  target_cpu_utilization: 0.6

# Environment variables
env_variables:
  ENVIRONMENT: "production"
  DEBUG: "False"

# Handlers
handlers:
- url: /static
  static_dir: static

- url: /.*
  script: auto

# Health check
readiness_check:
  path: "/health"
  check_interval_sec: 5
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2

liveness_check:
  path: "/health"
  check_interval_sec: 30
  timeout_sec: 4
  failure_threshold: 4
  success_threshold: 2
EOF
      ;;
    nodejs16|nodejs18|nodejs20)
      cat << 'EOF'
runtime: nodejs18
instance_class: F2

# Basic scaling configuration
automatic_scaling:
  min_instances: 1
  max_instances: 10
  target_cpu_utilization: 0.6

# Environment variables
env_variables:
  NODE_ENV: "production"

# Handlers
handlers:
- url: /static
  static_dir: public

- url: /.*
  script: auto

# Health check
readiness_check:
  path: "/health"
  check_interval_sec: 5
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2

liveness_check:
  path: "/health"
  check_interval_sec: 30
  timeout_sec: 4
  failure_threshold: 4
  success_threshold: 2
EOF
      ;;
    go116|go117|go118|go119|go120|go121)
      cat << 'EOF'
runtime: go121
instance_class: F2

# Basic scaling configuration
automatic_scaling:
  min_instances: 1
  max_instances: 10
  target_cpu_utilization: 0.6

# Environment variables
env_variables:
  GIN_MODE: "release"

# Handlers
handlers:
- url: /static
  static_dir: static

- url: /.*
  script: auto

# Health check
readiness_check:
  path: "/health"
  check_interval_sec: 5
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2

liveness_check:
  path: "/health"
  check_interval_sec: 30
  timeout_sec: 4
  failure_threshold: 4
  success_threshold: 2
EOF
      ;;
    java11|java17)
      cat << 'EOF'
runtime: java17
instance_class: F2

# Basic scaling configuration
automatic_scaling:
  min_instances: 1
  max_instances: 10
  target_cpu_utilization: 0.6

# Environment variables
env_variables:
  SPRING_PROFILES_ACTIVE: "production"

# Handlers
handlers:
- url: /static
  static_dir: src/main/resources/static

- url: /.*
  script: auto

# Health check
readiness_check:
  path: "/actuator/health"
  check_interval_sec: 5
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2

liveness_check:
  path: "/actuator/health"
  check_interval_sec: 30
  timeout_sec: 4
  failure_threshold: 4
  success_threshold: 2
EOF
      ;;
    *)
      cat << 'EOF'
runtime: python39
instance_class: F2

# Basic scaling configuration
automatic_scaling:
  min_instances: 1
  max_instances: 10
  target_cpu_utilization: 0.6

# Environment variables
env_variables:
  ENVIRONMENT: "production"

# Handlers
handlers:
- url: /.*
  script: auto

# Health check
readiness_check:
  path: "/health"
  check_interval_sec: 5
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2

liveness_check:
  path: "/health"
  check_interval_sec: 30
  timeout_sec: 4
  failure_threshold: 4
  success_threshold: 2
EOF
      ;;
  esac
}

#=====================================================================
# APPLICATION MANAGEMENT
#=====================================================================
# Function to create App Engine application
create_app() {
  local project="$1"
  local region="$2"
  
  format-echo "INFO" "Creating App Engine application"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create App Engine application:"
    format-echo "INFO" "  Project: $project"
    format-echo "INFO" "  Region: $region"
    return 0
  fi
  
  if ! gcloud app create \
    --project="$project" \
    --region="$region"; then
    format-echo "ERROR" "Failed to create App Engine application"
    return 1
  fi
  
  format-echo "SUCCESS" "Created App Engine application in region: $region"
  return 0
}

# Function to describe App Engine application
describe_app() {
  local project="$1"
  
  format-echo "INFO" "Describing App Engine application"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would describe App Engine application"
    return 0
  fi
  
  if ! gcloud app describe \
    --project="$project"; then
    format-echo "ERROR" "Failed to describe App Engine application"
    return 1
  fi
  
  return 0
}

# Function to browse App Engine application
browse_app() {
  local project="$1"
  local service="${2:-}"
  local version="${3:-}"
  
  format-echo "INFO" "Opening App Engine application in browser"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would open application in browser"
    return 0
  fi
  
  local browse_cmd="gcloud app browse"
  browse_cmd+=" --project=$project"
  
  if [ -n "$service" ]; then
    browse_cmd+=" --service=$service"
  fi
  
  if [ -n "$version" ]; then
    browse_cmd+=" --version=$version"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $browse_cmd"
  fi
  
  if ! eval "$browse_cmd"; then
    format-echo "ERROR" "Failed to open application in browser"
    return 1
  fi
  
  format-echo "SUCCESS" "Opened application in browser"
  return 0
}

#=====================================================================
# DEPLOYMENT MANAGEMENT
#=====================================================================
# Function to deploy application
deploy_app() {
  local project="$1"
  local app_yaml="$2"
  
  format-echo "INFO" "Deploying App Engine application"
  
  if [ ! -f "$app_yaml" ] && [ "$DRY_RUN" != true ]; then
    format-echo "ERROR" "App configuration file not found: $app_yaml"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would deploy application:"
    format-echo "INFO" "  Config: $app_yaml"
    format-echo "INFO" "  Source: $SOURCE_DIR"
    format-echo "INFO" "  Promote: $PROMOTE"
    return 0
  fi
  
  local deploy_cmd="gcloud app deploy $app_yaml"
  deploy_cmd+=" --project=$project"
  deploy_cmd+=" --source-dir=$SOURCE_DIR"
  
  if [ "$PROMOTE" = true ]; then
    deploy_cmd+=" --promote"
  else
    deploy_cmd+=" --no-promote"
  fi
  
  if [ "$STOP_PREVIOUS_VERSION" = true ]; then
    deploy_cmd+=" --stop-previous-version"
  fi
  
  if [ -n "$VERSION" ]; then
    deploy_cmd+=" --version=$VERSION"
  fi
  
  if [ -n "$SERVICE_ACCOUNT" ]; then
    deploy_cmd+=" --service-account=$SERVICE_ACCOUNT"
  fi
  
  if [ -n "$IMAGE_URL" ]; then
    deploy_cmd+=" --image-url=$IMAGE_URL"
  fi
  
  if [ "$NO_CACHE" = true ]; then
    deploy_cmd+=" --no-cache"
  fi
  
  if [ "$QUIET" = true ]; then
    deploy_cmd+=" --quiet"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $deploy_cmd"
  fi
  
  if ! eval "$deploy_cmd"; then
    format-echo "ERROR" "Failed to deploy application"
    return 1
  fi
  
  format-echo "SUCCESS" "Application deployed successfully"
  return 0
}

# Function to deploy cron configuration
deploy_cron() {
  local project="$1"
  local cron_yaml="$2"
  
  format-echo "INFO" "Deploying cron configuration"
  
  if [ ! -f "$cron_yaml" ] && [ "$DRY_RUN" != true ]; then
    format-echo "ERROR" "Cron configuration file not found: $cron_yaml"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would deploy cron configuration: $cron_yaml"
    return 0
  fi
  
  if ! gcloud app deploy "$cron_yaml" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to deploy cron configuration"
    return 1
  fi
  
  format-echo "SUCCESS" "Cron configuration deployed successfully"
  return 0
}

#=====================================================================
# SERVICE MANAGEMENT
#=====================================================================
# Function to list services
list_services() {
  local project="$1"
  
  format-echo "INFO" "Listing App Engine services"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list App Engine services"
    return 0
  fi
  
  if ! gcloud app services list \
    --project="$project" \
    --format="table(id,split.allocations.yesno(yes='Yes', no='No'):label='TRAFFIC_SPLIT')"; then
    format-echo "ERROR" "Failed to list services"
    return 1
  fi
  
  return 0
}

# Function to describe service
describe_service() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Describing service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would describe service: $service"
    return 0
  fi
  
  if ! gcloud app services describe "$service" \
    --project="$project"; then
    format-echo "ERROR" "Failed to describe service: $service"
    return 1
  fi
  
  return 0
}

# Function to delete service
delete_service() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Deleting service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete service: $service"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the service '$service'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud app services delete "$service" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete service: $service"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted service: $service"
  return 0
}

#=====================================================================
# VERSION MANAGEMENT
#=====================================================================
# Function to list versions
list_versions() {
  local project="$1"
  local service="${2:-}"
  
  format-echo "INFO" "Listing App Engine versions"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list versions"
    return 0
  fi
  
  local list_cmd="gcloud app versions list"
  list_cmd+=" --project=$project"
  
  if [ -n "$service" ]; then
    list_cmd+=" --service=$service"
  fi
  
  list_cmd+=" --format='table(id,service,version.createTime.date(),traffic_split,runtime)'"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $list_cmd"
  fi
  
  if ! eval "$list_cmd"; then
    format-echo "ERROR" "Failed to list versions"
    return 1
  fi
  
  return 0
}

# Function to describe version
describe_version() {
  local project="$1"
  local version="$2"
  local service="${3:-default}"
  
  format-echo "INFO" "Describing version: $version"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would describe version: $version"
    return 0
  fi
  
  if ! gcloud app versions describe "$version" \
    --project="$project" \
    --service="$service"; then
    format-echo "ERROR" "Failed to describe version: $version"
    return 1
  fi
  
  return 0
}

# Function to delete version
delete_version() {
  local project="$1"
  local version="$2"
  local service="${3:-default}"
  
  format-echo "INFO" "Deleting version: $version"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete version: $version"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete version '$version' of service '$service'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud app versions delete "$version" \
    --project="$project" \
    --service="$service" \
    --quiet; then
    format-echo "ERROR" "Failed to delete version: $version"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted version: $version"
  return 0
}

# Function to stop version
stop_version() {
  local project="$1"
  local version="$2"
  local service="${3:-default}"
  
  format-echo "INFO" "Stopping version: $version"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would stop version: $version"
    return 0
  fi
  
  if ! gcloud app versions stop "$version" \
    --project="$project" \
    --service="$service" \
    --quiet; then
    format-echo "ERROR" "Failed to stop version: $version"
    return 1
  fi
  
  format-echo "SUCCESS" "Stopped version: $version"
  return 0
}

# Function to start version
start_version() {
  local project="$1"
  local version="$2"
  local service="${3:-default}"
  
  format-echo "INFO" "Starting version: $version"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would start version: $version"
    return 0
  fi
  
  if ! gcloud app versions start "$version" \
    --project="$project" \
    --service="$service" \
    --quiet; then
    format-echo "ERROR" "Failed to start version: $version"
    return 1
  fi
  
  format-echo "SUCCESS" "Started version: $version"
  return 0
}

#=====================================================================
# TRAFFIC MANAGEMENT
#=====================================================================
# Function to migrate traffic
migrate_traffic() {
  local project="$1"
  local version="$2"
  local service="${3:-default}"
  
  format-echo "INFO" "Migrating traffic to version: $version"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would migrate traffic to version: $version"
    return 0
  fi
  
  if ! gcloud app versions migrate "$version" \
    --project="$project" \
    --service="$service" \
    --quiet; then
    format-echo "ERROR" "Failed to migrate traffic"
    return 1
  fi
  
  format-echo "SUCCESS" "Migrated traffic to version: $version"
  return 0
}

# Function to split traffic
split_traffic() {
  local project="$1"
  local service="$2"
  local allocation="$3"
  
  format-echo "INFO" "Splitting traffic for service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would split traffic:"
    format-echo "INFO" "  Service: $service"
    format-echo "INFO" "  Allocation: $allocation"
    return 0
  fi
  
  local split_cmd="gcloud app services set-traffic $service"
  split_cmd+=" --project=$project"
  split_cmd+=" --splits=$allocation"
  
  if [ -n "$SPLIT_BY" ]; then
    split_cmd+=" --split-by=$SPLIT_BY"
  fi
  
  if [ "$MIGRATE_TRAFFIC" = true ]; then
    split_cmd+=" --migrate"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $split_cmd"
  fi
  
  if ! eval "$split_cmd"; then
    format-echo "ERROR" "Failed to split traffic"
    return 1
  fi
  
  format-echo "SUCCESS" "Split traffic for service: $service"
  return 0
}

#=====================================================================
# LOGS AND MONITORING
#=====================================================================
# Function to get logs
get_logs() {
  local project="$1"
  local service="${2:-default}"
  local version="${3:-}"
  
  format-echo "INFO" "Getting logs for service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get logs for service: $service"
    return 0
  fi
  
  local logs_cmd="gcloud app logs tail"
  logs_cmd+=" --project=$project"
  logs_cmd+=" --service=$service"
  
  if [ -n "$version" ]; then
    logs_cmd+=" --version=$version"
  fi
  
  logs_cmd+=" --level=$LOGS_LEVEL"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $logs_cmd"
  fi
  
  if ! eval "$logs_cmd"; then
    format-echo "ERROR" "Failed to get logs"
    return 1
  fi
  
  return 0
}

#=====================================================================
# CONFIGURATION MANAGEMENT
#=====================================================================
# Function to generate configuration
generate_config() {
  local runtime="${1:-python39}"
  local output_file="${2:-app.yaml}"
  
  format-echo "INFO" "Generating sample app.yaml for runtime: $runtime"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would generate config file: $output_file"
    return 0
  fi
  
  if [ -f "$output_file" ] && [ "$FORCE" != true ]; then
    echo "WARNING: File '$output_file' already exists."
    read -p "Overwrite? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  generate_sample_app_yaml "$runtime" > "$output_file"
  
  format-echo "SUCCESS" "Generated sample app.yaml: $output_file"
  return 0
}

# Function to validate configuration
validate_config() {
  local app_yaml="$1"
  
  format-echo "INFO" "Validating configuration file: $app_yaml"
  
  if [ ! -f "$app_yaml" ]; then
    format-echo "ERROR" "Configuration file not found: $app_yaml"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would validate config: $app_yaml"
    return 0
  fi
  
  # Check YAML syntax
  if ! python3 -c "import yaml; yaml.safe_load(open('$app_yaml'))" 2>/dev/null; then
    format-echo "ERROR" "Invalid YAML syntax in configuration file"
    return 1
  fi
  
  format-echo "SUCCESS" "Configuration file is valid"
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
  
  print_with_separator "GCP App Engine Manager Script"
  format-echo "INFO" "Starting GCP App Engine Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP App Engine Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP App Engine Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP App Engine Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-app)
      # Project and region are sufficient
      ;;
    deploy)
      if [ ! -f "$APP_YAML" ] && [ "$DRY_RUN" != true ]; then
        format-echo "ERROR" "App configuration file not found: $APP_YAML"
        exit 1
      fi
      ;;
    deploy-cron)
      if [ -z "$CRON_YAML" ] || ([ ! -f "$CRON_YAML" ] && [ "$DRY_RUN" != true ]); then
        format-echo "ERROR" "Cron configuration file is required and must exist"
        exit 1
      fi
      ;;
    delete-service|describe-service|browse-service)
      if [ -z "$SERVICE" ]; then
        format-echo "ERROR" "Service name is required for action: $ACTION"
        exit 1
      fi
      ;;
    delete-version|describe-version|start-version|stop-version|migrate-traffic)
      if [ -z "$VERSION" ]; then
        format-echo "ERROR" "Version is required for action: $ACTION"
        exit 1
      fi
      ;;
    split-traffic)
      if [ -z "$SERVICE" ] || [ -z "$TRAFFIC_ALLOCATION" ]; then
        format-echo "ERROR" "Service and traffic allocation are required for traffic splitting"
        exit 1
      fi
      ;;
    generate-config)
      # Runtime is optional, defaults to python39
      ;;
    validate-config)
      if [ -z "$APP_YAML" ]; then
        format-echo "ERROR" "Configuration file path is required for validation"
        exit 1
      fi
      ;;
    describe-app|list-services|list-versions|browse|get-logs)
      # No additional requirements
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-app, deploy, list-services, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-app)
      if create_app "$PROJECT_ID" "$REGION"; then
        format-echo "SUCCESS" "App Engine application creation completed successfully"
      else
        format-echo "ERROR" "Failed to create App Engine application"
        exit 1
      fi
      ;;
    describe-app)
      if describe_app "$PROJECT_ID"; then
        format-echo "SUCCESS" "App Engine application described successfully"
      else
        format-echo "ERROR" "Failed to describe App Engine application"
        exit 1
      fi
      ;;
    browse)
      if browse_app "$PROJECT_ID" "$SERVICE" "$VERSION"; then
        format-echo "SUCCESS" "Opened application in browser successfully"
      else
        format-echo "ERROR" "Failed to open application in browser"
        exit 1
      fi
      ;;
    deploy)
      if deploy_app "$PROJECT_ID" "$APP_YAML"; then
        format-echo "SUCCESS" "Application deployment completed successfully"
      else
        format-echo "ERROR" "Failed to deploy application"
        exit 1
      fi
      ;;
    deploy-cron)
      if deploy_cron "$PROJECT_ID" "$CRON_YAML"; then
        format-echo "SUCCESS" "Cron configuration deployment completed successfully"
      else
        format-echo "ERROR" "Failed to deploy cron configuration"
        exit 1
      fi
      ;;
    list-services)
      if list_services "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed services successfully"
      else
        format-echo "ERROR" "Failed to list services"
        exit 1
      fi
      ;;
    describe-service)
      if describe_service "$PROJECT_ID" "$SERVICE"; then
        format-echo "SUCCESS" "Described service successfully"
      else
        format-echo "ERROR" "Failed to describe service"
        exit 1
      fi
      ;;
    delete-service)
      if delete_service "$PROJECT_ID" "$SERVICE"; then
        format-echo "SUCCESS" "Service deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete service"
        exit 1
      fi
      ;;
    list-versions)
      if list_versions "$PROJECT_ID" "$SERVICE"; then
        format-echo "SUCCESS" "Listed versions successfully"
      else
        format-echo "ERROR" "Failed to list versions"
        exit 1
      fi
      ;;
    describe-version)
      if describe_version "$PROJECT_ID" "$VERSION" "$SERVICE"; then
        format-echo "SUCCESS" "Described version successfully"
      else
        format-echo "ERROR" "Failed to describe version"
        exit 1
      fi
      ;;
    delete-version)
      if delete_version "$PROJECT_ID" "$VERSION" "$SERVICE"; then
        format-echo "SUCCESS" "Version deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete version"
        exit 1
      fi
      ;;
    start-version)
      if start_version "$PROJECT_ID" "$VERSION" "$SERVICE"; then
        format-echo "SUCCESS" "Version started successfully"
      else
        format-echo "ERROR" "Failed to start version"
        exit 1
      fi
      ;;
    stop-version)
      if stop_version "$PROJECT_ID" "$VERSION" "$SERVICE"; then
        format-echo "SUCCESS" "Version stopped successfully"
      else
        format-echo "ERROR" "Failed to stop version"
        exit 1
      fi
      ;;
    migrate-traffic)
      if migrate_traffic "$PROJECT_ID" "$VERSION" "$SERVICE"; then
        format-echo "SUCCESS" "Traffic migration completed successfully"
      else
        format-echo "ERROR" "Failed to migrate traffic"
        exit 1
      fi
      ;;
    split-traffic)
      if split_traffic "$PROJECT_ID" "$SERVICE" "$TRAFFIC_ALLOCATION"; then
        format-echo "SUCCESS" "Traffic splitting completed successfully"
      else
        format-echo "ERROR" "Failed to split traffic"
        exit 1
      fi
      ;;
    get-logs)
      if get_logs "$PROJECT_ID" "$SERVICE" "$VERSION"; then
        format-echo "SUCCESS" "Retrieved logs successfully"
      else
        format-echo "ERROR" "Failed to get logs"
        exit 1
      fi
      ;;
    generate-config)
      if generate_config "$RUNTIME" "$APP_YAML"; then
        format-echo "SUCCESS" "Configuration generation completed successfully"
      else
        format-echo "ERROR" "Failed to generate configuration"
        exit 1
      fi
      ;;
    validate-config)
      if validate_config "$APP_YAML"; then
        format-echo "SUCCESS" "Configuration validation completed successfully"
      else
        format-echo "ERROR" "Failed to validate configuration"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP App Engine Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
