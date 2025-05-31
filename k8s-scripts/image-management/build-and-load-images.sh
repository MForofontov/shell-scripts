#!/bin/bash
# build-and-load-images.sh
# Build Docker images and load them into a local Kubernetes cluster (minikube, kind, or k3d)

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

IMAGE_LIST=""
CLUSTER_NAME="k8s-cluster"
PROVIDER="minikube"
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Build and Load Images Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  Build Docker images and load them into a local Kubernetes cluster (minikube, kind, or k3d)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 -f <images.txt> [--provider <minikube|kind|k3d>] [--name <cluster>] [--log <file>]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-f, --file <FILE>\033[0m        File listing images to build (format: <image>:<tag> <dockerfile-dir>)"
  echo -e "  \033[1;33m--provider <PROVIDER>\033[0m    Cluster provider (minikube, kind, k3d) (default: minikube)"
  echo -e "  \033[1;33m--name <NAME>\033[0m           Cluster name (default: k8s-cluster)"
  echo -e "  \033[1;33m--log <FILE>\033[0m            Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -f images.txt --provider kind --name my-cluster"
  print_with_separator
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--file)
        IMAGE_LIST="$2"
        shift 2
        ;;
      --provider)
        PROVIDER="$2"
        shift 2
        ;;
      --name)
        CLUSTER_NAME="$2"
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

  if [[ -z "$IMAGE_LIST" ]]; then
    log_message "ERROR" "Image list file is required."
    usage
  fi
}

check_requirements() {
  log_message "INFO" "Checking requirements..."
  if ! command -v docker &>/dev/null; then
    log_message "ERROR" "docker not found. Please install Docker."
    exit 1
  fi
  case "$PROVIDER" in
    minikube)
      if ! command -v minikube &>/dev/null; then
        log_message "ERROR" "minikube not found. Please install minikube."
        exit 1
      fi
      ;;
    kind)
      if ! command -v kind &>/dev/null; then
        log_message "ERROR" "kind not found. Please install kind."
        exit 1
      fi
      ;;
    k3d)
      if ! command -v k3d &>/dev/null; then
        log_message "ERROR" "k3d not found. Please install k3d."
        exit 1
      fi
      ;;
    *)
      log_message "ERROR" "Unsupported provider: $PROVIDER"
      exit 1
      ;;
  esac
  log_message "SUCCESS" "All required tools are available."
}

build_and_load_images() {
  while read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    image=$(echo "$line" | awk '{print $1}')
    dir=$(echo "$line" | awk '{print $2}')
    if [[ -z "$image" || -z "$dir" ]]; then
      log_message "WARNING" "Skipping invalid line: $line"
      continue
    fi
    log_message "INFO" "Building image $image from directory $dir"
    docker build -t "$image" "$dir"
    log_message "SUCCESS" "Built image $image"

    case "$PROVIDER" in
      minikube)
        log_message "INFO" "Loading image $image into minikube ($CLUSTER_NAME)"
        minikube image load "$image" -p "$CLUSTER_NAME"
        ;;
      kind)
        log_message "INFO" "Loading image $image into kind ($CLUSTER_NAME)"
        kind load docker-image "$image" --name "$CLUSTER_NAME"
        ;;
      k3d)
        log_message "INFO" "Importing image $image into k3d ($CLUSTER_NAME)"
        k3d image import "$image" -c "$CLUSTER_NAME"
        ;;
    esac
    log_message "SUCCESS" "Loaded image $image into $PROVIDER"
  done < "$IMAGE_LIST"
}

main() {
  parse_args "$@"

  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Build and Load Images Script"
  log_message "INFO" "Starting build and load process..."
  log_message "INFO" "  Provider:     $PROVIDER"
  log_message "INFO" "  Cluster Name: $CLUSTER_NAME"
  log_message "INFO" "  Image List:   $IMAGE_LIST"

  check_requirements
  build_and_load_images

  print_with_separator "End of Build and Load Images Script"
  log_message "SUCCESS" "All images built and loaded successfully."
}

main "$@"