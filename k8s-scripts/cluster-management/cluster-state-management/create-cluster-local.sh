#!/bin/bash
# create-cluster.sh
# Script to create Kubernetes clusters with various providers

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/print-functions/print-with-separator.sh"

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

#=====================================================================
# DEFAULT VALUES
#=====================================================================
# Default values
CLUSTER_NAME="k8s-cluster"
PROVIDER="minikube"  # Default provider is minikube
NODE_COUNT=1
K8S_VERSION="latest"
CONFIG_FILE=""
WAIT_TIMEOUT=300 # 5 minutes timeout
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Creation Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates Kubernetes clusters using various providers (minikube, kind, k3d)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m          (Optional) Cluster name (default: ${CLUSTER_NAME})"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m  (Optional) Provider to use: minikube, kind, k3d (default: ${PROVIDER})"
  echo -e "  \033[1;33m-c, --nodes <COUNT>\033[0m        (Optional) Number of nodes (default: ${NODE_COUNT})"
  echo -e "  \033[1;33m-v, --version <VERSION>\033[0m    (Optional) Kubernetes version (default: ${K8S_VERSION})"
  echo -e "  \033[1;33m-f, --config <FILE>\033[0m        (Optional) Path to custom config file"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m    (Optional) Timeout in seconds for cluster readiness (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--log <FILE>\033[0m               (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster --nodes 3"
  echo "  $0 --version 1.25.0 --log create.log"
  echo "  $0 --provider kind --nodes 2"
  echo "  $0 --provider k3d --config custom-config.yaml"
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
  log_message "INFO" "Checking requirements..."
  
  case "$PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        log_message "WARNING" "minikube not found. Attempting to install..."
        if command_exists brew; then
          brew install minikube
        else
          log_message "ERROR" "minikube not found. Please install it manually:"
          echo "https://minikube.sigs.k8s.io/docs/start/"
          exit 1
        fi
      fi
      ;;
    kind)
      if ! command_exists kind; then
        log_message "WARNING" "kind not found. Attempting to install..."
        if command_exists brew; then
          brew install kind
        else
          log_message "ERROR" "kind not found. Please install it manually:"
          echo "https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
          exit 1
        fi
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        log_message "WARNING" "k3d not found. Attempting to install..."
        if command_exists brew; then
          brew install k3d
        else
          log_message "ERROR" "k3d not found. Please install it manually:"
          echo "https://k3d.io/#installation"
          exit 1
        fi
      fi
      ;;
  esac

  if ! command_exists kubectl; then
    log_message "WARNING" "kubectl not found. Attempting to install..."
    if command_exists brew; then
      brew install kubectl
    else
      log_message "ERROR" "kubectl not found. Please install it manually:"
      echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
      exit 1
    fi
  fi

  log_message "SUCCESS" "All required tools are installed."
}

#=====================================================================
# CLUSTER VALIDATION
#=====================================================================
# Check if cluster already exists
check_cluster_exists() {
  log_message "INFO" "Checking if cluster already exists..."
  
  case "$PROVIDER" in
    minikube)
      if minikube profile list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        log_message "ERROR" "minikube profile '${CLUSTER_NAME}' already exists."
        exit 1
      fi
      ;;
    kind)
      if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_message "ERROR" "kind cluster '${CLUSTER_NAME}' already exists."
        exit 1
      fi
      ;;
    k3d)
      if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        log_message "ERROR" "k3d cluster '${CLUSTER_NAME}' already exists."
        exit 1
      fi
      ;;
  esac
  
  log_message "SUCCESS" "No existing cluster with name '${CLUSTER_NAME}' found."
}

#=====================================================================
# PROVIDER-SPECIFIC CREATION OPERATIONS
#=====================================================================

#---------------------------------------------------------------------
# MINIKUBE CREATION
#---------------------------------------------------------------------
# Create cluster with minikube
create_minikube_cluster() {
  log_message "INFO" "Creating minikube cluster '${CLUSTER_NAME}'..."
  
  MINIKUBE_ARGS="start -p ${CLUSTER_NAME}"
  
  if [[ "$K8S_VERSION" != "latest" ]]; then
    MINIKUBE_ARGS="$MINIKUBE_ARGS --kubernetes-version=$K8S_VERSION"
  fi
  
  if [[ "$NODE_COUNT" -gt 1 ]]; then
    MINIKUBE_ARGS="$MINIKUBE_ARGS --nodes=$NODE_COUNT"
  fi
  
  if [[ -n "$CONFIG_FILE" ]]; then
    log_message "INFO" "Using custom config file: $CONFIG_FILE"
    # Minikube doesn't directly accept a config file parameter like kind or k3d
    # We could parse the file and extract values if needed
    log_message "WARNING" "Custom config file for minikube is used as a reference only. Some settings may not be applied."
  fi
  
  log_message "INFO" "Running: minikube $MINIKUBE_ARGS"
  if minikube $MINIKUBE_ARGS; then
    log_message "SUCCESS" "minikube cluster '${CLUSTER_NAME}' created successfully."
  else
    log_message "ERROR" "Failed to create minikube cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

#---------------------------------------------------------------------
# KIND CREATION
#---------------------------------------------------------------------
# Create cluster with kind
create_kind_cluster() {
  log_message "INFO" "Creating kind cluster '${CLUSTER_NAME}'..."
  
  KIND_ARGS="--name ${CLUSTER_NAME}"
  
  if [[ "$K8S_VERSION" != "latest" ]]; then
    KIND_ARGS="$KIND_ARGS --image kindest/node:v$K8S_VERSION"
  fi
  
  if [[ -n "$CONFIG_FILE" ]]; then
    KIND_ARGS="$KIND_ARGS --config $CONFIG_FILE"
  elif [[ "$NODE_COUNT" -gt 1 ]]; then
    # Generate a temporary config file for multi-node setup
    TEMP_CONFIG=$(mktemp)
    echo "kind: Cluster" > "$TEMP_CONFIG"
    echo "apiVersion: kind.x-k8s.io/v1alpha4" >> "$TEMP_CONFIG"
    echo "nodes:" >> "$TEMP_CONFIG"
    echo "- role: control-plane" >> "$TEMP_CONFIG"
    
    for ((i=1; i<NODE_COUNT; i++)); do
      echo "- role: worker" >> "$TEMP_CONFIG"
    done
    
    KIND_ARGS="$KIND_ARGS --config $TEMP_CONFIG"
    log_message "INFO" "Generated temporary config for $NODE_COUNT nodes."
  fi
  
  log_message "INFO" "Running: kind create cluster $KIND_ARGS"
  if kind create cluster $KIND_ARGS; then
    log_message "SUCCESS" "kind cluster '${CLUSTER_NAME}' created successfully."
  else
    log_message "ERROR" "Failed to create kind cluster '${CLUSTER_NAME}'."
    exit 1
  fi
  
  if [[ -f "$TEMP_CONFIG" ]]; then
    rm "$TEMP_CONFIG"
  fi
}

#---------------------------------------------------------------------
# K3D CREATION
#---------------------------------------------------------------------
# Create cluster with k3d
create_k3d_cluster() {
  log_message "INFO" "Creating k3d cluster '${CLUSTER_NAME}'..."
  
  K3D_ARGS="cluster create ${CLUSTER_NAME}"
  
  if [[ "$K8S_VERSION" != "latest" ]]; then
    K3D_ARGS="$K3D_ARGS --image rancher/k3s:v$K8S_VERSION-k3s1"
  fi
  
  if [[ "$NODE_COUNT" -gt 1 ]]; then
    K3D_ARGS="$K3D_ARGS --agents $(($NODE_COUNT - 1))"
  fi
  
  if [[ -n "$CONFIG_FILE" ]]; then
    K3D_ARGS="$K3D_ARGS --config $CONFIG_FILE"
  fi
  
  log_message "INFO" "Running: k3d $K3D_ARGS"
  if k3d $K3D_ARGS; then
    log_message "SUCCESS" "k3d cluster '${CLUSTER_NAME}' created successfully."
  else
    log_message "ERROR" "Failed to create k3d cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

#=====================================================================
# MONITORING AND VERIFICATION
#=====================================================================
# Wait for cluster to be ready
wait_for_cluster() {
  log_message "INFO" "Waiting for cluster to be ready (timeout: ${WAIT_TIMEOUT}s)..."
  
  local start_time=$(date +%s)
  local end_time=$((start_time + WAIT_TIMEOUT))
  local progress=0
  
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
        echo "" # New line after progress dots
        break
      fi
    fi
    
    current_time=$(date +%s)
    if [[ $current_time -ge $end_time ]]; then
      echo "" # New line after progress dots
      log_message "ERROR" "Timed out waiting for cluster to be ready."
      exit 1
    fi
    
    # Show progress dots with percentage
    elapsed=$((current_time - start_time))
    new_progress=$((elapsed * 100 / WAIT_TIMEOUT))
    
    if [[ $new_progress -gt $progress ]]; then
      progress=$new_progress
      echo -n "."
      if [[ $((progress % 10)) -eq 0 ]]; then
        echo -n " ${progress}% "
      fi
    fi
    
    sleep 5
  done
  
  log_message "SUCCESS" "Cluster is ready."
}

#=====================================================================
# DISPLAY AND REPORTING
#=====================================================================
# Display cluster info
display_cluster_info() {
  print_with_separator "Cluster Information"
  
  log_message "INFO" "Nodes:"
  kubectl get nodes
  
  log_message "INFO" "Cluster Info:"
  kubectl cluster-info
  
  case "$PROVIDER" in
    minikube)
      echo -e "\n\033[1;34mTo use this cluster with kubectl:\033[0m"
      echo "kubectl config use-context ${CLUSTER_NAME}"
      ;;
    kind)
      echo -e "\n\033[1;34mTo use this cluster with kubectl:\033[0m"
      echo "kubectl cluster-info --context kind-${CLUSTER_NAME}"
      ;;
    k3d)
      echo -e "\n\033[1;34mTo use this cluster with kubectl:\033[0m"
      echo "kubectl config use-context k3d-${CLUSTER_NAME}"
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
            log_message "ERROR" "Unsupported provider '${PROVIDER}'."
            log_message "ERROR" "Supported providers: minikube, kind, k3d"
            exit 1
            ;;
        esac
        shift 2
        ;;
      -c|--nodes)
        NODE_COUNT="$2"
        if ! [[ "$NODE_COUNT" =~ ^[1-9][0-9]*$ ]]; then
          log_message "ERROR" "Node count must be a positive integer."
          exit 1
        fi
        shift 2
        ;;
      -v|--version)
        K8S_VERSION="$2"
        shift 2
        ;;
      -f|--config)
        CONFIG_FILE="$2"
        if [[ ! -f "$CONFIG_FILE" ]]; then
          log_message "ERROR" "Config file not found: ${CONFIG_FILE}"
          exit 1
        fi
        shift 2
        ;;
      -t|--timeout)
        WAIT_TIMEOUT="$2"
        if ! [[ "$WAIT_TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
          log_message "ERROR" "Timeout must be a positive integer."
          exit 1
        fi
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

  print_with_separator "Kubernetes Cluster Creation Script"
  
  log_message "INFO" "Starting Kubernetes cluster creation..."
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Cluster Name: $CLUSTER_NAME"
  log_message "INFO" "  Provider:     $PROVIDER"
  log_message "INFO" "  Node Count:   $NODE_COUNT"
  log_message "INFO" "  K8s Version:  $K8S_VERSION"
  log_message "INFO" "  Config File:  ${CONFIG_FILE:-None}"
  log_message "INFO" "  Timeout:      ${WAIT_TIMEOUT}s"
  
  # Check requirements
  check_requirements
  
  # Check if a cluster with the same name already exists
  check_cluster_exists
  
  # Create the cluster based on the provider
  case "$PROVIDER" in
    minikube)
      create_minikube_cluster
      ;;
    kind)
      create_kind_cluster
      ;;
    k3d)
      create_k3d_cluster
      ;;
  esac
  
  wait_for_cluster
  display_cluster_info
  
  print_with_separator "End of Kubernetes Cluster Creation"
  log_message "SUCCESS" "Kubernetes cluster creation completed successfully."
}

# Run the main function
main "$@"