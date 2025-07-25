#!/bin/bash
# create-cluster-local.sh
# Script to create Kubernetes clusters with various providers

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../../functions/common-init.sh"
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
  echo -e "  \033[1;33m-f, --config <FILE>\033[0m        (Optional) Path to custom config file (YAML)"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m    (Optional) Timeout in seconds for cluster readiness (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--log <FILE>\033[0m               (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster --nodes 3"
  echo "  $0 --version 1.25.0 --log create.log"
  echo "  $0 --provider kind --nodes 2"
  echo "  $0 --provider minikube --config minikube-config.yaml"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
#=====================================================================
# YAML CONFIGURATION PARSING
#=====================================================================
# Parse YAML config file for minikube
parse_minikube_config() {
  local config_file="$1"
  
  format-echo "INFO" "Parsing minikube configuration from $config_file"
  
  # Set up the array for minikube arguments
  MINIKUBE_ARGS=(start -p "${CLUSTER_NAME}")
  
  # Apply command line arguments first
  if [[ "$K8S_VERSION" != "latest" ]]; then
    MINIKUBE_ARGS+=(--kubernetes-version "$K8S_VERSION")
  fi
  
  if [[ "$NODE_COUNT" -gt 1 ]]; then
    MINIKUBE_ARGS+=(--nodes "$NODE_COUNT")
  fi
  
  # Parse the YAML file with safer approach
  parse_yaml "$config_file"
}

# Parse YAML file and add arguments to MINIKUBE_ARGS array
parse_yaml() {
  local config_file="$1"
  local current_section=""
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    if [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]]; then
      continue
    fi
    
    # Detect section headers (keys with just a colon)
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      continue
    fi
    
    # Handle array items (lines starting with dash)
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.+)$ ]]; then
      local value="${BASH_REMATCH[1]}"
      value=$(echo "$value" | xargs) # Trim whitespace
      
      case "$current_section" in
        addons)
          MINIKUBE_ARGS+=(--addons "$value")
          ;;
        insecure-registry)
          MINIKUBE_ARGS+=(--insecure-registry "$value")
          ;;
      esac
      continue
    fi
    
    # Handle key-value pairs
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*(.+)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      
      # Trim whitespace
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      
      # Skip if this is a section that contains array items
      if [[ "$key" == "addons" || "$key" == "insecure-registry" ]]; then
        current_section="$key"
        continue
      fi
      
      # Handle boolean values and regular values
      if [[ "$value" == "true" ]]; then
        MINIKUBE_ARGS+=(--"$key")
      elif [[ "$value" != "false" && "$value" != "{" && "$value" != "[" ]]; then
        # Remove quotes if present
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        MINIKUBE_ARGS+=(--"$key" "$value")
      fi
    fi
  done < "$config_file"
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
        format-echo "WARNING" "minikube not found. Attempting to install..."
        if command_exists brew; then
          brew install minikube
        else
          format-echo "ERROR" "minikube not found. Please install it manually:"
          echo "https://minikube.sigs.k8s.io/docs/start/"
          exit 1
        fi
      fi
      ;;
    kind)
      if ! command_exists kind; then
        format-echo "WARNING" "kind not found. Attempting to install..."
        if command_exists brew; then
          brew install kind
        else
          format-echo "ERROR" "kind not found. Please install it manually:"
          echo "https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
          exit 1
        fi
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        format-echo "WARNING" "k3d not found. Attempting to install..."
        if command_exists brew; then
          brew install k3d
        else
          format-echo "ERROR" "k3d not found. Please install it manually:"
          echo "https://k3d.io/#installation"
          exit 1
        fi
      fi
      ;;
  esac

  if ! command_exists kubectl; then
    format-echo "WARNING" "kubectl not found. Attempting to install..."
    if command_exists brew; then
      brew install kubectl
    else
      format-echo "ERROR" "kubectl not found. Please install it manually:"
      echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
      exit 1
    fi
  fi

  format-echo "SUCCESS" "All required tools are installed."
}

#=====================================================================
# CLUSTER VALIDATION
#=====================================================================
# Check if cluster already exists
check_cluster_exists() {
  format-echo "INFO" "Checking if cluster already exists..."
  
  case "$PROVIDER" in
    minikube)
      if minikube profile list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        format-echo "ERROR" "minikube profile '${CLUSTER_NAME}' already exists."
        exit 1
      fi
      ;;
    kind)
      if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        format-echo "ERROR" "kind cluster '${CLUSTER_NAME}' already exists."
        exit 1
      fi
      ;;
    k3d)
      if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        format-echo "ERROR" "k3d cluster '${CLUSTER_NAME}' already exists."
        exit 1
      fi
      ;;
  esac
  
  format-echo "SUCCESS" "No existing cluster with name '${CLUSTER_NAME}' found."
}

#=====================================================================
# PROVIDER-SPECIFIC CREATION OPERATIONS
#=====================================================================

#---------------------------------------------------------------------
# MINIKUBE CREATION
#---------------------------------------------------------------------
# Create cluster with minikube
create_minikube_cluster() {
  format-echo "INFO" "Creating minikube cluster '${CLUSTER_NAME}'..."
  
  # If config file is provided, parse it and apply settings
  if [[ -n "$CONFIG_FILE" ]]; then
    format-echo "INFO" "Using custom config file: $CONFIG_FILE"
    parse_minikube_config "$CONFIG_FILE"
  else
    # No config file, just use command line arguments
    MINIKUBE_ARGS=(start -p "${CLUSTER_NAME}")
    
    if [[ "$K8S_VERSION" != "latest" ]]; then
      MINIKUBE_ARGS+=(--kubernetes-version "$K8S_VERSION")
    fi
    
    if [[ "$NODE_COUNT" -gt 1 ]]; then
      MINIKUBE_ARGS+=(--nodes "$NODE_COUNT")
    fi
  fi
  
  # Show command for debugging
  format-echo "DEBUG" "Running: minikube ${MINIKUBE_ARGS[*]}"
  
  # Execute minikube with array arguments (prevents word splitting issues)
  if minikube "${MINIKUBE_ARGS[@]}"; then
    format-echo "SUCCESS" "minikube cluster '${CLUSTER_NAME}' created successfully."
  else
    format-echo "ERROR" "Failed to create minikube cluster '${CLUSTER_NAME}'."
    exit 1
  fi
  
  # Wait for cluster to be ready
  format-echo "INFO" "Waiting for cluster to be ready..."
  local timeout=$WAIT_TIMEOUT
  local interval=5
  local elapsed=0
  
  while [ $elapsed -lt $timeout ]; do
    if kubectl --context="${CLUSTER_NAME}" get nodes &>/dev/null; then
      local ready_count=$(kubectl --context="${CLUSTER_NAME}" get nodes --no-headers | grep -c " Ready ")
      format-echo "INFO" "$ready_count of $NODE_COUNT nodes are ready."
      if [[ $ready_count -eq $NODE_COUNT ]]; then
        format-echo "SUCCESS" "All nodes are ready."
        return 0
      fi
    fi

    sleep $interval
    elapsed=$((elapsed + interval))
    format-echo "INFO" "Waiting for cluster to be ready... ($elapsed/$timeout seconds)"
  done

  format-echo "WARNING" "Timeout waiting for cluster to be ready."
  return 1
}

#---------------------------------------------------------------------
# KIND CREATION
#---------------------------------------------------------------------
# Create cluster with kind
create_kind_cluster() {
  format-echo "INFO" "Creating kind cluster '${CLUSTER_NAME}'..."
  
  local kind_args=(create cluster --name "$CLUSTER_NAME")
  
  if [[ -n "$CONFIG_FILE" ]]; then
    format-echo "INFO" "Using custom kind config file: $CONFIG_FILE"
    kind_args+=(--config "$CONFIG_FILE")
  elif [[ "$NODE_COUNT" -gt 1 ]]; then
    # Create a temporary config file for multi-node setup
    local temp_config=$(mktemp)
    cat > "$temp_config" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF
    
    # Add worker nodes
    for i in $(seq 2 $NODE_COUNT); do
      echo "- role: worker" >> "$temp_config"
    done
    
    kind_args+=(--config "$temp_config")
    format-echo "INFO" "Generated kind config with $NODE_COUNT nodes"
  fi
  
  if [[ "$K8S_VERSION" != "latest" ]]; then
    kind_args+=(--image "kindest/node:$K8S_VERSION")
    format-echo "INFO" "Using Kubernetes version: $K8S_VERSION"
  fi
  
  # Show command for debugging
  format-echo "DEBUG" "Running: kind ${kind_args[*]}"
  
  # Execute kind with array arguments
  if kind "${kind_args[@]}"; then
    format-echo "SUCCESS" "kind cluster '${CLUSTER_NAME}' created successfully."
  else
    format-echo "ERROR" "Failed to create kind cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

#---------------------------------------------------------------------
# K3D CREATION
#---------------------------------------------------------------------
# Create cluster with k3d
create_k3d_cluster() {
  format-echo "INFO" "Creating k3d cluster '${CLUSTER_NAME}'..."
  
  local k3d_args=(cluster create "$CLUSTER_NAME")
  
  if [[ -n "$CONFIG_FILE" ]]; then
    format-echo "INFO" "Using custom k3d config file: $CONFIG_FILE"
    k3d_args+=(--config "$CONFIG_FILE")
  else
    # Add server and agent nodes based on node count
    if [[ "$NODE_COUNT" -gt 1 ]]; then
      local agent_count=$((NODE_COUNT - 1))
      k3d_args+=(--servers 1 --agents "$agent_count")
    fi
    
    # Add Kubernetes version if specified
    if [[ "$K8S_VERSION" != "latest" ]]; then
      # k3d uses different image naming
      k3d_args+=(--image "rancher/k3s:v$K8S_VERSION-k3s1")
    fi
  fi
  
  # Show command for debugging
  format-echo "DEBUG" "Running: k3d ${k3d_args[*]}"
  
  # Execute k3d with array arguments
  if k3d "${k3d_args[@]}"; then
    format-echo "SUCCESS" "k3d cluster '${CLUSTER_NAME}' created successfully."
  else
    format-echo "ERROR" "Failed to create k3d cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--name)
        CLUSTER_NAME="$2"
        shift 2
        ;;
      -p|--provider)
        PROVIDER="$2"
        shift 2
        ;;
      -c|--nodes)
        NODE_COUNT="$2"
        shift 2
        ;;
      -v|--version)
        K8S_VERSION="$2"
        shift 2
        ;;
      -f|--config)
        CONFIG_FILE="$2"
        shift 2
        ;;
      -t|--timeout)
        WAIT_TIMEOUT="$2"
        shift 2
        ;;
      --log)
        LOG_FILE="$2"
        shift 2
        ;;
      --help)
        usage
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  # Validate provider
  case "$PROVIDER" in
    minikube|kind|k3d) ;;
    *)
      format-echo "ERROR" "Unsupported provider: $PROVIDER"
      format-echo "ERROR" "Supported providers: minikube, kind, k3d"
      exit 1
      ;;
  esac
  
  # Validate config file if specified
  if [[ -n "$CONFIG_FILE" && ! -f "$CONFIG_FILE" ]]; then
    format-echo "ERROR" "Config file not found: $CONFIG_FILE"
    exit 1
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
main() {
  # Parse command line arguments
  parse_args "$@"
  
  setup_log_file
  
  print_with_separator "Kubernetes Cluster Creation"
  
  format-echo "INFO" "Creating Kubernetes cluster with the following settings:"
  format-echo "INFO" "  Provider:  $PROVIDER"
  format-echo "INFO" "  Name:      $CLUSTER_NAME"
  format-echo "INFO" "  Nodes:     $NODE_COUNT"
  format-echo "INFO" "  Version:   $K8S_VERSION"
  
  if [[ -n "$CONFIG_FILE" ]]; then
    format-echo "INFO" "  Config:    $CONFIG_FILE"
  fi
  
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
  
  print_with_separator "Kubernetes Cluster Creation Complete"
  
  # Display some helpful information
  format-echo "INFO" "To use this cluster, run:"
  
  case "$PROVIDER" in
    minikube)
      echo "  kubectl config use-context minikube-$CLUSTER_NAME"
      echo "  minikube -p $CLUSTER_NAME status"
      ;;
    kind)
      echo "  kubectl config use-context kind-$CLUSTER_NAME"
      echo "  kind get nodes --name $CLUSTER_NAME"
      ;;
    k3d)
      echo "  kubectl config use-context k3d-$CLUSTER_NAME"
      echo "  k3d cluster list"
      ;;
  esac
  
  format-echo "SUCCESS" "Cluster creation completed successfully."
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"
