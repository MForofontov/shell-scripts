#!/bin/bash
# Script: push-images-to-minikube-registry.sh
# Usage: ./push-images-to-minikube-registry.sh -n <minikube-profile> -f <images.txt>
# images.txt format: image-name:path/to/context

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/print-functions/print-with-separator.sh"

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

PROFILE="minikube"
IMAGE_LIST="images.txt"

usage() {
  print_with_separator "Push Images to Minikube Registry Script"
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 -n <minikube-profile> -f <images.txt>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-n, --name <PROFILE>\033[0m    Minikube profile name (default: minikube)"
  echo -e "  \033[1;33m-f, --file <FILE>\033[0m       Path to images.txt file (default: images.txt)"
  echo -e "  \033[1;33m--help\033[0m                  Show this help message"
  print_with_separator
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      PROFILE="$2"
      shift 2
      ;;
    -f|--file)
      IMAGE_LIST="$2"
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

if [[ ! -f "$IMAGE_LIST" ]]; then
  log_message "ERROR" "Image list file not found: $IMAGE_LIST"
  exit 1
fi

log_message "INFO" "Enabling minikube registry addon for profile: $PROFILE"
minikube -p "$PROFILE" addons enable registry

log_message "INFO" "Waiting for registry service to be ready..."
until kubectl -n kube-system get svc registry &>/dev/null; do sleep 2; done

REGISTRY_PORT=$(kubectl -n kube-system get svc registry -o jsonpath='{.spec.ports[0].nodePort}')
REGISTRY="localhost:$REGISTRY_PORT"
log_message "INFO" "Using registry at $REGISTRY"

log_message "INFO" "Building and pushing images from $IMAGE_LIST"
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  image_name=$(echo "$line" | cut -d: -f1)
  context_path=$(echo "$line" | cut -d: -f2-)
  registry_image="$REGISTRY/$image_name:latest"
  log_message "INFO" "Building $registry_image from $context_path"
  docker build -t "$registry_image" "$context_path"
  log_message "INFO" "Pushing $registry_image"
  docker push "$registry_image"
done < "$IMAGE_LIST"

log_message "SUCCESS" "All images built and pushed to $REGISTRY"
log_message "INFO" "Use image references like: $REGISTRY/<your-image>:latest in your Kubernetes manifests."