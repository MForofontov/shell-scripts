#!/bin/bash
# resume-cluster.sh
# Script to resume paused Kubernetes clusters with additional validation

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../..../functions/log/log-with-levels.sh"
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
PROVIDER="auto"
STATE_FILE=""
STATE_DIR="$HOME/.kube/cluster-states"
WAIT_TIMEOUT=300
LOG_FILE="/dev/null"
VERBOSE=false
RESTORE_WORKLOADS=false
SKIP_VALIDATION=false
FORCE=false
TIMEOUT_MULTIPLIER=5  # For waiting for resources to stabilize

# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Resume Tool"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script resumes paused/hibernated Kubernetes clusters with validation."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-n, --name <NAME>\033[0m           (Required) Cluster name to resume"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m   (Optional) Provider to use (minikube, kind, k3d) (default: auto-detect)"
  echo -e "  \033[1;33m-s, --state-file <FILE>\033[0m     (Optional) Path to the specific state file to use"
  echo -e "  \033[1;33m--state-dir <DIR>\033[0m           (Optional) Directory with state files (default: ${STATE_DIR})"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m     (Optional) Timeout in seconds for operations (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--restore-workloads\033[0m         (Optional) Restore backed up workloads"
  echo -e "  \033[1;33m--skip-validation\033[0m           (Optional) Skip post-resume validation"
  echo -e "  \033[1;33m-f, --force\033[0m                 (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m-v, --verbose\033[0m               (Optional) Show more detailed output"
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster"
  echo "  $0 --name test-cluster --provider kind"
  echo "  $0 --state-file /path/to/my-cluster-kind.state"
  echo "  $0 --name dev-cluster --restore-workloads"
  print_with_separator
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Auto-detect provider based on cluster name (simplified version)
detect_provider() {
  local cluster="$1"
  
  log_message "INFO" "Auto-detecting provider for cluster: $cluster"
  
  # Check for minikube clusters
  if command_exists minikube; then
    if minikube profile list 2>/dev/null | grep -q "$cluster"; then
      log_message "INFO" "Detected provider: minikube"
      echo "minikube"
      return 0
    fi
  fi
  
  # Check for kind clusters
  if command_exists kind; then
    if kind get clusters 2>/dev/null | grep -q "$cluster"; then
      log_message "INFO" "Detected provider: kind"
      echo "kind"
      return 0
    fi
  fi
  
  # Check for k3d clusters
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

# Find state file for a cluster
find_state_file() {
  local cluster="$1"
  local provider="$2"
  
  log_message "INFO" "Looking for state file for cluster '$cluster'"
  
  # If provider is specified, try that specific file
  if [[ "$provider" != "auto" ]]; then
    local specific_file="$STATE_DIR/${cluster}-${provider}.state"
    if [[ -f "$specific_file" ]]; then
      log_message "INFO" "Found state file: $specific_file"
      echo "$specific_file"
      return 0
    fi
  fi
  
  # Try all possible providers
  for p in minikube kind k3d; do
    local possible_file="$STATE_DIR/${cluster}-${p}.state"
    if [[ -f "$possible_file" ]]; then
      log_message "INFO" "Found state file: $possible_file"
      echo "$possible_file"
      return 0
    fi
  done
  
  # Try any file that matches the cluster name
  local found_file=$(find "$STATE_DIR" -name "${cluster}*.state" -type f | head -n 1)
  if [[ -n "$found_file" ]]; then
    log_message "INFO" "Found state file: $found_file"
    echo "$found_file"
    return 0
  fi
  
  log_message "ERROR" "Could not find state file for cluster: $cluster"
  return 1
}

# Resume the cluster
resume_cluster() {
  local cluster="$1"
  local provider="$2"
  local state_file="$3"
  
  log_message "INFO" "Resuming cluster '$cluster' using provider '$provider'"
  
  # Load the state file
  if [[ ! -f "$state_file" ]]; then
    log_message "ERROR" "State file not found: $state_file"
    return 1
  fi
  
  # Source the state file to get variables
  source "$state_file"
  
  # Make sure the cluster info matches
  if [[ "$CLUSTER_NAME" != "$cluster" || "$PROVIDER" != "$provider" ]]; then
    log_message "WARNING" "State file contains different cluster info: $CLUSTER_NAME/$PROVIDER"
    if [[ "$FORCE" != true ]]; then
      read -p "Continue anyway? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_message "INFO" "Operation cancelled by user."
        return 1
      fi
    fi
  fi
  
  # Resume based on provider
  case "$provider" in
    minikube)
      log_message "INFO" "Starting minikube cluster: $cluster"
      minikube start -p "$cluster"
      if [[ $? -ne 0 ]]; then
        log_message "ERROR" "Failed to start minikube cluster: $cluster"
        return 1
      fi
      ;;
      
    kind)
      log_message "INFO" "Starting kind cluster: $cluster"
      
      # Start the Docker containers
      local containers
      containers=$(docker ps -a --filter "name=kind-${cluster}" --format "{{.ID}}")
      
      if [[ -z "$containers" ]]; then
        log_message "ERROR" "No Docker containers found for kind cluster: $cluster"
        return 1
      fi
      
      for container_id in $containers; do
        local container_name
        container_name=$(docker inspect --format "{{.Name}}" "$container_id" | sed 's|^/||')
        
        log_message "INFO" "Starting container: $container_name"
        docker start "$container_id" > /dev/null
        
        if [[ $? -ne 0 ]]; then
          log_message "ERROR" "Failed to start container: $container_name"
          return 1
        fi
      done
      ;;
      
    k3d)
      log_message "INFO" "Starting k3d cluster: $cluster"
      k3d cluster start "$cluster"
      if [[ $? -ne 0 ]]; then
        log_message "ERROR" "Failed to start k3d cluster: $cluster"
        return 1
      fi
      ;;
      
    *)
      log_message "ERROR" "Unsupported provider: $provider"
      return 1
      ;;
  esac
  
  log_message "SUCCESS" "Cluster '$cluster' resumed successfully"
  return 0
}

# Restore kubeconfig
restore_kubeconfig() {
  local state_file="$1"
  
  # Get KUBECONFIG_PATH from state file if it's not already set
  if [ -z "$KUBECONFIG_PATH" ]; then
    source "$state_file"
  fi
  
  if [[ "$KUBECONFIG_SAVED" == "true" && -n "$KUBECONFIG_PATH" ]]; then
    log_message "INFO" "Restoring kubeconfig from: $KUBECONFIG_PATH"
    
    if [[ -f "$KUBECONFIG_PATH" ]]; then
      export KUBECONFIG="$KUBECONFIG_PATH"
      log_message "SUCCESS" "Kubeconfig restored"
      log_message "INFO" "Run the following command to use this kubeconfig:"
      log_message "INFO" "  export KUBECONFIG=$KUBECONFIG_PATH"
      return 0
    else
      log_message "WARNING" "Kubeconfig file not found: $KUBECONFIG_PATH"
      return 1
    fi
  else
    log_message "INFO" "No kubeconfig to restore"
    return 0
  fi
}

# Restore workloads from backup
restore_workloads() {
  local state_file="$1"
  
  # Get WORKLOADS_BACKUP_DIR from state file if it's not already set
  if [ -z "$WORKLOADS_BACKUP_DIR" ]; then
    source "$state_file"
  fi
  
  if [[ -n "$WORKLOADS_BACKUP_DIR" && -d "$WORKLOADS_BACKUP_DIR" ]]; then
    log_message "INFO" "Restoring workloads from backup: $WORKLOADS_BACKUP_DIR"
    
    # Check if kubectl is available
    if ! command_exists kubectl; then
      log_message "ERROR" "kubectl not found, cannot restore workloads"
      return 1
    fi
    
    # Get a list of all backup YAML files
    local backup_files=($(find "$WORKLOADS_BACKUP_DIR" -name "*.yaml" -type f))
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
      log_message "WARNING" "No backup files found in $WORKLOADS_BACKUP_DIR"
      return 1
    fi
    
    # Apply each file with confirmation
    log_message "INFO" "Found ${#backup_files[@]} backup files"
    
    if [[ "$FORCE" != true ]]; then
      read -p "Do you want to restore all workloads? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_message "INFO" "Workload restoration skipped by user"
        return 0
      fi
    fi
    
    # Apply namespace definitions first
    if [[ -f "$WORKLOADS_BACKUP_DIR/namespaces.yaml" ]]; then
      log_message "INFO" "Restoring namespaces..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/namespaces.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    # Apply ConfigMaps and Secrets next
    if [[ -f "$WORKLOADS_BACKUP_DIR/configmaps.yaml" ]]; then
      log_message "INFO" "Restoring ConfigMaps..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/configmaps.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    if [[ -f "$WORKLOADS_BACKUP_DIR/secrets.yaml" ]]; then
      log_message "INFO" "Restoring Secrets..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/secrets.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    # Apply PVs and PVCs
    if [[ -f "$WORKLOADS_BACKUP_DIR/persistent-volumes.yaml" ]]; then
      log_message "INFO" "Restoring Persistent Volumes..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/persistent-volumes.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    if [[ -f "$WORKLOADS_BACKUP_DIR/persistent-volume-claims.yaml" ]]; then
      log_message "INFO" "Restoring Persistent Volume Claims..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/persistent-volume-claims.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    # Apply Services
    if [[ -f "$WORKLOADS_BACKUP_DIR/services.yaml" ]]; then
      log_message "INFO" "Restoring Services..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/services.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    # Finally, apply Deployments and other workloads
    if [[ -f "$WORKLOADS_BACKUP_DIR/deployments.yaml" ]]; then
      log_message "INFO" "Restoring Deployments..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/deployments.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    log_message "SUCCESS" "Workloads restored successfully"
    return 0
  else
    log_message "INFO" "No workload backups to restore"
    return 0
  fi
}

# Validate cluster is running properly
validate_cluster() {
  local cluster="$1"
  local provider="$2"
  
  if [[ "$SKIP_VALIDATION" == true ]]; then
    log_message "INFO" "Validation skipped as requested"
    return 0
  fi
  
  log_message "INFO" "Validating cluster '$cluster' health..."
  
  # Check if kubectl is available
  if ! command_exists kubectl; then
    log_message "ERROR" "kubectl not found, cannot validate cluster"
    return 1
  fi
  
  # Set context to this cluster
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
    log_message "WARNING" "Could not set kubectl context, validation may be incomplete"
  fi
  
  # Wait for the cluster to stabilize
  log_message "INFO" "Waiting for cluster to stabilize..."
  sleep 5
  
  # Check if kubectl can connect
  log_message "INFO" "Testing API server connectivity..."
  if ! kubectl get nodes &>/dev/null; then
    log_message "ERROR" "Cannot connect to Kubernetes API server"
    return 1
  fi
  
  # Check node status
  log_message "INFO" "Checking node status..."
  local all_nodes_ready=true
  local nodes_output
  nodes_output=$(kubectl get nodes -o wide)
  
  while read -r line; do
    if echo "$line" | grep -q "NotReady"; then
      all_nodes_ready=false
      break
    fi
  done <<< "$nodes_output"
  
  if [[ "$all_nodes_ready" != true ]]; then
    log_message "WARNING" "Not all nodes are ready. Current status:"
    echo "$nodes_output"
  else
    log_message "SUCCESS" "All nodes are in Ready state"
  fi
  
  # Check system pods
  log_message "INFO" "Checking system pods..."
  local all_system_pods_running=true
  local pods_output
  pods_output=$(kubectl get pods -n kube-system)
  
  while read -r line; do
    if echo "$line" | grep -q -E 'Pending|Failed|Unknown|Error'; then
      all_system_pods_running=false
      break
    fi
  done <<< "$pods_output"
  
  if [[ "$all_system_pods_running" != true ]]; then
    log_message "WARNING" "Not all system pods are running. Current status:"
    echo "$pods_output"
  else
    log_message "SUCCESS" "All system pods are running"
  fi
  
  # Check for restored workloads if applicable
  if [[ "$RESTORE_WORKLOADS" == true ]]; then
    log_message "INFO" "Checking restored workload status..."
    local all_workloads_running=true
    local workload_output
    workload_output=$(kubectl get deployments --all-namespaces)
    
    while read -r line; do
      if echo "$line" | grep -v "NAMESPACE" | awk '{split($5,a,"/"); if (a[1] != a[2]) print $0}' | grep -q .; then
        all_workloads_running=false
        break
      fi
    done <<< "$workload_output"
    
    if [[ "$all_workloads_running" != true ]]; then
      log_message "WARNING" "Not all workloads are fully ready. Current status:"
      kubectl get deployments --all-namespaces | grep -v "NAMESPACE" | 
        awk '{split($5,a,"/"); if (a[1] != a[2]) print $0}'
    else
      log_message "SUCCESS" "All workloads are running"
    fi
  fi
  
  # Final health check
  if [[ "$all_nodes_ready" == true && "$all_system_pods_running" == true ]]; then
    if [[ "$RESTORE_WORKLOADS" == true && "$all_workloads_running" != true ]]; then
      log_message "WARNING" "Cluster is running but some workloads aren't fully ready"
      log_message "INFO" "You may need to check specific workloads manually"
    else
      log_message "SUCCESS" "Cluster is healthy and ready for use"
    fi
  else
    log_message "WARNING" "Cluster is running but may have issues - check the warnings above"
  fi
  
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
      -s|--state-file)
        STATE_FILE="$2"
        shift 2
        ;;
      --state-dir)
        STATE_DIR="$2"
        shift 2
        ;;
      -t|--timeout)
        WAIT_TIMEOUT="$2"
        shift 2
        ;;
      --restore-workloads)
        RESTORE_WORKLOADS=true
        shift
        ;;
      --skip-validation)
        SKIP_VALIDATION=true
        shift
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
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
        log_message "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  # Validate required arguments
  if [[ -z "$CLUSTER_NAME" && -z "$STATE_FILE" ]]; then
    log_message "ERROR" "Either cluster name (-n, --name) or state file (-s, --state-file) is required"
    usage
  fi
}

# Main function
main() {
  print_with_separator "Kubernetes Cluster Resume"
  
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
  
  log_message "INFO" "Starting cluster resume process..."
  
  # If state file is provided, extract cluster name and provider from it
  if [[ -n "$STATE_FILE" ]]; then
    if [[ ! -f "$STATE_FILE" ]]; then
      log_message "ERROR" "Specified state file not found: $STATE_FILE"
      exit 1
    fi
    
    # Source the state file to get the cluster name and provider
    source "$STATE_FILE"
    
    # Update variables
    CLUSTER_NAME="$CLUSTER_NAME"
    PROVIDER="$PROVIDER"
    
    log_message "INFO" "Loaded state file: $STATE_FILE"
    log_message "INFO" "Cluster: $CLUSTER_NAME, Provider: $PROVIDER"
  else
    # Auto-detect provider if not specified
    if [[ "$PROVIDER" == "auto" ]]; then
      PROVIDER=$(detect_provider "$CLUSTER_NAME")
      if [[ $? -ne 0 ]]; then
        log_message "ERROR" "Failed to auto-detect provider for cluster '$CLUSTER_NAME'"
        exit 1
      fi
    fi
    
    # Find the state file
    STATE_FILE=$(find_state_file "$CLUSTER_NAME" "$PROVIDER")
    if [[ $? -ne 0 ]]; then
      log_message "ERROR" "Failed to find state file for cluster '$CLUSTER_NAME'"
      exit 1
    fi
  fi
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Cluster Name:      $CLUSTER_NAME"
  log_message "INFO" "  Provider:          $PROVIDER"
  log_message "INFO" "  State File:        $STATE_FILE"
  log_message "INFO" "  Wait Timeout:      $WAIT_TIMEOUT seconds"
  log_message "INFO" "  Restore Workloads: $RESTORE_WORKLOADS"
  log_message "INFO" "  Skip Validation:   $SKIP_VALIDATION"
  log_message "INFO" "  Force:             $FORCE"
  log_message "INFO" "  Verbose:           $VERBOSE"
  
  # Resume the cluster
  if ! resume_cluster "$CLUSTER_NAME" "$PROVIDER" "$STATE_FILE"; then
    log_message "ERROR" "Failed to resume cluster"
    exit 1
  fi
  
  # Restore kubeconfig
  restore_kubeconfig "$STATE_FILE"
  
  # Restore workloads if requested
  if [[ "$RESTORE_WORKLOADS" == true ]]; then
    if ! restore_workloads "$STATE_FILE"; then
      log_message "WARNING" "Issues while restoring workloads"
    fi
  fi
  
  # Validate cluster is running properly
  validate_cluster "$CLUSTER_NAME" "$PROVIDER"
  
  print_with_separator "End of Kubernetes Cluster Resume"
  
  # Final summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  echo -e "Cluster \033[1;32m${CLUSTER_NAME}\033[0m resumed successfully."
  echo -e "To switch to this cluster: \033[1mkubectl config use-context ${CLUSTER_NAME}\033[0m"
  if [[ -n "$KUBECONFIG_PATH" && -f "$KUBECONFIG_PATH" ]]; then
    echo -e "Or use the saved kubeconfig: \033[1mexport KUBECONFIG=${KUBECONFIG_PATH}\033[0m"
  fi
}

# Run the main function
main "$@"