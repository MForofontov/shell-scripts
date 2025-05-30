#!/bin/bash
# create-cluster-build-load-apply.sh
# Create cluster, build/load images, and apply manifests if files are given

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"
CREATE_CLUSTER_SCRIPT="$SCRIPT_DIR/cluster-management/cluster-state-management/create-cluster-local.sh"
BUILD_LOAD_SCRIPT="$SCRIPT_DIR/image-management/build-and-load-images-into-minikube.sh"
APPLY_MANIFESTS_SCRIPT="$SCRIPT_DIR/apply-k8s-configuration.sh"

if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
fi

CLUSTER_NAME="k8s-cluster"
PROVIDER="minikube"
NODE_COUNT=1
K8S_VERSION="latest"
CONFIG_FILE=""
WAIT_TIMEOUT=300
LOG_FILE=""
IMAGE_LIST=""
MANIFEST_ROOT=""

usage() {
  print_with_separator "Create Cluster, Build/Load Images, and Apply Manifests Script"
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m          Cluster name (default: ${CLUSTER_NAME})"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m  Provider: minikube, kind, k3d (default: ${PROVIDER})"
  echo -e "  \033[1;33m-c, --nodes <COUNT>\033[0m        Number of nodes (default: ${NODE_COUNT})"
  echo -e "  \033[1;33m-v, --version <VERSION>\033[0m    Kubernetes version (default: ${K8S_VERSION})"
  echo -e "  \033[1;33m-f, --config <FILE>\033[0m        Path to provider config file"
  echo -e "  \033[1;33m--images <FILE>\033[0m            Path to images.txt file to build/load images"
  echo -e "  \033[1;33m--manifests <DIR>\033[0m          Root directory for manifests to apply"
  echo -e "  \033[1;33m--log <FILE>\033[0m               Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     Show this help message"
  print_with_separator
  exit 1
}

# Parse arguments
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
    --images)
      IMAGE_LIST="$2"
      shift 2
      ;;
    --manifests)
      MANIFEST_ROOT="$2"
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
      log_message "ERROR" "Unknown option: $1"
      usage
      ;;
  esac
done

# Build cluster creation command
CREATE_CMD=("$CREATE_CLUSTER_SCRIPT" --name "$CLUSTER_NAME" --provider "$PROVIDER" --nodes "$NODE_COUNT" --version "$K8S_VERSION" --timeout "$WAIT_TIMEOUT")
[ -n "$CONFIG_FILE" ] && CREATE_CMD+=(--config "$CONFIG_FILE")
[ -n "$LOG_FILE" ] && CREATE_CMD+=(--log "$LOG_FILE")

log_message "INFO" "Creating cluster: ${CLUSTER_NAME} with provider: ${PROVIDER}"
"${CREATE_CMD[@]}"

# If images file is provided, build and load images
if [[ -n "$IMAGE_LIST" ]]; then
  if [ ! -f "$BUILD_LOAD_SCRIPT" ]; then
    log_message "ERROR" "Image build/load script not found: $BUILD_LOAD_SCRIPT"
    exit 1
  fi
  BUILD_CMD=("$BUILD_LOAD_SCRIPT" -n "$CLUSTER_NAME" -f "$IMAGE_LIST")
  [ -n "$LOG_FILE" ] && BUILD_CMD+=(--log "$LOG_FILE")
  log_message "INFO" "Building and loading images from $IMAGE_LIST into minikube profile: $CLUSTER_NAME"
  "${BUILD_CMD[@]}"
fi

# If manifests directory is provided, apply manifests
if [[ -n "$MANIFEST_ROOT" ]]; then
  if [ ! -f "$APPLY_MANIFESTS_SCRIPT" ]; then
    log_message "ERROR" "Apply manifests script not found: $APPLY_MANIFESTS_SCRIPT"
    exit 1
  fi
  APPLY_CMD=("$APPLY_MANIFESTS_SCRIPT" --manifests "$MANIFEST_ROOT")
  [ -n "$LOG_FILE" ] && APPLY_CMD+=(--log "$LOG_FILE")
  log_message "INFO" "Applying manifests from $MANIFEST_ROOT"
  "${APPLY_CMD[@]}"
fi

log_message "SUCCESS" "Cluster creation, image loading, and manifest application complete."