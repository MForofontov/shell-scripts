#!/usr/bin/env bash
# gcp-kubernetes-manager.sh
# Script to manage GCP Google Kubernetes Engine (GKE) clusters, workloads, and operations.

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
REGION="us-central1"
ZONE="us-central1-a"
CLUSTER_VERSION=""
NODE_VERSION=""
NUM_NODES="3"
MIN_NODES="1"
MAX_NODES="10"
MACHINE_TYPE="e2-medium"
DISK_TYPE="pd-standard"
DISK_SIZE="100GB"
IMAGE_TYPE="COS_CONTAINERD"
NETWORK="default"
SUBNETWORK=""
CLUSTER_IPRANGE=""
SERVICES_IPRANGE=""
ENABLE_AUTOSCALING=false
ENABLE_AUTOREPAIR=true
ENABLE_AUTOUPGRADE=true
ENABLE_NETWORK_POLICY=false
ENABLE_STACKDRIVER_KUBERNETES=true
ENABLE_IP_ALIAS=true
ENABLE_SHIELDED_NODES=false
ENABLE_WORKLOAD_IDENTITY=false
ENABLE_PRIVATE_NODES=false
MASTER_IPV4_CIDR=""
PREEMPTIBLE=false
SPOT=false
NODE_POOL_NAME=""
SERVICE_ACCOUNT=""
OAUTH_SCOPES=""
NODE_LABELS=""
NODE_TAINTS=""
MASTER_AUTHORIZED_NETWORKS=""
MAINTENANCE_WINDOW=""
RELEASE_CHANNEL="regular"
WORKLOAD_POOL=""
NAMESPACE="default"
DEPLOYMENT_NAME=""
SERVICE_NAME=""
INGRESS_NAME=""
CONFIG_MAP_NAME=""
SECRET_NAME=""
YAML_FILE=""
CONTAINER_IMAGE=""
CONTAINER_PORT="80"
REPLICAS="3"
RESOURCE_CPU=""
RESOURCE_MEMORY=""
LIMITS_CPU=""
LIMITS_MEMORY=""
ENV_VARS=""
VOLUME_MOUNTS=""
LOAD_BALANCER_TYPE="LoadBalancer"
EXPOSE_PORT="80"
TARGET_PORT="8080"
HPA_MIN_REPLICAS="1"
HPA_MAX_REPLICAS="10"
HPA_CPU_PERCENT="80"
MONITORING_ENABLED=true
LOGGING_ENABLED=true
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Google Kubernetes Engine Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP GKE clusters, node pools, and Kubernetes workloads."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mCluster Actions:\033[0m"
  echo -e "  \033[1;33mcreate-cluster\033[0m           Create a GKE cluster"
  echo -e "  \033[1;33mdelete-cluster\033[0m           Delete a GKE cluster"
  echo -e "  \033[1;33mlist-clusters\033[0m            List all GKE clusters"
  echo -e "  \033[1;33mget-cluster\033[0m              Get cluster details"
  echo -e "  \033[1;33mupdate-cluster\033[0m           Update cluster configuration"
  echo -e "  \033[1;33mupgrade-cluster\033[0m          Upgrade cluster version"
  echo -e "  \033[1;33mresize-cluster\033[0m           Resize cluster node count"
  echo -e "  \033[1;33mget-credentials\033[0m          Get cluster credentials for kubectl"
  echo
  echo -e "\033[1;34mNode Pool Actions:\033[0m"
  echo -e "  \033[1;33mcreate-node-pool\033[0m         Create a node pool"
  echo -e "  \033[1;33mdelete-node-pool\033[0m         Delete a node pool"
  echo -e "  \033[1;33mlist-node-pools\033[0m          List node pools"
  echo -e "  \033[1;33mget-node-pool\033[0m            Get node pool details"
  echo -e "  \033[1;33mupdate-node-pool\033[0m         Update node pool"
  echo -e "  \033[1;33mupgrade-node-pool\033[0m        Upgrade node pool version"
  echo
  echo -e "\033[1;34mWorkload Actions:\033[0m"
  echo -e "  \033[1;33mdeploy-workload\033[0m          Deploy application workload"
  echo -e "  \033[1;33mupdate-deployment\033[0m        Update deployment"
  echo -e "  \033[1;33mscale-deployment\033[0m         Scale deployment replicas"
  echo -e "  \033[1;33mdelete-deployment\033[0m        Delete deployment"
  echo -e "  \033[1;33mcreate-service\033[0m           Create Kubernetes service"
  echo -e "  \033[1;33mdelete-service\033[0m           Delete Kubernetes service"
  echo -e "  \033[1;33mcreate-ingress\033[0m           Create ingress resource"
  echo -e "  \033[1;33mdelete-ingress\033[0m           Delete ingress resource"
  echo -e "  \033[1;33mcreate-hpa\033[0m               Create horizontal pod autoscaler"
  echo -e "  \033[1;33mdelete-hpa\033[0m               Delete horizontal pod autoscaler"
  echo -e "  \033[1;33mcreate-configmap\033[0m         Create config map"
  echo -e "  \033[1;33mcreate-secret\033[0m            Create secret"
  echo -e "  \033[1;33mapply-yaml\033[0m               Apply YAML configuration"
  echo
  echo -e "\033[1;34mOperational Actions:\033[0m"
  echo -e "  \033[1;33mlist-pods\033[0m                List pods in namespace"
  echo -e "  \033[1;33mget-pod-logs\033[0m             Get pod logs"
  echo -e "  \033[1;33mexec-pod\033[0m                 Execute command in pod"
  echo -e "  \033[1;33mport-forward\033[0m             Port forward to pod/service"
  echo -e "  \033[1;33mget-events\033[0m               Get cluster events"
  echo -e "  \033[1;33mget-nodes\033[0m                List cluster nodes"
  echo -e "  \033[1;33msetup-monitoring\033[0m         Setup cluster monitoring"
  echo -e "  \033[1;33msetup-istio\033[0m              Setup Istio service mesh"
  echo -e "  \033[1;33mbackup-cluster\033[0m           Backup cluster configuration"
  echo -e "  \033[1;33mrestore-cluster\033[0m          Restore cluster from backup"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--cluster <name>\033[0m                 (Required for cluster actions) Cluster name"
  echo -e "  \033[1;33m--region <region>\033[0m                (Optional) Region (default: us-central1)"
  echo -e "  \033[1;33m--zone <zone>\033[0m                    (Optional) Zone (default: us-central1-a)"
  echo -e "  \033[1;33m--cluster-version <version>\033[0m      (Optional) Kubernetes version"
  echo -e "  \033[1;33m--num-nodes <count>\033[0m              (Optional) Number of nodes (default: 3)"
  echo -e "  \033[1;33m--min-nodes <count>\033[0m              (Optional) Minimum nodes for autoscaling"
  echo -e "  \033[1;33m--max-nodes <count>\033[0m              (Optional) Maximum nodes for autoscaling"
  echo -e "  \033[1;33m--machine-type <type>\033[0m            (Optional) Node machine type (default: e2-medium)"
  echo -e "  \033[1;33m--disk-size <size>\033[0m               (Optional) Node disk size (default: 100GB)"
  echo -e "  \033[1;33m--disk-type <type>\033[0m               (Optional) Node disk type (default: pd-standard)"
  echo -e "  \033[1;33m--image-type <type>\033[0m              (Optional) Node image type (default: COS_CONTAINERD)"
  echo -e "  \033[1;33m--network <network>\033[0m              (Optional) VPC network (default: default)"
  echo -e "  \033[1;33m--subnetwork <subnet>\033[0m            (Optional) VPC subnetwork"
  echo -e "  \033[1;33m--node-pool <name>\033[0m               (Required for node pool actions) Node pool name"
  echo -e "  \033[1;33m--service-account <email>\033[0m        (Optional) Node service account"
  echo -e "  \033[1;33m--namespace <name>\033[0m               (Optional) Kubernetes namespace (default: default)"
  echo -e "  \033[1;33m--deployment <name>\033[0m              (Required for deployment actions) Deployment name"
  echo -e "  \033[1;33m--service <name>\033[0m                 (Required for service actions) Service name"
  echo -e "  \033[1;33m--image <image>\033[0m                  (Required for deployment) Container image"
  echo -e "  \033[1;33m--port <port>\033[0m                    (Optional) Container port (default: 80)"
  echo -e "  \033[1;33m--replicas <count>\033[0m               (Optional) Number of replicas (default: 3)"
  echo -e "  \033[1;33m--yaml-file <file>\033[0m               (Required for apply-yaml) YAML file path"
  echo -e "  \033[1;33m--enable-autoscaling\033[0m             (Optional) Enable cluster autoscaling"
  echo -e "  \033[1;33m--enable-network-policy\033[0m          (Optional) Enable network policy"
  echo -e "  \033[1;33m--enable-private-nodes\033[0m           (Optional) Enable private nodes"
  echo -e "  \033[1;33m--enable-workload-identity\033[0m       (Optional) Enable workload identity"
  echo -e "  \033[1;33m--enable-shielded-nodes\033[0m          (Optional) Enable shielded nodes"
  echo -e "  \033[1;33m--preemptible\033[0m                    (Optional) Use preemptible nodes"
  echo -e "  \033[1;33m--spot\033[0m                           (Optional) Use spot instances"
  echo -e "  \033[1;33m--release-channel <channel>\033[0m      (Optional) Release channel: rapid, regular, stable"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 create-cluster --project my-project --cluster my-cluster --zone us-central1-a"
  echo "  $0 deploy-workload --project my-project --cluster my-cluster --deployment nginx --image nginx:latest"
  echo "  $0 create-service --project my-project --cluster my-cluster --service nginx-svc --deployment nginx"
  echo "  $0 scale-deployment --project my-project --cluster my-cluster --deployment nginx --replicas 5"
  echo "  $0 list-pods --project my-project --cluster my-cluster --namespace default"
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
      --region)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No region provided after --region."
          usage
        fi
        REGION="$2"
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
      --cluster-version)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No cluster version provided after --cluster-version."
          usage
        fi
        CLUSTER_VERSION="$2"
        shift 2
        ;;
      --num-nodes)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No number of nodes provided after --num-nodes."
          usage
        fi
        NUM_NODES="$2"
        shift 2
        ;;
      --min-nodes)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No minimum nodes provided after --min-nodes."
          usage
        fi
        MIN_NODES="$2"
        shift 2
        ;;
      --max-nodes)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No maximum nodes provided after --max-nodes."
          usage
        fi
        MAX_NODES="$2"
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
      --disk-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No disk type provided after --disk-type."
          usage
        fi
        DISK_TYPE="$2"
        shift 2
        ;;
      --image-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No image type provided after --image-type."
          usage
        fi
        IMAGE_TYPE="$2"
        shift 2
        ;;
      --network)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No network provided after --network."
          usage
        fi
        NETWORK="$2"
        shift 2
        ;;
      --subnetwork)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No subnetwork provided after --subnetwork."
          usage
        fi
        SUBNETWORK="$2"
        shift 2
        ;;
      --node-pool)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No node pool name provided after --node-pool."
          usage
        fi
        NODE_POOL_NAME="$2"
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
      --namespace)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No namespace provided after --namespace."
          usage
        fi
        NAMESPACE="$2"
        shift 2
        ;;
      --deployment)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No deployment name provided after --deployment."
          usage
        fi
        DEPLOYMENT_NAME="$2"
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
          format-echo "ERROR" "No container image provided after --image."
          usage
        fi
        CONTAINER_IMAGE="$2"
        shift 2
        ;;
      --port)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No port provided after --port."
          usage
        fi
        CONTAINER_PORT="$2"
        shift 2
        ;;
      --replicas)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No replicas provided after --replicas."
          usage
        fi
        REPLICAS="$2"
        shift 2
        ;;
      --yaml-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No YAML file provided after --yaml-file."
          usage
        fi
        YAML_FILE="$2"
        shift 2
        ;;
      --release-channel)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No release channel provided after --release-channel."
          usage
        fi
        RELEASE_CHANNEL="$2"
        shift 2
        ;;
      --enable-autoscaling)
        ENABLE_AUTOSCALING=true
        shift
        ;;
      --enable-network-policy)
        ENABLE_NETWORK_POLICY=true
        shift
        ;;
      --enable-private-nodes)
        ENABLE_PRIVATE_NODES=true
        shift
        ;;
      --enable-workload-identity)
        ENABLE_WORKLOAD_IDENTITY=true
        shift
        ;;
      --enable-shielded-nodes)
        ENABLE_SHIELDED_NODES=true
        shift
        ;;
      --preemptible)
        PREEMPTIBLE=true
        shift
        ;;
      --spot)
        SPOT=true
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
  
  if ! command_exists kubectl; then
    missing_deps+=("kubectl")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    format-echo "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    format-echo "INFO" "Please install Google Cloud SDK and kubectl"
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

# Function to get cluster credentials
get_cluster_credentials() {
  local project="$1"
  local cluster="$2"
  local location="$3"
  
  format-echo "INFO" "Getting cluster credentials for kubectl"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get credentials for cluster: $cluster"
    return 0
  fi
  
  if [[ "$location" =~ ^.*-[a-z]$ ]]; then
    # Zone-based cluster
    if ! gcloud container clusters get-credentials "$cluster" \
      --project="$project" \
      --zone="$location"; then
      format-echo "ERROR" "Failed to get cluster credentials"
      return 1
    fi
  else
    # Regional cluster
    if ! gcloud container clusters get-credentials "$cluster" \
      --project="$project" \
      --region="$location"; then
      format-echo "ERROR" "Failed to get cluster credentials"
      return 1
    fi
  fi
  
  format-echo "SUCCESS" "Got cluster credentials for kubectl"
  return 0
}

#=====================================================================
# CLUSTER MANAGEMENT
#=====================================================================
# Function to create GKE cluster
create_cluster() {
  local project="$1"
  local cluster_name="$2"
  
  format-echo "INFO" "Creating GKE cluster: $cluster_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create GKE cluster:"
    format-echo "INFO" "  Name: $cluster_name"
    format-echo "INFO" "  Zone: $ZONE"
    format-echo "INFO" "  Nodes: $NUM_NODES"
    format-echo "INFO" "  Machine type: $MACHINE_TYPE"
    return 0
  fi
  
  local create_cmd="gcloud container clusters create $cluster_name"
  create_cmd+=" --project=$project"
  create_cmd+=" --zone=$ZONE"
  create_cmd+=" --num-nodes=$NUM_NODES"
  create_cmd+=" --machine-type=$MACHINE_TYPE"
  create_cmd+=" --disk-type=$DISK_TYPE"
  create_cmd+=" --disk-size=$DISK_SIZE"
  create_cmd+=" --image-type=$IMAGE_TYPE"
  create_cmd+=" --network=$NETWORK"
  create_cmd+=" --release-channel=$RELEASE_CHANNEL"
  
  # Subnetwork
  if [ -n "$SUBNETWORK" ]; then
    create_cmd+=" --subnetwork=$SUBNETWORK"
  fi
  
  # Cluster version
  if [ -n "$CLUSTER_VERSION" ]; then
    create_cmd+=" --cluster-version=$CLUSTER_VERSION"
  fi
  
  # Autoscaling
  if [ "$ENABLE_AUTOSCALING" = true ]; then
    create_cmd+=" --enable-autoscaling"
    create_cmd+=" --min-nodes=$MIN_NODES"
    create_cmd+=" --max-nodes=$MAX_NODES"
  fi
  
  # Advanced features
  if [ "$ENABLE_AUTOREPAIR" = true ]; then
    create_cmd+=" --enable-autorepair"
  fi
  
  if [ "$ENABLE_AUTOUPGRADE" = true ]; then
    create_cmd+=" --enable-autoupgrade"
  fi
  
  if [ "$ENABLE_NETWORK_POLICY" = true ]; then
    create_cmd+=" --enable-network-policy"
  fi
  
  if [ "$ENABLE_IP_ALIAS" = true ]; then
    create_cmd+=" --enable-ip-alias"
  fi
  
  if [ "$ENABLE_STACKDRIVER_KUBERNETES" = true ]; then
    create_cmd+=" --enable-cloud-logging --enable-cloud-monitoring"
  fi
  
  if [ "$ENABLE_SHIELDED_NODES" = true ]; then
    create_cmd+=" --enable-shielded-nodes"
  fi
  
  if [ "$ENABLE_WORKLOAD_IDENTITY" = true ]; then
    create_cmd+=" --workload-pool=$project.svc.id.goog"
  fi
  
  if [ "$ENABLE_PRIVATE_NODES" = true ]; then
    create_cmd+=" --enable-private-nodes"
    create_cmd+=" --master-ipv4-cidr=${MASTER_IPV4_CIDR:-172.16.0.0/28}"
  fi
  
  # Node configuration
  if [ "$PREEMPTIBLE" = true ]; then
    create_cmd+=" --preemptible"
  fi
  
  if [ "$SPOT" = true ]; then
    create_cmd+=" --spot"
  fi
  
  if [ -n "$SERVICE_ACCOUNT" ]; then
    create_cmd+=" --service-account=$SERVICE_ACCOUNT"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create GKE cluster: $cluster_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created GKE cluster: $cluster_name"
  
  # Get credentials automatically
  if get_cluster_credentials "$project" "$cluster_name" "$ZONE"; then
    format-echo "SUCCESS" "Cluster is ready for kubectl commands"
  fi
  
  return 0
}

# Function to delete GKE cluster
delete_cluster() {
  local project="$1"
  local cluster_name="$2"
  
  format-echo "INFO" "Deleting GKE cluster: $cluster_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete GKE cluster: $cluster_name"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the cluster '$cluster_name' and all its workloads."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud container clusters delete "$cluster_name" \
    --project="$project" \
    --zone="$ZONE" \
    --quiet; then
    format-echo "ERROR" "Failed to delete GKE cluster: $cluster_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted GKE cluster: $cluster_name"
  return 0
}

# Function to list GKE clusters
list_clusters() {
  local project="$1"
  
  format-echo "INFO" "Listing GKE clusters"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list GKE clusters"
    return 0
  fi
  
  if ! gcloud container clusters list \
    --project="$project" \
    --format="table(name,location,status,currentMasterVersion,currentNodeVersion,numNodes)"; then
    format-echo "ERROR" "Failed to list GKE clusters"
    return 1
  fi
  
  return 0
}

#=====================================================================
# WORKLOAD MANAGEMENT
#=====================================================================
# Function to deploy workload
deploy_workload() {
  local project="$1"
  local cluster_name="$2"
  local deployment_name="$3"
  local image="$4"
  
  format-echo "INFO" "Deploying workload: $deployment_name"
  
  # Ensure kubectl credentials
  if ! get_cluster_credentials "$project" "$cluster_name" "$ZONE"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would deploy workload:"
    format-echo "INFO" "  Deployment: $deployment_name"
    format-echo "INFO" "  Image: $image"
    format-echo "INFO" "  Replicas: $REPLICAS"
    format-echo "INFO" "  Namespace: $NAMESPACE"
    return 0
  fi
  
  # Create deployment
  if ! kubectl create deployment "$deployment_name" \
    --image="$image" \
    --replicas="$REPLICAS" \
    --namespace="$NAMESPACE"; then
    format-echo "ERROR" "Failed to create deployment: $deployment_name"
    return 1
  fi
  
  # Wait for deployment to be ready
  format-echo "INFO" "Waiting for deployment to be ready..."
  if ! kubectl rollout status deployment/"$deployment_name" \
    --namespace="$NAMESPACE" \
    --timeout=300s; then
    format-echo "ERROR" "Deployment did not become ready within timeout"
    return 1
  fi
  
  format-echo "SUCCESS" "Deployed workload: $deployment_name"
  return 0
}

# Function to create Kubernetes service
create_service() {
  local project="$1"
  local cluster_name="$2"
  local service_name="$3"
  local deployment_name="$4"
  
  format-echo "INFO" "Creating Kubernetes service: $service_name"
  
  # Ensure kubectl credentials
  if ! get_cluster_credentials "$project" "$cluster_name" "$ZONE"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create service:"
    format-echo "INFO" "  Service: $service_name"
    format-echo "INFO" "  Deployment: $deployment_name"
    format-echo "INFO" "  Type: $LOAD_BALANCER_TYPE"
    format-echo "INFO" "  Port: $EXPOSE_PORT"
    return 0
  fi
  
  # Expose deployment as service
  if ! kubectl expose deployment "$deployment_name" \
    --name="$service_name" \
    --type="$LOAD_BALANCER_TYPE" \
    --port="$EXPOSE_PORT" \
    --target-port="$TARGET_PORT" \
    --namespace="$NAMESPACE"; then
    format-echo "ERROR" "Failed to create service: $service_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created Kubernetes service: $service_name"
  
  # Show service details
  if [ "$LOAD_BALANCER_TYPE" = "LoadBalancer" ]; then
    format-echo "INFO" "Waiting for external IP assignment..."
    kubectl get service "$service_name" --namespace="$NAMESPACE" --watch --timeout=120s || true
  fi
  
  return 0
}

# Function to scale deployment
scale_deployment() {
  local project="$1"
  local cluster_name="$2"
  local deployment_name="$3"
  local replicas="$4"
  
  format-echo "INFO" "Scaling deployment: $deployment_name to $replicas replicas"
  
  # Ensure kubectl credentials
  if ! get_cluster_credentials "$project" "$cluster_name" "$ZONE"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would scale deployment $deployment_name to $replicas replicas"
    return 0
  fi
  
  if ! kubectl scale deployment "$deployment_name" \
    --replicas="$replicas" \
    --namespace="$NAMESPACE"; then
    format-echo "ERROR" "Failed to scale deployment: $deployment_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Scaled deployment: $deployment_name to $replicas replicas"
  return 0
}

# Function to list pods
list_pods() {
  local project="$1"
  local cluster_name="$2"
  
  format-echo "INFO" "Listing pods in namespace: $NAMESPACE"
  
  # Ensure kubectl credentials
  if ! get_cluster_credentials "$project" "$cluster_name" "$ZONE"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list pods in namespace: $NAMESPACE"
    return 0
  fi
  
  if ! kubectl get pods \
    --namespace="$NAMESPACE" \
    --output=wide; then
    format-echo "ERROR" "Failed to list pods"
    return 1
  fi
  
  return 0
}

# Function to apply YAML configuration
apply_yaml() {
  local project="$1"
  local cluster_name="$2"
  local yaml_file="$3"
  
  format-echo "INFO" "Applying YAML configuration: $yaml_file"
  
  if [ ! -f "$yaml_file" ]; then
    format-echo "ERROR" "YAML file not found: $yaml_file"
    return 1
  fi
  
  # Ensure kubectl credentials
  if ! get_cluster_credentials "$project" "$cluster_name" "$ZONE"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would apply YAML file: $yaml_file"
    return 0
  fi
  
  if ! kubectl apply -f "$yaml_file" --namespace="$NAMESPACE"; then
    format-echo "ERROR" "Failed to apply YAML configuration"
    return 1
  fi
  
  format-echo "SUCCESS" "Applied YAML configuration: $yaml_file"
  return 0
}

# Function to create horizontal pod autoscaler
create_hpa() {
  local project="$1"
  local cluster_name="$2"
  local deployment_name="$3"
  
  format-echo "INFO" "Creating horizontal pod autoscaler for: $deployment_name"
  
  # Ensure kubectl credentials
  if ! get_cluster_credentials "$project" "$cluster_name" "$ZONE"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create HPA for deployment: $deployment_name"
    return 0
  fi
  
  if ! kubectl autoscale deployment "$deployment_name" \
    --min="$HPA_MIN_REPLICAS" \
    --max="$HPA_MAX_REPLICAS" \
    --cpu-percent="$HPA_CPU_PERCENT" \
    --namespace="$NAMESPACE"; then
    format-echo "ERROR" "Failed to create horizontal pod autoscaler"
    return 1
  fi
  
  format-echo "SUCCESS" "Created horizontal pod autoscaler for: $deployment_name"
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
  
  print_with_separator "GCP Google Kubernetes Engine Manager Script"
  format-echo "INFO" "Starting GCP GKE Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP GKE Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP GKE Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP GKE Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-cluster|delete-cluster|get-cluster|update-cluster|upgrade-cluster|resize-cluster|get-credentials)
      if [ -z "$CLUSTER_NAME" ]; then
        format-echo "ERROR" "Cluster name is required for action: $ACTION"
        exit 1
      fi
      ;;
    deploy-workload|update-deployment|scale-deployment|delete-deployment)
      if [ -z "$CLUSTER_NAME" ] || [ -z "$DEPLOYMENT_NAME" ]; then
        format-echo "ERROR" "Cluster name and deployment name are required for action: $ACTION"
        exit 1
      fi
      if [ "$ACTION" = "deploy-workload" ] && [ -z "$CONTAINER_IMAGE" ]; then
        format-echo "ERROR" "Container image is required for deployment"
        exit 1
      fi
      if [ "$ACTION" = "scale-deployment" ] && [ -z "$REPLICAS" ]; then
        format-echo "ERROR" "Replicas count is required for scaling"
        exit 1
      fi
      ;;
    create-service|delete-service)
      if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ]; then
        format-echo "ERROR" "Cluster name and service name are required for action: $ACTION"
        exit 1
      fi
      if [ "$ACTION" = "create-service" ] && [ -z "$DEPLOYMENT_NAME" ]; then
        format-echo "ERROR" "Deployment name is required for service creation"
        exit 1
      fi
      ;;
    apply-yaml)
      if [ -z "$CLUSTER_NAME" ] || [ -z "$YAML_FILE" ]; then
        format-echo "ERROR" "Cluster name and YAML file are required for action: $ACTION"
        exit 1
      fi
      ;;
    list-clusters|setup-monitoring)
      # No additional requirements for these actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-cluster, delete-cluster, deploy-workload, create-service, scale-deployment, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-cluster)
      if create_cluster "$PROJECT_ID" "$CLUSTER_NAME"; then
        format-echo "SUCCESS" "GKE cluster creation completed successfully"
      else
        format-echo "ERROR" "Failed to create GKE cluster"
        exit 1
      fi
      ;;
    delete-cluster)
      if delete_cluster "$PROJECT_ID" "$CLUSTER_NAME"; then
        format-echo "SUCCESS" "GKE cluster deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete GKE cluster"
        exit 1
      fi
      ;;
    list-clusters)
      if list_clusters "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed GKE clusters successfully"
      else
        format-echo "ERROR" "Failed to list GKE clusters"
        exit 1
      fi
      ;;
    get-credentials)
      if get_cluster_credentials "$PROJECT_ID" "$CLUSTER_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Got cluster credentials successfully"
      else
        format-echo "ERROR" "Failed to get cluster credentials"
        exit 1
      fi
      ;;
    deploy-workload)
      if deploy_workload "$PROJECT_ID" "$CLUSTER_NAME" "$DEPLOYMENT_NAME" "$CONTAINER_IMAGE"; then
        format-echo "SUCCESS" "Workload deployment completed successfully"
      else
        format-echo "ERROR" "Failed to deploy workload"
        exit 1
      fi
      ;;
    create-service)
      if create_service "$PROJECT_ID" "$CLUSTER_NAME" "$SERVICE_NAME" "$DEPLOYMENT_NAME"; then
        format-echo "SUCCESS" "Service creation completed successfully"
      else
        format-echo "ERROR" "Failed to create service"
        exit 1
      fi
      ;;
    scale-deployment)
      if scale_deployment "$PROJECT_ID" "$CLUSTER_NAME" "$DEPLOYMENT_NAME" "$REPLICAS"; then
        format-echo "SUCCESS" "Deployment scaling completed successfully"
      else
        format-echo "ERROR" "Failed to scale deployment"
        exit 1
      fi
      ;;
    list-pods)
      if list_pods "$PROJECT_ID" "$CLUSTER_NAME"; then
        format-echo "SUCCESS" "Listed pods successfully"
      else
        format-echo "ERROR" "Failed to list pods"
        exit 1
      fi
      ;;
    apply-yaml)
      if apply_yaml "$PROJECT_ID" "$CLUSTER_NAME" "$YAML_FILE"; then
        format-echo "SUCCESS" "YAML configuration applied successfully"
      else
        format-echo "ERROR" "Failed to apply YAML configuration"
        exit 1
      fi
      ;;
    create-hpa)
      if create_hpa "$PROJECT_ID" "$CLUSTER_NAME" "$DEPLOYMENT_NAME"; then
        format-echo "SUCCESS" "Horizontal pod autoscaler created successfully"
      else
        format-echo "ERROR" "Failed to create horizontal pod autoscaler"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP GKE Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
