#!/bin/bash
# resume-cluster.sh
# Script to resume paused Kubernetes clusters with additional validation

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
CLUSTER_NAME=""
PROVIDER="auto"
STATE_FILE=""
STATE_DIR="$HOME/.kube/cluster-states"
WAIT_TIMEOUT=300
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
VERBOSE=false
RESTORE_WORKLOADS=false
SKIP_VALIDATION=false
FORCE=false
TIMEOUT_MULTIPLIER=5  # For waiting for resources to stabilize

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Resume Tool"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script resumes paused/hibernated Kubernetes clusters with validation."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m-n, --name <NAME>\033[0m           (Required*) Cluster name to resume"
  echo -e "  \033[1;36m-s, --state-file <FILE>\033[0m     (Required*) Path to the specific state file to use"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m   (Optional) Provider to use (minikube, kind, k3d) (default: auto-detect)"
  echo -e "  \033[1;33m--state-dir <DIR>\033[0m           (Optional) Directory with state files (default: ${STATE_DIR})"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m     (Optional) Timeout in seconds for operations (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--restore-workloads\033[0m         (Optional) Restore backed up workloads"
  echo -e "  \033[1;33m--skip-validation\033[0m           (Optional) Skip post-resume validation"
  echo -e "  \033[1;33m-f, --force\033[0m                 (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m-v, --verbose\033[0m               (Optional) Show more detailed output"
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mNotes:\033[0m"
  echo "  * Either --name or --state-file is required."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster"
  echo "  $0 --name test-cluster --provider kind"
  echo "  $0 --state-file /path/to/my-cluster-kind.state"
  echo "  $0 --name dev-cluster --restore-workloads"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
#=====================================================================
# PROVIDER DETECTION
#=====================================================================
# Auto-detect provider based on cluster name (simplified version)
detect_provider() {
  local cluster="$1"
  
  format-echo "INFO" "Auto-detecting provider for cluster: $cluster"
  
  #---------------------------------------------------------------------
  # MINIKUBE DETECTION
  #---------------------------------------------------------------------
  # Check for minikube clusters
  if command_exists minikube; then
    if minikube profile list 2>/dev/null | grep -q "$cluster"; then
      format-echo "INFO" "Detected provider: minikube"
      echo "minikube"
      return 0
    fi
  fi
  
  #---------------------------------------------------------------------
  # KIND DETECTION
  #---------------------------------------------------------------------
  # Check for kind clusters
  if command_exists kind; then
    if kind get clusters 2>/dev/null | grep -q "$cluster"; then
      format-echo "INFO" "Detected provider: kind"
      echo "kind"
      return 0
    fi
  fi
  
  #---------------------------------------------------------------------
  # K3D DETECTION
  #---------------------------------------------------------------------
  # Check for k3d clusters
  if command_exists k3d; then
    if k3d cluster list 2>/dev/null | grep -q "$cluster"; then
      format-echo "INFO" "Detected provider: k3d"
      echo "k3d"
      return 0
    fi
  fi
  
  format-echo "ERROR" "Could not detect provider for cluster: $cluster"
  return 1
}

#=====================================================================
# STATE FILE HANDLING
#=====================================================================
# Find state file for a cluster
find_state_file() {
  local cluster="$1"
  local provider="$2"
  
  format-echo "INFO" "Looking for state file for cluster '$cluster'"
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC STATE FILES
  #---------------------------------------------------------------------
  # If provider is specified, try that specific file
  if [[ "$provider" != "auto" ]]; then
    local specific_file="$STATE_DIR/${cluster}-${provider}.state"
    if [[ -f "$specific_file" ]]; then
      format-echo "INFO" "Found state file: $specific_file"
      echo "$specific_file"
      return 0
    fi
  fi
  
  #---------------------------------------------------------------------
  # MULTI-PROVIDER SEARCH
  #---------------------------------------------------------------------
  # Try all possible providers
  for p in minikube kind k3d; do
    local possible_file="$STATE_DIR/${cluster}-${p}.state"
    if [[ -f "$possible_file" ]]; then
      format-echo "INFO" "Found state file: $possible_file"
      echo "$possible_file"
      return 0
    fi
  done
  
  #---------------------------------------------------------------------
  # FALLBACK SEARCH
  #---------------------------------------------------------------------
  # Try any file that matches the cluster name
  local found_file=$(find "$STATE_DIR" -name "${cluster}*.state" -type f | head -n 1)
  if [[ -n "$found_file" ]]; then
    format-echo "INFO" "Found state file: $found_file"
    echo "$found_file"
    return 0
  fi
  
  format-echo "ERROR" "Could not find state file for cluster: $cluster"
  return 1
}

#=====================================================================
# CLUSTER RESUME OPERATIONS
#=====================================================================
# Resume the cluster
resume_cluster() {
  local cluster="$1"
  local provider="$2"
  local state_file="$3"
  
  format-echo "INFO" "Resuming cluster '$cluster' using provider '$provider'"
  
  #---------------------------------------------------------------------
  # STATE FILE VALIDATION
  #---------------------------------------------------------------------
  # Load the state file
  if [[ ! -f "$state_file" ]]; then
    format-echo "ERROR" "State file not found: $state_file"
    return 1
  fi
  
  # Source the state file to get variables
  source "$state_file"
  
  # Make sure the cluster info matches
  if [[ "$CLUSTER_NAME" != "$cluster" || "$PROVIDER" != "$provider" ]]; then
    format-echo "WARNING" "State file contains different cluster info: $CLUSTER_NAME/$PROVIDER"
    if [[ "$FORCE" != true ]]; then
      read -p "Continue anyway? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        return 1
      fi
    fi
  fi
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC RESUME OPERATIONS
  #---------------------------------------------------------------------
  # Resume based on provider
  case "$provider" in
    minikube)
      format-echo "INFO" "Starting minikube cluster: $cluster"
      minikube start -p "$cluster"
      if [[ $? -ne 0 ]]; then
        format-echo "ERROR" "Failed to start minikube cluster: $cluster"
        return 1
      fi
      ;;
      
    kind)
      format-echo "INFO" "Starting kind cluster: $cluster"
      
      # Start the Docker containers
      local containers
      containers=$(docker ps -a --filter "name=kind-${cluster}" --format "{{.ID}}")
      
      if [[ -z "$containers" ]]; then
        format-echo "ERROR" "No Docker containers found for kind cluster: $cluster"
        return 1
      fi
      
      for container_id in $containers; do
        local container_name
        container_name=$(docker inspect --format "{{.Name}}" "$container_id" | sed 's|^/||')
        
        format-echo "INFO" "Starting container: $container_name"
        docker start "$container_id" > /dev/null
        
        if [[ $? -ne 0 ]]; then
          format-echo "ERROR" "Failed to start container: $container_name"
          return 1
        fi
      done
      ;;
      
    k3d)
      format-echo "INFO" "Starting k3d cluster: $cluster"
      k3d cluster start "$cluster"
      if [[ $? -ne 0 ]]; then
        format-echo "ERROR" "Failed to start k3d cluster: $cluster"
        return 1
      fi
      ;;
      
    *)
      format-echo "ERROR" "Unsupported provider: $provider"
      return 1
      ;;
  esac
  
  format-echo "SUCCESS" "Cluster '$cluster' resumed successfully"
  return 0
}

#=====================================================================
# KUBECONFIG RESTORATION
#=====================================================================
# Restore kubeconfig
restore_kubeconfig() {
  local state_file="$1"
  
  #---------------------------------------------------------------------
  # LOADING KUBECONFIG SETTINGS
  #---------------------------------------------------------------------
  # Get KUBECONFIG_PATH from state file if it's not already set
  if [ -z "$KUBECONFIG_PATH" ]; then
    source "$state_file"
  fi
  
  #---------------------------------------------------------------------
  # KUBECONFIG SETUP
  #---------------------------------------------------------------------
  if [[ "$KUBECONFIG_SAVED" == "true" && -n "$KUBECONFIG_PATH" ]]; then
    format-echo "INFO" "Restoring kubeconfig from: $KUBECONFIG_PATH"
    
    if [[ -f "$KUBECONFIG_PATH" ]]; then
      export KUBECONFIG="$KUBECONFIG_PATH"
      format-echo "SUCCESS" "Kubeconfig restored"
      format-echo "INFO" "Run the following command to use this kubeconfig:"
      format-echo "INFO" "  export KUBECONFIG=$KUBECONFIG_PATH"
      return 0
    else
      format-echo "WARNING" "Kubeconfig file not found: $KUBECONFIG_PATH"
      return 1
    fi
  else
    format-echo "INFO" "No kubeconfig to restore"
    return 0
  fi
}

#=====================================================================
# WORKLOAD RESTORATION
#=====================================================================
# Restore workloads from backup
restore_workloads() {
  local state_file="$1"
  
  #---------------------------------------------------------------------
  # LOADING WORKLOAD BACKUP SETTINGS
  #---------------------------------------------------------------------
  # Get WORKLOADS_BACKUP_DIR from state file if it's not already set
  if [ -z "$WORKLOADS_BACKUP_DIR" ]; then
    source "$state_file"
  fi
  
  if [[ -n "$WORKLOADS_BACKUP_DIR" && -d "$WORKLOADS_BACKUP_DIR" ]]; then
    format-echo "INFO" "Restoring workloads from backup: $WORKLOADS_BACKUP_DIR"
    
    # Check if kubectl is available
    if ! command_exists kubectl; then
      format-echo "ERROR" "kubectl not found, cannot restore workloads"
      return 1
    fi
    
    #---------------------------------------------------------------------
    # BACKUP FILE DISCOVERY
    #---------------------------------------------------------------------
    # Get a list of all backup YAML files
    local backup_files=($(find "$WORKLOADS_BACKUP_DIR" -name "*.yaml" -type f))
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
      format-echo "WARNING" "No backup files found in $WORKLOADS_BACKUP_DIR"
      return 1
    fi
    
    # Apply each file with confirmation
    format-echo "INFO" "Found ${#backup_files[@]} backup files"
    
    if [[ "$FORCE" != true ]]; then
      read -p "Do you want to restore all workloads? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Workload restoration skipped by user"
        return 0
      fi
    fi
    
    #---------------------------------------------------------------------
    # ORDERED RESOURCE RESTORATION
    #---------------------------------------------------------------------
    # Apply namespace definitions first
    if [[ -f "$WORKLOADS_BACKUP_DIR/namespaces.yaml" ]]; then
      format-echo "INFO" "Restoring namespaces..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/namespaces.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    # Apply ConfigMaps and Secrets next
    if [[ -f "$WORKLOADS_BACKUP_DIR/configmaps.yaml" ]]; then
      format-echo "INFO" "Restoring ConfigMaps..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/configmaps.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    if [[ -f "$WORKLOADS_BACKUP_DIR/secrets.yaml" ]]; then
      format-echo "INFO" "Restoring Secrets..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/secrets.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    # Apply PVs and PVCs
    if [[ -f "$WORKLOADS_BACKUP_DIR/persistent-volumes.yaml" ]]; then
      format-echo "INFO" "Restoring Persistent Volumes..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/persistent-volumes.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    if [[ -f "$WORKLOADS_BACKUP_DIR/persistent-volume-claims.yaml" ]]; then
      format-echo "INFO" "Restoring Persistent Volume Claims..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/persistent-volume-claims.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    # Apply Services
    if [[ -f "$WORKLOADS_BACKUP_DIR/services.yaml" ]]; then
      format-echo "INFO" "Restoring Services..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/services.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    # Finally, apply Deployments and other workloads
    if [[ -f "$WORKLOADS_BACKUP_DIR/deployments.yaml" ]]; then
      format-echo "INFO" "Restoring Deployments..."
      kubectl apply -f "$WORKLOADS_BACKUP_DIR/deployments.yaml" --timeout="${WAIT_TIMEOUT}s"
    fi
    
    format-echo "SUCCESS" "Workloads restored successfully"
    return 0
  else
    format-echo "INFO" "No workload backups to restore"
    return 0
  fi
}

#=====================================================================
# CLUSTER VALIDATION
#=====================================================================
# Validate cluster is running properly
validate_cluster() {
  local cluster="$1"
  local provider="$2"
  
  if [[ "$SKIP_VALIDATION" == true ]]; then
    format-echo "INFO" "Validation skipped as requested"
    return 0
  fi
  
  format-echo "INFO" "Validating cluster '$cluster' health..."
  
  #---------------------------------------------------------------------
  # VALIDATION PREREQUISITES
  #---------------------------------------------------------------------
  # Check if kubectl is available
  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found, cannot validate cluster"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # CONTEXT CONFIGURATION
  #---------------------------------------------------------------------
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
    format-echo "WARNING" "Could not set kubectl context, validation may be incomplete"
  fi
  
  # Wait for the cluster to stabilize
  format-echo "INFO" "Waiting for cluster to stabilize..."
  sleep 5
  
  #---------------------------------------------------------------------
  # API SERVER VALIDATION
  #---------------------------------------------------------------------
  # Check if kubectl can connect
  format-echo "INFO" "Testing API server connectivity..."
  if ! kubectl get nodes &>/dev/null; then
    format-echo "ERROR" "Cannot connect to Kubernetes API server"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # NODE STATUS VALIDATION
  #---------------------------------------------------------------------
  # Check node status
  format-echo "INFO" "Checking node status..."
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
    format-echo "WARNING" "Not all nodes are ready. Current status:"
    echo "$nodes_output"
  else
    format-echo "SUCCESS" "All nodes are in Ready state"
  fi
  
  #---------------------------------------------------------------------
  # SYSTEM PODS VALIDATION
  #---------------------------------------------------------------------
  # Check system pods
  format-echo "INFO" "Checking system pods..."
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
    format-echo "WARNING" "Not all system pods are running. Current status:"
    echo "$pods_output"
  else
    format-echo "SUCCESS" "All system pods are running"
  fi
  
  #---------------------------------------------------------------------
  # WORKLOAD VALIDATION
  #---------------------------------------------------------------------
  # Check for restored workloads if applicable
  if [[ "$RESTORE_WORKLOADS" == true ]]; then
    format-echo "INFO" "Checking restored workload status..."
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
      format-echo "WARNING" "Not all workloads are fully ready. Current status:"
      kubectl get deployments --all-namespaces | grep -v "NAMESPACE" | 
        awk '{split($5,a,"/"); if (a[1] != a[2]) print $0}'
    else
      format-echo "SUCCESS" "All workloads are running"
    fi
  fi
  
  #---------------------------------------------------------------------
  # HEALTH ASSESSMENT
  #---------------------------------------------------------------------
  # Final health check
  if [[ "$all_nodes_ready" == true && "$all_system_pods_running" == true ]]; then
    if [[ "$RESTORE_WORKLOADS" == true && "$all_workloads_running" != true ]]; then
      format-echo "WARNING" "Cluster is running but some workloads aren't fully ready"
      format-echo "INFO" "You may need to check specific workloads manually"
    else
      format-echo "SUCCESS" "Cluster is healthy and ready for use"
    fi
  else
    format-echo "WARNING" "Cluster is running but may have issues - check the warnings above"
  fi
  
  return 0
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
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
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  #---------------------------------------------------------------------
  # ARGUMENTS VALIDATION
  #---------------------------------------------------------------------
  # Validate required arguments
  if [[ -z "$CLUSTER_NAME" && -z "$STATE_FILE" ]]; then
    format-echo "ERROR" "Either cluster name (-n, --name) or state file (-s, --state-file) is required"
    usage
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
  setup_log_file
  
  print_with_separator "Kubernetes Cluster Resume Script"

  format-echo "INFO" "Starting cluster resume process..."
  
  #---------------------------------------------------------------------
  # STATE FILE IDENTIFICATION
  #---------------------------------------------------------------------
  # If state file is provided, extract cluster name and provider from it
  if [[ -n "$STATE_FILE" ]]; then
    if [[ ! -f "$STATE_FILE" ]]; then
      format-echo "ERROR" "Specified state file not found: $STATE_FILE"
      exit 1
    fi
    
    # Source the state file to get the cluster name and provider
    source "$STATE_FILE"
    
    # Update variables
    CLUSTER_NAME="$CLUSTER_NAME"
    PROVIDER="$PROVIDER"
    
    format-echo "INFO" "Loaded state file: $STATE_FILE"
    format-echo "INFO" "Cluster: $CLUSTER_NAME, Provider: $PROVIDER"
  else
    # Auto-detect provider if not specified
    if [[ "$PROVIDER" == "auto" ]]; then
      PROVIDER=$(detect_provider "$CLUSTER_NAME")
      if [[ $? -ne 0 ]]; then
        format-echo "ERROR" "Failed to auto-detect provider for cluster '$CLUSTER_NAME'"
        exit 1
      fi
    fi
    
    # Find the state file
    STATE_FILE=$(find_state_file "$CLUSTER_NAME" "$PROVIDER")
    if [[ $? -ne 0 ]]; then
      format-echo "ERROR" "Failed to find state file for cluster '$CLUSTER_NAME'"
      exit 1
    fi
  fi
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Cluster Name:      $CLUSTER_NAME"
  format-echo "INFO" "  Provider:          $PROVIDER"
  format-echo "INFO" "  State File:        $STATE_FILE"
  format-echo "INFO" "  Wait Timeout:      $WAIT_TIMEOUT seconds"
  format-echo "INFO" "  Restore Workloads: $RESTORE_WORKLOADS"
  format-echo "INFO" "  Skip Validation:   $SKIP_VALIDATION"
  format-echo "INFO" "  Force:             $FORCE"
  format-echo "INFO" "  Verbose:           $VERBOSE"
  
  #---------------------------------------------------------------------
  # RESUMING OPERATIONS
  #---------------------------------------------------------------------
  # Resume the cluster
  if ! resume_cluster "$CLUSTER_NAME" "$PROVIDER" "$STATE_FILE"; then
    format-echo "ERROR" "Failed to resume cluster"
    exit 1
  fi
  
  # Restore kubeconfig
  restore_kubeconfig "$STATE_FILE"
  
  # Restore workloads if requested
  if [[ "$RESTORE_WORKLOADS" == true ]]; then
    if ! restore_workloads "$STATE_FILE"; then
      format-echo "WARNING" "Issues while restoring workloads"
    fi
  fi
  
  # Validate cluster is running properly
  validate_cluster "$CLUSTER_NAME" "$PROVIDER"
  
  print_with_separator "End of Kubernetes Cluster Resume"
  
  #---------------------------------------------------------------------
  # SUMMARY DISPLAY
  #---------------------------------------------------------------------
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
