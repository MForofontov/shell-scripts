#!/bin/bash
# k8s-registry-pipeline.sh
# Script to set up an insecure Docker registry, build images, and push them to the registry.

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
REGISTRY_PORT=5001    # Default local registry port
REGISTRY_NAME="local-registry" # Default registry name
REGISTRY_HOST="localhost" # Default registry host
K8S_PROVIDER=""       # Kubernetes provider (kind, minikube, k3d)
CLUSTER_NAME=""       # Cluster name
SKIP_CONNECTION_CHECK=false # Skip connection check when possible
NAMESPACE="project-002"   # Default namespace

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Insecure Docker Registry Setup and Image Push Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates an insecure HTTP Docker registry,"
  echo "  builds Docker images, and pushes them to the registry."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-f, --file <FILE>\033[0m        (Required) File listing images to build (format: <image>:<tag> <dockerfile-dir>)"
  echo -e "  \033[1;33m-p, --port <PORT>\033[0m        (Optional) Port for registry (default: ${REGISTRY_PORT})"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m        (Optional) Name for registry container (default: ${REGISTRY_NAME})"
  echo -e "  \033[1;33m-h, --host <HOST>\033[0m        (Optional) Host for registry (default: ${REGISTRY_HOST})"
  echo -e "  \033[1;33m--k8s <PROVIDER>\033[0m         (Optional) Kubernetes provider (kind, minikube, k3d) to configure for registry"
  echo -e "  \033[1;33m--cluster <NAME>\033[0m         (Optional) Kubernetes cluster name"
  echo -e "  \033[1;33m--namespace <NAMESPACE>\033[0m  (Optional) Kubernetes namespace (default: ${NAMESPACE})"
  echo -e "  \033[1;33m--skip-connection-check\033[0m  (Optional) Skip checking if cluster is already connected to registry"
  echo -e "  \033[1;33m--log <FILE>\033[0m             (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Show this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -f images.txt"
  echo "  $0 -f images.txt -p 5555 -n my-registry -h registry.local"
  echo "  $0 -f images.txt --k8s minikube --cluster my-cluster"
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
# Create and start an insecure Docker registry
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
    
    # Create the insecure registry
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
# KUBERNETES CONFIGURATION
#=====================================================================
# Configure Kubernetes to use the insecure registry
configure_kubernetes_for_registry() {
  if [ -z "$K8S_PROVIDER" ]; then
    format-echo "INFO" "No Kubernetes provider specified, skipping cluster configuration"
    return
  fi
  
  format-echo "INFO" "Configuring $K8S_PROVIDER to use insecure registry"
  
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
      
      # Check if registry is already connected to kind network
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
      
      # Configure kind nodes to use insecure registry
      format-echo "INFO" "Configuring kind nodes to use insecure registry"
      for node in $(kind get nodes --name "$CLUSTER_NAME"); do
        docker exec "$node" bash -c "echo '{\"insecure-registries\":[\"$REGISTRY_NAME:5000\"]}' > /etc/docker/daemon.json"
        docker exec "$node" systemctl restart docker
      done
      
      # Update registry host to use registry container name within the kind network
      REGISTRY_HOST="$REGISTRY_NAME"
      format-echo "SUCCESS" "Registry accessible within kind cluster as $REGISTRY_HOST:5000"
      
      # Create Kubernetes secret for Docker registry authentication
      format-echo "INFO" "Creating Kubernetes image pull secret"
      # Create namespace if it doesn't exist
      kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
      
      # Create Docker registry secret
      kubectl create secret docker-registry regcred \
        --docker-server="$REGISTRY_HOST:5000" \
        --docker-username=user \
        --docker-password=pass \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
      
      format-echo "SUCCESS" "Created image pull secret in namespace $NAMESPACE"
      ;;
      
    minikube)
      if [ -z "$CLUSTER_NAME" ]; then
        CLUSTER_NAME="minikube"
      fi
      
      # Check if cluster exists - use flexible pattern matching
      if ! minikube profile list 2>/dev/null | grep -q "[[:space:]]${CLUSTER_NAME}[[:space:]]"; then
        # Try another approach
        if ! minikube profile list 2>/dev/null | grep -o -E "[a-zA-Z0-9-]+" | grep -q "^${CLUSTER_NAME}$"; then
          format-echo "ERROR" "minikube profile '$CLUSTER_NAME' not found"
          # Show available profiles for troubleshooting
          format-echo "INFO" "Available profiles:"
          minikube profile list 2>/dev/null
          exit 1
        fi
      fi
      
      # For minikube, we need different hostnames for host vs. container access
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # On macOS, containers use host.docker.internal to access the host
        MINIKUBE_REGISTRY_HOST="host.docker.internal"
        # The host itself uses localhost
        PUSH_REGISTRY_HOST="localhost"
      else
        # On Linux, use the host's IP address
        MINIKUBE_REGISTRY_HOST=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        PUSH_REGISTRY_HOST="$MINIKUBE_REGISTRY_HOST"
      fi
      
      # Configure minikube to use insecure registry
      format-echo "INFO" "Configuring minikube to use insecure registry"
      
      # Restart minikube with insecure registry configuration
      format-echo "INFO" "Restarting minikube with insecure registry configuration"
      minikube stop -p "$CLUSTER_NAME"
      minikube start -p "$CLUSTER_NAME" --insecure-registry="$MINIKUBE_REGISTRY_HOST:$REGISTRY_PORT"
      
      # Delete and recreate minikube with the proper configuration
      format-echo "INFO" "Completely recreating minikube with insecure registry support"
      minikube delete -p "$CLUSTER_NAME"
      format-echo "INFO" "Starting minikube with explicit insecure registry configuration"
      minikube start -p "$CLUSTER_NAME" --insecure-registry="$MINIKUBE_REGISTRY_HOST:$REGISTRY_PORT"

      # Verify the configuration was applied correctly
      format-echo "INFO" "Verifying minikube insecure registry configuration"
      minikube ssh -p "$CLUSTER_NAME" "grep -r insecure /etc || echo 'Insecure registry configuration not found'"

      # Give minikube time to fully initialize
      format-echo "INFO" "Waiting for minikube to stabilize after configuration"
      sleep 5

      # Rather than verify Docker is running, let's just create the registry secret
      format-echo "INFO" "Creating Kubernetes image pull secret"
      kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

      # Create Docker registry secret with insecure flag
      kubectl create secret docker-registry regcred \
        --docker-server="$MINIKUBE_REGISTRY_HOST:$REGISTRY_PORT" \
        --docker-username=user \
        --docker-password=pass \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -

      format-echo "SUCCESS" "Created image pull secret in namespace $NAMESPACE"
      
      # Patch existing deployments to use the image pull secret
      format-echo "INFO" "Patching existing deployments to use the registry credentials"
      kubectl get deployments -n "$NAMESPACE" -o name 2>/dev/null | while read -r deployment; do
        format-echo "INFO" "Patching $deployment to use regcred"
        kubectl patch $deployment -n "$NAMESPACE" --type=strategic --patch '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"regcred"}]}}}}' 2>/dev/null || true
      done
      
      # Update REGISTRY_HOST for image building/pushing to use the host perspective
      format-echo "INFO" "Using $PUSH_REGISTRY_HOST:$REGISTRY_PORT for pushing images"
      REGISTRY_HOST="$PUSH_REGISTRY_HOST"
      
      format-echo "SUCCESS" "Registry accessible from host as $REGISTRY_HOST:$REGISTRY_PORT"
      format-echo "SUCCESS" "Registry accessible from minikube as $MINIKUBE_REGISTRY_HOST:$REGISTRY_PORT"
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
      
      # Check if registry is already connected to k3d network
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
      
      # Configure k3d to use insecure registry
      format-echo "INFO" "Configuring k3d to use insecure registry"
      
      # Update registry host to use registry container name within the k3d network
      REGISTRY_HOST="$REGISTRY_NAME"
      format-echo "SUCCESS" "Registry accessible within k3d cluster as $REGISTRY_HOST:5000"
      
      # Create Kubernetes secret for Docker registry authentication
      format-echo "INFO" "Creating Kubernetes image pull secret"
      
      # Create namespace if it doesn't exist
      kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
      
      # Create Docker registry secret
      kubectl create secret docker-registry regcred \
        --docker-server="$REGISTRY_HOST:5000" \
        --docker-username=user \
        --docker-password=pass \
        --namespace="$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
      
      format-echo "SUCCESS" "Created image pull secret in namespace $NAMESPACE"
      ;;
      
    *)
      format-echo "ERROR" "Unsupported Kubernetes provider: $K8S_PROVIDER"
      format-echo "ERROR" "Supported providers: kind, minikube, k3d"
      exit 1
      ;;
  esac
  
  # Add instructions for deployment YAMLs
  format-echo "INFO" "Add this section to your deployment YAMLs to use the registry:"
  echo -e "\033[1;36mspec:\n  template:\n    spec:\n      imagePullSecrets:\n        - name: regcred\033[0m"
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
    
    # Push the image to the registry with insecure flag
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
      --k8s)
        K8S_PROVIDER="$2"
        shift 2
        ;;
      --cluster)
        CLUSTER_NAME="$2"
        shift 2
        ;;
      --namespace)
        NAMESPACE="$2"
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
  # Configure log file if specified
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Insecure Docker Registry Setup and Image Push Script"
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  format-echo "INFO" "Starting insecure registry setup and image push process..."
  format-echo "INFO" "  Registry Host:  $REGISTRY_HOST"
  format-echo "INFO" "  Registry Port:  $REGISTRY_PORT"
  format-echo "INFO" "  Registry Name:  $REGISTRY_NAME"
  format-echo "INFO" "  Image List:     $IMAGE_LIST"
  format-echo "INFO" "  Namespace:      $NAMESPACE"
  
  if [ -n "$K8S_PROVIDER" ]; then
    format-echo "INFO" "  K8s Provider:   $K8S_PROVIDER"
    format-echo "INFO" "  Cluster Name:   $CLUSTER_NAME"
  fi

  #---------------------------------------------------------------------
  # EXECUTION STAGES
  #---------------------------------------------------------------------
  # Check for required tools
  check_requirements
  
  # Set up insecure Docker registry
  setup_registry
  
  # Configure Kubernetes to use the insecure registry (if requested)
  if [ -n "$K8S_PROVIDER" ]; then
    configure_kubernetes_for_registry
  fi
  
  # Build and push images to the registry
  build_and_push_images

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Insecure Docker Registry Setup and Image Push Script"
  
  # Show registry access information
  echo -e "\033[1;32mRegistry Information:\033[0m"
  echo "  Registry URL: http://$REGISTRY_HOST:$REGISTRY_PORT/v2/"
  echo "  Registry container name: $REGISTRY_NAME"
  
  if [ "$K8S_PROVIDER" = "minikube" ]; then
    echo "  Images can be referenced in deployments as: host.docker.internal:$REGISTRY_PORT/<image-name>:<tag>"
  else
    echo "  Images can be referenced in deployments as: $REGISTRY_HOST:$REGISTRY_PORT/<image-name>:<tag>"
  fi
  
  # Reminder about deployment configuration
  echo -e "\033[1;36mRemember to add this to your deployment YAMLs:\033[0m"
  echo "  spec:"
  echo "    template:"
  echo "      spec:"
  echo "        imagePullSecrets:"
  echo "          - name: regcred"
  
  format-echo "SUCCESS" "Insecure registry setup and image push completed successfully."
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"