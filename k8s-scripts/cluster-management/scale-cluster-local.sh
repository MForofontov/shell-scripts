#!/usr/bin/env bash
# scale-cluster-local.sh
# Script to scale Kubernetes clusters by changing the number of nodes

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
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
CLUSTER_NAME=""
PROVIDER="minikube"  # Default provider is minikube
NODE_COUNT=0         # Target node count (0 means show current count)
LOG_FILE="/dev/null"
FORCE=false
WAIT_TIMEOUT=300     # 5 minutes timeout for operation to complete

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Scaling Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scales Kubernetes clusters by changing the number of nodes."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-n, --name <NAME>\033[0m         (Required) Cluster name to scale"
  echo -e "  \033[1;36m-c, --nodes <COUNT>\033[0m       (Required) Target number of nodes (must be ≥ 1)"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m (Optional) Provider to use (minikube, kind, k3d) (default: ${PROVIDER})"
  echo -e "  \033[1;33m-f, --force\033[0m               (Optional) Force scaling without confirmation"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m   (Optional) Timeout in seconds for operation (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--log <FILE>\033[0m              (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster --nodes 3"
  echo "  $0 --name test-cluster --provider kind --nodes 2"
  echo "  $0 --name dev-cluster --provider k3d --nodes 5 --force"
  echo "  $0 --name my-cluster --nodes 2 --log scale.log"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#=====================================================================
# REQUIREMENTS CHECKING
#=====================================================================
# Check for required tools
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  case "$PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        format-echo "ERROR" "minikube not found. Please install it first:"
        echo "https://minikube.sigs.k8s.io/docs/start/"
        exit 1
      fi
      ;;
    kind)
      if ! command_exists kind; then
        format-echo "ERROR" "kind not found. Please install it first:"
        echo "https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        exit 1
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        format-echo "ERROR" "k3d not found. Please install it first:"
        echo "https://k3d.io/#installation"
        exit 1
      fi
      ;;
  esac

  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi

  # For kind and k3d, we need jq to handle JSON
  if [[ "$PROVIDER" == "kind" || "$PROVIDER" == "k3d" ]] && ! command_exists jq; then
    format-echo "ERROR" "jq is required for $PROVIDER but not found. Please install it first."
    exit 1
  fi

  format-echo "SUCCESS" "Required tools are available."
}

#=====================================================================
# CLUSTER VALIDATION
#=====================================================================
# Check if cluster exists
check_cluster_exists() {
  format-echo "INFO" "Checking if cluster exists..."
  
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
    format-echo "SUCCESS" "Cluster '${CLUSTER_NAME}' found."
    return 0
  else
    format-echo "ERROR" "Cluster '${CLUSTER_NAME}' not found for provider ${PROVIDER}."
    exit 1
  fi
}

#=====================================================================
# CLUSTER INFORMATION
#=====================================================================
# Get current cluster info
get_cluster_info() {
  format-echo "INFO" "Getting current cluster information..."
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC INFO GATHERING
  #---------------------------------------------------------------------
  case "$PROVIDER" in
    minikube)
      # Get minikube node count
      CURRENT_NODE_COUNT=$(minikube node list -p "$CLUSTER_NAME" 2>/dev/null | wc -l | tr -d ' ')
      format-echo "INFO" "Current node count: $CURRENT_NODE_COUNT"
      
      # Get Kubernetes version to maintain during scaling
      K8S_VERSION=$(minikube kubectl -- version --output=json -p "$CLUSTER_NAME" | jq -r '.serverVersion.gitVersion' | tr -d 'v')
      format-echo "INFO" "Kubernetes version: $K8S_VERSION"
      ;;
    kind)
      # Get kind node count
      CURRENT_NODE_COUNT=$(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null | wc -l | tr -d ' ')
      format-echo "INFO" "Current node count: $CURRENT_NODE_COUNT"
      
      # Get the node image to maintain during scaling
      NODE_IMAGE=$(kind get nodes --name "$CLUSTER_NAME" | head -1 | xargs docker inspect --format='{{.Config.Image}}')
      K8S_VERSION=$(echo "$NODE_IMAGE" | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | tr -d 'v')
      format-echo "INFO" "Kubernetes version: $K8S_VERSION"
      format-echo "INFO" "Node image: $NODE_IMAGE"
      ;;
    k3d)
      # For k3d, get server and agent counts separately
      SERVER_COUNT=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\" and .role.server==true)] | length")
      AGENT_COUNT=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\" and .role.agent==true)] | length")
      CURRENT_NODE_COUNT=$((SERVER_COUNT + AGENT_COUNT))
      format-echo "INFO" "Current node count: $CURRENT_NODE_COUNT (Servers: $SERVER_COUNT, Agents: $AGENT_COUNT)"
      
      # For k3d, store the server count separately since we usually only scale agents
      K8S_VERSION=$(kubectl --context="k3d-${CLUSTER_NAME}" version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' | tr -d 'v')
      format-echo "INFO" "Kubernetes version: $K8S_VERSION"
      ;;
  esac
  
  #---------------------------------------------------------------------
  # SCALING DETERMINATION
  #---------------------------------------------------------------------
  # If node count is 0 (just show current state), exit here
  if [ "$NODE_COUNT" -eq 0 ]; then
    format-echo "INFO" "No scaling requested. Current node count: $CURRENT_NODE_COUNT"
    exit 0
  fi
  
  # Determine if we're scaling up or down
  if [ "$NODE_COUNT" -gt "$CURRENT_NODE_COUNT" ]; then
    SCALE_DIRECTION="up"
    NODES_DELTA=$((NODE_COUNT - CURRENT_NODE_COUNT))
    format-echo "INFO" "Scaling UP from $CURRENT_NODE_COUNT to $NODE_COUNT nodes (+$NODES_DELTA)"
  elif [ "$NODE_COUNT" -lt "$CURRENT_NODE_COUNT" ]; then
    SCALE_DIRECTION="down"
    NODES_DELTA=$((CURRENT_NODE_COUNT - NODE_COUNT))
    format-echo "INFO" "Scaling DOWN from $CURRENT_NODE_COUNT to $NODE_COUNT nodes (-$NODES_DELTA)"
  else
    format-echo "INFO" "Current node count ($CURRENT_NODE_COUNT) already matches requested count ($NODE_COUNT). No scaling needed."
    exit 0
  fi
}

#=====================================================================
# SCALING OPERATIONS: MINIKUBE
#=====================================================================
# Scale minikube cluster
scale_minikube_cluster() {
  if [ "$SCALE_DIRECTION" == "up" ]; then
    #---------------------------------------------------------------------
    # MINIKUBE SCALE UP
    #---------------------------------------------------------------------
    # Scaling up - add nodes
    format-echo "INFO" "Scaling minikube cluster '${CLUSTER_NAME}' UP to ${NODE_COUNT} nodes..."
    
    for ((i=CURRENT_NODE_COUNT+1; i<=NODE_COUNT; i++)); do
      local node_name="${CLUSTER_NAME}-m0${i}"
      format-echo "INFO" "Adding node ${node_name}..."
      
      if ! minikube node add -p "${CLUSTER_NAME}"; then
        format-echo "ERROR" "Failed to add node to minikube cluster '${CLUSTER_NAME}'."
        exit 1
      fi
    done
    
    format-echo "SUCCESS" "minikube cluster '${CLUSTER_NAME}' scaled UP to ${NODE_COUNT} nodes."
    
  elif [ "$SCALE_DIRECTION" == "down" ]; then
    #---------------------------------------------------------------------
    # MINIKUBE SCALE DOWN
    #---------------------------------------------------------------------
    # Scaling down - remove nodes
    format-echo "INFO" "Scaling minikube cluster '${CLUSTER_NAME}' DOWN to ${NODE_COUNT} nodes..."
    
    # Minikube nodes are named like: clustername-m02, clustername-m03, etc.
    # The control plane is always m01, so we need to keep that and remove others
    for ((i=CURRENT_NODE_COUNT; i>NODE_COUNT; i--)); do
      local node_name="${CLUSTER_NAME}-m0${i}"
      format-echo "INFO" "Removing node ${node_name}..."
      
      if ! minikube node delete "${node_name}" -p "${CLUSTER_NAME}"; then
        format-echo "ERROR" "Failed to remove node ${node_name} from minikube cluster '${CLUSTER_NAME}'."
        exit 1
      fi
    done
    
    format-echo "SUCCESS" "minikube cluster '${CLUSTER_NAME}' scaled DOWN to ${NODE_COUNT} nodes."
  fi
}

#=====================================================================
# SCALING OPERATIONS: KIND
#=====================================================================
# Scale kind cluster (requires delete and recreate)
scale_kind_cluster() {
  format-echo "INFO" "Scaling kind cluster '${CLUSTER_NAME}' to ${NODE_COUNT} nodes..."
  format-echo "WARNING" "Kind clusters require recreation to scale. This will cause downtime."
  
  #---------------------------------------------------------------------
  # RESOURCE BACKUP
  #---------------------------------------------------------------------
  # Save cluster configuration and important resources
  format-echo "INFO" "Backing up cluster resources before scaling..."
  local backup_dir="${CLUSTER_NAME}-backup-$(date +%Y%m%d%H%M%S)"
  mkdir -p "$backup_dir"
  
  # Switch to the right context
  kubectl config use-context "kind-$CLUSTER_NAME"
  
  # Export cluster resources
  kubectl get ns -o json > "$backup_dir/namespaces.json"
  kubectl get deploy --all-namespaces -o json > "$backup_dir/deployments.json"
  kubectl get svc --all-namespaces -o json > "$backup_dir/services.json"
  kubectl get pv -o json > "$backup_dir/persistent-volumes.json"
  kubectl get pvc --all-namespaces -o json > "$backup_dir/persistent-volume-claims.json"
  
  format-echo "INFO" "Backup created at $backup_dir"
  
  #---------------------------------------------------------------------
  # CLUSTER RECREATION
  #---------------------------------------------------------------------
  # Delete the existing cluster
  format-echo "INFO" "Deleting existing kind cluster for scaling..."
  if ! kind delete cluster --name "${CLUSTER_NAME}"; then
    format-echo "ERROR" "Failed to delete kind cluster for scaling."
    exit 1
  fi
  
  # Create a new config file with the desired number of nodes
  format-echo "INFO" "Creating new kind cluster with ${NODE_COUNT} nodes..."
  local kind_config=$(mktemp)
  echo "kind: Cluster" > "$kind_config"
  echo "apiVersion: kind.x-k8s.io/v1alpha4" >> "$kind_config"
  echo "nodes:" >> "$kind_config"
  echo "- role: control-plane" >> "$kind_config"
  
  # Add worker nodes if needed
  if [[ "$NODE_COUNT" -gt 1 ]]; then
    for ((i=1; i<NODE_COUNT; i++)); do
      echo "- role: worker" >> "$kind_config"
    done
  fi
  
  # Create the new cluster with the same Kubernetes version
  if kind create cluster --name "${CLUSTER_NAME}" --image="kindest/node:v${K8S_VERSION}" --config="$kind_config"; then
    format-echo "SUCCESS" "kind cluster '${CLUSTER_NAME}' recreated with ${NODE_COUNT} nodes."
    rm "$kind_config"
  else
    format-echo "ERROR" "Failed to recreate kind cluster with ${NODE_COUNT} nodes."
    rm "$kind_config"
    exit 1
  fi
  
  format-echo "INFO" "Node scaling complete. Cluster resources may need to be reapplied from $backup_dir"
}

#=====================================================================
# SCALING OPERATIONS: K3D
#=====================================================================
# Scale k3d cluster
scale_k3d_cluster() {
  if [ "$SCALE_DIRECTION" == "up" ]; then
    #---------------------------------------------------------------------
    # K3D SCALE UP
    #---------------------------------------------------------------------
    # Scaling up - add agent nodes
    format-echo "INFO" "Scaling k3d cluster '${CLUSTER_NAME}' UP to ${NODE_COUNT} nodes..."
    
    # Calculate how many agent nodes to add
    # For k3d, we keep the server (control plane) count the same and only add agent nodes
    local new_agent_count=$((NODE_COUNT - SERVER_COUNT))
    local agents_to_add=$((new_agent_count - AGENT_COUNT))
    
    format-echo "INFO" "Adding ${agents_to_add} agent nodes to k3d cluster..."
    
    if ! k3d node create "${CLUSTER_NAME}-agent-$(date +%s)" --cluster "${CLUSTER_NAME}" --role agent -c "${agents_to_add}"; then
      format-echo "ERROR" "Failed to add nodes to k3d cluster '${CLUSTER_NAME}'."
      exit 1
    fi
    
    format-echo "SUCCESS" "k3d cluster '${CLUSTER_NAME}' scaled UP to ${NODE_COUNT} nodes."
    
  elif [ "$SCALE_DIRECTION" == "down" ]; then
    #---------------------------------------------------------------------
    # K3D SCALE DOWN
    #---------------------------------------------------------------------
    # Scaling down - remove agent nodes
    format-echo "INFO" "Scaling k3d cluster '${CLUSTER_NAME}' DOWN to ${NODE_COUNT} nodes..."
    
    # Calculate how many agent nodes to remove
    # Make sure we keep at least the server nodes
    if [ "$NODE_COUNT" -lt "$SERVER_COUNT" ]; then
      format-echo "ERROR" "Cannot scale below the number of server nodes (${SERVER_COUNT})."
      format-echo "ERROR" "Minimum node count for this cluster is ${SERVER_COUNT}."
      exit 1
    fi
    
    local new_agent_count=$((NODE_COUNT - SERVER_COUNT))
    local agents_to_remove=$((AGENT_COUNT - new_agent_count))
    
    # Get the list of agent nodes
    local agent_nodes=($(k3d node list -o json | jq -r ".[] | select(.clusterAssociation.cluster==\"$CLUSTER_NAME\" and .role.agent==true) | .name"))
    
    # Remove the calculated number of agent nodes
    for ((i=0; i<agents_to_remove; i++)); do
      if [ $i -lt ${#agent_nodes[@]} ]; then
        local node_to_remove="${agent_nodes[$i]}"
        format-echo "INFO" "Removing node ${node_to_remove}..."
        
        if ! k3d node delete "${node_to_remove}"; then
          format-echo "ERROR" "Failed to remove node ${node_to_remove}."
          exit 1
        fi
      fi
    done
    
    format-echo "SUCCESS" "k3d cluster '${CLUSTER_NAME}' scaled DOWN to ${NODE_COUNT} nodes."
  fi
}

#=====================================================================
# VERIFICATION AND MONITORING
#=====================================================================
# Wait for cluster nodes to be ready
wait_for_cluster() {
  format-echo "INFO" "Waiting for all nodes to be ready (timeout: ${WAIT_TIMEOUT}s)..."
  
  local start_time=$(date +%s)
  local end_time=$((start_time + WAIT_TIMEOUT))
  
  #---------------------------------------------------------------------
  # CONTEXT SETTING
  #---------------------------------------------------------------------
  # Set correct context based on provider
  case "$PROVIDER" in
    minikube)
      kubectl config use-context "$CLUSTER_NAME"
      ;;
    kind)
      kubectl config use-context "kind-$CLUSTER_NAME"
      ;;
    k3d)
      kubectl config use-context "k3d-$CLUSTER_NAME"
      ;;
  esac
  
  #---------------------------------------------------------------------
  # NODE READINESS MONITORING
  #---------------------------------------------------------------------
  while true; do
    # First check if we can connect to the cluster
    if kubectl get nodes &>/dev/null; then
      # Check if we have the expected number of nodes
      local actual_nodes=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
      
      if [ "$actual_nodes" -eq "$NODE_COUNT" ]; then
        # Now check if all nodes are ready
        local all_ready=true
        for status in $(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}'); do
          if [[ "$status" != "True" ]]; then
            all_ready=false
            break
          fi
        done
        
        if $all_ready; then
          break
        fi
      fi
    fi
    
    current_time=$(date +%s)
    if [[ $current_time -ge $end_time ]]; then
      format-echo "ERROR" "Timeout waiting for cluster nodes to be ready."
      format-echo "WARNING" "The scaling operation may have partially completed."
      exit 1
    fi
    
    sleep 5
  done
  
  format-echo "SUCCESS" "All ${NODE_COUNT} nodes are ready."
}

#---------------------------------------------------------------------
# CLUSTER INFO DISPLAY
#---------------------------------------------------------------------
# Display cluster info
display_cluster_info() {
  print_with_separator "Cluster Information After Scaling"
  
  format-echo "INFO" "Nodes:"
  kubectl get nodes
  
  format-echo "INFO" "Node Resources:"
  kubectl top nodes 2>/dev/null || echo "Metrics not available (metrics-server may not be installed)"
  
  print_with_separator
}

#=====================================================================
# USER INTERACTION
#=====================================================================
# Confirm scaling with user
confirm_scaling() {
  if [ "$FORCE" = true ]; then
    return 0
  fi
  
  echo -e "\033[1;33mWarning:\033[0m You are about to scale the cluster '${CLUSTER_NAME}' (provider: ${PROVIDER})."
  
  if [ "$SCALE_DIRECTION" == "up" ]; then
    echo "  Scaling UP from $CURRENT_NODE_COUNT to $NODE_COUNT nodes (+$NODES_DELTA)."
  else
    echo "  Scaling DOWN from $CURRENT_NODE_COUNT to $NODE_COUNT nodes (-$NODES_DELTA)."
  fi
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC WARNINGS
  #---------------------------------------------------------------------
  # Provider-specific warnings
  case "$PROVIDER" in
    kind)
      echo -e "\033[1;31mCAUTION:\033[0m Kind clusters require complete recreation to scale."
      echo "  This will cause downtime and may require you to redeploy applications."
      echo "  A backup of cluster resources will be created, but stateful applications may be affected."
      ;;
    k3d)
      if [ "$SCALE_DIRECTION" == "down" ]; then
        echo -e "\033[1;31mCAUTION:\033[0m Scaling down will remove nodes which may be running workloads."
        echo "  Ensure you have enough capacity for all workloads after scaling."
      fi
      ;;
    minikube)
      if [ "$SCALE_DIRECTION" == "down" ]; then
        echo -e "\033[1;31mCAUTION:\033[0m Scaling down will remove nodes which may be running workloads."
        echo "  Ensure you have enough capacity for all workloads after scaling."
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # USER CONFIRMATION
  #---------------------------------------------------------------------
  read -p "Are you sure you want to continue? [y/N]: " answer
  
  case "$answer" in
    [Yy]|[Yy][Ee][Ss])
      return 0
      ;;
    *)
      format-echo "INFO" "Scaling canceled by user."
      exit 0
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
            format-echo "ERROR" "Unsupported provider '${PROVIDER}'."
            format-echo "ERROR" "Supported providers: minikube, kind, k3d"
            exit 1
            ;;
        esac
        shift 2
        ;;
      -c|--nodes)
        NODE_COUNT="$2"
        # Validate that NODE_COUNT is a positive integer
        if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ]; then
          format-echo "ERROR" "Node count must be a positive integer."
          exit 1
        fi
        shift 2
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      -t|--timeout)
        WAIT_TIMEOUT="$2"
        shift 2
        ;;
      --log)
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  #---------------------------------------------------------------------
  # ARGUMENTS VALIDATION
  #---------------------------------------------------------------------
  # Check if required parameters are provided
  if [ -z "$CLUSTER_NAME" ]; then
    format-echo "ERROR" "Cluster name is required. Use -n or --name to specify."
    usage
  fi
  
  if [ "$NODE_COUNT" -eq 0 ]; then
    # If node count is 0, just show current state - this is valid
    format-echo "INFO" "No node count specified. Will show current cluster state."
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
# Main function
main() {
  # Parse arguments
  parse_args "$@"
  
  #---------------------------------------------------------------------
  # LOG CONFIGURATION
  #---------------------------------------------------------------------
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Kubernetes Cluster Scaling Script"
  
  format-echo "INFO" "Starting Kubernetes cluster scaling..."
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Cluster Name: $CLUSTER_NAME"
  format-echo "INFO" "  Provider:     $PROVIDER"
  format-echo "INFO" "  Target Nodes: $NODE_COUNT"
  
  #---------------------------------------------------------------------
  # PREPARATION
  #---------------------------------------------------------------------
  # Check requirements
  check_requirements
  
  # Check if the cluster exists
  check_cluster_exists
  
  # Get current cluster info and determine scaling direction
  get_cluster_info
  
  # If no scaling is needed, exit
  if [ -z "$SCALE_DIRECTION" ]; then
    exit 0
  fi
  
  # Confirm scaling with user
  confirm_scaling
  
  #---------------------------------------------------------------------
  # SCALING EXECUTION
  #---------------------------------------------------------------------
  # Scale the cluster based on the provider
  case "$PROVIDER" in
    minikube)
      scale_minikube_cluster
      ;;
    kind)
      scale_kind_cluster
      ;;
    k3d)
      scale_k3d_cluster
      ;;
  esac
  
  #---------------------------------------------------------------------
  # VERIFICATION
  #---------------------------------------------------------------------
  # Wait for cluster nodes to be ready
  wait_for_cluster
  
  # Display cluster info after scaling
  display_cluster_info
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Kubernetes Cluster Scaling"
  format-echo "SUCCESS" "Kubernetes cluster scaling completed successfully."
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"
