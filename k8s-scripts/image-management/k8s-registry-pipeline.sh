#!/bin/bash
# k8s-registry-pipeline.sh
# Simplified script to set up a Docker registry and push images to it.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
IMAGE_LIST=""         # File containing list of images to build and push
LOG_FILE="/dev/null"  # Default log file location
REGISTRY_PORT=5001    # Default local registry port
REGISTRY_NAME="local-registry" # Default registry name
REGISTRY_HOST="localhost" # Default registry host

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Docker Registry Setup and Image Push Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a Docker registry, builds Docker images,"
  echo "  and pushes them to the registry."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-f, --file <FILE>\033[0m        (Required) File listing images to build (format: <image>:<tag> <dockerfile-dir>)"
  echo -e "  \033[1;33m-p, --port <PORT>\033[0m        (Optional) Port for registry (default: ${REGISTRY_PORT})"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m        (Optional) Name for registry container (default: ${REGISTRY_NAME})"
  echo -e "  \033[1;33m-h, --host <HOST>\033[0m        (Optional) Host for registry (default: ${REGISTRY_HOST})"
  echo -e "  \033[1;33m--log <FILE>\033[0m             (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Show this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -f images.txt"
  echo "  $0 -f images.txt -p 5555 -n my-registry -h registry.local"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Check if registry container exists
registry_exists() {
  docker ps -a --filter "name=^/${REGISTRY_NAME}$" --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"
}

# Check if registry container is running
registry_running() {
  docker ps --filter "name=^/${REGISTRY_NAME}$" --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"
}

# Check if port is available
check_port_availability() {
  local port=$1
  
  # First check if it's used by any Docker container
  if docker ps -q --filter "publish=$port" | grep -q .; then
    format-echo "WARNING" "Port $port is already in use by a Docker container"
    return 1
  fi
  
  # Then check if any process is using the port
  if command -v lsof >/dev/null 2>&1; then
    if lsof -i :"$port" >/dev/null 2>&1; then
      format-echo "WARNING" "Port $port is already in use by a process"
      return 1
    fi
  elif command -v netstat >/dev/null 2>&1; then
    if netstat -tuln | grep -q ":$port "; then
      format-echo "WARNING" "Port $port is already in use by a process"
      return 1
    fi
  fi
  
  return 0
}

#=====================================================================
# DOCKER REGISTRY OPERATIONS
#=====================================================================
# Create and start a Docker registry
setup_registry() {
  #---------------------------------------------------------------------
  # REGISTRY CREATION
  #---------------------------------------------------------------------
  if registry_exists; then
    format-echo "INFO" "Docker registry container '$REGISTRY_NAME' already exists"
    
    if registry_running; then
      format-echo "INFO" "Docker registry container '$REGISTRY_NAME' is already running"
    else
      format-echo "INFO" "Starting Docker registry container '$REGISTRY_NAME'"
      if ! docker start "$REGISTRY_NAME"; then
        format-echo "ERROR" "Failed to start Docker registry container '$REGISTRY_NAME'"
        exit 1
      fi
      format-echo "SUCCESS" "Started Docker registry container '$REGISTRY_NAME'"
    fi
  else
    format-echo "INFO" "Creating and starting Docker registry container '$REGISTRY_NAME'"
    
    # Stop and remove any conflicting container with the same name
    docker stop "$REGISTRY_NAME" 2>/dev/null || true
    docker rm "$REGISTRY_NAME" 2>/dev/null || true
    
    # Create the registry
    if ! docker run -d --name "$REGISTRY_NAME" \
         -p "$REGISTRY_PORT:5000" \
         --restart=always \
         registry:2; then
      format-echo "ERROR" "Failed to create and start Docker registry container '$REGISTRY_NAME'"
      exit 1
    fi
    
    format-echo "SUCCESS" "Created and started Docker registry container '$REGISTRY_NAME'"
  fi
  
  #---------------------------------------------------------------------
  # REGISTRY VERIFICATION
  #---------------------------------------------------------------------
  # Wait for registry to be ready
  format-echo "INFO" "Waiting for registry to be ready..."
  local max_attempts=10
  local attempt=1
  local registry_url="http://$REGISTRY_HOST:$REGISTRY_PORT/v2/"
  
  while [ $attempt -le $max_attempts ]; do
    if curl -s "$registry_url" > /dev/null 2>&1; then
      format-echo "SUCCESS" "Registry is ready at $registry_url"
      break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
      format-echo "ERROR" "Registry is not responding after $max_attempts attempts"
      exit 1
    fi
    
    format-echo "INFO" "Waiting for registry to be ready (attempt $attempt/$max_attempts)..."
    sleep 2
    ((attempt++))
  done
}

#=====================================================================
# IMAGE OPERATIONS
#=====================================================================
# Build and push images to the registry
build_and_push_images() {
  format-echo "INFO" "Processing image list from $IMAGE_LIST"
  
  # Count total images to process
  local total_images=$(grep -v '^\s*$\|^\s*#' "$IMAGE_LIST" | wc -l | tr -d ' ')
  local current_image=0
  
  #---------------------------------------------------------------------
  # IMAGE LIST PROCESSING
  #---------------------------------------------------------------------
  while read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    
    # Parse image and directory
    local orig_image=$(echo "$line" | awk '{print $1}')
    local dir=$(echo "$line" | awk '{print $2}')
    
    # Extract image name and tag
    local image_name=$(echo "$orig_image" | cut -d: -f1)
    local image_tag=$(echo "$orig_image" | cut -d: -f2)
    
    # If no tag was specified, use 'latest'
    if [ "$image_name" = "$image_tag" ]; then
      image_tag="latest"
    fi
    
    # Construct the registry image reference
    local registry_image="$REGISTRY_HOST:$REGISTRY_PORT/$image_name:$image_tag"
    
    # Increment counter
    ((current_image++))
    format-echo "INFO" "Processing image $current_image of $total_images: $registry_image"
    
    #---------------------------------------------------------------------
    # IMAGE BUILDING
    #---------------------------------------------------------------------
    format-echo "INFO" "Building image $registry_image from directory $dir"
    
    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
      format-echo "ERROR" "Directory does not exist: $dir"
      continue
    fi
    
    # Check if Dockerfile exists
    if [[ ! -f "$dir/Dockerfile" ]]; then
      format-echo "ERROR" "Dockerfile not found in directory: $dir"
      continue
    fi
    
    # Build the image
    if ! docker build -t "$registry_image" "$dir"; then
      format-echo "ERROR" "Failed to build image $registry_image"
      continue
    fi
    
    format-echo "SUCCESS" "Built image $registry_image"
    
    #---------------------------------------------------------------------
    # IMAGE PUSHING
    #---------------------------------------------------------------------
    format-echo "INFO" "Pushing image $registry_image to registry"
    
    # Push the image to the registry
    if ! docker push "$registry_image"; then
      format-echo "ERROR" "Failed to push image $registry_image to registry"
      continue
    fi
    
    format-echo "SUCCESS" "Pushed image $registry_image to registry"
  done < "$IMAGE_LIST"
  
  format-echo "INFO" "Processed $current_image images"
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--file)
        IMAGE_LIST="$2"
        shift 2
        ;;
      -p|--port)
        REGISTRY_PORT="$2"
        shift 2
        ;;
      -n|--name)
        REGISTRY_NAME="$2"
        shift 2
        ;;
      -h|--host)
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

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check required parameters
  if [[ -z "$IMAGE_LIST" ]]; then
    format-echo "ERROR" "Image list file is required (-f, --file)"
    usage
  fi
  
  # Validate image list file exists
  if [[ ! -f "$IMAGE_LIST" ]]; then
    format-echo "ERROR" "Image list file does not exist: $IMAGE_LIST"
    exit 1
  fi
}

#=====================================================================
# REQUIREMENTS CHECKING
#=====================================================================
# Check for required tools
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  #---------------------------------------------------------------------
  # DOCKER AVAILABILITY
  #---------------------------------------------------------------------
  if ! command_exists docker; then
    format-echo "ERROR" "docker not found. Please install Docker."
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # CURL AVAILABILITY
  #---------------------------------------------------------------------
  if ! command_exists curl; then
    format-echo "ERROR" "curl not found. Please install curl."
    exit 1
  fi
  
  format-echo "SUCCESS" "All required tools are available."
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
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if port is available before starting registry
  if ! check_port_availability "$REGISTRY_PORT"; then
    format-echo "WARNING" "Registry port $REGISTRY_PORT is already in use"
    format-echo "INFO" "Try using a different port with --port"
  else
    format-echo "INFO" "Registry port $REGISTRY_PORT is available"
  fi

  #---------------------------------------------------------------------
  # LOG CONFIGURATION
  #---------------------------------------------------------------------
  setup_log_file
  fi

  print_with_separator "Docker Registry Setup and Image Push Script"
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  format-echo "INFO" "Starting registry setup and image push process..."
  format-echo "INFO" "  Registry Host:  $REGISTRY_HOST"
  format-echo "INFO" "  Registry Port:  $REGISTRY_PORT"
  format-echo "INFO" "  Registry Name:  $REGISTRY_NAME"
  format-echo "INFO" "  Image List:     $IMAGE_LIST"

  #---------------------------------------------------------------------
  # EXECUTION STAGES
  #---------------------------------------------------------------------
  # Check for required tools
  check_requirements
  
  # Set up Docker registry
  setup_registry
  
  # Build and push images to the registry
  build_and_push_images

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Docker Registry Setup and Image Push Script"
  
  # Show registry access information
  echo -e "\033[1;32mRegistry Information:\033[0m"
  echo "  Registry URL: http://$REGISTRY_HOST:$REGISTRY_PORT/v2/"
  echo "  Registry container name: $REGISTRY_NAME"
  echo "  Images can be referenced as: $REGISTRY_HOST:$REGISTRY_PORT/<image-name>:<tag>"
  
  format-echo "SUCCESS" "Registry setup and image push completed successfully."
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"
