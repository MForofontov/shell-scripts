#!/bin/bash
# build-and-push-images-to-local-docker-registry.sh
# Script to create a local Docker registry if it doesn't exist and push images to it

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files
FORMAT_ECHO_FILE="$SCRIPT_DIR/../../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
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
IMAGE_LIST=""         # File containing list of images to build and push
LOG_FILE="/dev/null"  # Default log file location
REGISTRY_PORT=5000    # Default local registry port
REGISTRY_NAME="local-registry" # Default registry name
REGISTRY_HOST="localhost" # Default registry host
REGISTRY_SECURE=false # Default to insecure registry
K8S_PROVIDER=""       # Kubernetes provider (kind, minikube, k3d)
CLUSTER_NAME=""       # Cluster name
SKIP_CONNECTION_CHECK=false # Skip connection check when possible

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Local Docker Registry Setup and Image Push Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a local Docker registry if it doesn't exist,"
  echo "  builds Docker images, and pushes them to the local registry."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-f, --file <FILE>\033[0m        (Required) File listing images to build (format: <image>:<tag> <dockerfile-dir>)"
  echo -e "  \033[1;33m-p, --port <PORT>\033[0m        (Optional) Port for local registry (default: 5000)"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m        (Optional) Name for local registry container (default: local-registry)"
  echo -e "  \033[1;33m-h, --host <HOST>\033[0m        (Optional) Host for local registry (default: localhost)"
  echo -e "  \033[1;33m--secure\033[0m                 (Optional) Use HTTPS for registry (default: HTTP)"
  echo -e "  \033[1;33m--k8s <PROVIDER>\033[0m         (Optional) Kubernetes provider (kind, minikube, k3d) to configure for registry"
  echo -e "  \033[1;33m--cluster <NAME>\033[0m         (Optional) Kubernetes cluster name"
  echo -e "  \033[1;33m--skip-connection-check\033[0m  (Optional) Skip checking if cluster is already connected to registry"
  echo -e "  \033[1;33m--log <FILE>\033[0m             (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Show this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -f images.txt"
  echo "  $0 -f images.txt -p 5555 -n my-registry -h registry.local"
  echo "  $0 -f images.txt --k8s kind --cluster my-cluster"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if registry container exists
registry_exists() {
  docker ps -a --filter "name=^/${REGISTRY_NAME}$" --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"
}

# Check if registry container is running
registry_running() {
  docker ps --filter "name=^/${REGISTRY_NAME}$" --format '{{.Names}}' | grep -q "^${REGISTRY_NAME}$"
}

# Check if registry is connected to a Docker network
registry_connected_to_network() {
  local network="$1"
  docker network inspect "$network" 2>/dev/null | grep -q "\"$REGISTRY_NAME\""
}

# Check if minikube has registry credentials configured
minikube_registry_configured() {
  local profile="$1"
  # This is an imperfect check, but it's the best we can do without more complex parsing
  minikube addons list -p "$profile" 2>/dev/null | grep "registry-creds" | grep -q "enabled"
}

#=====================================================================
# DOCKER REGISTRY OPERATIONS
#=====================================================================
# Create and start a local Docker registry
setup_local_registry() {
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
    
    # Base Docker run command
    local docker_run_cmd="docker run -d --name $REGISTRY_NAME -p $REGISTRY_PORT:5000"
    
    # Add restart policy
    docker_run_cmd="$docker_run_cmd --restart=always"
    
    # If secure registry is requested
    if [ "$REGISTRY_SECURE" = true ]; then
      # Create certs directory if it doesn't exist
      mkdir -p "$SCRIPT_DIR/certs"
      
      # Generate self-signed certificate if it doesn't exist
      if [ ! -f "$SCRIPT_DIR/certs/domain.crt" ] || [ ! -f "$SCRIPT_DIR/certs/domain.key" ]; then
        format-echo "INFO" "Generating self-signed certificate for registry"
        openssl req -x509 -newkey rsa:4096 -days 365 -nodes \
          -keyout "$SCRIPT_DIR/certs/domain.key" -out "$SCRIPT_DIR/certs/domain.crt" \
          -subj "/CN=$REGISTRY_HOST" -addext "subjectAltName=DNS:$REGISTRY_HOST,IP:127.0.0.1"
      fi
      
      # Add volume mounts for certificates
      docker_run_cmd="$docker_run_cmd -v $SCRIPT_DIR/certs:/certs"
      docker_run_cmd="$docker_run_cmd -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt"
      docker_run_cmd="$docker_run_cmd -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key"
    fi
    
    # Add final image name
    docker_run_cmd="$docker_run_cmd registry:2"
    
    # Run the command
    if ! eval "$docker_run_cmd"; then
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
  local registry_url
  
  if [ "$REGISTRY_SECURE" = true ]; then
    registry_url="https://$REGISTRY_HOST:$REGISTRY_PORT/v2/"
  else
    registry_url="http://$REGISTRY_HOST:$REGISTRY_PORT/v2/"
  fi
  
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
# KUBERNETES CONFIGURATION
#=====================================================================
# Configure Kubernetes to use the local registry
configure_kubernetes_for_registry() {
  if [ -z "$K8S_PROVIDER" ]; then
    format-echo "INFO" "No Kubernetes provider specified, skipping cluster configuration"
    return
  fi
  
  format-echo "INFO" "Configuring $K8S_PROVIDER to use local registry"
  
  case "$K8S_PROVIDER" in
    kind)
      if [ -z "$CLUSTER_NAME" ]; then
        format-echo "ERROR" "Cluster name is required for kind provider"
        exit 1
      fi
      
      # Check if cluster exists
      if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        format-echo "ERROR" "kind cluster '$CLUSTER_NAME' not found"
        exit 1
      fi
      
      # Check if registry is already connected to kind network (unless skip is enabled)
      local kind_network="kind"
      if ! $SKIP_CONNECTION_CHECK && registry_connected_to_network "$kind_network"; then
        format-echo "INFO" "Registry already connected to kind network - skipping connection"
      else
        # Connect registry to kind network
        format-echo "INFO" "Connecting registry to kind network"
        if ! docker network connect "$kind_network" "$REGISTRY_NAME" 2>/dev/null; then
          format-echo "ERROR" "Failed to connect registry to kind network"
          exit 1
        fi
        format-echo "SUCCESS" "Connected registry to kind network"
      fi
      
      # Update registry host to use registry container name within the kind network
      REGISTRY_HOST="$REGISTRY_NAME"
      format-echo "SUCCESS" "Registry accessible within kind cluster as $REGISTRY_HOST:$REGISTRY_PORT"
      ;;
      
    minikube)
      if [ -z "$CLUSTER_NAME" ]; then
        CLUSTER_NAME="minikube"
      fi
      
      # Check if cluster exists
      if ! minikube profile list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        format-echo "ERROR" "minikube profile '$CLUSTER_NAME' not found"
        exit 1
      fi
      
      # For minikube, we need to use the host IP that's accessible from within minikube
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # On macOS, we use the special docker.for.mac.localhost hostname
        REGISTRY_HOST="host.docker.internal"
      else
        # On Linux, we use the host's IP address on the docker0 interface
        REGISTRY_HOST=$(ip -f inet addr show docker0 | grep -Po 'inet \K[\d.]+')
      fi
      
      # Check if registry is already configured (unless skip is enabled)
      if ! $SKIP_CONNECTION_CHECK && minikube_registry_configured "$CLUSTER_NAME"; then
        format-echo "INFO" "Registry already configured in minikube - skipping configuration"
      else
        # Add insecure registry to minikube
        format-echo "INFO" "Configuring minikube to use insecure registry"
        # Note: We're not actually checking the exact registry config here, just if the addon is enabled
        if ! minikube addons enable registry-creds -p "$CLUSTER_NAME" &>/dev/null; then
          format-echo "WARNING" "Failed to enable registry-creds addon"
        fi
        
        if ! minikube addons configure registry-creds --registry="$REGISTRY_HOST:$REGISTRY_PORT" -p "$CLUSTER_NAME" &>/dev/null; then
          format-echo "WARNING" "Failed to configure registry-creds addon. You may need to manually configure insecure registry."
        else
          format-echo "SUCCESS" "Configured minikube to use registry at $REGISTRY_HOST:$REGISTRY_PORT"
        fi
      fi
      
      format-echo "SUCCESS" "Registry accessible from minikube as $REGISTRY_HOST:$REGISTRY_PORT"
      ;;
      
    k3d)
      if [ -z "$CLUSTER_NAME" ]; then
        format-echo "ERROR" "Cluster name is required for k3d provider"
        exit 1
      fi
      
      # Check if cluster exists
      if ! k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        format-echo "ERROR" "k3d cluster '$CLUSTER_NAME' not found"
        exit 1
      fi
      
      # Check if registry is already connected to k3d network (unless skip is enabled)
      local k3d_network="k3d-$CLUSTER_NAME"
      if ! $SKIP_CONNECTION_CHECK && registry_connected_to_network "$k3d_network"; then
        format-echo "INFO" "Registry already connected to k3d network - skipping connection"
      else
        # Connect registry to k3d network
        format-echo "INFO" "Connecting registry to k3d network"
        if ! docker network connect "$k3d_network" "$REGISTRY_NAME" 2>/dev/null; then
          format-echo "ERROR" "Failed to connect registry to k3d network"
          exit 1
        fi
        format-echo "SUCCESS" "Connected registry to k3d network"
      fi
      
      # Update registry host to use registry container name within the k3d network
      REGISTRY_HOST="$REGISTRY_NAME"
      format-echo "SUCCESS" "Registry accessible within k3d cluster as $REGISTRY_HOST:$REGISTRY_PORT"
      ;;
      
    *)
      format-echo "ERROR" "Unsupported Kubernetes provider: $K8S_PROVIDER"
      format-echo "ERROR" "Supported providers: kind, minikube, k3d"
      exit 1
      ;;
  esac
}

#=====================================================================
# IMAGE OPERATIONS
#=====================================================================
# Build and push images to the local registry
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
    format-echo "INFO" "Pushing image $registry_image to local registry"
    
    # Push the image to the local registry
    if ! docker push "$registry_image"; then
      format-echo "ERROR" "Failed to push image $registry_image to local registry"
      continue
    fi
    
    format-echo "SUCCESS" "Pushed image $registry_image to local registry"
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
      --secure)
        REGISTRY_SECURE=true
        shift
        ;;
      --k8s)
        K8S_PROVIDER="$2"
        shift 2
        ;;
      --cluster)
        CLUSTER_NAME="$2"
        shift 2
        ;;
      --skip-connection-check)
        SKIP_CONNECTION_CHECK=true
        shift
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
  
  # Validate Kubernetes provider if specified
  if [[ -n "$K8S_PROVIDER" ]]; then
    case "$K8S_PROVIDER" in
      kind|minikube|k3d) ;;
      *)
        format-echo "ERROR" "Unsupported Kubernetes provider: $K8S_PROVIDER"
        format-echo "ERROR" "Supported providers: kind, minikube, k3d"
        exit 1
        ;;
    esac
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
  
  #---------------------------------------------------------------------
  # OPENSSL AVAILABILITY (if secure registry)
  #---------------------------------------------------------------------
  if [ "$REGISTRY_SECURE" = true ] && ! command_exists openssl; then
    format-echo "ERROR" "openssl not found. Please install openssl for secure registry."
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # KUBERNETES PROVIDER SPECIFIC CHECKS
  #---------------------------------------------------------------------
  if [ -n "$K8S_PROVIDER" ]; then
    case "$K8S_PROVIDER" in
      kind)
        if ! command_exists kind; then
          format-echo "ERROR" "kind not found. Please install kind."
          exit 1
        fi
        ;;
      minikube)
        if ! command_exists minikube; then
          format-echo "ERROR" "minikube not found. Please install minikube."
          exit 1
        fi
        ;;
      k3d)
        if ! command_exists k3d; then
          format-echo "ERROR" "k3d not found. Please install k3d."
          exit 1
        fi
        ;;
    esac
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
  # LOG CONFIGURATION
  #---------------------------------------------------------------------
  # Configure log file if specified
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Local Docker Registry Setup and Image Push Script"
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  format-echo "INFO" "Starting local registry setup and image push process..."
  format-echo "INFO" "  Registry Host:  $REGISTRY_HOST"
  format-echo "INFO" "  Registry Port:  $REGISTRY_PORT"
  format-echo "INFO" "  Registry Name:  $REGISTRY_NAME"
  format-echo "INFO" "  Image List:     $IMAGE_LIST"
  format-echo "INFO" "  Secure Mode:    $REGISTRY_SECURE"
  
  if [ -n "$K8S_PROVIDER" ]; then
    format-echo "INFO" "  K8s Provider:   $K8S_PROVIDER"
    format-echo "INFO" "  Cluster Name:   $CLUSTER_NAME"
  fi

  #---------------------------------------------------------------------
  # EXECUTION STAGES
  #---------------------------------------------------------------------
  # Check for required tools
  check_requirements
  
  # Set up local Docker registry
  setup_local_registry
  
  # Configure Kubernetes to use the local registry (if requested)
  if [ -n "$K8S_PROVIDER" ]; then
    configure_kubernetes_for_registry
  fi
  
  # Build and push images to the local registry
  build_and_push_images

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Local Docker Registry Setup and Image Push Script"
  
  # Show registry access information
  echo -e "\033[1;32mRegistry Information:\033[0m"
  echo "  Registry URL: ${REGISTRY_SECURE:+https://}${REGISTRY_SECURE:-http://}$REGISTRY_HOST:$REGISTRY_PORT"
  echo "  Registry container name: $REGISTRY_NAME"
  echo "  Images can be referenced as: $REGISTRY_HOST:$REGISTRY_PORT/<image-name>:<tag>"
  
  format-echo "SUCCESS" "Local registry setup and image push completed successfully."
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"