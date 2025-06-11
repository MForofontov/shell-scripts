#!/bin/bash
# create-cluster-build-load-apply.sh
# Script to create a cluster, build/load images into the cluster, and apply manifests if files are given.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"
BUILD_LOAD_SCRIPT="$SCRIPT_DIR/../image-management/build-and-load-images.sh"
APPLY_MANIFESTS_SCRIPT="$SCRIPT_DIR/../cluster-management/cluster-configuration-management/apply-k8s-configuration.sh"
CREATE_CLUSTER_SCRIPT="$SCRIPT_DIR/../cluster-management/cluster-state-management/create-cluster-local.sh"
REGISTRY_SCRIPT="$SCRIPT_DIR/../image-management/k8s-registry-pipeline.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
CLUSTER_NAME="k8s-cluster"
PROVIDER="minikube"
NODE_COUNT=1
K8S_VERSION="latest"
CONFIG_FILE=""
WAIT_TIMEOUT=300
LOG_FILE=""
IMAGE_LIST=""
MANIFEST_ROOT=""
USE_REGISTRY=false
REGISTRY_PORT=5001
REGISTRY_NAME="local-registry"
REGISTRY_HOST="localhost"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Kubernetes Cluster Build/Load/Apply Tool"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a Kubernetes cluster, optionally builds and loads images into the cluster,"
  echo "  and optionally applies manifests."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m           (Optional) Cluster name (default: ${CLUSTER_NAME})"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m   (Optional) Provider: minikube, kind, k3d (default: ${PROVIDER})"
  echo -e "  \033[1;33m-c, --nodes <COUNT>\033[0m         (Optional) Number of nodes (default: ${NODE_COUNT})"
  echo -e "  \033[1;33m-v, --version <VERSION>\033[0m     (Optional) Kubernetes version (default: ${K8S_VERSION})"
  echo -e "  \033[1;33m-f, --config <FILE>\033[0m         (Optional) Path to provider config file"
  echo -e "  \033[1;36m-i, --images <FILE>\033[0m         (Required for image build/load) Images file to build/load"
  echo -e "  \033[1;36m-m, --manifests <DIR>\033[0m       (Required for manifest apply) Manifests directory to apply"
  echo -e "  \033[1;33m--use-registry\033[0m              (Optional) Use local registry for images (auto-enabled for multi-node)"
  echo -e "  \033[1;33m--registry-port <PORT>\033[0m      (Optional) Port for local registry (default: ${REGISTRY_PORT})"
  echo -e "  \033[1;33m--registry-name <NAME>\033[0m      (Optional) Name for local registry (default: ${REGISTRY_NAME})"
  echo -e "  \033[1;33m--registry-host <HOST>\033[0m      (Optional) Host for registry (default: ${REGISTRY_HOST})"
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Show this help message"
  echo
  echo -e "\033[1;34mNotes:\033[0m"
  echo "  - All options are optional unless you want to build/load images or apply manifests."
  echo "  - \033[1;36m-i, --images\033[0m is required only if you want to build/load images."
  echo "  - \033[1;36m-m, --manifests\033[0m is required only if you want to apply manifests."
  echo "  - For multi-node clusters (NODE_COUNT > 1), a registry is automatically enabled."
  echo "  - For single-node clusters, direct image loading is used by default (faster)."
  echo "  - Use --use-registry with single-node clusters if you specifically need registry functionality."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -n mycluster -i images.txt -m k8s --log pipeline.log"
  echo "  $0 --provider kind --nodes 3 -i images.txt"
  echo "  $0 --provider minikube --use-registry -i images.txt"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
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
      -i|--images)
        IMAGE_LIST="$2"
        shift 2
        ;;
      -m|--manifests)
        MANIFEST_ROOT="$2"
        shift 2
        ;;
      --use-registry)
        USE_REGISTRY=true
        shift
        ;;
      --registry-port)
        REGISTRY_PORT="$2"
        shift 2
        ;;
      --registry-name)
        REGISTRY_NAME="$2"
        shift 2
        ;;
      --registry-host)
        REGISTRY_HOST="$2"
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
}

#=====================================================================
# CLUSTER MANAGEMENT
#=====================================================================
#---------------------------------------------------------------------
# CREATE A CLUSTER USING CREATE-CLUSTER-LOCAL.SH
#---------------------------------------------------------------------
create_cluster() {
  print_with_separator "Creating Kubernetes Cluster"
  format-echo "INFO" "Creating cluster: $CLUSTER_NAME with provider: $PROVIDER using create-cluster-local.sh"

  if [ ! -f "$CREATE_CLUSTER_SCRIPT" ]; then
    format-echo "ERROR" "Create cluster script not found: $CREATE_CLUSTER_SCRIPT"
    exit 1
  fi

  # Prepare arguments for create-cluster-local.sh
  local cluster_args=(
    "-n" "$CLUSTER_NAME"
    "-p" "$PROVIDER"
    "-c" "$NODE_COUNT"
    "-v" "$K8S_VERSION"
  )

  # Add config file if specified
  if [[ -n "$CONFIG_FILE" ]]; then
    cluster_args+=("-f" "$CONFIG_FILE")
  fi

  # Add log file if specified
  if [[ -n "$LOG_FILE" ]]; then
    cluster_args+=("--log" "$LOG_FILE")
  fi

  # Execute create-cluster-local.sh with the prepared arguments
  if ! "$CREATE_CLUSTER_SCRIPT" "${cluster_args[@]}"; then
    format-echo "ERROR" "Failed to create $PROVIDER cluster '$CLUSTER_NAME'"
    exit 1
  fi

  format-echo "SUCCESS" "Cluster $CLUSTER_NAME created successfully."
}

#=====================================================================
# IMAGE MANAGEMENT
#=====================================================================
#---------------------------------------------------------------------
# SETUP REGISTRY AND PUSH IMAGES
#---------------------------------------------------------------------
setup_registry_and_push_images() {
  print_with_separator "Setting Up Registry and Pushing Images"
  format-echo "INFO" "Setting up registry and pushing images"

  if [ ! -f "$REGISTRY_SCRIPT" ]; then
    format-echo "ERROR" "Registry script not found: $REGISTRY_SCRIPT"
    exit 1
  fi

  # Prepare arguments for registry script - simplified for updated version
  local registry_args=(
    "-f" "$IMAGE_LIST"
    "-p" "$REGISTRY_PORT"
    "-n" "$REGISTRY_NAME"
    "-h" "$REGISTRY_HOST"
  )

  # Add log file if specified
  if [[ -n "$LOG_FILE" ]]; then
    registry_args+=("--log" "$LOG_FILE")
  fi

  # Execute registry script with the prepared arguments
  if ! "$REGISTRY_SCRIPT" "${registry_args[@]}"; then
    format-echo "ERROR" "Failed to setup registry and push images"
    exit 1
  fi

  format-echo "SUCCESS" "Registry setup and images pushed successfully."
  
  # Set the appropriate registry host for different providers and OS
  if [[ "$PROVIDER" == "minikube" && "$OSTYPE" == "darwin"* ]]; then
    format-echo "INFO" "For MacOS with minikube, deployments should reference: host.docker.internal:$REGISTRY_PORT/<image>"
    REGISTRY_HOST_INSTRUCTION="host.docker.internal:$REGISTRY_PORT"
  else
    format-echo "INFO" "Deployments should reference: $REGISTRY_HOST:$REGISTRY_PORT/<image>"
    REGISTRY_HOST_INSTRUCTION="$REGISTRY_HOST:$REGISTRY_PORT"
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Auto-enable registry for multi-node clusters with images
  if [[ -n "$IMAGE_LIST" && "$NODE_COUNT" -gt 1 && "$USE_REGISTRY" != true ]]; then
    USE_REGISTRY=true
    format-echo "INFO" "Multi-node cluster detected - automatically enabling registry"
  fi

  #---------------------------------------------------------------------
  # LOG CONFIGURATION
  #---------------------------------------------------------------------
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Create Cluster, Build/Load Images, and Apply Manifests Script"
  format-echo "INFO" "Starting Create Cluster, Build/Load Images, and Apply Manifests Script..."

  #---------------------------------------------------------------------
  # DISPLAY CONFIGURATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Cluster Name:    $CLUSTER_NAME"
  format-echo "INFO" "  Provider:        $PROVIDER"
  format-echo "INFO" "  Node Count:      $NODE_COUNT"
  format-echo "INFO" "  K8s Version:     $K8S_VERSION"
  format-echo "INFO" "  Config File:     ${CONFIG_FILE:-None}"
  
  if [[ -n "$IMAGE_LIST" ]]; then
    format-echo "INFO" "  Images File:     $IMAGE_LIST"
    if [[ "$USE_REGISTRY" = true ]]; then
      format-echo "INFO" "  Registry:        Enabled"
      format-echo "INFO" "  Registry Name:   $REGISTRY_NAME"
      format-echo "INFO" "  Registry Port:   $REGISTRY_PORT"
      format-echo "INFO" "  Registry Host:   $REGISTRY_HOST"
    else
      format-echo "INFO" "  Registry:        Disabled (using direct load)"
    fi
  fi
  
  if [[ -n "$MANIFEST_ROOT" ]]; then
    format-echo "INFO" "  Manifests Dir:   $MANIFEST_ROOT"
  fi

  #---------------------------------------------------------------------
  # CLUSTER CREATION
  #---------------------------------------------------------------------
  create_cluster

  #---------------------------------------------------------------------
  # IMAGE BUILDING AND LOADING
  #---------------------------------------------------------------------
  # Track registry host instruction for later output
  REGISTRY_HOST_INSTRUCTION=""
  
  if [[ -n "$IMAGE_LIST" ]]; then
    if [[ "$USE_REGISTRY" = true ]]; then
      # Use registry approach for multi-node or when explicitly requested
      setup_registry_and_push_images
    else
      # Use direct loading approach for single-node (more efficient)
      if [ ! -f "$BUILD_LOAD_SCRIPT" ]; then
        format-echo "ERROR" "Image build/load script not found: $BUILD_LOAD_SCRIPT"
        exit 1
      fi
      
      format-echo "INFO" "Building and loading images directly (single-node cluster)"
      
      # Prepare arguments for build-and-load-images.sh
      local build_args=(
        "-f" "$IMAGE_LIST"
        "--provider" "$PROVIDER"
        "--name" "$CLUSTER_NAME"
      )
      
      # Add log file if specified
      if [[ -n "$LOG_FILE" ]]; then
        build_args+=("--log" "$LOG_FILE")
      fi
      
      # Execute build-and-load-images.sh with the prepared arguments
      if ! "$BUILD_LOAD_SCRIPT" "${build_args[@]}"; then
        format-echo "ERROR" "Failed to build and load images"
        exit 1
      fi
      
      format-echo "SUCCESS" "Images built and loaded successfully."
    fi
  fi

  #---------------------------------------------------------------------
  # MANIFEST APPLICATION
  #---------------------------------------------------------------------
  if [[ -n "$MANIFEST_ROOT" ]]; then
    if [ ! -f "$APPLY_MANIFESTS_SCRIPT" ]; then
      format-echo "ERROR" "Apply manifests script not found: $APPLY_MANIFESTS_SCRIPT"
      exit 1
    fi
    
    format-echo "INFO" "Applying manifests from $MANIFEST_ROOT"
    
    # Prepare arguments for apply-k8s-configuration.sh
    local apply_args=("--manifests" "$MANIFEST_ROOT")
    
    # Add log file if specified
    if [[ -n "$LOG_FILE" ]]; then
      apply_args+=("--log" "$LOG_FILE")
    fi
    
    # Execute apply-k8s-configuration.sh with the prepared arguments
    if ! "$APPLY_MANIFESTS_SCRIPT" "${apply_args[@]}"; then
      format-echo "ERROR" "Failed to apply manifests"
      exit 1
    fi
    
    format-echo "SUCCESS" "Manifests applied successfully."
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "Cluster creation, image build/load, and manifest application complete."
  
  # Print summary information
  echo -e "\033[1;32mCluster Information:\033[0m"
  echo "  Cluster Name: $CLUSTER_NAME"
  echo "  Provider: $PROVIDER"
  echo "  Node Count: $NODE_COUNT"
  
  # Display context switch command
  case "$PROVIDER" in
    minikube)
      echo "  Switch Context: kubectl config use-context minikube-$CLUSTER_NAME"
      ;;
    kind)
      echo "  Switch Context: kubectl config use-context kind-$CLUSTER_NAME"
      ;;
    k3d)
      echo "  Switch Context: kubectl config use-context k3d-$CLUSTER_NAME"
      ;;
  esac
  
  # Display registry information whenever registry is used
  if [[ "$USE_REGISTRY" = true && -n "$IMAGE_LIST" ]]; then
    echo -e "\033[1;32mRegistry Information:\033[0m"
    echo "  Registry Name: $REGISTRY_NAME"
    echo "  Registry Port: $REGISTRY_PORT"
    
    # Show image reference format if we have it
    if [[ -n "$REGISTRY_HOST_INSTRUCTION" ]]; then
      echo -e "\033[1;33mIMPORTANT:\033[0m In your deployments, reference images as:"
      echo "  $REGISTRY_HOST_INSTRUCTION/<image-name>:<tag>"
      
      # Add note about imagePullSecrets for minikube
      if [[ "$PROVIDER" == "minikube" ]]; then
        echo "  Add to deployments:"
        echo "  spec:"
        echo "    imagePullSecrets:"
        echo "    - name: regcred"
      fi
    fi
  fi
  
  print_with_separator "End of Create Cluster, Build/Load Images, and Apply Manifests Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"