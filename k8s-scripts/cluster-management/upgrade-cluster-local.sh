#!/bin/bash
# upgrade-cluster.sh
# Script to upgrade Kubernetes clusters across various providers

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Default values
CLUSTER_NAME=""
PROVIDER="minikube"  # Default provider is minikube
K8S_VERSION=""       # Target Kubernetes version for upgrade
LOG_FILE="/dev/null"
FORCE=false
BACKUP=true          # Create backup/snapshot before upgrading if possible
WAIT_TIMEOUT=600     # 10 minutes timeout for upgrade to complete

# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Upgrade Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script upgrades Kubernetes clusters created with various providers (minikube, kind, k3d)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-n, --name <NAME>\033[0m         (Required) Cluster name to upgrade"
  echo -e "  \033[1;36m-v, --version <VERSION>\033[0m   (Required) Target Kubernetes version"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m (Optional) Provider to use (minikube, kind, k3d) (default: ${PROVIDER})"
  echo -e "  \033[1;33m-f, --force\033[0m               (Optional) Force upgrade without confirmation"
  echo -e "  \033[1;33m--no-backup\033[0m               (Optional) Skip backup/snapshot before upgrade"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m   (Optional) Timeout in seconds for upgrade (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--log <FILE>\033[0m              (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster --version 1.27.0"
  echo "  $0 --name test-cluster --provider kind --version 1.28.0"
  echo "  $0 --name dev-cluster --provider k3d --version 1.26.5 --force"
  echo "  $0 --name my-cluster --version 1.27.0 --log upgrade.log"
  print_with_separator
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required tools
check_requirements() {
  log_message "INFO" "Checking requirements..."
  
  case "$PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        log_message "ERROR" "minikube not found. Please install it first:"
        echo "https://minikube.sigs.k8s.io/docs/start/"
        exit 1
      fi
      ;;
    kind)
      if ! command_exists kind; then
        log_message "ERROR" "kind not found. Please install it first:"
        echo "https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        log_message "ERROR" "k3d not found. Please install it first:"
        echo "https://k3d.io/#installation"
        exit 1
      fi
      ;;
  esac

  if ! command_exists kubectl; then
    log_message "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi

  # Specific to upgrade operations
  if [ "$PROVIDER" = "kind" ] && ! command_exists jq; then
    log_message "ERROR" "jq not found but required for kind clusters. Please install it first:"
    echo "https://stedolan.github.io/jq/download/"
    exit 1
  fi

  log_message "SUCCESS" "Required tools are available."
}

# Check if cluster exists
check_cluster_exists() {
  log_message "INFO" "Checking if cluster exists..."
  
  local cluster_exists=false
  
  case "$PROVIDER" in
    minikube)
      if minikube profile list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        cluster_exists=true
      fi
      ;;
    kind)
      if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        cluster_exists=true
      fi
      ;;
    k3d)
      if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        cluster_exists=true
      fi
      ;;
  esac
  
  if $cluster_exists; then
    log_message "SUCCESS" "Cluster '${CLUSTER_NAME}' found."
    return 0
  else
    log_message "ERROR" "Cluster '${CLUSTER_NAME}' not found for provider ${PROVIDER}."
    exit 1
  fi
}

# Get cluster info before upgrade
get_cluster_info() {
  log_message "INFO" "Getting cluster information before upgrade..."
  
  local current_version=""
  
  case "$PROVIDER" in
    minikube)
      # Get minikube cluster info
      CLUSTER_INFO=$(minikube profile list -o json | jq -r ".[] | select(.Name==\"$CLUSTER_NAME\")")
      current_version=$(echo "$CLUSTER_INFO" | jq -r ".Config.KubernetesConfig.KubernetesVersion")
      NODE_COUNT=$(minikube node list -p "$CLUSTER_NAME" 2>/dev/null | wc -l | tr -d ' ')
      ;;
    kind)
      # For kind, we check the node image to get the version
      NODE_IMAGE=$(kind get nodes --name "$CLUSTER_NAME" | head -1 | xargs docker inspect --format='{{.Config.Image}}')
      current_version=$(echo "$NODE_IMAGE" | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | tr -d 'v')
      NODE_COUNT=$(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null | wc -l | tr -d ' ')
      ;;
    k3d)
      # For k3d, get version from kubectl
      current_version=$(kubectl --context="k3d-${CLUSTER_NAME}" version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' | tr -d 'v')
      NODE_COUNT=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\")] | length")
      ;;
  esac
  
  log_message "INFO" "Current Kubernetes Version: $current_version"
  log_message "INFO" "Target Kubernetes Version: $K8S_VERSION"
  log_message "INFO" "Node Count: $NODE_COUNT"
  
  # Check if the versions are the same
  if [[ "$current_version" == "$K8S_VERSION" ]]; then
    log_message "WARNING" "Cluster is already running Kubernetes version $K8S_VERSION."
    read -p "Continue anyway? [y/N]: " continue_anyway
    
    case "$continue_anyway" in
      [Yy]|[Yy][Ee][Ss])
        return 0
        ;;
      *)
        log_message "INFO" "Upgrade canceled by user."
        exit 0
        ;;
    esac
  fi
  
  # Check if we're attempting to downgrade
  if [[ "$(printf '%s\n' "$current_version" "$K8S_VERSION" | sort -V | head -n1)" == "$K8S_VERSION" ]]; then
    log_message "WARNING" "Target version ($K8S_VERSION) is older than current version ($current_version)."
    log_message "WARNING" "Downgrading Kubernetes clusters is not recommended and may cause issues."
    
    if [ "$FORCE" != true ]; then
      read -p "Continue with downgrade anyway? [y/N]: " continue_anyway
      
      case "$continue_anyway" in
        [Yy]|[Yy][Ee][Ss])
          return 0
          ;;
        *)
          log_message "INFO" "Downgrade canceled by user."
          exit 0
          ;;
      esac
    else
      log_message "WARNING" "Force flag set. Proceeding with downgrade."
    fi
  fi
  
  CURRENT_VERSION="$current_version"
  return 0
}

# Create backup before upgrade
create_backup() {
  if [ "$BACKUP" != true ]; then
    log_message "WARNING" "Skipping backup as --no-backup flag was provided."
    return 0
  fi
  
  log_message "INFO" "Creating backup before upgrade..."
  
  case "$PROVIDER" in
    minikube)
      # For minikube, we can't easily create a snapshot, so we'll export important resources
      log_message "INFO" "Creating resource backup for minikube cluster..."
      backup_dir="$CLUSTER_NAME-backup-$(date +%Y%m%d%H%M%S)"
      mkdir -p "$backup_dir"
      
      # Switch to the right context
      kubectl config use-context "$CLUSTER_NAME"
      
      # Export all namespaces, deployments, services, etc.
      kubectl get ns -o json > "$backup_dir/namespaces.json"
      kubectl get deploy --all-namespaces -o json > "$backup_dir/deployments.json"
      kubectl get svc --all-namespaces -o json > "$backup_dir/services.json"
      kubectl get pv -o json > "$backup_dir/persistent-volumes.json"
      kubectl get pvc --all-namespaces -o json > "$backup_dir/persistent-volume-claims.json"
      kubectl get cm --all-namespaces -o json > "$backup_dir/configmaps.json"
      kubectl get secret --all-namespaces -o json > "$backup_dir/secrets.json"
      
      log_message "SUCCESS" "Backup created at $backup_dir"
      ;;
    kind)
      # For kind, we'll back up the cluster configuration and resources
      log_message "INFO" "Creating resource backup for kind cluster..."
      backup_dir="$CLUSTER_NAME-backup-$(date +%Y%m%d%H%M%S)"
      mkdir -p "$backup_dir"
      
      # Switch to the right context
      kubectl config use-context "kind-$CLUSTER_NAME"
      
      # Export cluster resources
      kubectl get ns -o json > "$backup_dir/namespaces.json"
      kubectl get deploy --all-namespaces -o json > "$backup_dir/deployments.json"
      kubectl get svc --all-namespaces -o json > "$backup_dir/services.json"
      kubectl get pv -o json > "$backup_dir/persistent-volumes.json"
      kubectl get pvc --all-namespaces -o json > "$backup_dir/persistent-volume-claims.json"
      
      log_message "SUCCESS" "Backup created at $backup_dir"
      ;;
    k3d)
      # For k3d, we'll back up the cluster resources
      log_message "INFO" "Creating resource backup for k3d cluster..."
      backup_dir="$CLUSTER_NAME-backup-$(date +%Y%m%d%H%M%S)"
      mkdir -p "$backup_dir"
      
      # Switch to the right context
      kubectl config use-context "k3d-$CLUSTER_NAME"
      
      # Export cluster resources
      kubectl get ns -o json > "$backup_dir/namespaces.json"
      kubectl get deploy --all-namespaces -o json > "$backup_dir/deployments.json"
      kubectl get svc --all-namespaces -o json > "$backup_dir/services.json"
      kubectl get pv -o json > "$backup_dir/persistent-volumes.json"
      kubectl get pvc --all-namespaces -o json > "$backup_dir/persistent-volume-claims.json"
      
      log_message "SUCCESS" "Backup created at $backup_dir"
      ;;
  esac
  
  BACKUP_DIR="$backup_dir"
}

# Upgrade minikube cluster
upgrade_minikube_cluster() {
  log_message "INFO" "Upgrading minikube cluster '${CLUSTER_NAME}' to Kubernetes ${K8S_VERSION}..."
  
  # Stop the cluster
  log_message "INFO" "Stopping minikube cluster..."
  if ! minikube stop -p "${CLUSTER_NAME}"; then
    log_message "ERROR" "Failed to stop minikube cluster '${CLUSTER_NAME}'."
    exit 1
  fi
  
  # Start the cluster with the new Kubernetes version
  log_message "INFO" "Starting minikube cluster with Kubernetes version ${K8S_VERSION}..."
  if minikube start -p "${CLUSTER_NAME}" --kubernetes-version="${K8S_VERSION}"; then
    log_message "SUCCESS" "minikube cluster '${CLUSTER_NAME}' upgraded successfully to Kubernetes ${K8S_VERSION}."
  else
    log_message "ERROR" "Failed to upgrade minikube cluster '${CLUSTER_NAME}'."
    # Try to revert to previous version if upgrade failed
    log_message "INFO" "Attempting to revert to previous Kubernetes version ${CURRENT_VERSION}..."
    if ! minikube start -p "${CLUSTER_NAME}" --kubernetes-version="${CURRENT_VERSION}"; then
      log_message "ERROR" "Failed to revert to previous version. Cluster may be in an inconsistent state."
    else
      log_message "INFO" "Successfully reverted to previous version ${CURRENT_VERSION}."
    fi
    exit 1
  fi
}

# Upgrade kind cluster (requires delete and recreate)
upgrade_kind_cluster() {
  log_message "INFO" "Upgrading kind cluster '${CLUSTER_NAME}' to Kubernetes ${K8S_VERSION}..."
  
  # For kind, we need to save the config
  local temp_config=$(mktemp)
  log_message "INFO" "Saving cluster configuration..."
  kubectl --context="kind-${CLUSTER_NAME}" get nodes -o json > "${temp_config}"
  
  # Get the number of nodes
  NODE_COUNT=$(jq '.items | length' "${temp_config}")
  
  # Delete the cluster
  log_message "INFO" "Deleting kind cluster for upgrade..."
  if ! kind delete cluster --name "${CLUSTER_NAME}"; then
    log_message "ERROR" "Failed to delete kind cluster '${CLUSTER_NAME}' for upgrade."
    exit 1
  fi
  
  # Create a new cluster with the specified Kubernetes version
  log_message "INFO" "Creating new kind cluster with Kubernetes version ${K8S_VERSION}..."
  
  # Generate a configuration for the cluster
  local kind_config=$(mktemp)
  echo "kind: Cluster" > "$kind_config"
  echo "apiVersion: kind.x-k8s.io/v1alpha4" >> "$kind_config"
  echo "nodes:" >> "$kind_config"
  echo "- role: control-plane" >> "$kind_config"
  
  # Add worker nodes if needed
  if [[ "$NODE_COUNT" -gt 1 ]]; then
    for ((i=1; i<NODE_COUNT; i++)); do
      echo "- role: worker" >> "$kind_config"
    done
  fi
  
  if kind create cluster --name "${CLUSTER_NAME}" --image="kindest/node:v${K8S_VERSION}" --config="$kind_config"; then
    log_message "SUCCESS" "kind cluster '${CLUSTER_NAME}' upgraded successfully to Kubernetes ${K8S_VERSION}."
    
    # Clean up temporary files
    rm "${temp_config}" "${kind_config}"
  else
    log_message "ERROR" "Failed to upgrade kind cluster '${CLUSTER_NAME}'."
    # Try to recreate with the previous version
    log_message "INFO" "Attempting to recreate cluster with previous Kubernetes version ${CURRENT_VERSION}..."
    if ! kind create cluster --name "${CLUSTER_NAME}" --image="kindest/node:v${CURRENT_VERSION}" --config="$kind_config"; then
      log_message "ERROR" "Failed to recreate cluster with previous version. Resources may be lost."
    else
      log_message "INFO" "Successfully recreated cluster with previous version ${CURRENT_VERSION}."
    fi
    rm "${temp_config}" "${kind_config}"
    exit 1
  fi
}

# Upgrade k3d cluster
upgrade_k3d_cluster() {
  log_message "INFO" "Upgrading k3d cluster '${CLUSTER_NAME}' to Kubernetes ${K8S_VERSION}..."
  
  # For k3d, we need to delete and recreate the cluster similar to kind
  # First, get existing configuration
  local node_count_server=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\" and .role.server==true)] | length")
  local node_count_agent=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\" and .role.agent==true)] | length")
  
  # Delete the cluster
  log_message "INFO" "Deleting k3d cluster for upgrade..."
  if ! k3d cluster delete "${CLUSTER_NAME}"; then
    log_message "ERROR" "Failed to delete k3d cluster '${CLUSTER_NAME}' for upgrade."
    exit 1
  fi
  
  # Create a new cluster with the specified Kubernetes version
  log_message "INFO" "Creating new k3d cluster with Kubernetes version ${K8S_VERSION}..."
  
  local k3d_args="--servers $node_count_server --agents $node_count_agent --image rancher/k3s:v${K8S_VERSION}-k3s1"
  
  if k3d cluster create "${CLUSTER_NAME}" $k3d_args; then
    log_message "SUCCESS" "k3d cluster '${CLUSTER_NAME}' upgraded successfully to Kubernetes ${K8S_VERSION}."
  else
    log_message "ERROR" "Failed to upgrade k3d cluster '${CLUSTER_NAME}'."
    # Try to recreate with the previous version
    log_message "INFO" "Attempting to recreate cluster with previous Kubernetes version ${CURRENT_VERSION}..."
    local prev_k3d_args="--servers $node_count_server --agents $node_count_agent --image rancher/k3s:v${CURRENT_VERSION}-k3s1"
    if ! k3d cluster create "${CLUSTER_NAME}" $prev_k3d_args; then
      log_message "ERROR" "Failed to recreate cluster with previous version. Resources may be lost."
    else
      log_message "INFO" "Successfully recreated cluster with previous version ${CURRENT_VERSION}."
    fi
    exit 1
  fi
}

# Wait for cluster to be ready
wait_for_cluster() {
  log_message "INFO" "Waiting for cluster to be ready after upgrade (timeout: ${WAIT_TIMEOUT}s)..."
  
  local start_time=$(date +%s)
  local end_time=$((start_time + WAIT_TIMEOUT))
  
  # Set correct context based on provider
  case "$PROVIDER" in
    minikube)
      kubectl config use-context "$CLUSTER_NAME"
      ;;
    kind)
      kubectl config use-context "kind-$CLUSTER_NAME"
      ;;
    k3d)
      kubectl config use-context "k3d-$CLUSTER_NAME"
      ;;
  esac
  
  while true; do
    if kubectl get nodes &>/dev/null; then
      local all_ready=true
      
      for status in $(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}'); do
        if [[ "$status" != "True" ]]; then
          all_ready=false
          break
        fi
      done
      
      if $all_ready; then
        log_message "INFO" "Checking core components status..."
        if kubectl get po -n kube-system &>/dev/null; then
          # Check if all core pods are running
          local all_pods_ready=true
          for pod_status in $(kubectl get po -n kube-system -o jsonpath='{.items[*].status.phase}'); do
            if [[ "$pod_status" != "Running" && "$pod_status" != "Succeeded" ]]; then
              all_pods_ready=false
              break
            fi
          done
          
          if $all_pods_ready; then
            break
          fi
        fi
      fi
    fi
    
    current_time=$(date +%s)
    if [[ $current_time -ge $end_time ]]; then
      log_message "ERROR" "Timeout waiting for cluster to be ready after upgrade."
      exit 1
    fi
    
    sleep 5
  done
  
  log_message "SUCCESS" "Cluster is ready after upgrade."
}

# Verify upgrade
verify_upgrade() {
  log_message "INFO" "Verifying upgrade..."
  
  local current_version=""
  
  case "$PROVIDER" in
    minikube)
      current_version=$(minikube kubectl -- version -o json | jq -r '.serverVersion.gitVersion' | tr -d 'v')
      ;;
    kind)
      current_version=$(kubectl version -o json | jq -r '.serverVersion.gitVersion' | tr -d 'v')
      ;;
    k3d)
      current_version=$(kubectl version -o json | jq -r '.serverVersion.gitVersion' | tr -d 'v')
      ;;
  esac
  
  if [[ "$current_version" == "$K8S_VERSION"* ]]; then
    log_message "SUCCESS" "Cluster successfully upgraded to Kubernetes version $current_version"
  else
    log_message "WARNING" "Cluster version after upgrade ($current_version) doesn't match target version ($K8S_VERSION)"
    # This might not be an error, as patch versions can differ
  fi
}

# Confirm upgrade with user
confirm_upgrade() {
  if [ "$FORCE" = true ]; then
    return 0
  fi
  
  echo -e "\033[1;33mWarning:\033[0m You are about to upgrade the cluster '${CLUSTER_NAME}' (provider: ${PROVIDER})."
  echo "  From Kubernetes version: $CURRENT_VERSION"
  echo "  To Kubernetes version:   $K8S_VERSION"
  echo
  echo "This operation may cause downtime and data loss. Make sure you have backups."
  echo
  read -p "Are you sure you want to continue? [y/N]: " answer
  
  case "$answer" in
    [Yy]|[Yy][Ee][Ss])
      return 0
      ;;
    *)
      log_message "INFO" "Upgrade canceled by user."
      exit 0
      ;;
  esac
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      -n|--name)
        CLUSTER_NAME="$2"
        shift 2
        ;;
      -p|--provider)
        PROVIDER="$2"
        case "$PROVIDER" in
          minikube|kind|k3d) ;;
          *)
            log_message "ERROR" "Unsupported provider '${PROVIDER}'."
            log_message "ERROR" "Supported providers: minikube, kind, k3d"
            exit 1
            ;;
        esac
        shift 2
        ;;
      -v|--version)
        K8S_VERSION="$2"
        shift 2
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      --no-backup)
        BACKUP=false
        shift
        ;;
      -t|--timeout)
        WAIT_TIMEOUT="$2"
        shift 2
        ;;
      --log)
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        log_message "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  # Check if required parameters are provided
  if [ -z "$CLUSTER_NAME" ]; then
    log_message "ERROR" "Cluster name is required. Use -n or --name to specify."
    usage
  fi
  
  if [ -z "$K8S_VERSION" ]; then
    log_message "ERROR" "Target Kubernetes version is required. Use -v or --version to specify."
    usage
  fi
}

# Display cluster info
display_cluster_info() {
  print_with_separator "Cluster Information After Upgrade"
  
  log_message "INFO" "Kubernetes Version:"
  kubectl version
  
  log_message "INFO" "Nodes:"
  kubectl get nodes
  
  log_message "INFO" "Cluster Info:"
  kubectl cluster-info
  
  print_with_separator
}

# Main function
main() {
  # Parse arguments
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Kubernetes Cluster Upgrade Script"
  
  log_message "INFO" "Starting Kubernetes cluster upgrade..."
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Cluster Name: $CLUSTER_NAME"
  log_message "INFO" "  Provider:     $PROVIDER"
  log_message "INFO" "  Target K8s:   $K8S_VERSION"
  log_message "INFO" "  Force Upgrade: $FORCE"
  log_message "INFO" "  Create Backup: $BACKUP"
  
  # Check requirements
  check_requirements
  
  # Check if the cluster exists
  check_cluster_exists
  
  # Get cluster info before upgrade
  get_cluster_info
  
  # Confirm upgrade with user
  confirm_upgrade
  
  # Create backup before upgrade
  create_backup
  
  # Upgrade the cluster based on the provider
  case "$PROVIDER" in
    minikube)
      upgrade_minikube_cluster
      ;;
    kind)
      upgrade_kind_cluster
      ;;
    k3d)
      upgrade_k3d_cluster
      ;;
  esac
  
  # Wait for cluster to be ready
  wait_for_cluster
  
  # Verify upgrade
  verify_upgrade
  
  # Display cluster info after upgrade
  display_cluster_info
  
  print_with_separator "End of Kubernetes Cluster Upgrade"
  log_message "SUCCESS" "Kubernetes cluster upgrade completed successfully."
  
  if [ -n "$BACKUP_DIR" ]; then
    log_message "INFO" "Backup of the cluster before upgrade is available at: $BACKUP_DIR"
  fi
}

# Run the main function
main "$@"