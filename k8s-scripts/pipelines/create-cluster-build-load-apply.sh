#!/bin/bash
# create-cluster-build-load-apply.sh
# Script to create a cluster, build/load images into the cluster, and apply manifests if files are given.

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"
BUILD_LOAD_SCRIPT="$SCRIPT_DIR/../image-management/build-and-load-images.sh"
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
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Show this help message"
  echo
  echo -e "\033[1;34mNotes:\033[0m"
  echo "  - All options are optional unless you want to build/load images or apply manifests."
  echo "  - \033[1;36m-i, --images\033[0m is required only if you want to build/load images."
  echo "  - \033[1;36m-m, --manifests\033[0m is required only if you want to apply manifests."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -n mycluster -i images.txt -m k8s --log pipeline.log"
  echo "  $0 --provider kind --nodes 2"
  print_with_separator
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

create_cluster() {
  print_with_separator "Creating Kubernetes Cluster"
  log_message "INFO" "Creating cluster: $CLUSTER_NAME with provider: $PROVIDER"

  case "$PROVIDER" in
    minikube)
      minikube start -p "$CLUSTER_NAME" --nodes="$NODE_COUNT" --kubernetes-version="$K8S_VERSION" ${CONFIG_FILE:+--config "$CONFIG_FILE"}
      ;;
    kind)
      if [[ -n "$CONFIG_FILE" ]]; then
        kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE" --image "kindest/node:$K8S_VERSION"
      else
        kind create cluster --name "$CLUSTER_NAME" --image "kindest/node:$K8S_VERSION"
      fi
      ;;
    k3d)
      if [[ -n "$CONFIG_FILE" ]]; then
        k3d cluster create "$CLUSTER_NAME" --config "$CONFIG_FILE"
      else
        k3d cluster create "$CLUSTER_NAME" --servers "$NODE_COUNT"
      fi
      ;;
    *)
      log_message "ERROR" "Unsupported provider: $PROVIDER"
      exit 1
      ;;
  esac
  log_message "SUCCESS" "Cluster $CLUSTER_NAME created."
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

  create_cluster

  # Build and load images into the cluster only if an image list is provided and NODE_COUNT is 1
  if [[ -n "$IMAGE_LIST" && "$NODE_COUNT" -eq 1 ]]; then
    if [ ! -f "$BUILD_LOAD_SCRIPT" ]; then
      log_message "ERROR" "Image build/load script not found: $BUILD_LOAD_SCRIPT"
      print_with_separator "End of Create Cluster, Build/Load Images, and Apply Manifests Script"
      exit 1
    fi
    BUILD_CMD=("$BUILD_LOAD_SCRIPT" -f "$IMAGE_LIST" --provider "$PROVIDER" --name "$CLUSTER_NAME")
    [ -n "$LOG_FILE" ] && BUILD_CMD+=(--log "$LOG_FILE")
    log_message "INFO" "Building and loading images from $IMAGE_LIST (single-node cluster)"
    "${BUILD_CMD[@]}"
  elif [[ -n "$IMAGE_LIST" && "$NODE_COUNT" -ne 1 ]]; then
    log_message "WARNING" "Skipping build-and-load-images.sh: cluster has more than one node. Use a registry for multi-node clusters."
  fi

  # If manifests directory is provided, apply manifests
  if [[ -n "$MANIFEST_ROOT" ]]; then
    if [ ! -f "$APPLY_MANIFESTS_SCRIPT" ]; then
      log_message "ERROR" "Apply manifests script not found: $APPLY_MANIFESTS_SCRIPT"
      print_with_separator "End of Create Cluster, Build/Load Images, and Apply Manifests Script"
      exit 1
    fi
    APPLY_CMD=("$APPLY_MANIFESTS_SCRIPT" --manifests "$MANIFEST_ROOT")
    [ -n "$LOG_FILE" ] && APPLY_CMD+=(--log "$LOG_FILE")
    log_message "INFO" "Applying manifests from $MANIFEST_ROOT"
    "${APPLY_CMD[@]}"
  fi

  log_message "SUCCESS" "Cluster creation, image build/load, and manifest application complete."
  print_with_separator "End of Create Cluster, Build/Load Images, and Apply Manifests Script"
}

main "$@"