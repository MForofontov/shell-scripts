#!/bin/bash
# build-and-push-images-to-dockerhub.sh
# Script to build and push images to Docker Hub (or any Docker registry) using username and PAT,
# and create a Kubernetes docker-registry secret for pulling images.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

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

#=====================================================================
# DEFAULT VALUES
#=====================================================================
IMAGE_LIST="images.txt"   # Default path to the image list file
MANIFEST_DIR=""           # Path to Kubernetes manifest directory (empty by default)
LOG_FILE="/dev/null"      # Default log file location
DOCKER_USERNAME=""        # Docker registry username
DOCKER_PAT=""             # Docker Personal Access Token
EMAIL=""                  # Email for Docker registry
PROJECT_NAME=""           # Kubernetes namespace for the secret

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Build and Push Images to Docker Registry Script"

  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script builds Docker images, pushes them to Docker Hub (or any Docker registry),"
  echo "  and creates a Kubernetes docker-registry secret for pulling images."
  echo

  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-u, --username <USERNAME>\033[0m   (Required) Docker registry username"
  echo -e "  \033[1;36m-p, --pat <PAT>\033[0m            (Required) Docker registry Personal Access Token"
  echo -e "  \033[1;36m-e, --email <EMAIL>\033[0m        (Required) Docker Hub email (for secret)"
  echo -e "  \033[1;36m-j, --project <PROJECT>\033[0m    (Required) Kubernetes project/namespace (for secret)"
  echo -e "  \033[1;36m-f, --file <FILE>\033[0m          (Required) Path to images.txt file (format: <image>:<tag> <dockerfile-dir>)"
  echo -e "  \033[1;33m-m, --manifests <DIR>\033[0m      (Optional) Path to manifest directory"
  echo -e "  \033[1;33m--log <FILE>\033[0m               (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Show this help message"
  echo

  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -u myuser -p mypat -e me@email.com -j myns -f images.txt"
  echo "  $0 --username myuser --pat mypat --email me@email.com --project myns --file images.txt --manifests ./manifests"
  echo "  $0 -u myuser -p mypat -e me@email.com -j myns -f images.txt --log build.log"
  
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
# Parse command line arguments
parse_args() {
  #---------------------------------------------------------------------
  # PARAMETER PROCESSING
  #---------------------------------------------------------------------
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

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if required parameters are provided
  if [[ -z "$DOCKER_USERNAME" || -z "$DOCKER_PAT" || -z "$EMAIL" || -z "$PROJECT_NAME" ]]; then
    log_message "ERROR" "Docker username, PAT, email, and project name are required."
    usage
  fi
  
  # Check if image list file exists
  if [[ ! -f "$IMAGE_LIST" ]]; then
    log_message "ERROR" "Image list file not found: $IMAGE_LIST"
    exit 1
  fi
  
  # Check if manifest directory exists if provided
  if [[ -n "$MANIFEST_DIR" && ! -d "$MANIFEST_DIR" ]]; then
    log_message "ERROR" "Manifest directory not found: $MANIFEST_DIR"
    exit 1
  fi
}

#=====================================================================
# DOCKER OPERATIONS
#=====================================================================
# Function to build and push Docker images
build_and_push_images() {
  local docker_username="$1"
  local image_list="$2"
  
  #---------------------------------------------------------------------
  # IMAGE LIST PROCESSING
  #---------------------------------------------------------------------
  # Read the image list file line by line
  local total_images=$(grep -v '^\s*$\|^\s*#' "$image_list" | wc -l | tr -d ' ')
  local current_image=0
  
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    
    #---------------------------------------------------------------------
    # IMAGE METADATA EXTRACTION
    #---------------------------------------------------------------------
    # Parse image name and context path
    image_name=$(echo "$line" | cut -d: -f1)
    context_path=$(echo "$line" | cut -d: -f2-)
    registry_image="$docker_username/$image_name:latest"
    
    # Increment counter
    ((current_image++))
    log_message "INFO" "Processing image $current_image of $total_images: $registry_image"
    
    #---------------------------------------------------------------------
    # BUILD OPERATION
    #---------------------------------------------------------------------
    # Build the Docker image
    log_message "INFO" "Building $registry_image from $context_path"
    if ! docker build -t "$registry_image" "$context_path"; then
      log_message "ERROR" "Failed to build $registry_image"
      exit 1
    fi
    
    #---------------------------------------------------------------------
    # PUSH OPERATION
    #---------------------------------------------------------------------
    # Push the Docker image to the registry
    log_message "INFO" "Pushing $registry_image to Docker registry"
    if ! docker push "$registry_image"; then
      log_message "ERROR" "Failed to push $registry_image"
      exit 1
    fi
    
    log_message "SUCCESS" "Successfully built and pushed $registry_image"
  done < "$image_list"
  
  log_message "INFO" "Processed $current_image images"
}

#=====================================================================
# MANIFEST PREPARATION
#=====================================================================
# Function to prepare Kubernetes manifests
prepare_manifests() {
  local manifest_dir="$1"
  local docker_username="$2"
  
  #---------------------------------------------------------------------
  # TEMPORARY DIRECTORY CREATION
  #---------------------------------------------------------------------
  # Create a temporary directory to store modified manifests
  TMP_MANIFEST_DIR=$(mktemp -d)
  log_message "INFO" "Creating temporary directory for manifests: $TMP_MANIFEST_DIR"
  
  #---------------------------------------------------------------------
  # MANIFEST COPYING
  #---------------------------------------------------------------------
  # Copy manifests from source directory to temporary directory
  log_message "INFO" "Copying manifests from $manifest_dir to temporary directory $TMP_MANIFEST_DIR"
  cp "$manifest_dir"/*.yaml "$TMP_MANIFEST_DIR"/
  
  #---------------------------------------------------------------------
  # PLACEHOLDER REPLACEMENT
  #---------------------------------------------------------------------
  # Replace Docker username placeholder in all YAML files
  log_message "INFO" "Replacing <DOCKER_USERNAME> with $docker_username in all YAMLs in $TMP_MANIFEST_DIR"
  for file in "$TMP_MANIFEST_DIR"/*.yaml; do
    sed -i '' "s|<DOCKER_USERNAME>|$docker_username|g" "$file"
  done
  
  log_message "SUCCESS" "Replaced <DOCKER_USERNAME> in all deployment YAMLs in $TMP_MANIFEST_DIR."
  echo "$TMP_MANIFEST_DIR"
}

#=====================================================================
# KUBERNETES OPERATIONS
#=====================================================================
# Function to create Kubernetes Docker registry secret
create_k8s_secret() {
  local username="$1"
  local pat="$2"
  local email="$3"
  local project="$4"
  
  #---------------------------------------------------------------------
  # SECRET CREATION
  #---------------------------------------------------------------------
  log_message "INFO" "Creating Docker registry secret in namespace $project"
  
  # Check if namespace exists, create if not
  if ! kubectl get namespace "$project" &>/dev/null; then
    log_message "INFO" "Namespace $project does not exist, creating it"
    kubectl create namespace "$project"
  fi
  
  # Create or update Docker registry secret
  kubectl create secret docker-registry regcred \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username="$username" \
    --docker-password="$pat" \
    --docker-email="$email" \
    -n "$project" --dry-run=client -o yaml | kubectl apply -f -
  
  log_message "SUCCESS" "Docker registry secret 'regcred' created or updated in namespace $project"
  
  #---------------------------------------------------------------------
  # SECRET VERIFICATION
  #---------------------------------------------------------------------
  # Verify the secret was created successfully
  if kubectl get secret regcred -n "$project" &>/dev/null; then
    log_message "INFO" "Secret 'regcred' verified in namespace $project"
  else
    log_message "WARNING" "Could not verify existence of secret 'regcred' in namespace $project"
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  # Parse command line arguments
  parse_args "$@"
  
  #---------------------------------------------------------------------
  # LOG CONFIGURATION
  #---------------------------------------------------------------------
  # Configure log file if specified
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Build and Push Images to Docker Registry Script"
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  log_message "INFO" "Starting build and push process..."
  log_message "INFO" "  Docker Username: $DOCKER_USERNAME"
  log_message "INFO" "  Email:           $EMAIL"
  log_message "INFO" "  K8s Namespace:   $PROJECT_NAME"
  log_message "INFO" "  Image List:      $IMAGE_LIST"
  if [[ -n "$MANIFEST_DIR" ]]; then
    log_message "INFO" "  Manifest Dir:    $MANIFEST_DIR"
  fi

  #---------------------------------------------------------------------
  # DOCKER LOGIN
  #---------------------------------------------------------------------
  # Log in to Docker registry
  log_message "INFO" "Logging in to Docker registry as $DOCKER_USERNAME"
  if ! echo "$DOCKER_PAT" | docker login --username "$DOCKER_USERNAME" --password-stdin; then
    log_message "ERROR" "Failed to log in to Docker registry"
    exit 1
  fi
  log_message "SUCCESS" "Successfully logged in to Docker registry"

  #---------------------------------------------------------------------
  # BUILD AND PUSH
  #---------------------------------------------------------------------
  # Build and push Docker images
  log_message "INFO" "Building and pushing images from $IMAGE_LIST to Docker registry"
  build_and_push_images "$DOCKER_USERNAME" "$IMAGE_LIST"
  log_message "SUCCESS" "All images built and pushed to Docker registry as $DOCKER_USERNAME"
  log_message "INFO" "Use image references like: $DOCKER_USERNAME/<image-name>:latest in your Kubernetes manifests."

  #---------------------------------------------------------------------
  # KUBERNETES SECRET CREATION
  #---------------------------------------------------------------------
  # Create Kubernetes Docker registry secret
  create_k8s_secret "$DOCKER_USERNAME" "$DOCKER_PAT" "$EMAIL" "$PROJECT_NAME"

  #---------------------------------------------------------------------
  # MANIFEST PROCESSING
  #---------------------------------------------------------------------
  # If manifest directory is provided, process manifests
  if [[ -n "$MANIFEST_DIR" && -d "$MANIFEST_DIR" ]]; then
    log_message "INFO" "Processing Kubernetes manifests in $MANIFEST_DIR"
    TMP_MANIFEST_DIR=$(prepare_manifests "$MANIFEST_DIR" "$DOCKER_USERNAME")
    log_message "SUCCESS" "Processed manifests available at: $TMP_MANIFEST_DIR"
    echo "Processed manifest directory: $TMP_MANIFEST_DIR"
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Build and Push Images to Docker Registry Script"
  log_message "SUCCESS" "Operation completed successfully."
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"