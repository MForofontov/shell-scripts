#!/bin/bash
# taint-nodes.sh
# Script to manage Kubernetes node taints with batch operations and presets

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
NODES=()
TAINTS=()
REMOVE_TAINTS=()
REMOVE_ALL=false
PRESET=""
FORCE=false
DRY_RUN=false
LOG_FILE="/dev/null"
SELECTOR=""
TEST_COMPATIBILITY=false
TEMPLATES_DIR="$HOME/.kube/taint-templates"
EVICTION_TIMEOUT=30
SAVE_PRESET=""

#=====================================================================
# TAINT PRESETS
#=====================================================================
# Define common taint presets
declare -A TAINT_PRESETS
TAINT_PRESETS=(
  ["dedicated"]="dedicated=true:NoSchedule"
  ["gpu"]="nvidia.com/gpu=true:NoSchedule"
  ["spot"]="cloud.google.com/gke-spot=true:NoSchedule"
  ["preemptible"]="cloud.google.com/gke-preemptible=true:NoSchedule"
  ["arm"]="kubernetes.io/arch=arm:NoSchedule"
  ["amd64"]="kubernetes.io/arch=amd64:NoSchedule"
  ["unschedulable"]="node.kubernetes.io/unschedulable=true:NoSchedule"
  ["network"]="node.kubernetes.io/network-unavailable=true:NoSchedule"
  ["memory-pressure"]="node.kubernetes.io/memory-pressure=true:NoSchedule"
  ["disk-pressure"]="node.kubernetes.io/disk-pressure=true:NoSchedule"
  ["pid-pressure"]="node.kubernetes.io/pid-pressure=true:NoSchedule"
  ["unreachable"]="node.kubernetes.io/unreachable=true:NoExecute"
  ["not-ready"]="node.kubernetes.io/not-ready=true:NoExecute"
  ["maintenance"]="maintenance=true:NoExecute,30"
  ["prefer-no-schedule"]="prefer=true:PreferNoSchedule"
)

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Kubernetes Node Taint Management Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Kubernetes node taints with batch operations and presets."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options> [node-names...]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m[node-names...]\033[0m                (Required unless --selector is used) Names of nodes to taint"
  echo -e "  \033[1;33m-t, --taint <KEY=VALUE:EFFECT>\033[0m (Optional) Taints to apply (can be used multiple times)"
  echo -e "  \033[1;33m-r, --remove <KEY[:EFFECT]>\033[0m    (Optional) Taints to remove (can be used multiple times)"
  echo -e "  \033[1;33m-p, --preset <PRESET>\033[0m          (Optional) Use a predefined taint preset"
  echo -e "  \033[1;33m-f, --force\033[0m                    (Optional) Skip confirmation prompts"
  echo -e "  \033[1;33m--selector <SELECTOR>\033[0m          (Optional) Select nodes by label selector"
  echo -e "  \033[1;33m--remove-all\033[0m                   (Optional) Remove all taints from the specified nodes"
  echo -e "  \033[1;33m--list-presets\033[0m                 (Optional) List available taint presets"
  echo -e "  \033[1;33m--save-preset <NAME>\033[0m           (Optional) Save current taints as a preset"
  echo -e "  \033[1;33m--test-compatibility\033[0m           (Optional) Test if existing pods would be affected"
  echo -e "  \033[1;33m--eviction-timeout <SECONDS>\033[0m   (Optional) Timeout for pod eviction tests (default: ${EVICTION_TIMEOUT}s)"
  echo -e "  \033[1;33m--dry-run\033[0m                      (Optional) Only print what would be done"
  echo -e "  \033[1;33m--log <FILE>\033[0m                   (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                         (Optional) Display this help message"
  echo
  echo -e "\033[1;34mAvailable Effects:\033[0m"
  echo "  NoSchedule, PreferNoSchedule, NoExecute"
  echo
  echo -e "\033[1;34mAvailable Presets:\033[0m"
  echo "  dedicated, gpu, spot, preemptible, arm, amd64, unschedulable,"
  echo "  network, memory-pressure, disk-pressure, pid-pressure,"
  echo "  unreachable, not-ready, maintenance, prefer-no-schedule"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --taint dedicated=true:NoSchedule worker-node-1 worker-node-2"
  echo "  $0 --selector role=worker --taint gpu=true:NoSchedule"
  echo "  $0 --preset gpu node1 node2 node3"
  echo "  $0 --selector kubernetes.io/hostname=node1 --remove dedicated:NoSchedule"
  echo "  $0 --remove-all --selector role=worker"
  echo "  $0 --taint maintenance=true:NoExecute:30 node1 --test-compatibility"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
#---------------------------------------------------------------------
# CHECK IF COMMAND EXISTS
#---------------------------------------------------------------------
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

#---------------------------------------------------------------------
# CHECK FOR REQUIRED DEPENDENCIES AND PERMISSIONS
#---------------------------------------------------------------------
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  #---------------------------------------------------------------------
  # KUBECTL AVAILABILITY
  #---------------------------------------------------------------------
  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # CLUSTER CONNECTIVITY
  #---------------------------------------------------------------------
  # Check if we can connect to the cluster
  if ! kubectl get nodes &>/dev/null; then
    format-echo "ERROR" "Cannot connect to Kubernetes cluster. Check your connection and credentials."
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # TEMPLATES DIRECTORY
  #---------------------------------------------------------------------
  # Create templates directory if it doesn't exist
  if [[ ! -d "$TEMPLATES_DIR" ]]; then
    mkdir -p "$TEMPLATES_DIR"
  fi
  
  format-echo "SUCCESS" "All required tools are available."
}

#=====================================================================
# PRESET MANAGEMENT
#=====================================================================
#---------------------------------------------------------------------
# LIST AVAILABLE PRESETS
#---------------------------------------------------------------------
list_presets() {
  print_with_separator "Available Taint Presets"
  
  #---------------------------------------------------------------------
  # BUILT-IN PRESETS
  #---------------------------------------------------------------------
  echo -e "\033[1;34mBuilt-in Presets:\033[0m"
  for preset in "${!TAINT_PRESETS[@]}"; do
    echo -e "  \033[1;32m$preset\033[0m: ${TAINT_PRESETS[$preset]}"
  done
  
  #---------------------------------------------------------------------
  # CUSTOM PRESETS
  #---------------------------------------------------------------------
  echo
  echo -e "\033[1;34mCustom Presets:\033[0m"
  if [[ -d "$TEMPLATES_DIR" ]]; then
    if [[ -n "$(ls -A "$TEMPLATES_DIR" 2>/dev/null)" ]]; then
      for preset_file in "$TEMPLATES_DIR"/*; do
        preset_name=$(basename "$preset_file")
        preset_content=$(cat "$preset_file")
        echo -e "  \033[1;32m$preset_name\033[0m: $preset_content"
      done
    else
      echo "  No custom presets found."
    fi
  else
    echo "  Presets directory not found."
  fi
  
  print_with_separator
  exit 0
}

#---------------------------------------------------------------------
# SAVE CURRENT TAINTS AS PRESET
#---------------------------------------------------------------------
save_preset() {
  local preset_name="$1"
  local preset_content=""
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  if [[ -z "$preset_name" ]]; then
    format-echo "ERROR" "Preset name is required"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # CONTENT PREPARATION
  #---------------------------------------------------------------------
  # Combine all taints into a single string
  for taint in "${TAINTS[@]}"; do
    if [[ -n "$preset_content" ]]; then
      preset_content="$preset_content,$taint"
    else
      preset_content="$taint"
    fi
  done
  
  if [[ -z "$preset_content" ]]; then
    format-echo "ERROR" "No taints specified to save as preset"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # PRESET STORAGE
  #---------------------------------------------------------------------
  # Save to preset file
  echo "$preset_content" > "$TEMPLATES_DIR/$preset_name"
  
  format-echo "SUCCESS" "Preset '$preset_name' saved to $TEMPLATES_DIR/$preset_name"
  return 0
}

#=====================================================================
# NODE SELECTION
#=====================================================================
#---------------------------------------------------------------------
# GET NODES BY SELECTOR
#---------------------------------------------------------------------
get_nodes_by_selector() {
  local selector="$1"
  format-echo "INFO" "Getting nodes with selector: $selector"
  
  local selected_nodes
  selected_nodes=$(kubectl get nodes -l "$selector" -o name | cut -d'/' -f2)
  
  if [[ -z "$selected_nodes" ]]; then
    format-echo "ERROR" "No nodes found matching selector: $selector"
    exit 1
  fi
  
  format-echo "INFO" "Selected nodes: $selected_nodes"
  echo "$selected_nodes"
}

#---------------------------------------------------------------------
# VALIDATE NODE NAMES
#---------------------------------------------------------------------
validate_nodes() {
  format-echo "INFO" "Validating node names..."
  
  #---------------------------------------------------------------------
  # EMPTY NODES CHECK
  #---------------------------------------------------------------------
  if [[ ${#NODES[@]} -eq 0 ]]; then
    format-echo "ERROR" "No nodes specified."
    usage
  fi
  
  #---------------------------------------------------------------------
  # NODE EXISTENCE VALIDATION
  #---------------------------------------------------------------------
  local valid_count=0
  local available_nodes
  available_nodes=$(kubectl get nodes -o name | cut -d'/' -f2)
  
  for node in "${NODES[@]}"; do
    if ! echo "$available_nodes" | grep -q "^$node$"; then
      format-echo "ERROR" "Node not found: $node"
      continue
    fi
    
    valid_count=$((valid_count + 1))
  done
  
  if [[ $valid_count -eq 0 ]]; then
    format-echo "ERROR" "No valid nodes found."
    exit 1
  fi
  
  format-echo "SUCCESS" "Found $valid_count valid nodes."
}

#=====================================================================
# TAINT VALIDATION
#=====================================================================
#---------------------------------------------------------------------
# VALIDATE TAINT FORMAT
#---------------------------------------------------------------------
validate_taint_format() {
  local taint="$1"
  
  #---------------------------------------------------------------------
  # FORMAT CHECKS
  #---------------------------------------------------------------------
  # Check basic format: key=value:effect or key=value:effect:seconds
  if ! echo "$taint" | grep -q "^[a-zA-Z0-9][-a-zA-Z0-9_.]*\/\?[a-zA-Z0-9][-a-zA-Z0-9_.]*=[^:]*:(NoSchedule|PreferNoSchedule|NoExecute)(:[0-9]+)?$"; then
    format-echo "ERROR" "Invalid taint format: $taint"
    format-echo "INFO" "Taints must follow the format: key=value:effect or key=value:effect:seconds"
    format-echo "INFO" "Valid effects are: NoSchedule, PreferNoSchedule, NoExecute"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # KEY AND EFFECT VALIDATION
  #---------------------------------------------------------------------
  # Extract key, value and effect
  local key
  local effect
  
  key=$(echo "$taint" | cut -d= -f1)
  effect=$(echo "$taint" | cut -d: -f2)
  
  # Check key length
  if [[ ${#key} -gt 253 ]]; then
    format-echo "ERROR" "Taint key too long: $key"
    format-echo "INFO" "Taint keys must be 253 characters or less"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # EVICTION TIMEOUT VALIDATION
  #---------------------------------------------------------------------
  # Check eviction timeout if NoExecute
  if [[ "$effect" == "NoExecute" ]]; then
    if echo "$taint" | grep -q ":[0-9]\+$"; then
      local timeout
      timeout=$(echo "$taint" | cut -d: -f3)
      if [[ "$timeout" -lt 0 ]]; then
        format-echo "ERROR" "Invalid eviction timeout: $timeout"
        format-echo "INFO" "Eviction timeout must be a positive number"
        return 1
      fi
    fi
  fi
  
  return 0
}

#---------------------------------------------------------------------
# VALIDATE ALL TAINTS
#---------------------------------------------------------------------
validate_taints() {
  format-echo "INFO" "Validating taint formats..."
  
  local valid_count=0
  
  for taint in "${TAINTS[@]}"; do
    if validate_taint_format "$taint"; then
      valid_count=$((valid_count + 1))
    fi
  done
  
  if [[ $valid_count -lt ${#TAINTS[@]} ]]; then
    format-echo "WARNING" "Some taints have invalid format"
    if [[ "$FORCE" != true ]]; then
      read -p "Continue anyway? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        exit 1
      fi
    fi
  else
    format-echo "SUCCESS" "All taints have valid format."
  fi
}

#=====================================================================
# COMPATIBILITY TESTING
#=====================================================================
#---------------------------------------------------------------------
# TEST COMPATIBILITY WITH EXISTING PODS
#---------------------------------------------------------------------
test_pod_compatibility() {
  if [[ "$TEST_COMPATIBILITY" != true ]]; then
    return 0
  fi
  
  format-echo "INFO" "Testing pod compatibility with the specified taints..."
  
  #---------------------------------------------------------------------
  # POD EVICTION ANALYSIS
  #---------------------------------------------------------------------
  local has_incompatible=false
  
  for node in "${NODES[@]}"; do
    format-echo "INFO" "Checking pods on node: $node"
    
    # Get all pods on this node
    local pod_list
    pod_list=$(kubectl get pods --all-namespaces -o wide --field-selector="spec.nodeName=$node" | grep -v "^NAME")
    
    if [[ -z "$pod_list" ]]; then
      format-echo "INFO" "No pods found on node $node"
      continue
    fi
    
    #---------------------------------------------------------------------
    # POD TOLERATION CHECKS
    #---------------------------------------------------------------------
    # Check each pod against each taint
    while IFS= read -r pod_info; do
      local namespace
      local pod_name
      
      namespace=$(echo "$pod_info" | awk '{print $1}')
      pod_name=$(echo "$pod_info" | awk '{print $2}')
      
      format-echo "INFO" "Checking pod: $namespace/$pod_name"
      
      # Get pod tolerations
      local tolerations
      tolerations=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.tolerations}')
      
      # Check each taint
      for taint in "${TAINTS[@]}"; do
        local taint_key
        local taint_value
        local taint_effect
        
        taint_key=$(echo "$taint" | cut -d= -f1)
        taint_value=$(echo "$taint" | cut -d= -f2 | cut -d: -f1)
        taint_effect=$(echo "$taint" | cut -d: -f2)
        
        if [[ "$taint_effect" == "NoExecute" ]]; then
          # Check if pod has tolerations for this taint
          if ! echo "$tolerations" | grep -q "\"key\":\"$taint_key\""; then
            format-echo "WARNING" "Pod $namespace/$pod_name does not tolerate taint $taint_key=$taint_value:$taint_effect"
            format-echo "WARNING" "This pod will be evicted when the taint is applied"
            has_incompatible=true
          else
            format-echo "INFO" "Pod $namespace/$pod_name tolerates taint $taint_key=$taint_value:$taint_effect"
          fi
        fi
      done
      
    done <<< "$pod_list"
  done
  
  #---------------------------------------------------------------------
  # USER CONFIRMATION
  #---------------------------------------------------------------------
  if [[ "$has_incompatible" == true ]]; then
    format-echo "WARNING" "Some pods will be evicted when these taints are applied"
    if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
      read -p "Continue anyway? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        exit 1
      fi
    fi
  else
    format-echo "SUCCESS" "All pods are compatible with the specified taints."
  fi
}

#=====================================================================
# TAINT APPLICATION
#=====================================================================
#---------------------------------------------------------------------
# APPLY TAINTS TO A NODE
#---------------------------------------------------------------------
apply_taints() {
  local node="$1"
  format-echo "INFO" "Applying taints to node: $node"
  
  #---------------------------------------------------------------------
  # REMOVE ALL TAINTS
  #---------------------------------------------------------------------
  # Handle the case where we want to remove all taints
  if [[ "$REMOVE_ALL" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      format-echo "DRY-RUN" "Would run: kubectl taint nodes $node all-"
      return 0
    fi
    
    if kubectl taint nodes "$node" all-; then
      format-echo "SUCCESS" "All taints removed from node $node."
      return 0
    else
      format-echo "ERROR" "Failed to remove all taints from node $node."
      return 1
    fi
  fi
  
  # Normal taint operation
  if [[ ${#TAINTS[@]} -eq 0 && ${#REMOVE_TAINTS[@]} -eq 0 ]]; then
    format-echo "WARNING" "No taints to apply or remove"
    return 0
  fi
  
  #---------------------------------------------------------------------
  # APPLY TAINTS
  #---------------------------------------------------------------------
  # Apply taints
  for taint in "${TAINTS[@]}"; do
    if [[ "$DRY_RUN" == true ]]; then
      format-echo "DRY-RUN" "Would run: kubectl taint nodes $node $taint"
    else
      if kubectl taint nodes "$node" "$taint" --overwrite; then
        format-echo "SUCCESS" "Taint $taint applied to node $node."
      else
        format-echo "ERROR" "Failed to apply taint $taint to node $node."
        return 1
      fi
    fi
  done
  
  #---------------------------------------------------------------------
  # REMOVE TAINTS
  #---------------------------------------------------------------------
  # Remove taints
  for taint in "${REMOVE_TAINTS[@]}"; do
    if [[ "$DRY_RUN" == true ]]; then
      format-echo "DRY-RUN" "Would run: kubectl taint nodes $node $taint-"
    else
      if kubectl taint nodes "$node" "$taint"-; then
        format-echo "SUCCESS" "Taint $taint removed from node $node."
      else
        format-echo "ERROR" "Failed to remove taint $taint from node $node."
        return 1
      fi
    fi
  done
  
  return 0
}

#---------------------------------------------------------------------
# PROCESS A PRESET
#---------------------------------------------------------------------
process_preset() {
  local preset="$1"
  format-echo "INFO" "Processing preset: $preset"
  
  #---------------------------------------------------------------------
  # BUILT-IN PRESET HANDLING
  #---------------------------------------------------------------------
  # Check if it's a built-in preset
  if [[ -n "${TAINT_PRESETS[$preset]}" ]]; then
    local preset_taints="${TAINT_PRESETS[$preset]}"
    format-echo "INFO" "Using built-in preset: $preset_taints"
    
    # Split comma-separated taints
    IFS=',' read -ra PRESET_TAINTS <<< "$preset_taints"
    for taint in "${PRESET_TAINTS[@]}"; do
      TAINTS+=("$taint")
    done
    
    return 0
  fi
  
  #---------------------------------------------------------------------
  # CUSTOM PRESET HANDLING
  #---------------------------------------------------------------------
  # Check if it's a custom preset
  if [[ -f "$TEMPLATES_DIR/$preset" ]]; then
    local preset_content
    preset_content=$(cat "$TEMPLATES_DIR/$preset")
    format-echo "INFO" "Using custom preset: $preset_content"
    
    # Split comma-separated taints
    IFS=',' read -ra PRESET_TAINTS <<< "$preset_content"
    for taint in "${PRESET_TAINTS[@]}"; do
      TAINTS+=("$taint")
    done
    
    return 0
  fi
  
  format-echo "ERROR" "Preset not found: $preset"
  format-echo "INFO" "Use --list-presets to see available presets"
  return 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --selector)
        SELECTOR="$2"
        shift 2
        ;;
      -t|--taint)
        TAINTS+=("$2")
        shift 2
        ;;
      -r|--remove)
        REMOVE_TAINTS+=("$2")
        shift 2
        ;;
      --remove-all)
        REMOVE_ALL=true
        shift
        ;;
      -p|--preset)
        PRESET="$2"
        shift 2
        ;;
      --list-presets)
        list_presets
        ;;
      --save-preset)
        SAVE_PRESET="$2"
        shift 2
        ;;
      --test-compatibility)
        TEST_COMPATIBILITY=true
        shift
        ;;
      --eviction-timeout)
        EVICTION_TIMEOUT="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      --log)
        LOG_FILE="$2"
        shift 2
        ;;
      -*)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
      *)
        # Treat remaining arguments as node names
        NODES+=("$1")
        shift
        ;;
    esac
  done
  
  #---------------------------------------------------------------------
  # SELECTOR PROCESSING
  #---------------------------------------------------------------------
  # Get nodes by selector if specified
  if [[ -n "$SELECTOR" ]]; then
    NODES=($(get_nodes_by_selector "$SELECTOR"))
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
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
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Kubernetes Node Taint Management Script"
  
  format-echo "INFO" "Starting node taint management..."
  
  #---------------------------------------------------------------------
  # REQUIREMENT VERIFICATION
  #---------------------------------------------------------------------
  # Check requirements
  check_requirements
  
  #---------------------------------------------------------------------
  # PRESET PROCESSING
  #---------------------------------------------------------------------
  # Process preset if specified
  if [[ -n "$PRESET" ]]; then
    process_preset "$PRESET"
  fi
  
  #---------------------------------------------------------------------
  # NODE AND TAINT VALIDATION
  #---------------------------------------------------------------------
  # Validate nodes
  validate_nodes
  
  # Validate taints
  if [[ ${#TAINTS[@]} -gt 0 ]]; then
    validate_taints
  fi
  
  #---------------------------------------------------------------------
  # COMPATIBILITY TESTING
  #---------------------------------------------------------------------
  # Test pod compatibility
  test_pod_compatibility
  
  #---------------------------------------------------------------------
  # PRESET MANAGEMENT
  #---------------------------------------------------------------------
  # Save preset if requested
  if [[ -n "$SAVE_PRESET" ]]; then
    save_preset "$SAVE_PRESET"
  fi
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Nodes:              ${NODES[*]}"
  
  if [[ "$REMOVE_ALL" == true ]]; then
    format-echo "INFO" "  Action:             Remove all taints"
  else
    format-echo "INFO" "  Taints to Apply:    ${TAINTS[*]}"
    format-echo "INFO" "  Taints to Remove:   ${REMOVE_TAINTS[*]}"
  fi
  
  format-echo "INFO" "  Test Compatibility: $TEST_COMPATIBILITY"
  format-echo "INFO" "  Dry Run:            $DRY_RUN"
  
  #---------------------------------------------------------------------
  # USER CONFIRMATION
  #---------------------------------------------------------------------
  # Confirm operation if not dry-run or forced
  if [[ "$DRY_RUN" != true && "$FORCE" != true ]]; then
    format-echo "WARNING" "You are about to modify taints on the following nodes: ${NODES[*]}"
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      format-echo "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  #---------------------------------------------------------------------
  # TAINT APPLICATION
  #---------------------------------------------------------------------
  # Apply taints to each node
  local success_count=0
  local failed_count=0
  
  for node in "${NODES[@]}"; do
    format-echo "INFO" "Processing node: $node"
    
    if apply_taints "$node"; then
      success_count=$((success_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
    
    echo  # Add a blank line for readability
  done
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Kubernetes Node Taint Management"
  
  # Final summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "Dry run completed for \033[1;32m${#NODES[@]}\033[0m nodes."
  else
    echo -e "Processed \033[1;32m${#NODES[@]}\033[0m nodes: \033[1;32m$success_count\033[0m succeeded, \033[1;31m$failed_count\033[0m failed."
    
    if [[ "$failed_count" -gt 0 ]]; then
      echo -e "\033[1;31mWarning:\033[0m Some taints failed to apply. Review the logs for details."
    fi
  fi
  
  # Show how to view current taints
  echo -e "\nTo view current node taints:"
  echo -e "  \033[1mkubectl describe node <node-name> | grep Taints -A1\033[0m"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"