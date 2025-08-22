#!/usr/bin/env bash
# gcp-container-manager.sh
# Script to manage GCP container services - GKE clusters, Cloud Run, and Container Registry.

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
CLUSTER_NAME=""
ZONE="us-central1-a"
REGION="us-central1"
NODE_COUNT="3"
MACHINE_TYPE="e2-medium"
DISK_SIZE="100"
SERVICE_NAME=""
IMAGE_NAME=""
REGISTRY_NAME=""
REPOSITORY_NAME=""
TAG="latest"
PORT="8080"
CPU="1"
MEMORY="512Mi"
MIN_INSTANCES="0"
MAX_INSTANCES="100"
CONCURRENCY="80"
ENV_VARS=""
LABELS=""
PLATFORM="managed"
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Container Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP container services - GKE clusters, Cloud Run, and Container Registry."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33m=== GKE Cluster Management ===\033[0m"
  echo -e "  \033[1;33mcreate-cluster\033[0m       Create a new GKE cluster"
  echo -e "  \033[1;33mdelete-cluster\033[0m       Delete a GKE cluster"
  echo -e "  \033[1;33mlist-clusters\033[0m        List all GKE clusters"
  echo -e "  \033[1;33mget-cluster\033[0m          Get cluster details"
  echo -e "  \033[1;33mresize-cluster\033[0m       Resize cluster node pool"
  echo -e "  \033[1;33mupgrade-cluster\033[0m      Upgrade cluster master/nodes"
  echo -e "  \033[1;33mget-credentials\033[0m      Get cluster credentials for kubectl"
  echo -e "  \033[1;33m=== Cloud Run Management ===\033[0m"
  echo -e "  \033[1;33mdeploy-service\033[0m       Deploy a Cloud Run service"
  echo -e "  \033[1;33mupdate-service\033[0m       Update a Cloud Run service"
  echo -e "  \033[1;33mdelete-service\033[0m       Delete a Cloud Run service"
  echo -e "  \033[1;33mlist-services\033[0m        List all Cloud Run services"
  echo -e "  \033[1;33mget-service\033[0m          Get service details"
  echo -e "  \033[1;33mget-service-logs\033[0m     Get service logs"
  echo -e "  \033[1;33m=== Container Registry ===\033[0m"
  echo -e "  \033[1;33mlist-images\033[0m          List container images"
  echo -e "  \033[1;33mdelete-image\033[0m         Delete container image"
  echo -e "  \033[1;33mtag-image\033[0m            Tag container image"
  echo -e "  \033[1;33mpush-image\033[0m           Push image to registry"
  echo -e "  \033[1;33mpull-image\033[0m           Pull image from registry"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--cluster <name>\033[0m             (Required for cluster actions) Cluster name"
  echo -e "  \033[1;33m--zone <zone>\033[0m                (Optional) Zone (default: us-central1-a)"
  echo -e "  \033[1;33m--region <region>\033[0m            (Optional) Region (default: us-central1)"
  echo -e "  \033[1;33m--node-count <count>\033[0m         (Optional) Number of nodes (default: 3)"
  echo -e "  \033[1;33m--machine-type <type>\033[0m        (Optional) Machine type (default: e2-medium)"
  echo -e "  \033[1;33m--disk-size <gb>\033[0m             (Optional) Disk size in GB (default: 100)"
  echo -e "  \033[1;33m--service <name>\033[0m             (Required for Cloud Run actions) Service name"
  echo -e "  \033[1;33m--image <image>\033[0m              (Required for deployments) Container image"
  echo -e "  \033[1;33m--registry <name>\033[0m            (Optional) Registry name"
  echo -e "  \033[1;33m--repository <name>\033[0m          (Optional) Repository name"
  echo -e "  \033[1;33m--tag <tag>\033[0m                  (Optional) Image tag (default: latest)"
  echo -e "  \033[1;33m--port <port>\033[0m                (Optional) Container port (default: 8080)"
  echo -e "  \033[1;33m--cpu <cpu>\033[0m                  (Optional) CPU allocation (default: 1)"
  echo -e "  \033[1;33m--memory <memory>\033[0m            (Optional) Memory allocation (default: 512Mi)"
  echo -e "  \033[1;33m--min-instances <count>\033[0m      (Optional) Min instances (default: 0)"
  echo -e "  \033[1;33m--max-instances <count>\033[0m      (Optional) Max instances (default: 100)"
  echo -e "  \033[1;33m--concurrency <count>\033[0m        (Optional) Max concurrent requests (default: 80)"
  echo -e "  \033[1;33m--env-vars <vars>\033[0m            (Optional) Environment variables (key=value,key2=value2)"
  echo -e "  \033[1;33m--labels <labels>\033[0m            (Optional) Labels (key=value,key2=value2)"
  echo -e "  \033[1;33m--platform <platform>\033[0m       (Optional) Cloud Run platform: managed, gke (default: managed)"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 create-cluster --project my-project --cluster my-cluster --zone us-west1-a --node-count 5"
  echo "  $0 deploy-service --project my-project --service my-app --image gcr.io/my-project/my-app:v1.0"
  echo "  $0 list-clusters --project my-project"
  echo "  $0 list-services --project my-project --region us-central1"
  echo "  $0 update-service --project my-project --service my-app --cpu 2 --memory 1Gi --max-instances 50"
  echo "  $0 list-images --project my-project"
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
      --cluster)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No cluster name provided after --cluster."
          usage
        fi
        CLUSTER_NAME="$2"
        shift 2
        ;;
      --zone)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No zone provided after --zone."
          usage
        fi
        ZONE="$2"
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
      --node-count)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No node count provided after --node-count."
          usage
        fi
        NODE_COUNT="$2"
        shift 2
        ;;
      --machine-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No machine type provided after --machine-type."
          usage
        fi
        MACHINE_TYPE="$2"
        shift 2
        ;;
      --disk-size)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No disk size provided after --disk-size."
          usage
        fi
        DISK_SIZE="$2"
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
          format-echo "ERROR" "No image name provided after --image."
          usage
        fi
        IMAGE_NAME="$2"
        shift 2
        ;;
      --registry)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No registry name provided after --registry."
          usage
        fi
        REGISTRY_NAME="$2"
        shift 2
        ;;
      --repository)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No repository name provided after --repository."
          usage
        fi
        REPOSITORY_NAME="$2"
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
      --port)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No port provided after --port."
          usage
        fi
        PORT="$2"
        shift 2
        ;;
      --cpu)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No CPU value provided after --cpu."
          usage
        fi
        CPU="$2"
        shift 2
        ;;
      --memory)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No memory value provided after --memory."
          usage
        fi
        MEMORY="$2"
        shift 2
        ;;
      --min-instances)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No min instances provided after --min-instances."
          usage
        fi
        MIN_INSTANCES="$2"
        shift 2
        ;;
      --max-instances)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max instances provided after --max-instances."
          usage
        fi
        MAX_INSTANCES="$2"
        shift 2
        ;;
      --concurrency)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No concurrency value provided after --concurrency."
          usage
        fi
        CONCURRENCY="$2"
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
      --labels)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No labels provided after --labels."
          usage
        fi
        LABELS="$2"
        shift 2
        ;;
      --platform)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No platform provided after --platform."
          usage
        fi
        PLATFORM="$2"
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
# GKE CLUSTER FUNCTIONS
#=====================================================================
# Function to create GKE cluster
create_cluster() {
  local project="$1"
  local cluster="$2"
  local zone="$3"
  
  format-echo "INFO" "Creating GKE cluster: $cluster in zone: $zone"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create cluster:"
    format-echo "INFO" "  Name: $cluster"
    format-echo "INFO" "  Zone: $zone"
    format-echo "INFO" "  Node count: $NODE_COUNT"
    format-echo "INFO" "  Machine type: $MACHINE_TYPE"
    format-echo "INFO" "  Disk size: ${DISK_SIZE}GB"
    return 0
  fi
  
  local create_cmd="gcloud container clusters create $cluster"
  create_cmd+=" --project=$project"
  create_cmd+=" --zone=$zone"
  create_cmd+=" --num-nodes=$NODE_COUNT"
  create_cmd+=" --machine-type=$MACHINE_TYPE"
  create_cmd+=" --disk-size=$DISK_SIZE"
  create_cmd+=" --enable-autoscaling"
  create_cmd+=" --min-nodes=1"
  create_cmd+=" --max-nodes=10"
  create_cmd+=" --enable-autorepair"
  create_cmd+=" --enable-autoupgrade"
  create_cmd+=" --enable-ip-alias"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create cluster: $cluster"
    return 1
  fi
  
  format-echo "SUCCESS" "Created GKE cluster: $cluster"
  return 0
}

# Function to delete GKE cluster
delete_cluster() {
  local project="$1"
  local cluster="$2"
  local zone="$3"
  
  # Confirmation unless forced
  if [ "$FORCE" = false ]; then
    echo
    format-echo "WARNING" "This will permanently delete GKE cluster: $cluster"
    format-echo "WARNING" "All workloads and data will be lost!"
    echo
    read -p "Are you sure you want to delete this cluster? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      format-echo "INFO" "Cluster deletion cancelled"
      return 0
    fi
  fi
  
  format-echo "INFO" "Deleting GKE cluster: $cluster"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete cluster: $cluster"
    return 0
  fi
  
  if ! gcloud container clusters delete "$cluster" \
    --project="$project" \
    --zone="$zone" \
    --quiet; then
    format-echo "ERROR" "Failed to delete cluster: $cluster"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted GKE cluster: $cluster"
  return 0
}

# Function to list GKE clusters
list_clusters() {
  local project="$1"
  
  format-echo "INFO" "Listing GKE clusters in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list clusters"
    return 0
  fi
  
  if ! gcloud container clusters list \
    --project="$project" \
    --format="table(name,location,status,currentMasterVersion,currentNodeVersion,currentNodeCount)"; then
    format-echo "ERROR" "Failed to list clusters"
    return 1
  fi
  
  return 0
}

# Function to get cluster details
get_cluster() {
  local project="$1"
  local cluster="$2"
  local zone="$3"
  
  format-echo "INFO" "Getting details for cluster: $cluster"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get cluster details: $cluster"
    return 0
  fi
  
  if ! gcloud container clusters describe "$cluster" \
    --project="$project" \
    --zone="$zone"; then
    format-echo "ERROR" "Failed to get cluster details: $cluster"
    return 1
  fi
  
  return 0
}

# Function to resize cluster
resize_cluster() {
  local project="$1"
  local cluster="$2"
  local zone="$3"
  local count="$4"
  
  format-echo "INFO" "Resizing cluster $cluster to $count nodes"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would resize cluster to $count nodes"
    return 0
  fi
  
  if ! gcloud container clusters resize "$cluster" \
    --project="$project" \
    --zone="$zone" \
    --num-nodes="$count" \
    --quiet; then
    format-echo "ERROR" "Failed to resize cluster: $cluster"
    return 1
  fi
  
  format-echo "SUCCESS" "Resized cluster $cluster to $count nodes"
  return 0
}

# Function to get cluster credentials
get_credentials() {
  local project="$1"
  local cluster="$2"
  local zone="$3"
  
  format-echo "INFO" "Getting credentials for cluster: $cluster"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get cluster credentials"
    return 0
  fi
  
  if ! gcloud container clusters get-credentials "$cluster" \
    --project="$project" \
    --zone="$zone"; then
    format-echo "ERROR" "Failed to get cluster credentials: $cluster"
    return 1
  fi
  
  format-echo "SUCCESS" "Retrieved cluster credentials for: $cluster"
  format-echo "INFO" "You can now use kubectl to interact with the cluster"
  return 0
}

#=====================================================================
# CLOUD RUN FUNCTIONS
#=====================================================================
# Function to deploy Cloud Run service
deploy_service() {
  local project="$1"
  local service="$2"
  local image="$3"
  local region="$4"
  
  format-echo "INFO" "Deploying Cloud Run service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would deploy service:"
    format-echo "INFO" "  Name: $service"
    format-echo "INFO" "  Image: $image"
    format-echo "INFO" "  Region: $region"
    format-echo "INFO" "  Platform: $PLATFORM"
    return 0
  fi
  
  local deploy_cmd="gcloud run deploy $service"
  deploy_cmd+=" --project=$project"
  deploy_cmd+=" --image=$image"
  deploy_cmd+=" --region=$region"
  deploy_cmd+=" --platform=$PLATFORM"
  deploy_cmd+=" --port=$PORT"
  deploy_cmd+=" --cpu=$CPU"
  deploy_cmd+=" --memory=$MEMORY"
  deploy_cmd+=" --min-instances=$MIN_INSTANCES"
  deploy_cmd+=" --max-instances=$MAX_INSTANCES"
  deploy_cmd+=" --concurrency=$CONCURRENCY"
  deploy_cmd+=" --allow-unauthenticated"
  
  if [ -n "$ENV_VARS" ]; then
    deploy_cmd+=" --set-env-vars=$ENV_VARS"
  fi
  
  if [ -n "$LABELS" ]; then
    deploy_cmd+=" --labels=$LABELS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $deploy_cmd"
  fi
  
  if ! eval "$deploy_cmd"; then
    format-echo "ERROR" "Failed to deploy service: $service"
    return 1
  fi
  
  format-echo "SUCCESS" "Deployed Cloud Run service: $service"
  return 0
}

# Function to update Cloud Run service
update_service() {
  local project="$1"
  local service="$2"
  local region="$3"
  
  format-echo "INFO" "Updating Cloud Run service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would update service: $service"
    return 0
  fi
  
  local update_cmd="gcloud run services update $service"
  update_cmd+=" --project=$project"
  update_cmd+=" --region=$region"
  update_cmd+=" --platform=$PLATFORM"
  
  if [ -n "$IMAGE_NAME" ]; then
    update_cmd+=" --image=$IMAGE_NAME"
  fi
  
  update_cmd+=" --cpu=$CPU"
  update_cmd+=" --memory=$MEMORY"
  update_cmd+=" --min-instances=$MIN_INSTANCES"
  update_cmd+=" --max-instances=$MAX_INSTANCES"
  update_cmd+=" --concurrency=$CONCURRENCY"
  
  if [ -n "$ENV_VARS" ]; then
    update_cmd+=" --update-env-vars=$ENV_VARS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $update_cmd"
  fi
  
  if ! eval "$update_cmd"; then
    format-echo "ERROR" "Failed to update service: $service"
    return 1
  fi
  
  format-echo "SUCCESS" "Updated Cloud Run service: $service"
  return 0
}

# Function to delete Cloud Run service
delete_service() {
  local project="$1"
  local service="$2"
  local region="$3"
  
  format-echo "INFO" "Deleting Cloud Run service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete service: $service"
    return 0
  fi
  
  if ! gcloud run services delete "$service" \
    --project="$project" \
    --region="$region" \
    --platform="$PLATFORM" \
    --quiet; then
    format-echo "ERROR" "Failed to delete service: $service"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Cloud Run service: $service"
  return 0
}

# Function to list Cloud Run services
list_services() {
  local project="$1"
  local region="$2"
  
  format-echo "INFO" "Listing Cloud Run services in region: $region"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list services"
    return 0
  fi
  
  if ! gcloud run services list \
    --project="$project" \
    --region="$region" \
    --platform="$PLATFORM" \
    --format="table(metadata.name,status.url,status.latestReadyRevisionName,status.traffic[0].percent)"; then
    format-echo "ERROR" "Failed to list services"
    return 1
  fi
  
  return 0
}

# Function to get service details
get_service() {
  local project="$1"
  local service="$2"
  local region="$3"
  
  format-echo "INFO" "Getting details for service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get service details: $service"
    return 0
  fi
  
  if ! gcloud run services describe "$service" \
    --project="$project" \
    --region="$region" \
    --platform="$PLATFORM"; then
    format-echo "ERROR" "Failed to get service details: $service"
    return 1
  fi
  
  return 0
}

# Function to get service logs
get_service_logs() {
  local project="$1"
  local service="$2"
  local region="$3"
  
  format-echo "INFO" "Getting logs for service: $service"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get service logs: $service"
    return 0
  fi
  
  if ! gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$service" \
    --project="$project" \
    --limit=50 \
    --format="table(timestamp,severity,textPayload)"; then
    format-echo "ERROR" "Failed to get service logs: $service"
    return 1
  fi
  
  return 0
}

#=====================================================================
# CONTAINER REGISTRY FUNCTIONS
#=====================================================================
# Function to list container images
list_images() {
  local project="$1"
  
  format-echo "INFO" "Listing container images in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list container images"
    return 0
  fi
  
  if ! gcloud container images list \
    --project="$project" \
    --format="table(name,tags)"; then
    format-echo "ERROR" "Failed to list container images"
    return 1
  fi
  
  return 0
}

# Function to delete container image
delete_image() {
  local project="$1"
  local image="$2"
  
  format-echo "INFO" "Deleting container image: $image"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete image: $image"
    return 0
  fi
  
  if ! gcloud container images delete "$image" \
    --project="$project" \
    --force-delete-tags \
    --quiet; then
    format-echo "ERROR" "Failed to delete image: $image"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted container image: $image"
  return 0
}

# Function to tag container image
tag_image() {
  local project="$1"
  local source_image="$2"
  local target_tag="$3"
  
  format-echo "INFO" "Tagging image $source_image with tag: $target_tag"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would tag image"
    return 0
  fi
  
  if ! gcloud container images add-tag "$source_image" "$target_tag" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to tag image"
    return 1
  fi
  
  format-echo "SUCCESS" "Tagged image with: $target_tag"
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
  
  print_with_separator "GCP Container Manager Script"
  format-echo "INFO" "Starting GCP Container Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Container Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Container Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Container Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-cluster|delete-cluster|get-cluster|resize-cluster|get-credentials)
      if [ -z "$CLUSTER_NAME" ]; then
        format-echo "ERROR" "Cluster name is required for action: $ACTION"
        exit 1
      fi
      ;;
    deploy-service|update-service|delete-service|get-service|get-service-logs)
      if [ -z "$SERVICE_NAME" ]; then
        format-echo "ERROR" "Service name is required for action: $ACTION"
        exit 1
      fi
      ;;
    deploy-service)
      if [ -z "$IMAGE_NAME" ]; then
        format-echo "ERROR" "Image name is required for deploying service"
        exit 1
      fi
      ;;
    delete-image|tag-image)
      if [ -z "$IMAGE_NAME" ]; then
        format-echo "ERROR" "Image name is required for action: $ACTION"
        exit 1
      fi
      ;;
    list-clusters|list-services|list-images)
      # No additional requirements for list actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-cluster, delete-cluster, list-clusters, get-cluster, resize-cluster, upgrade-cluster, get-credentials, deploy-service, update-service, delete-service, list-services, get-service, get-service-logs, list-images, delete-image, tag-image, push-image, pull-image"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-cluster)
      if create_cluster "$PROJECT_ID" "$CLUSTER_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Cluster creation completed successfully"
      else
        format-echo "ERROR" "Failed to create cluster"
        exit 1
      fi
      ;;
    delete-cluster)
      if delete_cluster "$PROJECT_ID" "$CLUSTER_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Cluster deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete cluster"
        exit 1
      fi
      ;;
    list-clusters)
      if list_clusters "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed clusters successfully"
      else
        format-echo "ERROR" "Failed to list clusters"
        exit 1
      fi
      ;;
    get-cluster)
      if get_cluster "$PROJECT_ID" "$CLUSTER_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Retrieved cluster details successfully"
      else
        format-echo "ERROR" "Failed to get cluster details"
        exit 1
      fi
      ;;
    resize-cluster)
      if resize_cluster "$PROJECT_ID" "$CLUSTER_NAME" "$ZONE" "$NODE_COUNT"; then
        format-echo "SUCCESS" "Cluster resize completed successfully"
      else
        format-echo "ERROR" "Failed to resize cluster"
        exit 1
      fi
      ;;
    get-credentials)
      if get_credentials "$PROJECT_ID" "$CLUSTER_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Retrieved cluster credentials successfully"
      else
        format-echo "ERROR" "Failed to get cluster credentials"
        exit 1
      fi
      ;;
    deploy-service)
      if deploy_service "$PROJECT_ID" "$SERVICE_NAME" "$IMAGE_NAME" "$REGION"; then
        format-echo "SUCCESS" "Service deployment completed successfully"
      else
        format-echo "ERROR" "Failed to deploy service"
        exit 1
      fi
      ;;
    update-service)
      if update_service "$PROJECT_ID" "$SERVICE_NAME" "$REGION"; then
        format-echo "SUCCESS" "Service update completed successfully"
      else
        format-echo "ERROR" "Failed to update service"
        exit 1
      fi
      ;;
    delete-service)
      if delete_service "$PROJECT_ID" "$SERVICE_NAME" "$REGION"; then
        format-echo "SUCCESS" "Service deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete service"
        exit 1
      fi
      ;;
    list-services)
      if list_services "$PROJECT_ID" "$REGION"; then
        format-echo "SUCCESS" "Listed services successfully"
      else
        format-echo "ERROR" "Failed to list services"
        exit 1
      fi
      ;;
    get-service)
      if get_service "$PROJECT_ID" "$SERVICE_NAME" "$REGION"; then
        format-echo "SUCCESS" "Retrieved service details successfully"
      else
        format-echo "ERROR" "Failed to get service details"
        exit 1
      fi
      ;;
    get-service-logs)
      if get_service_logs "$PROJECT_ID" "$SERVICE_NAME" "$REGION"; then
        format-echo "SUCCESS" "Retrieved service logs successfully"
      else
        format-echo "ERROR" "Failed to get service logs"
        exit 1
      fi
      ;;
    list-images)
      if list_images "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed container images successfully"
      else
        format-echo "ERROR" "Failed to list container images"
        exit 1
      fi
      ;;
    delete-image)
      if delete_image "$PROJECT_ID" "$IMAGE_NAME"; then
        format-echo "SUCCESS" "Image deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete image"
        exit 1
      fi
      ;;
    tag-image)
      if tag_image "$PROJECT_ID" "$IMAGE_NAME" "$TAG"; then
        format-echo "SUCCESS" "Image tagging completed successfully"
      else
        format-echo "ERROR" "Failed to tag image"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Container Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
