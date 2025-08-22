#!/usr/bin/env bash
# gcp-cloudrun-manager.sh
# Script to manage GCP Cloud Run services, revisions, and traffic management.

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
REGION="us-central1"
SERVICE_NAME=""
IMAGE=""
SERVICE_YAML=""
REVISION=""
TRAFFIC_PERCENT=""
PLATFORM="managed"
ALLOW_UNAUTHENTICATED=false
MEMORY="512Mi"
CPU="1000m"
CONCURRENCY="80"
TIMEOUT="300s"
MIN_INSTANCES="0"
MAX_INSTANCES="100"
EXECUTION_ENVIRONMENT="gen2"
PORT="8080"
ENV_VARS=""
SERVICE_ACCOUNT=""
LABELS=""
ANNOTATIONS=""
INGRESS="all"
BINARY_AUTHORIZATION=""
VPC_CONNECTOR=""
VPC_EGRESS=""
CLOUDSQL_INSTANCES=""
SECRET_ENV_VARS=""
SECRET_VOLUMES=""
TAG=""
DESCRIPTION=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Run Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Cloud Run services, revisions, and traffic."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mService Actions:\033[0m"
  echo -e "  \033[1;33mdeploy\033[0m                   Deploy a Cloud Run service"
  echo -e "  \033[1;33mupdate\033[0m                   Update an existing service"
  echo -e "  \033[1;33mdelete\033[0m                   Delete a Cloud Run service"
  echo -e "  \033[1;33mlist\033[0m                     List all Cloud Run services"
  echo -e "  \033[1;33mdescribe\033[0m                 Describe a specific service"
  echo -e "  \033[1;33mget-url\033[0m                  Get service URL"
  echo -e "  \033[1;33mreplace\033[0m                  Replace service with YAML"
  echo
  echo -e "\033[1;34mRevision Actions:\033[0m"
  echo -e "  \033[1;33mlist-revisions\033[0m           List service revisions"
  echo -e "  \033[1;33mdescribe-revision\033[0m        Describe a specific revision"
  echo -e "  \033[1;33mdelete-revision\033[0m          Delete a revision"
  echo -e "  \033[1;33mupdate-traffic\033[0m           Update traffic allocation"
  echo
  echo -e "\033[1;34mIAM Actions:\033[0m"
  echo -e "  \033[1;33mallow-unauthenticated\033[0m    Allow unauthenticated access"
  echo -e "  \033[1;33mrevoke-unauthenticated\033[0m   Revoke unauthenticated access"
  echo -e "  \033[1;33mget-iam-policy\033[0m           Get IAM policy"
  echo -e "  \033[1;33mset-iam-policy\033[0m           Set IAM policy"
  echo -e "  \033[1;33madd-iam-binding\033[0m          Add IAM policy binding"
  echo -e "  \033[1;33mremove-iam-binding\033[0m       Remove IAM policy binding"
  echo
  echo -e "\033[1;34mOperational Actions:\033[0m"
  echo -e "  \033[1;33mget-logs\033[0m                 Get service logs"
  echo -e "  \033[1;33mstream-logs\033[0m              Stream service logs"
  echo -e "  \033[1;33mget-metrics\033[0m              Get service metrics"
  echo -e "  \033[1;33mlist-domains\033[0m             List custom domains"
  echo -e "  \033[1;33mmap-domain\033[0m               Map custom domain"
  echo -e "  \033[1;33munmap-domain\033[0m             Unmap custom domain"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--region <region>\033[0m                (Required) GCP region (default: us-central1)"
  echo -e "  \033[1;33m--service <name>\033[0m                 (Required for most actions) Service name"
  echo -e "  \033[1;33m--image <image>\033[0m                  (Required for deploy) Container image"
  echo -e "  \033[1;33m--yaml <file>\033[0m                    (Optional) Service YAML file"
  echo -e "  \033[1;33m--revision <name>\033[0m                (Optional) Specific revision name"
  echo -e "  \033[1;33m--traffic <percent>\033[0m              (Optional) Traffic percentage for revision"
  echo -e "  \033[1;33m--tag <name>\033[0m                     (Optional) Revision tag"
  echo -e "  \033[1;33m--platform <platform>\033[0m           (Optional) Platform: managed (default)"
  echo -e "  \033[1;33m--allow-unauthenticated\033[0m          (Optional) Allow unauthenticated access"
  echo -e "  \033[1;33m--memory <size>\033[0m                  (Optional) Memory limit (default: 512Mi)"
  echo -e "  \033[1;33m--cpu <amount>\033[0m                   (Optional) CPU allocation (default: 1000m)"
  echo -e "  \033[1;33m--concurrency <number>\033[0m           (Optional) Max concurrent requests (default: 80)"
  echo -e "  \033[1;33m--timeout <duration>\033[0m             (Optional) Request timeout (default: 300s)"
  echo -e "  \033[1;33m--min-instances <number>\033[0m         (Optional) Minimum instances (default: 0)"
  echo -e "  \033[1;33m--max-instances <number>\033[0m         (Optional) Maximum instances (default: 100)"
  echo -e "  \033[1;33m--port <port>\033[0m                    (Optional) Container port (default: 8080)"
  echo -e "  \033[1;33m--env-vars <vars>\033[0m                (Optional) Environment variables (KEY=VALUE,KEY2=VALUE2)"
  echo -e "  \033[1;33m--service-account <email>\033[0m        (Optional) Service account email"
  echo -e "  \033[1;33m--labels <labels>\033[0m                (Optional) Labels (KEY=VALUE,KEY2=VALUE2)"
  echo -e "  \033[1;33m--vpc-connector <name>\033[0m           (Optional) VPC connector name"
  echo -e "  \033[1;33m--cloudsql-instances <instances>\033[0m (Optional) Cloud SQL instances"
  echo -e "  \033[1;33m--ingress <type>\033[0m                 (Optional) Ingress setting: all, internal, internal-and-cloud-load-balancing"
  echo -e "  \033[1;33m--execution-environment <env>\033[0m    (Optional) Execution environment: gen1, gen2 (default)"
  echo -e "  \033[1;33m--description <text>\033[0m             (Optional) Service description"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 deploy --project my-project --service hello-world --image gcr.io/my-project/hello"
  echo "  $0 deploy --project my-project --service api --image us-docker.pkg.dev/my-project/repo/api:latest --allow-unauthenticated"
  echo "  $0 update-traffic --project my-project --service api --revision api-v2 --traffic 50"
  echo "  $0 list --project my-project --region us-central1"
  echo "  $0 get-logs --project my-project --service hello-world"
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
        SERVICE_NAME="$2"
        shift 2
        ;;
      --image)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No image provided after --image."
          usage
        fi
        IMAGE="$2"
        shift 2
        ;;
      --yaml)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No YAML file provided after --yaml."
          usage
        fi
        SERVICE_YAML="$2"
        shift 2
        ;;
      --revision)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No revision provided after --revision."
          usage
        fi
        REVISION="$2"
        shift 2
        ;;
      --traffic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No traffic percentage provided after --traffic."
          usage
        fi
        TRAFFIC_PERCENT="$2"
        shift 2
        ;;
      --tag)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No tag provided after --tag."
          usage
        fi
        TAG="$2"
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
          format-echo "ERROR" "No CPU amount provided after --cpu."
          usage
        fi
        CPU="$2"
        shift 2
        ;;
      --concurrency)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No concurrency number provided after --concurrency."
          usage
        fi
        CONCURRENCY="$2"
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
      --port)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No port provided after --port."
          usage
        fi
        PORT="$2"
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
      --labels)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No labels provided after --labels."
          usage
        fi
        LABELS="$2"
        shift 2
        ;;
      --vpc-connector)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No VPC connector provided after --vpc-connector."
          usage
        fi
        VPC_CONNECTOR="$2"
        shift 2
        ;;
      --cloudsql-instances)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Cloud SQL instances provided after --cloudsql-instances."
          usage
        fi
        CLOUDSQL_INSTANCES="$2"
        shift 2
        ;;
      --ingress)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No ingress type provided after --ingress."
          usage
        fi
        INGRESS="$2"
        shift 2
        ;;
      --execution-environment)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No execution environment provided after --execution-environment."
          usage
        fi
        EXECUTION_ENVIRONMENT="$2"
        shift 2
        ;;
      --description)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No description provided after --description."
          usage
        fi
        DESCRIPTION="$2"
        shift 2
        ;;
      --allow-unauthenticated)
        ALLOW_UNAUTHENTICATED=true
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

# Function to build deployment command
build_deploy_command() {
  local deploy_cmd="gcloud run deploy $SERVICE_NAME"
  deploy_cmd+=" --project=$PROJECT_ID"
  deploy_cmd+=" --region=$REGION"
  deploy_cmd+=" --platform=$PLATFORM"
  
  if [ -n "$IMAGE" ]; then
    deploy_cmd+=" --image=$IMAGE"
  fi
  
  if [ -n "$MEMORY" ]; then
    deploy_cmd+=" --memory=$MEMORY"
  fi
  
  if [ -n "$CPU" ]; then
    deploy_cmd+=" --cpu=$CPU"
  fi
  
  if [ -n "$CONCURRENCY" ]; then
    deploy_cmd+=" --concurrency=$CONCURRENCY"
  fi
  
  if [ -n "$TIMEOUT" ]; then
    deploy_cmd+=" --timeout=$TIMEOUT"
  fi
  
  if [ -n "$MIN_INSTANCES" ]; then
    deploy_cmd+=" --min-instances=$MIN_INSTANCES"
  fi
  
  if [ -n "$MAX_INSTANCES" ]; then
    deploy_cmd+=" --max-instances=$MAX_INSTANCES"
  fi
  
  if [ -n "$PORT" ]; then
    deploy_cmd+=" --port=$PORT"
  fi
  
  if [ -n "$ENV_VARS" ]; then
    deploy_cmd+=" --set-env-vars=$ENV_VARS"
  fi
  
  if [ -n "$SERVICE_ACCOUNT" ]; then
    deploy_cmd+=" --service-account=$SERVICE_ACCOUNT"
  fi
  
  if [ -n "$LABELS" ]; then
    deploy_cmd+=" --labels=$LABELS"
  fi
  
  if [ -n "$VPC_CONNECTOR" ]; then
    deploy_cmd+=" --vpc-connector=$VPC_CONNECTOR"
  fi
  
  if [ -n "$CLOUDSQL_INSTANCES" ]; then
    deploy_cmd+=" --add-cloudsql-instances=$CLOUDSQL_INSTANCES"
  fi
  
  if [ -n "$INGRESS" ]; then
    deploy_cmd+=" --ingress=$INGRESS"
  fi
  
  if [ -n "$EXECUTION_ENVIRONMENT" ]; then
    deploy_cmd+=" --execution-environment=$EXECUTION_ENVIRONMENT"
  fi
  
  if [ "$ALLOW_UNAUTHENTICATED" = true ]; then
    deploy_cmd+=" --allow-unauthenticated"
  else
    deploy_cmd+=" --no-allow-unauthenticated"
  fi
  
  if [ -n "$TAG" ]; then
    deploy_cmd+=" --tag=$TAG"
  fi
  
  echo "$deploy_cmd"
}

#=====================================================================
# SERVICE MANAGEMENT
#=====================================================================
# Function to deploy Cloud Run service
deploy_service() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Deploying Cloud Run service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would deploy Cloud Run service:"
    format-echo "INFO" "  Service: $service"
    format-echo "INFO" "  Image: $IMAGE"
    format-echo "INFO" "  Region: $REGION"
    format-echo "INFO" "  Memory: $MEMORY"
    format-echo "INFO" "  CPU: $CPU"
    return 0
  fi
  
  local deploy_cmd
  deploy_cmd=$(build_deploy_command)
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $deploy_cmd"
  fi
  
  if ! eval "$deploy_cmd"; then
    format-echo "ERROR" "Failed to deploy Cloud Run service: $service"
    return 1
  fi
  
  format-echo "SUCCESS" "Deployed Cloud Run service: $service"
  
  # Get service URL
  local service_url
  if service_url=$(gcloud run services describe "$service" \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM" \
    --format="value(status.url)" 2>/dev/null); then
    format-echo "INFO" "Service URL: $service_url"
  fi
  
  return 0
}

# Function to delete Cloud Run service
delete_service() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Deleting Cloud Run service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete Cloud Run service: $service"
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
  
  if ! gcloud run services delete "$service" \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM" \
    --quiet; then
    format-echo "ERROR" "Failed to delete Cloud Run service: $service"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Cloud Run service: $service"
  return 0
}

# Function to list Cloud Run services
list_services() {
  local project="$1"
  
  format-echo "INFO" "Listing Cloud Run services"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list Cloud Run services"
    return 0
  fi
  
  if ! gcloud run services list \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM" \
    --format="table(metadata.name,status.url,spec.template.spec.containers[0].image,status.conditions[0].status)"; then
    format-echo "ERROR" "Failed to list Cloud Run services"
    return 1
  fi
  
  return 0
}

# Function to describe Cloud Run service
describe_service() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Describing Cloud Run service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would describe Cloud Run service: $service"
    return 0
  fi
  
  if ! gcloud run services describe "$service" \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM"; then
    format-echo "ERROR" "Failed to describe Cloud Run service: $service"
    return 1
  fi
  
  return 0
}

# Function to get service URL
get_service_url() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Getting Cloud Run service URL: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get service URL for: $service"
    return 0
  fi
  
  local service_url
  if service_url=$(gcloud run services describe "$service" \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM" \
    --format="value(status.url)" 2>/dev/null); then
    format-echo "SUCCESS" "Service URL: $service_url"
    echo "$service_url"
  else
    format-echo "ERROR" "Failed to get service URL for: $service"
    return 1
  fi
  
  return 0
}

#=====================================================================
# TRAFFIC MANAGEMENT
#=====================================================================
# Function to update traffic allocation
update_traffic() {
  local project="$1"
  local service="$2"
  local revision="$3"
  local traffic="$4"
  
  format-echo "INFO" "Updating traffic allocation for service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would update traffic:"
    format-echo "INFO" "  Service: $service"
    format-echo "INFO" "  Revision: $revision"
    format-echo "INFO" "  Traffic: $traffic%"
    return 0
  fi
  
  if ! gcloud run services update-traffic "$service" \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM" \
    --to-revisions="$revision=$traffic"; then
    format-echo "ERROR" "Failed to update traffic allocation"
    return 1
  fi
  
  format-echo "SUCCESS" "Updated traffic allocation for service: $service"
  return 0
}

# Function to list revisions
list_revisions() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Listing revisions for service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list revisions for service: $service"
    return 0
  fi
  
  if ! gcloud run revisions list \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM" \
    --service="$service" \
    --format="table(metadata.name,status.conditions[0].status,spec.containers[0].image,metadata.creationTimestamp)"; then
    format-echo "ERROR" "Failed to list revisions"
    return 1
  fi
  
  return 0
}

#=====================================================================
# IAM MANAGEMENT
#=====================================================================
# Function to allow unauthenticated access
allow_unauthenticated() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Allowing unauthenticated access to service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would allow unauthenticated access to: $service"
    return 0
  fi
  
  if ! gcloud run services add-iam-policy-binding "$service" \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM" \
    --member="allUsers" \
    --role="roles/run.invoker"; then
    format-echo "ERROR" "Failed to allow unauthenticated access"
    return 1
  fi
  
  format-echo "SUCCESS" "Allowed unauthenticated access to service: $service"
  return 0
}

# Function to revoke unauthenticated access
revoke_unauthenticated() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Revoking unauthenticated access from service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would revoke unauthenticated access from: $service"
    return 0
  fi
  
  if ! gcloud run services remove-iam-policy-binding "$service" \
    --project="$project" \
    --region="$REGION" \
    --platform="$PLATFORM" \
    --member="allUsers" \
    --role="roles/run.invoker"; then
    format-echo "ERROR" "Failed to revoke unauthenticated access"
    return 1
  fi
  
  format-echo "SUCCESS" "Revoked unauthenticated access from service: $service"
  return 0
}

#=====================================================================
# LOGGING AND MONITORING
#=====================================================================
# Function to get service logs
get_logs() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Getting logs for service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get logs for service: $service"
    return 0
  fi
  
  if ! gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$service" \
    --project="$project" \
    --limit=50 \
    --format="table(timestamp,severity,textPayload)"; then
    format-echo "ERROR" "Failed to get logs for service: $service"
    return 1
  fi
  
  return 0
}

# Function to stream service logs
stream_logs() {
  local project="$1"
  local service="$2"
  
  format-echo "INFO" "Streaming logs for service: $service (Press Ctrl+C to stop)"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would stream logs for service: $service"
    return 0
  fi
  
  if ! gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=$service" \
    --project="$project" \
    --format="table(timestamp,severity,textPayload)"; then
    format-echo "ERROR" "Failed to stream logs for service: $service"
    return 1
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
  
  print_with_separator "GCP Cloud Run Manager Script"
  format-echo "INFO" "Starting GCP Cloud Run Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Cloud Run Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Cloud Run Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Cloud Run Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    deploy)
      if [ -z "$SERVICE_NAME" ] || [ -z "$IMAGE" ]; then
        format-echo "ERROR" "Service name and image are required for deployment"
        exit 1
      fi
      ;;
    delete|describe|get-url|list-revisions|allow-unauthenticated|revoke-unauthenticated|get-logs|stream-logs)
      if [ -z "$SERVICE_NAME" ]; then
        format-echo "ERROR" "Service name is required for action: $ACTION"
        exit 1
      fi
      ;;
    update-traffic)
      if [ -z "$SERVICE_NAME" ] || [ -z "$REVISION" ] || [ -z "$TRAFFIC_PERCENT" ]; then
        format-echo "ERROR" "Service name, revision, and traffic percentage are required for traffic update"
        exit 1
      fi
      ;;
    replace)
      if [ -z "$SERVICE_YAML" ]; then
        format-echo "ERROR" "YAML file is required for replace action"
        exit 1
      fi
      ;;
    list)
      # No additional requirements
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: deploy, delete, list, describe, update-traffic, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    deploy)
      if deploy_service "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Cloud Run service deployment completed successfully"
      else
        format-echo "ERROR" "Failed to deploy Cloud Run service"
        exit 1
      fi
      ;;
    delete)
      if delete_service "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Cloud Run service deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete Cloud Run service"
        exit 1
      fi
      ;;
    list)
      if list_services "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed Cloud Run services successfully"
      else
        format-echo "ERROR" "Failed to list Cloud Run services"
        exit 1
      fi
      ;;
    describe)
      if describe_service "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Described Cloud Run service successfully"
      else
        format-echo "ERROR" "Failed to describe Cloud Run service"
        exit 1
      fi
      ;;
    get-url)
      if get_service_url "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Got service URL successfully"
      else
        format-echo "ERROR" "Failed to get service URL"
        exit 1
      fi
      ;;
    list-revisions)
      if list_revisions "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Listed revisions successfully"
      else
        format-echo "ERROR" "Failed to list revisions"
        exit 1
      fi
      ;;
    update-traffic)
      if update_traffic "$PROJECT_ID" "$SERVICE_NAME" "$REVISION" "$TRAFFIC_PERCENT"; then
        format-echo "SUCCESS" "Traffic allocation updated successfully"
      else
        format-echo "ERROR" "Failed to update traffic allocation"
        exit 1
      fi
      ;;
    allow-unauthenticated)
      if allow_unauthenticated "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Allowed unauthenticated access successfully"
      else
        format-echo "ERROR" "Failed to allow unauthenticated access"
        exit 1
      fi
      ;;
    revoke-unauthenticated)
      if revoke_unauthenticated "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Revoked unauthenticated access successfully"
      else
        format-echo "ERROR" "Failed to revoke unauthenticated access"
        exit 1
      fi
      ;;
    get-logs)
      if get_logs "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Retrieved logs successfully"
      else
        format-echo "ERROR" "Failed to retrieve logs"
        exit 1
      fi
      ;;
    stream-logs)
      if stream_logs "$PROJECT_ID" "$SERVICE_NAME"; then
        format-echo "SUCCESS" "Log streaming completed"
      else
        format-echo "ERROR" "Failed to stream logs"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Cloud Run Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
