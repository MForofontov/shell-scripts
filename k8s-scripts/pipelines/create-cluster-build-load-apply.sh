#!/bin/bash
# create-cluster-build-load-apply.sh
# Script to create a cluster, build/load images, and apply manifests if files are given.

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"
CREATE_CLUSTER_SCRIPT="$SCRIPT_DIR/../cluster-management/cluster-state-management/create-cluster-local.sh"
BUILD_PUSH_SCRIPT="$SCRIPT_DIR/../image-management/build-and-push-images-to-dockerhub.sh"
APPLY_MANIFESTS_SCRIPT="$SCRIPT_DIR/../cluster-management/cluster-configuration-management/apply-k8s-configuration.sh"

if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
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
DOCKER_USERNAME=""
DOCKER_PAT=""

usage() {
  print_with_separator "Create Cluster, Build/Load Images, and Apply Manifests Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a Kubernetes cluster, builds/loads images, and applies manifests."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m          Cluster name (default: ${CLUSTER_NAME})"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m  Provider: minikube, kind, k3d (default: ${PROVIDER})"
  echo -e "  \033[1;33m-c, --nodes <COUNT>\033[0m        Number of nodes (default: ${NODE_COUNT})"
  echo -e "  \033[1;33m-v, --version <VERSION>\033[0m    Kubernetes version (default: ${K8S_VERSION})"
  echo -e "  \033[1;33m-f, --config <FILE>\033[0m        Path to provider config file"
  echo -e "  \033[1;33m-i, --images <FILE>\033[0m        Images file to build/load"
  echo -e "  \033[1;33m-m, --manifests <DIR>\033[0m      Manifests directory to apply"
  echo -e "  \033[1;33m--username <USERNAME>\033[0m      Docker registry username (required for Docker Hub push)"
  echo -e "  \033[1;33m--pat <PAT>\033[0m                Docker registry Personal Access Token (required for Docker Hub push)"
  echo -e "  \033[1;33m--log <FILE>\033[0m               Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     Show this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -n mycluster -i images.txt -m k8s --username myuser --pat mytoken --log pipeline.log"
  echo "  $0 --provider kind --nodes 2"
  print_with_separator "End of Create Cluster, Build/Load Images, and Apply Manifests Script"
  exit 1
}

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
      --username)
        DOCKER_USERNAME="$2"
        shift 2
        ;;
      --pat)
        DOCKER_PAT="$2"
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
}

main() {
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Create Cluster, Build/Load Images, and Apply Manifests Script"
  log_message "INFO" "Starting Create Cluster, Build/Load Images, and Apply Manifests Script..."

  # Build cluster creation command
  CREATE_CMD=("$CREATE_CLUSTER_SCRIPT" --name "$CLUSTER_NAME" --provider "$PROVIDER" --nodes "$NODE_COUNT" --version "$K8S_VERSION" --timeout "$WAIT_TIMEOUT")
  [ -n "$CONFIG_FILE" ] && CREATE_CMD+=(--config "$CONFIG_FILE")
  [ -n "$LOG_FILE" ] && CREATE_CMD+=(--log "$LOG_FILE")

  log_message "INFO" "Creating cluster: ${CLUSTER_NAME} with provider: ${PROVIDER}"
  "${CREATE_CMD[@]}"

  TMP_MANIFEST_DIR=""
  # If images file is provided, build and load images, and capture the temp manifest dir if manifests are used
  if [[ -n "$IMAGE_LIST" ]]; then
    if [ ! -f "$BUILD_PUSH_SCRIPT" ]; then
      log_message "ERROR" "Image build/load script not found: $BUILD_PUSH_SCRIPT"
      print_with_separator "End of Create Cluster, Build/Load Images, and Apply Manifests Script"
      exit 1
    fi
    BUILD_CMD=("$BUILD_PUSH_SCRIPT" -f "$IMAGE_LIST")
    [[ -n "$DOCKER_USERNAME" ]] && BUILD_CMD+=(--username "$DOCKER_USERNAME")
    [[ -n "$DOCKER_PAT" ]] && BUILD_CMD+=(--pat "$DOCKER_PAT")
    if [[ -n "$MANIFEST_ROOT" ]]; then
      BUILD_CMD+=(-m "$MANIFEST_ROOT")
    fi
    [ -n "$LOG_FILE" ] && BUILD_CMD+=(--log "$LOG_FILE")

    if [[ -n "$MANIFEST_ROOT" ]]; then
      TMP_MANIFEST_DIR=$(
        { "${BUILD_CMD[@]}" | tee /dev/tty; } | tail -n 1
      )
      TMP_MANIFEST_DIR=$(echo "$TMP_MANIFEST_DIR" | tail -n 1)
    else
      "${BUILD_CMD[@]}"
    fi
  fi

  # If manifests directory is provided, apply manifests from the temp dir if it exists, else from the original
  if [[ -n "$MANIFEST_ROOT" ]]; then
    if [ ! -f "$APPLY_MANIFESTS_SCRIPT" ]; then
      log_message "ERROR" "Apply manifests script not found: $APPLY_MANIFESTS_SCRIPT"
      print_with_separator "End of Create Cluster, Build/Load Images, and Apply Manifests Script"
      exit 1
    fi
    MANIFESTS_TO_APPLY="$MANIFEST_ROOT"
    if [[ -n "$TMP_MANIFEST_DIR" && -d "$TMP_MANIFEST_DIR" ]]; then
      MANIFESTS_TO_APPLY="$TMP_MANIFEST_DIR"
    fi
    APPLY_CMD=("$APPLY_MANIFESTS_SCRIPT" --manifests "$MANIFESTS_TO_APPLY")
    [ -n "$LOG_FILE" ] && APPLY_CMD+=(--log "$LOG_FILE")
    log_message "INFO" "Applying manifests from $MANIFESTS_TO_APPLY"
    "${APPLY_CMD[@]}"
    # Clean up the temp manifest directory if it was used
    if [[ -n "$TMP_MANIFEST_DIR" && -d "$TMP_MANIFEST_DIR" ]]; then
      log_message "INFO" "Deleting temporary manifest directory $TMP_MANIFEST_DIR"
      rm -rf "$TMP_MANIFEST_DIR"
    fi
  fi

  log_message "SUCCESS" "Cluster creation, image loading, and manifest application complete."
  print_with_separator "End of Create Cluster, Build/Load Images, and Apply Manifests Script"
}

main "$@"