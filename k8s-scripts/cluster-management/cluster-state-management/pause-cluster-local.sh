#!/bin/bash
# pause-cluster.sh
# Script to temporarily pause/hibernate Kubernetes clusters to save resources

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
PROVIDER="auto"  # auto-detect provider if not specified
FORCE=false
WAIT_TIMEOUT=300  # 5 minutes timeout
STATE_DIR="$HOME/.kube/cluster-states"
LOG_FILE="/dev/null"
DRAIN_NODES=true
BACKUP_WORKLOADS=true
SNAPSHOTS=false
PRESERVE_KUBECONFIG=true

# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Pause Tool"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script temporarily pauses/hibernates Kubernetes clusters to save resources."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-n, --name <NAME>\033[0m           (Required) Cluster name to pause"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m   (Optional) Provider to use (minikube, kind, k3d) (default: auto-detect)"
  echo -e "  \033[1;33m-f, --force\033[0m                 (Optional) Force pause without confirmation"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m     (Optional) Timeout in seconds for graceful operations (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--no-drain\033[0m                  (Optional) Skip draining nodes before pause"
  echo -e "  \033[1;33m--no-backup\033[0m                 (Optional) Skip backing up workloads"
  echo -e "  \033[1;33m--snapshot\033[0m                  (Optional) Create provider-specific snapshots if available"
  echo -e "  \033[1;33m--no-preserve-config\033[0m        (Optional) Don't preserve kubeconfig context"
  echo -e "  \033[1;33m--state-dir <DIR>\033[0m           (Optional) Directory to store state files (default: ${STATE_DIR})"
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster"
  echo "  $0 --name test-cluster --provider kind --force"
  echo "  $0 --name dev-cluster --provider k3d --no-drain"
  echo "  $0 --name minikube --snapshot --state-dir /tmp/cluster-states"
  print_with_separator
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Auto-detect provider based on cluster name
detect_provider() {
  local cluster="$1"
  
  log_message "INFO" "Auto-detecting provider for cluster: $cluster"
  
  # Check for minikube clusters
  if [[ "$cluster" == "minikube" || "$cluster" == minikube-* ]]; then
    if command_exists minikube; then
      # Verify cluster exists in minikube
      if minikube profile list 2>/dev/null | grep -q "$cluster"; then
        log_message "INFO" "Detected provider: minikube"
        echo "minikube"
        return 0
      fi
    fi
  fi
  
  # Check for kind clusters
  if [[ "$cluster" == kind-* || "$cluster" == *-kind ]]; then
    if command_exists kind; then
      # Verify cluster exists in kind
      if kind get clusters 2>/dev/null | grep -q "$cluster"; then
        log_message "INFO" "Detected provider: kind"
        echo "kind"
        return 0
      fi
    fi
  fi
  
  # Check for k3d clusters
  if [[ "$cluster" == k3d-* || "$cluster" == *-k3d ]]; then
    if command_exists k3d; then
      # Verify cluster exists in k3d
      if k3d cluster list 2>/dev/null | grep -q "$cluster"; then
        log_message "INFO" "Detected provider: k3d"
        echo "k3d"
        return 0
      fi
    fi
  fi
  
  # Try to find the cluster in each provider
  if command_exists minikube; then
    if minikube profile list 2>/dev/null | grep -q "$cluster"; then
      log_message "INFO" "Detected provider: minikube"
      echo "minikube"
      return 0
    fi
  fi
  
  if command_exists kind; then
    if kind get clusters 2>/dev/null | grep -q "$cluster"; then
      log_message "INFO" "Detected provider: kind"
      echo "kind"
      return 0
    fi
  fi
  
  if command_exists k3d; then
    if k3d cluster list 2>/dev/null | grep -q "$cluster"; then
      log_message "INFO" "Detected provider: k3d"
      echo "k3d"
      return 0
    fi
  fi
  
  log_message "ERROR" "Could not detect provider for cluster: $cluster"
  return 1
}

# Check if cluster exists for given provider
check_cluster_exists() {
  local cluster="$1"
  local provider="$2"
  
  log_message "INFO" "Checking if cluster '$cluster' exists for provider '$provider'"
  
  case "$provider" in
    minikube)
      if ! command_exists minikube; then
        log_message "ERROR" "minikube command not found"
        return 1
      fi
      if minikube profile list 2>/dev/null | grep -q "$cluster"; then
        return 0
      fi
      ;;
      
    kind)
      if ! command_exists kind; then
        log_message "ERROR" "kind command not found"
        return 1
      fi
      if kind get clusters 2>/dev/null | grep -q "$cluster"; then
        return 0
      fi
      ;;
      
    k3d)
      if ! command_exists k3d; then
        log_message "ERROR" "k3d command not found"
        return 1
      fi
      if k3d cluster list 2>/dev/null | grep -q "$cluster"; then
        return 0
      fi
      ;;
      
    *)
      log_message "ERROR" "Unsupported provider: $provider"
      return 1
      ;;
  esac
  
  log_message "ERROR" "Cluster '$cluster' not found for provider '$provider'"
  return 1
}

# Check if cluster is running
check_cluster_running() {
  local cluster="$1"
  local provider="$2"
  
  log_message "INFO" "Checking if cluster '$cluster' is running"
  
  case "$provider" in
    minikube)
      local status
      status=$(minikube status -p "$cluster" -o json 2>/dev/null | jq -r '.Host')
      if [[ "$status" == "Running" ]]; then
        return 0
      fi
      ;;
      
    kind)
      # For kind, check if the Docker containers are running
      local container
      container="$(kind get kubeconfig --name "$cluster" 2>/dev/null | grep server | awk '{print $2}' | cut -d/ -f3 | cut -d: -f1)"
      if [[ -n "$container" ]] && docker ps --format '{{.Names}}' | grep -q "$container"; then
        return 0
      fi
      ;;
      
    k3d)
      # For k3d, check if the cluster is in the running state
      if k3d cluster list -o json 2>/dev/null | jq -r '.[] | select(.name=="'"$cluster"'") | .servers[].state' | grep -q "running"; then
        return 0
      fi
      ;;
  esac
  
  log_message "WARNING" "Cluster '$cluster' is not running"
  return 1
}

# Save cluster state for future resume
save_cluster_state() {
  local cluster="$1"
  local provider="$2"
  
  log_message "INFO" "Saving cluster state for '$cluster'"
  
  # Create state directory if it doesn't exist
  mkdir -p "$STATE_DIR"
  
  # Create a state file with information about the cluster
  local state_file="$STATE_DIR/${cluster}-${provider}.state"
  
  log_message "INFO" "Creating state file: $state_file"
  
  # Get current timestamp
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  # Start writing state information
  cat > "$state_file" << EOF
# Kubernetes cluster state file
# Generated by pause-cluster.sh on $timestamp
CLUSTER_NAME=$cluster
PROVIDER=$provider
PAUSED_AT=$timestamp
EOF
  
  # Add provider-specific state information
  case "$provider" in
    minikube)
      # Save minikube-specific state
      minikube profile list -o json | jq '.valid[] | select(.Name=="'"$cluster"'")' >> "$state_file"
      ;;
      
    kind)
      # Save kind-specific state
      kind get kubeconfig --name "$cluster" 2>/dev/null > "$STATE_DIR/${cluster}-kind-kubeconfig.yaml"
      echo "KUBECONFIG_SAVED=true" >> "$state_file"
      ;;
      
    k3d)
      # Save k3d-specific state
      k3d cluster list -o json | jq '.[] | select(.name=="'"$cluster"'")' >> "$state_file"
      ;;
  esac
  
  # Save current workloads if backup is enabled
  if [[ "$BACKUP_WORKLOADS" == true ]]; then
    log_message "INFO" "Backing up workloads for future resume"
    
    # Create a backup directory for this cluster
    local backup_dir="$STATE_DIR/$cluster-backup"
    mkdir -p "$backup_dir"
    
    # Temporary switch kubectl context to this cluster
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null || echo "")
    
    # Try to use the correct context for this cluster
    if ! kubectl config use-context "$cluster" &>/dev/null; then
      case "$provider" in
        minikube)
          kubectl config use-context "$cluster" &>/dev/null
          ;;
        kind)
          kubectl config use-context "kind-$cluster" &>/dev/null
          ;;
        k3d)
          kubectl config use-context "k3d-$cluster" &>/dev/null
          ;;
      esac
    fi
    
    # Backup key resources
    log_message "INFO" "Backing up deployments..."
    kubectl get deployments --all-namespaces -o yaml > "$backup_dir/deployments.yaml" 2>/dev/null
    
    log_message "INFO" "Backing up services..."
    kubectl get services --all-namespaces -o yaml > "$backup_dir/services.yaml" 2>/dev/null
    
    log_message "INFO" "Backing up configmaps..."
    kubectl get configmaps --all-namespaces -o yaml > "$backup_dir/configmaps.yaml" 2>/dev/null
    
    log_message "INFO" "Backing up secrets..."
    kubectl get secrets --all-namespaces -o yaml > "$backup_dir/secrets.yaml" 2>/dev/null
    
    log_message "INFO" "Backing up persistent volumes..."
    kubectl get pv -o yaml > "$backup_dir/persistent-volumes.yaml" 2>/dev/null
    
    log_message "INFO" "Backing up persistent volume claims..."
    kubectl get pvc --all-namespaces -o yaml > "$backup_dir/persistent-volume-claims.yaml" 2>/dev/null
    
    # Switch back to the original context
    if [[ -n "$current_context" ]]; then
      kubectl config use-context "$current_context" &>/dev/null
    fi
    
    log_message "SUCCESS" "Workloads backed up to $backup_dir"
    echo "WORKLOADS_BACKUP_DIR=$backup_dir" >> "$state_file"
  fi
  
  # Save kubeconfig if needed
  if [[ "$PRESERVE_KUBECONFIG" == true ]]; then
    log_message "INFO" "Preserving kubeconfig context"
    
    # Save the kubeconfig for this cluster only
    case "$provider" in
      minikube)
        minikube update-context -p "$cluster" 2>/dev/null
        kubectl config view --minify --flatten --context="$cluster" > "$STATE_DIR/${cluster}-kubeconfig.yaml" 2>/dev/null
        ;;
      kind)
        kind get kubeconfig --name "$cluster" > "$STATE_DIR/${cluster}-kubeconfig.yaml" 2>/dev/null
        ;;
      k3d)
        k3d kubeconfig get "$cluster" > "$STATE_DIR/${cluster}-kubeconfig.yaml" 2>/dev/null
        ;;
    esac
    
    if [[ -f "$STATE_DIR/${cluster}-kubeconfig.yaml" ]]; then
      log_message "SUCCESS" "Kubeconfig preserved at $STATE_DIR/${cluster}-kubeconfig.yaml"
      echo "KUBECONFIG_SAVED=true" >> "$state_file"
      echo "KUBECONFIG_PATH=$STATE_DIR/${cluster}-kubeconfig.yaml" >> "$state_file"
    else
      log_message "WARNING" "Failed to preserve kubeconfig"
    fi
  fi
  
  log_message "SUCCESS" "Cluster state saved to $state_file"
  return 0
}

# Drain nodes for graceful shutdown
drain_cluster_nodes() {
  local cluster="$1"
  local provider="$2"
  
  if [[ "$DRAIN_NODES" != true ]]; then
    log_message "INFO" "Node draining skipped as requested"
    return 0
  fi
  
  log_message "INFO" "Draining nodes for cluster '$cluster'"
  
  # Temporary switch kubectl context to this cluster
  local current_context
  current_context=$(kubectl config current-context 2>/dev/null || echo "")
  
  # Try to use the correct context for this cluster
  local context_set=false
  if kubectl config use-context "$cluster" &>/dev/null; then
    context_set=true
  else
    case "$provider" in
      minikube)
        if kubectl config use-context "$cluster" &>/dev/null; then
          context_set=true
        fi
        ;;
      kind)
        if kubectl config use-context "kind-$cluster" &>/dev/null; then
          context_set=true
        fi
        ;;
      k3d)
        if kubectl config use-context "k3d-$cluster" &>/dev/null; then
          context_set=true
        fi
        ;;
    esac
  fi
  
  if [[ "$context_set" != true ]]; then
    log_message "WARNING" "Could not set kubectl context for draining nodes"
    return 1
  fi
  
  # Get list of nodes
  local nodes
  nodes=$(kubectl get nodes -o name 2>/dev/null)
  
  if [[ -z "$nodes" ]]; then
    log_message "WARNING" "No nodes found to drain"
    
    # Switch back to the original context
    if [[ -n "$current_context" ]]; then
      kubectl config use-context "$current_context" &>/dev/null
    fi
    
    return 1
  fi
  
  # Cordon and drain each node
  for node in $nodes; do
    local node_name
    node_name=$(echo "$node" | cut -d/ -f2)
    
    log_message "INFO" "Cordoning node $node_name"
    kubectl cordon "$node_name" --timeout="${WAIT_TIMEOUT}s" &>/dev/null
    
    log_message "INFO" "Draining node $node_name"
    kubectl drain "$node_name" --ignore-daemonsets --delete-emptydir-data --force --timeout="${WAIT_TIMEOUT}s" &>/dev/null
    
    if [[ $? -eq 0 ]]; then
      log_message "SUCCESS" "Node $node_name drained successfully"
    else
      log_message "WARNING" "Failed to drain node $node_name completely, continuing anyway"
    fi
  done
  
  # Switch back to the original context
  if [[ -n "$current_context" ]]; then
    kubectl config use-context "$current_context" &>/dev/null
  fi
  
  log_message "SUCCESS" "All nodes drained for cluster '$cluster'"
  return 0
}

# Create snapshots of the cluster state if supported
create_cluster_snapshot() {
  local cluster="$1"
  local provider="$2"
  
  if [[ "$SNAPSHOTS" != true ]]; then
    log_message "INFO" "Snapshot creation skipped as not requested"
    return 0
  fi
  
  log_message "INFO" "Creating snapshot for cluster '$cluster'"
  
  case "$provider" in
    minikube)
      # Minikube doesn't have built-in snapshot capability, so we'll save the VM state
      local snapshot_name="${cluster}_$(date +%Y%m%d%H%M%S)"
      log_message "INFO" "Creating minikube snapshot: $snapshot_name"
      
      # Check the VM driver in use
      local driver
      driver=$(minikube profile list -o json | jq -r '.valid[] | select(.Name=="'"$cluster"'") | .Config.Driver')
      
      if [[ "$driver" == "virtualbox" ]]; then
        # VirtualBox has snapshot capability
        if command_exists VBoxManage; then
          local vm_name
          vm_name="minikube"
          if [[ "$cluster" != "minikube" ]]; then
            vm_name="$cluster"
          fi
          
          VBoxManage snapshot "$vm_name" take "$snapshot_name" &>/dev/null
          if [[ $? -eq 0 ]]; then
            log_message "SUCCESS" "Created VirtualBox snapshot: $snapshot_name"
            echo "SNAPSHOT_CREATED=true" >> "$STATE_DIR/${cluster}-${provider}.state"
            echo "SNAPSHOT_NAME=$snapshot_name" >> "$STATE_DIR/${cluster}-${provider}.state"
            echo "SNAPSHOT_DRIVER=virtualbox" >> "$STATE_DIR/${cluster}-${provider}.state"
            return 0
          else
            log_message "WARNING" "Failed to create VirtualBox snapshot"
          fi
        else
          log_message "WARNING" "VBoxManage command not found, cannot create snapshot"
        fi
      elif [[ "$driver" == "hyperkit" || "$driver" == "hyperv" || "$driver" == "kvm" || "$driver" == "kvm2" ]]; then
        log_message "WARNING" "Snapshot not supported for $driver driver"
      else
        log_message "WARNING" "Snapshot not supported for $driver driver"
      fi
      ;;
      
    kind)
      # Kind doesn't have built-in snapshot capability, but we can save container snapshots
      log_message "INFO" "Creating Docker container snapshots for kind cluster"
      
      # Get the Docker container IDs for this cluster
      local containers
      containers=$(docker ps --filter "name=kind-${cluster}" --format "{{.ID}}")
      
      if [[ -z "$containers" ]]; then
        log_message "WARNING" "No Docker containers found for kind cluster: $cluster"
        return 1
      fi
      
      # Create a snapshot directory
      local snapshot_dir="$STATE_DIR/${cluster}-snapshot-$(date +%Y%m%d%H%M%S)"
      mkdir -p "$snapshot_dir"
      
      # Save container information and state
      for container_id in $containers; do
        local container_name
        container_name=$(docker inspect --format "{{.Name}}" "$container_id" | sed 's|^/||')
        
        log_message "INFO" "Creating snapshot for container: $container_name"
        
        # Save container details
        docker inspect "$container_id" > "$snapshot_dir/$container_name.json"
        
        log_message "SUCCESS" "Saved container information for $container_name"
      done
      
      log_message "SUCCESS" "Container information saved to $snapshot_dir"
      echo "SNAPSHOT_CREATED=true" >> "$STATE_DIR/${cluster}-${provider}.state"
      echo "SNAPSHOT_DIR=$snapshot_dir" >> "$STATE_DIR/${cluster}-${provider}.state"
      ;;
      
    k3d)
      # K3d doesn't have built-in snapshot capability, but we can save container snapshots
      # similar to kind approach
      log_message "INFO" "Creating Docker container snapshots for k3d cluster"
      
      # Get the Docker container IDs for this cluster
      local containers
      containers=$(docker ps --filter "name=k3d-${cluster}" --format "{{.ID}}")
      
      if [[ -z "$containers" ]]; then
        log_message "WARNING" "No Docker containers found for k3d cluster: $cluster"
        return 1
      fi
      
      # Create a snapshot directory
      local snapshot_dir="$STATE_DIR/${cluster}-snapshot-$(date +%Y%m%d%H%M%S)"
      mkdir -p "$snapshot_dir"
      
      # Save container information and state
      for container_id in $containers; do
        local container_name
        container_name=$(docker inspect --format "{{.Name}}" "$container_id" | sed 's|^/||')
        
        log_message "INFO" "Creating snapshot for container: $container_name"
        
        # Save container details
        docker inspect "$container_id" > "$snapshot_dir/$container_name.json"
        
        log_message "SUCCESS" "Saved container information for $container_name"
      done
      
      log_message "SUCCESS" "Container information saved to $snapshot_dir"
      echo "SNAPSHOT_CREATED=true" >> "$STATE_DIR/${cluster}-${provider}.state"
      echo "SNAPSHOT_DIR=$snapshot_dir" >> "$STATE_DIR/${cluster}-${provider}.state"
      ;;
  esac
  
  log_message "INFO" "Snapshot process complete"
  return 0
}

# Pause the cluster based on provider
pause_cluster() {
  local cluster="$1"
  local provider="$2"
  
  log_message "INFO" "Pausing cluster '$cluster' using provider '$provider'"
  
  case "$provider" in
    minikube)
      # First try the pause feature (for newer minikube versions)
      if minikube help | grep -q "pause"; then
        log_message "INFO" "Using minikube pause feature"
        minikube pause -p "$cluster"
        if [[ $? -eq 0 ]]; then
          log_message "SUCCESS" "Minikube cluster '$cluster' paused successfully"
          return 0
        else
          log_message "WARNING" "Failed to pause cluster using minikube pause, falling back to stop"
        fi
      fi
      
      # Fall back to stopping the cluster
      log_message "INFO" "Stopping minikube cluster '$cluster'"
      minikube stop -p "$cluster"
      if [[ $? -eq 0 ]]; then
        log_message "SUCCESS" "Minikube cluster '$cluster' stopped successfully"
        return 0
      else
        log_message "ERROR" "Failed to stop minikube cluster '$cluster'"
        return 1
      fi
      ;;
      
    kind)
      # kind doesn't have a built-in pause feature, so we'll stop the Docker containers
      log_message "INFO" "Stopping Docker containers for kind cluster '$cluster'"
      
      # Get the Docker containers for this cluster
      local containers
      containers=$(docker ps --filter "name=kind-${cluster}" --format "{{.ID}}")
      
      if [[ -z "$containers" ]]; then
        log_message "ERROR" "No running Docker containers found for kind cluster: $cluster"
        return 1
      fi
      
      # Stop each container
      for container_id in $containers; do
        local container_name
        container_name=$(docker inspect --format "{{.Name}}" "$container_id" | sed 's|^/||')
        
        log_message "INFO" "Stopping container: $container_name"
        docker stop "$container_id" > /dev/null
        
        if [[ $? -eq 0 ]]; then
          log_message "SUCCESS" "Container $container_name stopped successfully"
        else
          log_message "ERROR" "Failed to stop container $container_name"
          return 1
        fi
      done
      
      log_message "SUCCESS" "Kind cluster '$cluster' paused successfully"
      return 0
      ;;
      
    k3d)
      # k3d has a stop feature
      log_message "INFO" "Stopping k3d cluster '$cluster'"
      k3d cluster stop "$cluster"
      
      if [[ $? -eq 0 ]]; then
        log_message "SUCCESS" "K3d cluster '$cluster' stopped successfully"
        return 0
      else
        log_message "ERROR" "Failed to stop k3d cluster '$cluster'"
        return 1
      fi
      ;;
      
    *)
      log_message "ERROR" "Unsupported provider: $provider"
      return 1
      ;;
  esac
  
  return 1
}

# Write resume instructions
write_resume_instructions() {
  local cluster="$1"
  local provider="$2"
  local state_file="$STATE_DIR/${cluster}-${provider}.state"
  
  if [[ ! -f "$state_file" ]]; then
    log_message "WARNING" "State file not found, cannot provide resume instructions"
    return 1
  fi
  
  local resume_script="$STATE_DIR/resume-${cluster}.sh"
  
  log_message "INFO" "Creating resume script: $resume_script"
  
  # Create the resume script with appropriate commands
  cat > "$resume_script" << 'EOF'
#!/bin/bash
# Auto-generated script to resume a paused Kubernetes cluster
# Generated by pause-cluster.sh

set -e

# Load the state file
if [[ ! -f "${STATE_FILE}" ]]; then
  echo "Error: State file not found: ${STATE_FILE}"
  exit 1
fi

source "${STATE_FILE}"

echo "Resuming cluster: ${CLUSTER_NAME} (${PROVIDER})"

# Resume based on provider
case "${PROVIDER}" in
  minikube)
    echo "Starting minikube cluster: ${CLUSTER_NAME}"
    minikube start -p "${CLUSTER_NAME}"
    ;;
    
  kind)
    echo "Starting kind cluster: ${CLUSTER_NAME}"
    # Start the Docker containers
    CONTAINERS=$(docker ps -a --filter "name=kind-${CLUSTER_NAME}" --format "{{.ID}}")
    if [[ -z "${CONTAINERS}" ]]; then
      echo "Error: No Docker containers found for kind cluster: ${CLUSTER_NAME}"
      exit 1
    fi
    
    for CONTAINER_ID in ${CONTAINERS}; do
      CONTAINER_NAME=$(docker inspect --format "{{.Name}}" "${CONTAINER_ID}" | sed 's|^/||')
      echo "Starting container: ${CONTAINER_NAME}"
      docker start "${CONTAINER_ID}"
    done
    ;;
    
  k3d)
    echo "Starting k3d cluster: ${CLUSTER_NAME}"
    k3d cluster start "${CLUSTER_NAME}"
    ;;
    
  *)
    echo "Error: Unsupported provider: ${PROVIDER}"
    exit 1
    ;;
esac

# Restore the kubeconfig if it was saved
if [[ "${KUBECONFIG_SAVED}" == "true" && -n "${KUBECONFIG_PATH}" ]]; then
  echo "Restoring kubeconfig from: ${KUBECONFIG_PATH}"
  if [[ -f "${KUBECONFIG_PATH}" ]]; then
    export KUBECONFIG="${KUBECONFIG_PATH}"
    echo "Run the following command to use the kubeconfig:"
    echo "export KUBECONFIG=${KUBECONFIG_PATH}"
  else
    echo "Warning: Kubeconfig file not found: ${KUBECONFIG_PATH}"
  fi
fi

echo "Cluster ${CLUSTER_NAME} resumed successfully."
echo "Note: Workloads may take some time to start up completely."

if [[ -n "${WORKLOADS_BACKUP_DIR}" && -d "${WORKLOADS_BACKUP_DIR}" ]]; then
  echo
  echo "Workloads were backed up to: ${WORKLOADS_BACKUP_DIR}"
  echo "You can restore them if needed with:"
  echo "kubectl apply -f ${WORKLOADS_BACKUP_DIR}/deployments.yaml"
  echo "kubectl apply -f ${WORKLOADS_BACKUP_DIR}/services.yaml"
  echo "# And other resources as needed"
fi
EOF
  
  # Make it executable
  chmod +x "$resume_script"
  
  # Create a wrapper script with the state file path
  cat > "${resume_script}.tmp" << EOF
#!/bin/bash
# Wrapper script to resume $cluster cluster

export STATE_FILE="$state_file"
$(cat "$resume_script")
EOF
  
  mv "${resume_script}.tmp" "$resume_script"
  chmod +x "$resume_script"
  
  log_message "SUCCESS" "Resume script created: $resume_script"
  echo
  log_message "INFO" "To resume this cluster later, run:"
  echo "  $resume_script"
  
  return 0
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--name)
        CLUSTER_NAME="$2"
        shift 2
        ;;
      -p|--provider)
        PROVIDER="$2"
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
      --no-drain)
        DRAIN_NODES=false
        shift
        ;;
      --no-backup)
        BACKUP_WORKLOADS=false
        shift
        ;;
      --snapshot)
        SNAPSHOTS=true
        shift
        ;;
      --no-preserve-config)
        PRESERVE_KUBECONFIG=false
        shift
        ;;
      --state-dir)
        STATE_DIR="$2"
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
  
  # Validate required arguments
  if [[ -z "$CLUSTER_NAME" ]]; then
    log_message "ERROR" "Cluster name (-n, --name) is required"
    usage
  fi
}

# Main function
main() {
  # Parse arguments
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Kubernetes Cluster Pause Script"
  
  log_message "INFO" "Starting cluster pause process..."
  
  # Auto-detect provider if not specified
  if [[ "$PROVIDER" == "auto" ]]; then
    PROVIDER=$(detect_provider "$CLUSTER_NAME")
    if [[ $? -ne 0 ]]; then
      log_message "ERROR" "Failed to auto-detect provider for cluster '$CLUSTER_NAME'"
      exit 1
    fi
  fi
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Cluster Name:        $CLUSTER_NAME"
  log_message "INFO" "  Provider:            $PROVIDER"
  log_message "INFO" "  Force:               $FORCE"
  log_message "INFO" "  Wait Timeout:        $WAIT_TIMEOUT seconds"
  log_message "INFO" "  Drain Nodes:         $DRAIN_NODES"
  log_message "INFO" "  Backup Workloads:    $BACKUP_WORKLOADS"
  log_message "INFO" "  Create Snapshots:    $SNAPSHOTS"
  log_message "INFO" "  Preserve Kubeconfig: $PRESERVE_KUBECONFIG"
  log_message "INFO" "  State Directory:     $STATE_DIR"
  
  # Check if the cluster exists
  if ! check_cluster_exists "$CLUSTER_NAME" "$PROVIDER"; then
    log_message "ERROR" "Cluster '$CLUSTER_NAME' does not exist for provider '$PROVIDER'"
    exit 1
  fi
  
  # Check if the cluster is running
  if ! check_cluster_running "$CLUSTER_NAME" "$PROVIDER"; then
    log_message "WARNING" "Cluster '$CLUSTER_NAME' is not running, cannot pause"
    
    # If not forcing, ask for confirmation to continue
    if [[ "$FORCE" != true ]]; then
      read -p "Would you like to continue with saving the state? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_message "INFO" "Operation cancelled by user."
        exit 0
      fi
    fi
  fi
  
  # Save cluster state
  if ! save_cluster_state "$CLUSTER_NAME" "$PROVIDER"; then
    log_message "ERROR" "Failed to save cluster state"
    exit 1
  fi
  
  # If the cluster is running, drain nodes and pause it
  if check_cluster_running "$CLUSTER_NAME" "$PROVIDER"; then
    # Drain nodes if requested
    if [[ "$DRAIN_NODES" == true ]]; then
      drain_cluster_nodes "$CLUSTER_NAME" "$PROVIDER"
    fi
    
    # Create snapshots if requested
    if [[ "$SNAPSHOTS" == true ]]; then
      create_cluster_snapshot "$CLUSTER_NAME" "$PROVIDER"
    fi
    
    # Confirm before pausing if not forced
    if [[ "$FORCE" != true ]]; then
      read -p "Are you sure you want to pause cluster '$CLUSTER_NAME'? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_message "INFO" "Operation cancelled by user."
        exit 0
      fi
    fi
    
    # Pause the cluster
    if ! pause_cluster "$CLUSTER_NAME" "$PROVIDER"; then
      log_message "ERROR" "Failed to pause cluster"
      exit 1
    fi
  fi
  
  # Write resume instructions
  write_resume_instructions "$CLUSTER_NAME" "$PROVIDER"
  
  print_with_separator "End of Kubernetes Cluster Pause"
  
  # Final summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  echo -e "Cluster \033[1;32m${CLUSTER_NAME}\033[0m successfully paused."
  echo -e "State saved to: \033[1;32m$STATE_DIR/${CLUSTER_NAME}-${PROVIDER}.state\033[0m"
  echo -e "To resume later, run: \033[1m$STATE_DIR/resume-${CLUSTER_NAME}.sh\033[0m"
}

# Run the main function
main "$@"