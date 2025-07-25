#!/bin/bash
# build-and-load-images.sh
# Build Docker images and load them into a local Kubernetes cluster (minikube, kind, or k3d)

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
IMAGE_LIST=""         # File containing list of images to build and load
CLUSTER_NAME="k8s-cluster"  # Default cluster name
PROVIDER="minikube"   # Default Kubernetes provider
# shellcheck disable=SC2034
LOG_FILE="/dev/null"  # Default log file location

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Build and Load Images Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  Build Docker images and load them into a local Kubernetes cluster (minikube, kind, or k3d)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-f, --file <FILE>\033[0m        (Required) File listing images to build (format: <image>:<tag> <dockerfile-dir>)"
  echo -e "  \033[1;33m--provider <PROVIDER>\033[0m    (Optional) Cluster provider (minikube, kind, k3d) (default: minikube)"
  echo -e "  \033[1;33m--name <NAME>\033[0m            (Optional) Cluster name (default: k8s-cluster)"
  echo -e "  \033[1;33m--log <FILE>\033[0m             (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Show this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -f images.txt --provider kind --name my-cluster"
  echo "  $0 --file images.txt --log build.log"
  print_with_separator
  exit 1
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
  if ! command -v docker &>/dev/null; then
    format-echo "ERROR" "docker not found. Please install Docker."
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC REQUIREMENTS
  #---------------------------------------------------------------------
  case "$PROVIDER" in
    minikube)
      if ! command -v minikube &>/dev/null; then
        format-echo "ERROR" "minikube not found. Please install minikube."
        exit 1
      fi
      # Check if the specified cluster exists
      if ! minikube profile list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        format-echo "ERROR" "minikube cluster '$CLUSTER_NAME' not found."
        exit 1
      fi
      ;;
    kind)
      if ! command -v kind &>/dev/null; then
        format-echo "ERROR" "kind not found. Please install kind."
        exit 1
      fi
      # Check if the specified cluster exists
      if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        format-echo "ERROR" "kind cluster '$CLUSTER_NAME' not found."
        exit 1
      fi
      ;;
    k3d)
      if ! command -v k3d &>/dev/null; then
        format-echo "ERROR" "k3d not found. Please install k3d."
        exit 1
      fi
      # Check if the specified cluster exists
      if ! k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
        format-echo "ERROR" "k3d cluster '$CLUSTER_NAME' not found."
        exit 1
      fi
      ;;
  esac
  
  format-echo "SUCCESS" "All required tools are available."
}

#=====================================================================
# IMAGE OPERATIONS
#=====================================================================
# Build and load images from the image list file
build_and_load_images() {
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
    image=$(echo "$line" | awk '{print $1}')
    dir=$(echo "$line" | awk '{print $2}')
    
    # Validate line format
    if [[ -z "$image" || -z "$dir" ]]; then
      format-echo "WARNING" "Skipping invalid line: $line"
      continue
    fi
    
    # Increment counter
    ((current_image++))
    format-echo "INFO" "Processing image $current_image of $total_images: $image"
    
    #---------------------------------------------------------------------
    # IMAGE BUILDING
    #---------------------------------------------------------------------
    format-echo "INFO" "Building image $image from directory $dir"
    
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
    if ! docker build -t "$image" "$dir"; then
      format-echo "ERROR" "Failed to build image $image"
      continue
    fi
    
    format-echo "SUCCESS" "Built image $image"
    
    #---------------------------------------------------------------------
    # IMAGE LOADING
    #---------------------------------------------------------------------
    # Load the image into the cluster based on provider
    case "$PROVIDER" in
      minikube)
        format-echo "INFO" "Loading image $image into minikube ($CLUSTER_NAME)"
        if ! minikube image load "$image" -p "$CLUSTER_NAME"; then
          format-echo "ERROR" "Failed to load image $image into minikube"
          continue
        fi
        ;;
      kind)
        format-echo "INFO" "Loading image $image into kind ($CLUSTER_NAME)"
        if ! kind load docker-image "$image" --name "$CLUSTER_NAME"; then
          format-echo "ERROR" "Failed to load image $image into kind"
          continue
        fi
        ;;
      k3d)
        format-echo "INFO" "Importing image $image into k3d ($CLUSTER_NAME)"
        if ! k3d image import "$image" -c "$CLUSTER_NAME"; then
          format-echo "ERROR" "Failed to import image $image into k3d"
          continue
        fi
        ;;
    esac
    
    format-echo "SUCCESS" "Loaded image $image into $PROVIDER cluster $CLUSTER_NAME"
  done < "$IMAGE_LIST"
  
  #---------------------------------------------------------------------
  # COMPLETION SUMMARY
  #---------------------------------------------------------------------
  format-echo "INFO" "Processed $current_image images"
}

#=====================================================================
# IMAGE VERIFICATION
#=====================================================================
# Verify images are loaded in the cluster
verify_images() {
  format-echo "INFO" "Verifying images in cluster $CLUSTER_NAME"
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC VERIFICATION
  #---------------------------------------------------------------------
  case "$PROVIDER" in
    minikube)
      # For minikube, list images in the cluster
      format-echo "INFO" "Images available in minikube cluster:"
      if ! minikube image ls -p "$CLUSTER_NAME"; then
        format-echo "WARNING" "Failed to list images in minikube"
      fi
      ;;
    kind)
      # For kind, we need to check inside the nodes
      format-echo "INFO" "Images available in kind cluster (control-plane node):"
      local control_plane_node="$CLUSTER_NAME-control-plane"
      if ! docker exec "$control_plane_node" crictl images; then
        format-echo "WARNING" "Failed to list images in kind control plane"
      fi
      ;;
    k3d)
      # For k3d, we need to check inside the server node
      format-echo "INFO" "Images available in k3d cluster (server node):"
      local server_node=$(k3d node list | grep "$CLUSTER_NAME.*server" | head -1 | awk '{print $1}')
      if [[ -n "$server_node" ]]; then
        if ! docker exec "$server_node" crictl images; then
          format-echo "WARNING" "Failed to list images in k3d server node"
        fi
      else
        format-echo "WARNING" "Could not find k3d server node"
      fi
      ;;
  esac
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
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  if [[ -z "$IMAGE_LIST" ]]; then
    format-echo "ERROR" "Image list file is required."
    usage
  fi
  
  # Validate provider
  case "$PROVIDER" in
    minikube|kind|k3d) ;;
    *)
      format-echo "ERROR" "Unsupported provider: $PROVIDER"
      format-echo "ERROR" "Supported providers: minikube, kind, k3d"
      exit 1
      ;;
  esac
  
  # Validate image list file exists
  if [[ ! -f "$IMAGE_LIST" ]]; then
    format-echo "ERROR" "Image list file does not exist: $IMAGE_LIST"
    exit 1
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
  setup_log_file

  print_with_separator "Build and Load Images Script"
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  format-echo "INFO" "Starting build and load process..."
  format-echo "INFO" "  Provider:     $PROVIDER"
  format-echo "INFO" "  Cluster Name: $CLUSTER_NAME"
  format-echo "INFO" "  Image List:   $IMAGE_LIST"

  #---------------------------------------------------------------------
  # EXECUTION STAGES
  #---------------------------------------------------------------------
  # Check for required tools and cluster existence
  check_requirements
  
  # Build and load the images
  build_and_load_images
  
  # Verify the images are loaded
  verify_images

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Build and Load Images Script"
  format-echo "SUCCESS" "All images built and loaded successfully."
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"
