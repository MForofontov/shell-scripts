#!/bin/bash
# restart-cluster.sh
# Script to restart Kubernetes clusters across various providers

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
FORMAT_ECHO_FILE="$SCRIPT_DIR/../../../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
CLUSTER_NAME=""
PROVIDER="minikube"  # Default provider is minikube
LOG_FILE="/dev/null"
FORCE=false
WAIT_TIMEOUT=300 # 5 minutes timeout for cluster to be ready

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Restart Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script restarts Kubernetes clusters created with various providers (minikube, kind, k3d)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-n, --name <NAME>\033[0m          (Required) Cluster name to restart"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m  (Optional) Provider to use (minikube, kind, k3d) (default: ${PROVIDER})"
  echo -e "  \033[1;33m-f, --force\033[0m                (Optional) Force restart without confirmation"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m    (Optional) Timeout in seconds for cluster readiness (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--log <FILE>\033[0m               (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster"
  echo "  $0 --name test-cluster --provider kind"
  echo "  $0 --name dev-cluster --provider k3d --force"
  echo "  $0 --name my-cluster --log restart.log"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#=====================================================================
# REQUIREMENTS CHECKING
#=====================================================================
# Check for required tools
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
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

  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
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
# Get cluster info before restart
get_cluster_info() {
  format-echo "INFO" "Getting cluster information before restart..."
  
  case "$PROVIDER" in
    minikube)
      # Get minikube cluster info
      CLUSTER_INFO=$(minikube profile list -o json | jq -r ".[] | select(.Name==\"$CLUSTER_NAME\")")
      K8S_VERSION=$(echo "$CLUSTER_INFO" | jq -r ".Config.KubernetesConfig.KubernetesVersion")
      NODE_COUNT=$(minikube node list -p "$CLUSTER_NAME" 2>/dev/null | wc -l | tr -d ' ')
      format-echo "INFO" "Kubernetes Version: $K8S_VERSION"
      format-echo "INFO" "Node Count: $NODE_COUNT"
      ;;
    kind)
      # For kind, we can't easily get detailed config, but we can get node info
      NODE_COUNT=$(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null | wc -l | tr -d ' ')
      format-echo "INFO" "Node Count: $NODE_COUNT"
      ;;
    k3d)
      # For k3d, get node info
      NODE_COUNT=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\")] | length")
      format-echo "INFO" "Node Count: $NODE_COUNT"
      ;;
  esac
}

#=====================================================================
# PROVIDER-SPECIFIC RESTART OPERATIONS
#=====================================================================

#---------------------------------------------------------------------
# MINIKUBE RESTART
#---------------------------------------------------------------------
# Restart minikube cluster
restart_minikube_cluster() {
  format-echo "INFO" "Restarting minikube cluster '${CLUSTER_NAME}'..."
  
  # Stop the cluster
  format-echo "INFO" "Stopping minikube cluster..."
  if ! minikube stop -p "${CLUSTER_NAME}"; then
    format-echo "ERROR" "Failed to stop minikube cluster '${CLUSTER_NAME}'."
    exit 1
  fi
  
  # Start the cluster
  format-echo "INFO" "Starting minikube cluster..."
  if minikube start -p "${CLUSTER_NAME}"; then
    format-echo "SUCCESS" "minikube cluster '${CLUSTER_NAME}' restarted successfully."
  else
    format-echo "ERROR" "Failed to start minikube cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

#---------------------------------------------------------------------
# KIND RESTART
#---------------------------------------------------------------------
# Restart kind cluster (requires delete and recreate)
restart_kind_cluster() {
  format-echo "INFO" "Restarting kind cluster '${CLUSTER_NAME}'..."
  
  # For kind, we need to save the config if available
  local temp_config=""
  if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    temp_config=$(mktemp)
    format-echo "INFO" "Saving cluster configuration..."
    kubectl --context="kind-${CLUSTER_NAME}" get nodes -o json > "${temp_config}"
  fi
  
  # Delete the cluster
  format-echo "INFO" "Deleting kind cluster..."
  if ! kind delete cluster --name "${CLUSTER_NAME}"; then
    format-echo "ERROR" "Failed to delete kind cluster '${CLUSTER_NAME}'."
    exit 1
  fi
  
  # Create new cluster with similar configuration
  format-echo "INFO" "Creating new kind cluster..."
  
  # If we have a saved config with node count
  local node_args=""
  if [[ -f "${temp_config}" ]]; then
    NODE_COUNT=$(jq '.items | length' "${temp_config}")
    
    if [[ "$NODE_COUNT" -gt 1 ]]; then
      # Generate a configuration for multi-node setup
      local kind_config=$(mktemp)
      echo "kind: Cluster" > "$kind_config"
      echo "apiVersion: kind.x-k8s.io/v1alpha4" >> "$kind_config"
      echo "nodes:" >> "$kind_config"
      echo "- role: control-plane" >> "$kind_config"
      
      # Add worker nodes
      for ((i=1; i<NODE_COUNT; i++)); do
        echo "- role: worker" >> "$kind_config"
      done
      
      node_args="--config $kind_config"
    fi
  fi
  
  if kind create cluster --name "${CLUSTER_NAME}" $node_args; then
    format-echo "SUCCESS" "kind cluster '${CLUSTER_NAME}' recreated successfully."
    
    # Clean up temporary files
    [[ -f "${temp_config}" ]] && rm "${temp_config}"
    [[ -f "${kind_config}" ]] && rm "${kind_config}"
  else
    format-echo "ERROR" "Failed to recreate kind cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

#---------------------------------------------------------------------
# K3D RESTART
#---------------------------------------------------------------------
# Restart k3d cluster
restart_k3d_cluster() {
  format-echo "INFO" "Restarting k3d cluster '${CLUSTER_NAME}'..."
  
  # Stop the cluster
  format-echo "INFO" "Stopping k3d cluster..."
  if ! k3d cluster stop "${CLUSTER_NAME}"; then
    format-echo "ERROR" "Failed to stop k3d cluster '${CLUSTER_NAME}'."
    exit 1
  fi
  
  # Start the cluster
  format-echo "INFO" "Starting k3d cluster..."
  if k3d cluster start "${CLUSTER_NAME}"; then
    format-echo "SUCCESS" "k3d cluster '${CLUSTER_NAME}' restarted successfully."
  else
    format-echo "ERROR" "Failed to start k3d cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

#=====================================================================
# MONITORING AND VERIFICATION
#=====================================================================
# Wait for cluster to be ready
wait_for_cluster() {
  format-echo "INFO" "Waiting for cluster to be ready (timeout: ${WAIT_TIMEOUT}s)..."
  
  local start_time=$(date +%s)
  local end_time=$((start_time + WAIT_TIMEOUT))
  
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
        break
      fi
    fi
    
    current_time=$(date +%s)
    if [[ $current_time -ge $end_time ]]; then
      format-echo "ERROR" "Timeout waiting for cluster to be ready."
      exit 1
    fi
    
    sleep 5
  done
  
  format-echo "SUCCESS" "Cluster is ready."
}

# Display cluster info
display_cluster_info() {
  print_with_separator "Cluster Information After Restart"
  
  format-echo "INFO" "Nodes:"
  kubectl get nodes
  
  format-echo "INFO" "Cluster Info:"
  kubectl cluster-info
  
  print_with_separator
}

#=====================================================================
# USER INTERACTION
#=====================================================================
# Confirm restart with user
confirm_restart() {
  if [ "$FORCE" = true ]; then
    return 0
  fi
  
  echo -e "\033[1;33mWarning:\033[0m You are about to restart the cluster '${CLUSTER_NAME}' (provider: ${PROVIDER})."
  echo "This may cause temporary downtime for any applications running on the cluster."
  read -p "Are you sure you want to continue? [y/N]: " answer
  
  case "$answer" in
    [Yy]|[Yy][Ee][Ss])
      return 0
      ;;
    *)
      format-echo "INFO" "Restart canceled by user."
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
      -f|--force)
        FORCE=true
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
  
  # Check if cluster name is provided
  if [ -z "$CLUSTER_NAME" ]; then
    format-echo "ERROR" "Cluster name is required. Use -n or --name to specify."
    usage
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
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
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  print_with_separator "Kubernetes Cluster Restart"

  format-echo "INFO" "Starting Kubernetes cluster restart..."
  
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Cluster Name: $CLUSTER_NAME"
  format-echo "INFO" "  Provider:     $PROVIDER"
  format-echo "INFO" "  Force Restart: $FORCE"
  
  # Check requirements
  check_requirements
  
  # Check if the cluster exists
  check_cluster_exists
  
  # Get cluster info before restart
  get_cluster_info
  
  # Confirm restart with user
  confirm_restart
  
  # Restart the cluster based on the provider
  case "$PROVIDER" in
    minikube)
      restart_minikube_cluster
      ;;
    kind)
      restart_kind_cluster
      ;;
    k3d)
      restart_k3d_cluster
      ;;
  esac
  
  # Wait for cluster to be ready
  wait_for_cluster
  
  # Display cluster info after restart
  display_cluster_info
  
  print_with_separator "End of Kubernetes Cluster Restart"
  format-echo "SUCCESS" "Kubernetes cluster restart completed successfully."
}

# Run the main function
main "$@"
