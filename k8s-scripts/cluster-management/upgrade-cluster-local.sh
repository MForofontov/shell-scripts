#!/bin/bash
# upgrade-cluster-local.sh
# Script to upgrade Kubernetes clusters across various providers

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
CLUSTER_NAME=""
PROVIDER="minikube"  # Default provider is minikube
K8S_VERSION=""       # Target Kubernetes version for upgrade
LOG_FILE="/dev/null"
FORCE=false
BACKUP=true          # Create backup/snapshot before upgrading if possible
WAIT_TIMEOUT=600     # 10 minutes timeout for upgrade to complete

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Upgrade Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script upgrades Kubernetes clusters created with various providers (minikube, kind, k3d)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-n, --name <NAME>\033[0m         (Required) Cluster name to upgrade"
  echo -e "  \033[1;36m-v, --version <VERSION>\033[0m   (Required) Target Kubernetes version"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m (Optional) Provider to use (minikube, kind, k3d) (default: ${PROVIDER})"
  echo -e "  \033[1;33m-f, --force\033[0m               (Optional) Force upgrade without confirmation"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m   (Optional) Timeout in seconds for upgrade (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--no-backup\033[0m               (Optional) Skip backup/snapshot before upgrade"
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

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
#=====================================================================
# REQUIREMENTS CHECKING
#=====================================================================
# Check for required tools
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC REQUIREMENTS
  #---------------------------------------------------------------------
  case "$PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        format-echo "ERROR" "minikube not found. Please install it first:"
        echo "https://minikube.sigs.k8s.io/docs/start/"
        exit 1
      fi
      ;;
    kind)
      if ! command_exists kind; then
        format-echo "ERROR" "kind not found. Please install it first:"
        echo "https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        format-echo "ERROR" "k3d not found. Please install it first:"
        echo "https://k3d.io/#installation"
        exit 1
      fi
      ;;
  esac

  #---------------------------------------------------------------------
  # COMMON REQUIREMENTS
  #---------------------------------------------------------------------
  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi

  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC UPGRADE REQUIREMENTS
  #---------------------------------------------------------------------
  # Specific to upgrade operations
  if [ "$PROVIDER" = "kind" ] && ! command_exists jq; then
    format-echo "ERROR" "jq not found but required for kind clusters. Please install it first:"
    echo "https://stedolan.github.io/jq/download/"
    exit 1
  fi

  format-echo "SUCCESS" "Required tools are available."
}

#=====================================================================
# CLUSTER VALIDATION
#=====================================================================
# Check if cluster exists
check_cluster_exists() {
  format-echo "INFO" "Checking if cluster exists..."
  
  local cluster_exists=false
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC CLUSTER DETECTION
  #---------------------------------------------------------------------
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
  
  #---------------------------------------------------------------------
  # EXISTENCE VERIFICATION
  #---------------------------------------------------------------------
  if $cluster_exists; then
    format-echo "SUCCESS" "Cluster '${CLUSTER_NAME}' found."
    return 0
  else
    format-echo "ERROR" "Cluster '${CLUSTER_NAME}' not found for provider ${PROVIDER}."
    exit 1
  fi
}

#=====================================================================
# CLUSTER INFORMATION
#=====================================================================
# Get cluster info before upgrade
get_cluster_info() {
  format-echo "INFO" "Getting cluster information before upgrade..."
  
  local current_version=""
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC VERSION DETECTION
  #---------------------------------------------------------------------
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
  
  #---------------------------------------------------------------------
  # CLUSTER INFORMATION DISPLAY
  #---------------------------------------------------------------------
  format-echo "INFO" "Current Kubernetes Version: $current_version"
  format-echo "INFO" "Target Kubernetes Version: $K8S_VERSION"
  format-echo "INFO" "Node Count: $NODE_COUNT"
  
  #---------------------------------------------------------------------
  # VERSION COMPARISON
  #---------------------------------------------------------------------
  # Check if the versions are the same
  if [[ "$current_version" == "$K8S_VERSION" ]]; then
    format-echo "WARNING" "Cluster is already running Kubernetes version $K8S_VERSION."
    read -p "Continue anyway? [y/N]: " continue_anyway
    
    case "$continue_anyway" in
      [Yy]|[Yy][Ee][Ss])
        return 0
        ;;
      *)
        format-echo "INFO" "Upgrade canceled by user."
        exit 0
        ;;
    esac
  fi
  
  #---------------------------------------------------------------------
  # DOWNGRADE DETECTION
  #---------------------------------------------------------------------
  # Check if we're attempting to downgrade
  if [[ "$(printf '%s\n' "$current_version" "$K8S_VERSION" | sort -V | head -n1)" == "$K8S_VERSION" ]]; then
    format-echo "WARNING" "Target version ($K8S_VERSION) is older than current version ($current_version)."
    format-echo "WARNING" "Downgrading Kubernetes clusters is not recommended and may cause issues."
    
    if [ "$FORCE" != true ]; then
      read -p "Continue with downgrade anyway? [y/N]: " continue_anyway
      
      case "$continue_anyway" in
        [Yy]|[Yy][Ee][Ss])
          return 0
          ;;
        *)
          format-echo "INFO" "Downgrade canceled by user."
          exit 0
          ;;
      esac
    else
      format-echo "WARNING" "Force flag set. Proceeding with downgrade."
    fi
  fi
  
  CURRENT_VERSION="$current_version"
  return 0
}

#=====================================================================
# BACKUP OPERATIONS
#=====================================================================
# Create backup before upgrade
create_backup() {
  #---------------------------------------------------------------------
  # BACKUP FLAG CHECKING
  #---------------------------------------------------------------------
  if [ "$BACKUP" != true ]; then
    format-echo "WARNING" "Skipping backup as --no-backup flag was provided."
    return 0
  fi
  
  format-echo "INFO" "Creating backup before upgrade..."
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC BACKUP PROCEDURES
  #---------------------------------------------------------------------
  case "$PROVIDER" in
    minikube)
      # For minikube, we can't easily create a snapshot, so we'll export important resources
      format-echo "INFO" "Creating resource backup for minikube cluster..."
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
      
      format-echo "SUCCESS" "Backup created at $backup_dir"
      ;;
    kind)
      # For kind, we'll back up the cluster configuration and resources
      format-echo "INFO" "Creating resource backup for kind cluster..."
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
      
      format-echo "SUCCESS" "Backup created at $backup_dir"
      ;;
    k3d)
      # For k3d, we'll back up the cluster resources
      format-echo "INFO" "Creating resource backup for k3d cluster..."
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
      
      format-echo "SUCCESS" "Backup created at $backup_dir"
      ;;
  esac
  
  BACKUP_DIR="$backup_dir"
}

#=====================================================================
# PROVIDER-SPECIFIC UPGRADE OPERATIONS
#=====================================================================
#---------------------------------------------------------------------
# MINIKUBE UPGRADE
#---------------------------------------------------------------------
# Upgrade minikube cluster
upgrade_minikube_cluster() {
  format-echo "INFO" "Upgrading minikube cluster '${CLUSTER_NAME}' to Kubernetes ${K8S_VERSION}..."
  
  #---------------------------------------------------------------------
  # CLUSTER SHUTDOWN
  #---------------------------------------------------------------------
  # Stop the cluster
  format-echo "INFO" "Stopping minikube cluster..."
  if ! minikube stop -p "${CLUSTER_NAME}"; then
    format-echo "ERROR" "Failed to stop minikube cluster '${CLUSTER_NAME}'."
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # CLUSTER UPGRADE
  #---------------------------------------------------------------------
  # Start the cluster with the new Kubernetes version
  format-echo "INFO" "Starting minikube cluster with Kubernetes version ${K8S_VERSION}..."
  if minikube start -p "${CLUSTER_NAME}" --kubernetes-version="${K8S_VERSION}"; then
    format-echo "SUCCESS" "minikube cluster '${CLUSTER_NAME}' upgraded successfully to Kubernetes ${K8S_VERSION}."
  else
    #---------------------------------------------------------------------
    # RECOVERY PROCEDURE
    #---------------------------------------------------------------------
    format-echo "ERROR" "Failed to upgrade minikube cluster '${CLUSTER_NAME}'."
    # Try to revert to previous version if upgrade failed
    format-echo "INFO" "Attempting to revert to previous Kubernetes version ${CURRENT_VERSION}..."
    if ! minikube start -p "${CLUSTER_NAME}" --kubernetes-version="${CURRENT_VERSION}"; then
      format-echo "ERROR" "Failed to revert to previous version. Cluster may be in an inconsistent state."
    else
      format-echo "INFO" "Successfully reverted to previous version ${CURRENT_VERSION}."
    fi
    exit 1
  fi
}

#---------------------------------------------------------------------
# KIND UPGRADE
#---------------------------------------------------------------------
# Upgrade kind cluster (requires delete and recreate)
upgrade_kind_cluster() {
  format-echo "INFO" "Upgrading kind cluster '${CLUSTER_NAME}' to Kubernetes ${K8S_VERSION}..."
  
  #---------------------------------------------------------------------
  # CONFIGURATION BACKUP
  #---------------------------------------------------------------------
  # For kind, we need to save the config
  local temp_config=$(mktemp)
  format-echo "INFO" "Saving cluster configuration..."
  kubectl --context="kind-${CLUSTER_NAME}" get nodes -o json > "${temp_config}"
  
  # Get the number of nodes
  NODE_COUNT=$(jq '.items | length' "${temp_config}")
  
  #---------------------------------------------------------------------
  # CLUSTER DELETION
  #---------------------------------------------------------------------
  # Delete the cluster
  format-echo "INFO" "Deleting kind cluster for upgrade..."
  if ! kind delete cluster --name "${CLUSTER_NAME}"; then
    format-echo "ERROR" "Failed to delete kind cluster '${CLUSTER_NAME}' for upgrade."
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # CLUSTER RECREATION
  #---------------------------------------------------------------------
  # Create a new cluster with the specified Kubernetes version
  format-echo "INFO" "Creating new kind cluster with Kubernetes version ${K8S_VERSION}..."
  
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
  
  #---------------------------------------------------------------------
  # CLUSTER CREATION
  #---------------------------------------------------------------------
  if kind create cluster --name "${CLUSTER_NAME}" --image="kindest/node:v${K8S_VERSION}" --config="$kind_config"; then
    format-echo "SUCCESS" "kind cluster '${CLUSTER_NAME}' upgraded successfully to Kubernetes ${K8S_VERSION}."
    
    # Clean up temporary files
    rm "${temp_config}" "${kind_config}"
  else
    #---------------------------------------------------------------------
    # RECOVERY PROCEDURE
    #---------------------------------------------------------------------
    format-echo "ERROR" "Failed to upgrade kind cluster '${CLUSTER_NAME}'."
    # Try to recreate with the previous version
    format-echo "INFO" "Attempting to recreate cluster with previous Kubernetes version ${CURRENT_VERSION}..."
    if ! kind create cluster --name "${CLUSTER_NAME}" --image="kindest/node:v${CURRENT_VERSION}" --config="$kind_config"; then
      format-echo "ERROR" "Failed to recreate cluster with previous version. Resources may be lost."
    else
      format-echo "INFO" "Successfully recreated cluster with previous version ${CURRENT_VERSION}."
    fi
    rm "${temp_config}" "${kind_config}"
    exit 1
  fi
}

#---------------------------------------------------------------------
# K3D UPGRADE
#---------------------------------------------------------------------
# Upgrade k3d cluster
upgrade_k3d_cluster() {
  format-echo "INFO" "Upgrading k3d cluster '${CLUSTER_NAME}' to Kubernetes ${K8S_VERSION}..."
  
  #---------------------------------------------------------------------
  # CONFIGURATION BACKUP
  #---------------------------------------------------------------------
  # For k3d, we need to delete and recreate the cluster similar to kind
  # First, get existing configuration
  local node_count_server=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\" and .role.server==true)] | length")
  local node_count_agent=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\" and .role.agent==true)] | length")
  
  #---------------------------------------------------------------------
  # CLUSTER DELETION
  #---------------------------------------------------------------------
  # Delete the cluster
  format-echo "INFO" "Deleting k3d cluster for upgrade..."
  if ! k3d cluster delete "${CLUSTER_NAME}"; then
    format-echo "ERROR" "Failed to delete k3d cluster '${CLUSTER_NAME}' for upgrade."
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # CLUSTER RECREATION
  #---------------------------------------------------------------------
  # Create a new cluster with the specified Kubernetes version
  format-echo "INFO" "Creating new k3d cluster with Kubernetes version ${K8S_VERSION}..."
  
  local k3d_args="--servers $node_count_server --agents $node_count_agent --image rancher/k3s:v${K8S_VERSION}-k3s1"
  
  if k3d cluster create "${CLUSTER_NAME}" $k3d_args; then
    format-echo "SUCCESS" "k3d cluster '${CLUSTER_NAME}' upgraded successfully to Kubernetes ${K8S_VERSION}."
  else
    #---------------------------------------------------------------------
    # RECOVERY PROCEDURE
    #---------------------------------------------------------------------
    format-echo "ERROR" "Failed to upgrade k3d cluster '${CLUSTER_NAME}'."
    # Try to recreate with the previous version
    format-echo "INFO" "Attempting to recreate cluster with previous Kubernetes version ${CURRENT_VERSION}..."
    local prev_k3d_args="--servers $node_count_server --agents $node_count_agent --image rancher/k3s:v${CURRENT_VERSION}-k3s1"
    if ! k3d cluster create "${CLUSTER_NAME}" $prev_k3d_args; then
      format-echo "ERROR" "Failed to recreate cluster with previous version. Resources may be lost."
    else
      format-echo "INFO" "Successfully recreated cluster with previous version ${CURRENT_VERSION}."
    fi
    exit 1
  fi
}

#=====================================================================
# VERIFICATION AND MONITORING
#=====================================================================
# Wait for cluster nodes to be ready
wait_for_cluster() {
  format-echo "INFO" "Waiting for cluster to be ready after upgrade (timeout: ${WAIT_TIMEOUT}s)..."
  
  #---------------------------------------------------------------------
  # TIMEOUT TRACKING
  #---------------------------------------------------------------------
  local start_time=$(date +%s)
  local end_time=$((start_time + WAIT_TIMEOUT))
  
  #---------------------------------------------------------------------
  # CONTEXT CONFIGURATION
  #---------------------------------------------------------------------
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
  
  #---------------------------------------------------------------------
  # READINESS POLLING
  #---------------------------------------------------------------------
  while true; do
    # First check if we can connect to the cluster
    if kubectl get nodes &>/dev/null; then
      # Check if we have the expected number of nodes
      local actual_nodes=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
      
      if [ "$actual_nodes" -eq "$NODE_COUNT" ]; then
        # Now check if all nodes are ready
        local all_ready=true
        for status in $(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}'); do
          if [[ "$status" != "True" ]]; then
            all_ready=false
            break
          fi
        done
        
        #---------------------------------------------------------------------
        # CORE COMPONENTS CHECK
        #---------------------------------------------------------------------
        if $all_ready; then
          format-echo "INFO" "Checking core components status..."
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
    fi
    
    #---------------------------------------------------------------------
    # TIMEOUT HANDLING
    #---------------------------------------------------------------------
    current_time=$(date +%s)
    if [[ $current_time -ge $end_time ]]; then
      format-echo "ERROR" "Timeout waiting for cluster to be ready after upgrade."
      format-echo "WARNING" "The scaling operation may have partially completed."
      exit 1
    fi
    
    sleep 5
  done
  
  format-echo "SUCCESS" "Cluster is ready after upgrade."
}

#=====================================================================
# UPGRADE VERIFICATION
#=====================================================================
# Verify upgrade
verify_upgrade() {
  format-echo "INFO" "Verifying upgrade..."
  
  #---------------------------------------------------------------------
  # VERSION VERIFICATION
  #---------------------------------------------------------------------
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
  
  #---------------------------------------------------------------------
  # VERSION COMPARISON
  #---------------------------------------------------------------------
  if [[ "$current_version" == "$K8S_VERSION"* ]]; then
    format-echo "SUCCESS" "Cluster successfully upgraded to Kubernetes version $current_version"
  else
    format-echo "WARNING" "Cluster version after upgrade ($current_version) doesn't match target version ($K8S_VERSION)"
    # This might not be an error, as patch versions can differ
  fi
}

#=====================================================================
# INFORMATION DISPLAY
#=====================================================================
# Display cluster info
display_cluster_info() {
  print_with_separator "Cluster Information After Upgrade"
  
  #---------------------------------------------------------------------
  # VERSION INFORMATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Kubernetes Version:"
  kubectl version
  
  #---------------------------------------------------------------------
  # NODE INFORMATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Nodes:"
  kubectl get nodes
  
  #---------------------------------------------------------------------
  # CLUSTER INFORMATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Cluster Info:"
  kubectl cluster-info
  
  print_with_separator
}

#=====================================================================
# USER INTERACTION
#=====================================================================
# Confirm upgrade with user
confirm_upgrade() {
  #---------------------------------------------------------------------
  # FORCE FLAG CHECK
  #---------------------------------------------------------------------
  if [ "$FORCE" = true ]; then
    return 0
  fi
  
  #---------------------------------------------------------------------
  # CONFIRMATION PROMPTING
  #---------------------------------------------------------------------
  echo -e "\033[1;33mWarning:\033[0m You are about to upgrade the cluster '${CLUSTER_NAME}' (provider: ${PROVIDER})."
  echo "  From Kubernetes version: $CURRENT_VERSION"
  echo "  To Kubernetes version:   $K8S_VERSION"
  echo
  echo "This operation may cause downtime and data loss. Make sure you have backups."
  echo
  read -p "Are you sure you want to continue? [y/N]: " answer
  
  #---------------------------------------------------------------------
  # USER RESPONSE HANDLING
  #---------------------------------------------------------------------
  case "$answer" in
    [Yy]|[Yy][Ee][Ss])
      return 0
      ;;
    *)
      format-echo "INFO" "Upgrade canceled by user."
      exit 0
      ;;
  esac
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
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
            format-echo "ERROR" "Unsupported provider '${PROVIDER}'."
            format-echo "ERROR" "Supported providers: minikube, kind, k3d"
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
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  #---------------------------------------------------------------------
  # REQUIRED PARAMETERS CHECKING
  #---------------------------------------------------------------------
  # Check if required parameters are provided
  if [ -z "$CLUSTER_NAME" ]; then
    format-echo "ERROR" "Cluster name is required. Use -n or --name to specify."
    usage
  fi
  
  if [ -z "$K8S_VERSION" ]; then
    format-echo "ERROR" "Target Kubernetes version is required. Use -v or --version to specify."
    usage
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
# Main function
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  # Parse arguments
  parse_args "$@"

  #---------------------------------------------------------------------
  # LOG CONFIGURATION
  #---------------------------------------------------------------------
  setup_log_file

  print_with_separator "Kubernetes Cluster Upgrade Script"
  
  format-echo "INFO" "Starting Kubernetes cluster upgrade..."
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Cluster Name: $CLUSTER_NAME"
  format-echo "INFO" "  Provider:     $PROVIDER"
  format-echo "INFO" "  Target K8s:   $K8S_VERSION"
  format-echo "INFO" "  Force Upgrade: $FORCE"
  format-echo "INFO" "  Create Backup: $BACKUP"
  
  #---------------------------------------------------------------------
  # PREREQUISITE CHECKS
  #---------------------------------------------------------------------
  # Check requirements
  check_requirements
  
  # Check if the cluster exists
  check_cluster_exists
  
  # Get cluster info before upgrade
  get_cluster_info
  
  #---------------------------------------------------------------------
  # USER CONFIRMATION
  #---------------------------------------------------------------------
  # Confirm upgrade with user
  confirm_upgrade
  
  #---------------------------------------------------------------------
  # BACKUP CREATION
  #---------------------------------------------------------------------
  # Create backup before upgrade
  create_backup
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC UPGRADE
  #---------------------------------------------------------------------
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
  
  #---------------------------------------------------------------------
  # POST-UPGRADE PROCEDURES
  #---------------------------------------------------------------------
  # Wait for cluster to be ready
  wait_for_cluster
  
  # Verify upgrade
  verify_upgrade
  
  # Display cluster info after upgrade
  display_cluster_info
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Kubernetes Cluster Upgrade"
  format-echo "SUCCESS" "Kubernetes cluster upgrade completed successfully."
  
  if [ -n "$BACKUP_DIR" ]; then
    format-echo "INFO" "Backup of the cluster before upgrade is available at: $BACKUP_DIR"
  fi
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"
