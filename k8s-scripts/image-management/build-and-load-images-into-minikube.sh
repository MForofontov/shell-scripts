#!/bin/bash
# push-images-to-minikube-registry.sh
# images.txt format: image-name:path/to/context
# Script to build and load images into a Minikube profile

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
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Load Images into Minikube Script"
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

log_message "INFO" "Building and loading images from $IMAGE_LIST into minikube profile: $PROFILE"
while IFS= read -r line || [ -n "$line" ]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  image_name=$(echo "$line" | cut -d: -f1)
  context_path=$(echo "$line" | cut -d: -f2-)
  log_message "INFO" "Building $image_name:latest from $context_path"
  docker build -t "$image_name:latest" "$context_path"
  log_message "INFO" "Loading $image_name:latest into minikube"
  minikube -p "$PROFILE" image load "$image_name:latest"
done < "$IMAGE_LIST"

log_message "SUCCESS" "All images built and loaded into minikube profile: $PROFILE"
log_message "INFO" "Use image references like: <image-name>:latest in your Kubernetes manifests."
log_message "INFO" "Images available in minikube profile: $PROFILE"
minikube -p "$PROFILE" image list