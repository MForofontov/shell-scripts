#!/bin/bash
# drain-nodes.sh
# Script to safely cordon and drain Kubernetes nodes for maintenance

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
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

# Default values
NODES=()
IGNORE_DAEMONSETS=true
DELETE_LOCAL_DATA=false
FORCE=false
TIMEOUT=300  # 5 minutes timeout
POLL_INTERVAL=5  # 5 seconds between status checks
CORDON_ONLY=false
DRY_RUN=false
LOG_FILE="/dev/null"
UNCORDON_AFTER=false
UNCORDON_DELAY=0
EVICTION_GRACE_PERIOD=30
NAMESPACE_FILTER=""
SELECTOR_FILTER=""
MAX_UNAVAILABLE_PODS=0

# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Node Drain Tool"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script safely cordons and drains Kubernetes nodes for maintenance."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options> [node-names...]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m[node-names...]\033[0m             (Required) Names of nodes to drain"
  echo -e "  \033[1;33m--selector <SELECTOR>\033[0m       (Optional) Select nodes by label selector"
  echo -e "  \033[1;33m--cordon-only\033[0m               (Optional) Only cordon nodes, don't drain"
  echo -e "  \033[1;33m--no-ignore-daemonsets\033[0m      (Optional) Don't ignore DaemonSets when draining"
  echo -e "  \033[1;33m--delete-local-data\033[0m         (Optional) Delete local data when draining"
  echo -e "  \033[1;33m--force\033[0m                     (Optional) Continue even if there are pods not managed by ReplicationController, Job, or DaemonSet"
  echo -e "  \033[1;33m--timeout <SECONDS>\033[0m         (Optional) Timeout for drain operation (default: ${TIMEOUT}s)"
  echo -e "  \033[1;33m--poll-interval <SECONDS>\033[0m   (Optional) Interval between status checks (default: ${POLL_INTERVAL}s)"
  echo -e "  \033[1;33m--grace-period <SECONDS>\033[0m    (Optional) Grace period for pod eviction (default: ${EVICTION_GRACE_PERIOD}s)"
  echo -e "  \033[1;33m--namespace <NAMESPACE>\033[0m     (Optional) Filter pods by namespace"
  echo -e "  \033[1;33m--pod-selector <SELECTOR>\033[0m   (Optional) Filter pods by selector"
  echo -e "  \033[1;33m--max-unavailable <COUNT>\033[0m   (Optional) Maximum number of unavailable pods during drain"
  echo -e "  \033[1;33m--uncordon-after\033[0m            (Optional) Uncordon nodes after drain"
  echo -e "  \033[1;33m--uncordon-delay <SECONDS>\033[0m  (Optional) Delay before uncordoning nodes"
  echo -e "  \033[1;33m--dry-run\033[0m                   (Optional) Only print what would be done"
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 worker-node-1 worker-node-2"
  echo "  $0 --selector role=worker --cordon-only"
  echo "  $0 --timeout 600 --force --delete-local-data node-maintenance"
  echo "  $0 --uncordon-after --uncordon-delay 3600 worker-node-1"
  print_with_separator
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check requirements
check_requirements() {
  log_message "INFO" "Checking requirements..."
  
  if ! command_exists kubectl; then
    log_message "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
  
  # Check if we can connect to the cluster
  if ! kubectl get nodes &>/dev/null; then
    log_message "ERROR" "Cannot connect to Kubernetes cluster. Check your connection and credentials."
    exit 1
  fi
  
  log_message "SUCCESS" "All required tools are available."
}

# Get nodes by selector
get_nodes_by_selector() {
  local selector="$1"
  log_message "INFO" "Getting nodes with selector: $selector"
  
  local selected_nodes
  selected_nodes=$(kubectl get nodes -l "$selector" -o name | cut -d'/' -f2)
  
  if [[ -z "$selected_nodes" ]]; then
    log_message "ERROR" "No nodes found matching selector: $selector"
    exit 1
  fi
  
  log_message "INFO" "Selected nodes: $selected_nodes"
  echo "$selected_nodes"
}

# Validate node names
validate_nodes() {
  log_message "INFO" "Validating node names..."
  
  if [[ ${#NODES[@]} -eq 0 ]]; then
    log_message "ERROR" "No nodes specified."
    usage
  fi
  
  local valid_count=0
  local available_nodes
  available_nodes=$(kubectl get nodes -o name | cut -d'/' -f2)
  
  for node in "${NODES[@]}"; do
    if ! echo "$available_nodes" | grep -q "^$node$"; then
      log_message "ERROR" "Node not found: $node"
      continue
    fi
    
    # Check if node is already cordoned
    if kubectl get node "$node" -o jsonpath='{.spec.unschedulable}' 2>/dev/null | grep -q "true"; then
      log_message "WARNING" "Node is already cordoned: $node"
    fi
    
    valid_count=$((valid_count + 1))
  done
  
  if [[ $valid_count -eq 0 ]]; then
    log_message "ERROR" "No valid nodes found."
    exit 1
  fi
  
  log_message "SUCCESS" "Found $valid_count valid nodes."
}

# Check pods on node
check_pods_on_node() {
  local node="$1"
  log_message "INFO" "Checking pods on node: $node"
  
  local pod_count
  local pod_filter=""
  
  # Apply namespace filter if specified
  if [[ -n "$NAMESPACE_FILTER" ]]; then
    pod_filter+=" --namespace $NAMESPACE_FILTER"
  else
    pod_filter+=" --all-namespaces"
  fi
  
  # Apply selector filter if specified
  if [[ -n "$SELECTOR_FILTER" ]]; then
    pod_filter+=" -l $SELECTOR_FILTER"
  fi
  
  # Count pods on node
  pod_count=$(kubectl get pods $pod_filter -o wide --field-selector="spec.nodeName=$node" | grep -v "^NAME" | wc -l)
  
  log_message "INFO" "Found $pod_count pods on node $node"
  
  # Show critical pods that might prevent drain
  log_message "INFO" "Checking for critical pods (no controllers)..."
  local critical_pods
  critical_pods=$(kubectl get pods $pod_filter -o wide --field-selector="spec.nodeName=$node" | grep -v "^NAME" | awk '{print $1 " " $2}' | grep "1/1" | wc -l)
  
  if [[ $critical_pods -gt 0 && "$FORCE" != true ]]; then
    log_message "WARNING" "Found $critical_pods critical pods on node $node"
    kubectl get pods $pod_filter -o wide --field-selector="spec.nodeName=$node" | grep -v "^NAME"
    
    if [[ "$DRY_RUN" != true ]]; then
      log_message "WARNING" "Some pods may not be evicted (use --force to override)"
    fi
  fi
  
  return 0
}

# Cordon a node
cordon_node() {
  local node="$1"
  log_message "INFO" "Cordoning node: $node"
  
  if [[ "$DRY_RUN" == true ]]; then
    log_message "DRY-RUN" "Would cordon node: $node"
    return 0
  fi
  
  if kubectl cordon "$node"; then
    log_message "SUCCESS" "Node $node cordoned successfully."
    return 0
  else
    log_message "ERROR" "Failed to cordon node $node."
    return 1
  fi
}

# Uncordon a node
uncordon_node() {
  local node="$1"
  log_message "INFO" "Uncordoning node: $node"
  
  if [[ "$DRY_RUN" == true ]]; then
    log_message "DRY-RUN" "Would uncordon node: $node"
    return 0
  fi
  
  if kubectl uncordon "$node"; then
    log_message "SUCCESS" "Node $node uncordoned successfully."
    return 0
  else
    log_message "ERROR" "Failed to uncordon node $node."
    return 1
  fi
}

# Drain a node
drain_node() {
  local node="$1"
  log_message "INFO" "Draining node: $node"
  
  # Build drain command options
  local drain_cmd="kubectl drain $node"
  
  if [[ "$IGNORE_DAEMONSETS" == true ]]; then
    drain_cmd+=" --ignore-daemonsets"
  fi
  
  if [[ "$DELETE_LOCAL_DATA" == true ]]; then
    drain_cmd+=" --delete-emptydir-data"
  fi
  
  if [[ "$FORCE" == true ]]; then
    drain_cmd+=" --force"
  fi
  
  drain_cmd+=" --timeout=${TIMEOUT}s"
  
  if [[ -n "$EVICTION_GRACE_PERIOD" ]]; then
    drain_cmd+=" --grace-period=$EVICTION_GRACE_PERIOD"
  fi
  
  if [[ -n "$NAMESPACE_FILTER" ]]; then
    drain_cmd+=" --namespace=$NAMESPACE_FILTER"
  fi
  
  if [[ -n "$SELECTOR_FILTER" ]]; then
    drain_cmd+=" --selector=$SELECTOR_FILTER"
  fi
  
  if [[ "$MAX_UNAVAILABLE_PODS" -gt 0 ]]; then
    drain_cmd+=" --pod-selector='!statefulset.kubernetes.io/pod-name' --max-pods-to-evict=$MAX_UNAVAILABLE_PODS"
  fi
  
  if [[ "$DRY_RUN" == true ]]; then
    drain_cmd+=" --dry-run"
    log_message "DRY-RUN" "Would run: $drain_cmd"
    return 0
  fi
  
  log_message "INFO" "Running: $drain_cmd"
  
  # Start drain with timeout
  local start_time=$(date +%s)
  local end_time=$((start_time + TIMEOUT))
  local drain_pid
  
  # Run drain in background
  eval "$drain_cmd" &
  drain_pid=$!
  
  # Monitor drain progress
  local current_time
  local elapsed_time
  local remaining_pods
  
  while kill -0 $drain_pid 2>/dev/null; do
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    remaining_time=$((end_time - current_time))
    
    if [[ $current_time -ge $end_time ]]; then
      log_message "ERROR" "Drain operation timed out after ${TIMEOUT} seconds."
      kill -9 $drain_pid 2>/dev/null
      return 1
    fi
    
    # Count remaining pods
    remaining_pods=$(kubectl get pods --all-namespaces -o wide --field-selector="spec.nodeName=$node" | grep -v "^NAME" | wc -l)
    log_message "INFO" "Draining in progress: $remaining_pods pods remaining (${elapsed_time}s elapsed, ${remaining_time}s remaining)"
    
    sleep $POLL_INTERVAL
  done
  
  # Check if drain completed successfully
  wait $drain_pid
  local drain_status=$?
  
  if [[ $drain_status -eq 0 ]]; then
    log_message "SUCCESS" "Node $node drained successfully."
    return 0
  else
    log_message "ERROR" "Failed to drain node $node (exit code: $drain_status)."
    return 1
  fi
}

# Process a node (cordon and potentially drain)
process_node() {
  local node="$1"
  
  # Check pods on node
  check_pods_on_node "$node"
  
  # Cordon the node
  if ! cordon_node "$node"; then
    return 1
  fi
  
  # Drain the node if not cordon-only
  if [[ "$CORDON_ONLY" != true ]]; then
    if ! drain_node "$node"; then
      return 1
    fi
  fi
  
  # Schedule uncordon if requested
  if [[ "$UNCORDON_AFTER" == true ]]; then
    if [[ "$UNCORDON_DELAY" -gt 0 ]]; then
      log_message "INFO" "Will uncordon node $node after ${UNCORDON_DELAY} seconds."
      
      if [[ "$DRY_RUN" != true ]]; then
        # Schedule uncordon in background
        (
          sleep $UNCORDON_DELAY
          log_message "INFO" "Delay complete, uncordoning node $node"
          uncordon_node "$node"
        ) &
        log_message "INFO" "Uncordon scheduled in background (PID: $!)."
      else
        log_message "DRY-RUN" "Would uncordon node $node after ${UNCORDON_DELAY} seconds."
      fi
    else
      # Uncordon immediately
      uncordon_node "$node"
    fi
  fi
  
  return 0
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --selector)
        SELECTOR="$2"
        NODES=($(get_nodes_by_selector "$SELECTOR"))
        shift 2
        ;;
      --cordon-only)
        CORDON_ONLY=true
        shift
        ;;
      --no-ignore-daemonsets)
        IGNORE_DAEMONSETS=false
        shift
        ;;
      --delete-local-data)
        DELETE_LOCAL_DATA=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --timeout)
        TIMEOUT="$2"
        shift 2
        ;;
      --poll-interval)
        POLL_INTERVAL="$2"
        shift 2
        ;;
      --grace-period)
        EVICTION_GRACE_PERIOD="$2"
        shift 2
        ;;
      --namespace)
        NAMESPACE_FILTER="$2"
        shift 2
        ;;
      --pod-selector)
        SELECTOR_FILTER="$2"
        shift 2
        ;;
      --max-unavailable)
        MAX_UNAVAILABLE_PODS="$2"
        shift 2
        ;;
      --uncordon-after)
        UNCORDON_AFTER=true
        shift
        ;;
      --uncordon-delay)
        UNCORDON_DELAY="$2"
        UNCORDON_AFTER=true
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --log)
        LOG_FILE="$2"
        shift 2
        ;;
      -*)
        log_message "ERROR" "Unknown option: $1"
        usage
        ;;
      *)
        # Treat remaining arguments as node names
        NODES+=("$1")
        shift
        ;;
    esac
  done
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
  
  print_with_separator "Kubernetes Node Drain"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  log_message "INFO" "Starting node drain process..."
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Nodes:               ${NODES[*]}"
  log_message "INFO" "  Cordon Only:         $CORDON_ONLY"
  log_message "INFO" "  Ignore DaemonSets:   $IGNORE_DAEMONSETS"
  log_message "INFO" "  Delete Local Data:   $DELETE_LOCAL_DATA"
  log_message "INFO" "  Force:               $FORCE"
  log_message "INFO" "  Timeout:             ${TIMEOUT}s"
  log_message "INFO" "  Poll Interval:       ${POLL_INTERVAL}s"
  log_message "INFO" "  Dry Run:             $DRY_RUN"
  
  if [[ -n "$NAMESPACE_FILTER" ]]; then
    log_message "INFO" "  Namespace Filter:    $NAMESPACE_FILTER"
  fi
  
  if [[ -n "$SELECTOR_FILTER" ]]; then
    log_message "INFO" "  Pod Selector:        $SELECTOR_FILTER"
  fi
  
  if [[ "$MAX_UNAVAILABLE_PODS" -gt 0 ]]; then
    log_message "INFO" "  Max Unavailable:     $MAX_UNAVAILABLE_PODS"
  fi
  
  if [[ "$UNCORDON_AFTER" == true ]]; then
    log_message "INFO" "  Uncordon After:      Yes"
    log_message "INFO" "  Uncordon Delay:      ${UNCORDON_DELAY}s"
  fi
  
  # Check requirements
  check_requirements
  
  # Validate nodes
  validate_nodes
  
  # Confirm operation if not a dry run
  if [[ "$DRY_RUN" != true ]]; then
    log_message "WARNING" "You are about to ${CORDON_ONLY:+cordon}${CORDON_ONLY:-drain} the following nodes: ${NODES[*]}"
    log_message "WARNING" "This might cause pod disruption and service unavailability."
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      log_message "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  # Process each node
  local success_count=0
  local failed_count=0
  
  for node in "${NODES[@]}"; do
    log_message "INFO" "Processing node: $node"
    
    if process_node "$node"; then
      success_count=$((success_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
    
    echo  # Add a blank line for readability
  done
  
  print_with_separator "End of Kubernetes Node Drain"
  
  # Final summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "Dry run completed for \033[1;32m${#NODES[@]}\033[0m nodes."
  else
    echo -e "Processed \033[1;32m${#NODES[@]}\033[0m nodes: \033[1;32m$success_count\033[0m succeeded, \033[1;31m$failed_count\033[0m failed."
    
    if [[ "$failed_count" -gt 0 ]]; then
      echo -e "\033[1;31mWarning:\033[0m Some nodes failed to process. Review the logs for details."
    fi
    
    if [[ "$UNCORDON_AFTER" == true && "$UNCORDON_DELAY" -gt 0 ]]; then
      echo -e "Nodes will be automatically uncordoned after \033[1;32m${UNCORDON_DELAY}\033[0m seconds."
      echo -e "To manually uncordon, run: \033[1mkubectl uncordon ${NODES[*]}\033[0m"
    fi
  fi
}

# Run the main function
main "$@"