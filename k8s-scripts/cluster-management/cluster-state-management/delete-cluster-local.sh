#!/bin/bash
# delete-cluster.sh
# Script to delete Kubernetes clusters from various providers

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

# Default values
CLUSTER_NAME=""
PROVIDER="minikube"  # Default provider is minikube
LOG_FILE="/dev/null"
FORCE=false

# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Deletion Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script deletes Kubernetes clusters created with various providers (minikube, kind, k3d)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-n, --name <NAME>\033[0m          (Required) Cluster name to delete"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m  (Optional) Provider to use (minikube, kind, k3d) (default: ${PROVIDER})"
  echo -e "  \033[1;33m-f, --force\033[0m                (Optional) Force deletion without confirmation"
  echo -e "  \033[1;33m--log <FILE>\033[0m               (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster"
  echo "  $0 --name test-cluster --provider kind"
  echo "  $0 --name dev-cluster --provider k3d --force"
  echo "  $0 --name my-cluster --log delete.log"
  print_with_separator
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required tools
check_requirements() {
  log_message "INFO" "Checking requirements..."
  
  case "$PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        log_message "ERROR" "minikube not found. Please install it first:"
        echo "https://minikube.sigs.k8s.io/docs/start/"
        exit 1
      fi
      ;;
    kind)
      if ! command_exists kind; then
        log_message "ERROR" "kind not found. Please install it first:"
        echo "https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        log_message "ERROR" "k3d not found. Please install it first:"
        echo "https://k3d.io/#installation"
        exit 1
      fi
      ;;
  esac

  log_message "SUCCESS" "Required tools are available."
}

# Check if cluster exists
check_cluster_exists() {
  log_message "INFO" "Checking if cluster exists..."
  
  local cluster_exists=false
  
  case "$PROVIDER" in
    minikube)
      if minikube profile list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        cluster_exists=true
      fi
      ;;
    kind)
      if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        cluster_exists=true
      fi
      ;;
    k3d)
      if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        cluster_exists=true
      fi
      ;;
  esac
  
  if $cluster_exists; then
    log_message "SUCCESS" "Cluster '${CLUSTER_NAME}' found."
    return 0
  else
    log_message "ERROR" "Cluster '${CLUSTER_NAME}' not found for provider ${PROVIDER}."
    exit 1
  fi
}

# Delete cluster with minikube
delete_minikube_cluster() {
  log_message "INFO" "Deleting minikube cluster '${CLUSTER_NAME}'..."
  
  if minikube delete -p ${CLUSTER_NAME}; then
    log_message "SUCCESS" "minikube cluster '${CLUSTER_NAME}' deleted successfully."
  else
    log_message "ERROR" "Failed to delete minikube cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

# Delete cluster with kind
delete_kind_cluster() {
  log_message "INFO" "Deleting kind cluster '${CLUSTER_NAME}'..."
  
  if kind delete cluster --name ${CLUSTER_NAME}; then
    log_message "SUCCESS" "kind cluster '${CLUSTER_NAME}' deleted successfully."
  else
    log_message "ERROR" "Failed to delete kind cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

# Delete cluster with k3d
delete_k3d_cluster() {
  log_message "INFO" "Deleting k3d cluster '${CLUSTER_NAME}'..."
  
  if k3d cluster delete ${CLUSTER_NAME}; then
    log_message "SUCCESS" "k3d cluster '${CLUSTER_NAME}' deleted successfully."
  else
    log_message "ERROR" "Failed to delete k3d cluster '${CLUSTER_NAME}'."
    exit 1
  fi
}

# Confirm deletion with user
confirm_deletion() {
  if [ "$FORCE" = true ]; then
    return 0
  fi
  
  echo -e "\033[1;33mWarning:\033[0m You are about to delete the cluster '${CLUSTER_NAME}' (provider: ${PROVIDER})."
  read -p "Are you sure you want to continue? [y/N]: " answer
  
  case "$answer" in
    [Yy]|[Yy][Ee][Ss])
      return 0
      ;;
    *)
      log_message "INFO" "Deletion canceled by user."
      exit 0
      ;;
  esac
}

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
      -f|--force)
        FORCE=true
        shift
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
  
  # Check if cluster name is provided
  if [ -z "$CLUSTER_NAME" ]; then
    log_message "ERROR" "Cluster name is required. Use -n or --name to specify."
    usage
  fi
}

# Main function
main() {
  # Parse arguments
  parse_args "$@"
  
  print_with_separator "Kubernetes Cluster Deletion Script"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  log_message "INFO" "Starting Kubernetes cluster deletion..."
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Cluster Name: $CLUSTER_NAME"
  log_message "INFO" "  Provider:     $PROVIDER"
  log_message "INFO" "  Force Delete: $FORCE"
  
  # Check requirements
  check_requirements
  
  # Check if the cluster exists
  check_cluster_exists
  
  # Confirm deletion with user
  confirm_deletion
  
  # Delete the cluster based on the provider
  case "$PROVIDER" in
    minikube)
      delete_minikube_cluster
      ;;
    kind)
      delete_kind_cluster
      ;;
    k3d)
      delete_k3d_cluster
      ;;
  esac
  
  print_with_separator "End of Kubernetes Cluster Deletion"
  log_message "SUCCESS" "Kubernetes cluster deletion completed successfully."
}

# Run the main function
main "$@"