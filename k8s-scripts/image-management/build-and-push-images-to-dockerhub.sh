#!/bin/bash
# build-and-push-images-to-dockerhub.sh
# Script to build and push images to Docker Hub (or any Docker registry) using username and PAT,
# and create a Kubernetes docker-registry secret for pulling images.

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

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

IMAGE_LIST="images.txt"
MANIFEST_DIR=""
LOG_FILE="/dev/null"
DOCKER_USERNAME=""
DOCKER_PAT=""
EMAIL=""
PROJECT_NAME=""

usage() {
  print_with_separator "Build and Push Images to Docker Registry Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script builds Docker images, pushes them to Docker Hub (or any Docker registry),"
  echo "  and creates a Kubernetes docker-registry secret for pulling images."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  build-and-push-images-to-dockerhub.sh -u <docker-username> -p <docker-pat> -e <email> -j <project-name> -f <images.txt> -m <manifest-dir> [--log <log_file>]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-u, --username <USERNAME>\033[0m    Docker registry username (required)"
  echo -e "  \033[1;33m-p, --pat <PAT>\033[0m             Docker registry Personal Access Token (required)"
  echo -e "  \033[1;33m-e, --email <EMAIL>\033[0m         Docker Hub email (required for secret)"
  echo -e "  \033[1;33m-j, --project <PROJECT>\033[0m     Kubernetes project/namespace (required for secret)"
  echo -e "  \033[1;33m-f, --file <FILE>\033[0m           Path to images.txt file (default: images.txt)"
  echo -e "  \033[1;33m-m, --manifests <DIR>\033[0m       Path to manifest directory (optional)"
  echo -e "  \033[1;33m--log <FILE>\033[0m                Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      Show this help message"
  print_with_separator "End of Build and Push Images to Docker Registry Script"
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u|--username)
        DOCKER_USERNAME="$2"
        shift 2
        ;;
      -p|--pat)
        DOCKER_PAT="$2"
        shift 2
        ;;
      -e|--email)
        EMAIL="$2"
        shift 2
        ;;
      -j|--project)
        PROJECT_NAME="$2"
        shift 2
        ;;
      -f|--file)
        IMAGE_LIST="$2"
        shift 2
        ;;
      -m|--manifests)
        MANIFEST_DIR="$2"
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

  if [[ -z "$DOCKER_USERNAME" || -z "$DOCKER_PAT" || -z "$EMAIL" || -z "$PROJECT_NAME" ]]; then
    log_message "ERROR" "Docker username, PAT, email, and project name are required."
    usage
  fi
}

build_and_push_images() {
  local docker_username="$1"
  local image_list="$2"
  while IFS= read -r line || [ -n "$line" ]; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    image_name=$(echo "$line" | cut -d: -f1)
    context_path=$(echo "$line" | cut -d: -f2-)
    registry_image="$docker_username/$image_name:latest"
    log_message "INFO" "Building $registry_image from $context_path"
    if ! docker build -t "$registry_image" "$context_path"; then
      log_message "ERROR" "Failed to build $registry_image"
      exit 1
    fi
    log_message "INFO" "Pushing $registry_image to Docker registry"
    if ! docker push "$registry_image"; then
      log_message "ERROR" "Failed to push $registry_image"
      exit 1
    fi
  done < "$image_list"
}

prepare_manifests() {
  local manifest_dir="$1"
  local docker_username="$2"
  TMP_MANIFEST_DIR=$(mktemp -d)
  log_message "INFO" "Copying manifests from $manifest_dir to temporary directory $TMP_MANIFEST_DIR"
  cp "$manifest_dir"/*.yaml "$TMP_MANIFEST_DIR"/
  log_message "INFO" "Replacing <DOCKER_USERNAME> with $docker_username in all YAMLs in $TMP_MANIFEST_DIR"
  for file in "$TMP_MANIFEST_DIR"/*.yaml; do
    sed -i '' "s|<DOCKER_USERNAME>|$docker_username|g" "$file"
  done
  log_message "SUCCESS" "Replaced <DOCKER_USERNAME> in all deployment YAMLs in $TMP_MANIFEST_DIR."
  echo "$TMP_MANIFEST_DIR"
}

create_k8s_secret() {
  local username="$1"
  local pat="$2"
  local email="$3"
  local project="$4"
  log_message "INFO" "Creating Docker registry secret in namespace $project"
  kubectl create secret docker-registry regcred \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username="$username" \
    --docker-password="$pat" \
    --docker-email="$email" \
    -n "$project" --dry-run=client -o yaml | kubectl apply -f -
  log_message "SUCCESS" "Docker registry secret 'regcred' created or updated in namespace $project"
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

  print_with_separator "Build and Push Images to Docker Registry Script"

  if [[ ! -f "$IMAGE_LIST" ]]; then
    log_message "ERROR" "Image list file not found: $IMAGE_LIST"
    exit 1
  fi

  log_message "INFO" "Logging in to Docker registry as $DOCKER_USERNAME"
  echo "$DOCKER_PAT" | docker login --username "$DOCKER_USERNAME" --password-stdin

  log_message "INFO" "Building and pushing images from $IMAGE_LIST to Docker registry"
  build_and_push_images "$DOCKER_USERNAME" "$IMAGE_LIST"

  log_message "SUCCESS" "All images built and pushed to Docker registry as $DOCKER_USERNAME"
  log_message "INFO" "Use image references like: $DOCKER_USERNAME/<image-name>:latest in your Kubernetes manifests."

  # Create Kubernetes Docker registry secret
  create_k8s_secret "$DOCKER_USERNAME" "$DOCKER_PAT" "$EMAIL" "$PROJECT_NAME"

  # If manifest directory is provided, copy to tmp, replace <DOCKER_USERNAME>, and output the tmp path
  if [[ -n "$MANIFEST_DIR" && -d "$MANIFEST_DIR" ]]; then
    TMP_MANIFEST_DIR=$(prepare_manifests "$MANIFEST_DIR" "$DOCKER_USERNAME")
    echo "$TMP_MANIFEST_DIR"
  fi

  print_with_separator "End of Build and Push Images to Docker Registry Script"
}

main "$@"