#!/bin/bash
# label-nodes.sh
# Script to manage Kubernetes node labels with batch operations and templates

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
NODES=()
LABELS=()
REMOVE_LABELS=()
TEMPLATE=""
OVERWRITE=false
DRY_RUN=false
FORCE=false
LOG_FILE="/dev/null"
IMPORT_FILE=""
EXPORT_FILE=""
CHECK_CONSISTENCY=true
SELECTOR=""
SAVE_TEMPLATE=""
TEMPLATES_DIR="$HOME/.kube/label-templates"

#=====================================================================
# LABEL TEMPLATES
#=====================================================================
# Define common label templates
declare -A LABEL_TEMPLATES
LABEL_TEMPLATES=(
  ["zone"]="topology.kubernetes.io/zone="
  ["region"]="topology.kubernetes.io/region="
  ["instance-type"]="node.kubernetes.io/instance-type="
  ["worker"]="node-role.kubernetes.io/worker=true"
  ["storage"]="node-role.kubernetes.io/storage=true,storage=true"
  ["ingress"]="node-role.kubernetes.io/ingress=true,ingress=true"
  ["gpu"]="nvidia.com/gpu=true,accelerator=nvidia"
  ["spot"]="node.kubernetes.io/lifecycle=spot"
  ["ondemand"]="node.kubernetes.io/lifecycle=normal"
  ["app"]="app=true,workload=general"
  ["prod"]="environment=production"
  ["dev"]="environment=development"
  ["test"]="environment=test"
  ["staging"]="environment=staging"
)

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Kubernetes Node Label Management Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Kubernetes node labels with batch operations and templates."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options> [node-names...]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m[node-names...]\033[0m             (Required unless --selector is used) Names of nodes to label"
  echo -e "  \033[1;33m--selector <SELECTOR>\033[0m       (Optional) Select nodes by label selector"
  echo -e "  \033[1;33m-l, --label <KEY=VALUE>\033[0m     (Optional) Labels to apply (can be used multiple times)"
  echo -e "  \033[1;33m-r, --remove <KEY>\033[0m          (Optional) Labels to remove (can be used multiple times)"
  echo -e "  \033[1;33m-t, --template <TEMPLATE>\033[0m   (Optional) Use a predefined label template"
  echo -e "  \033[1;33m-f, --force\033[0m                 (Optional) Skip confirmation prompts"
  echo -e "  \033[1;33m--list-templates\033[0m            (Optional) List available label templates"
  echo -e "  \033[1;33m--save-template <NAME>\033[0m      (Optional) Save current labels as a template"
  echo -e "  \033[1;33m--import <FILE>\033[0m             (Optional) Import labels from JSON/YAML file"
  echo -e "  \033[1;33m--export <FILE>\033[0m             (Optional) Export current node labels to file"
  echo -e "  \033[1;33m--overwrite\033[0m                 (Optional) Overwrite existing labels"
  echo -e "  \033[1;33m--no-consistency\033[0m            (Optional) Skip consistency validation"
  echo -e "  \033[1;33m--dry-run\033[0m                   (Optional) Only print what would be done"
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mAvailable Templates:\033[0m"
  echo "  zone, region, instance-type, worker, storage, ingress, gpu,"
  echo "  spot, ondemand, app, prod, dev, test, staging"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --label role=worker worker-node-1 worker-node-2"
  echo "  $0 --selector role=worker --label storage=true --label disk=ssd"
  echo "  $0 --template worker node1 node2 node3"
  echo "  $0 --selector kubernetes.io/hostname=node1 --remove deprecated-label"
  echo "  $0 --import node-labels.yaml --dry-run"
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
# CHECK REQUIREMENTS
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
# TEMPLATE MANAGEMENT
#=====================================================================
#---------------------------------------------------------------------
# LIST AVAILABLE TEMPLATES
#---------------------------------------------------------------------
list_templates() {
  print_with_separator "Available Label Templates"
  
  #---------------------------------------------------------------------
  # BUILT-IN TEMPLATES
  #---------------------------------------------------------------------
  echo -e "\033[1;34mBuilt-in Templates:\033[0m"
  for template in "${!LABEL_TEMPLATES[@]}"; do
    echo -e "  \033[1;32m$template\033[0m: ${LABEL_TEMPLATES[$template]}"
  done
  
  #---------------------------------------------------------------------
  # CUSTOM TEMPLATES
  #---------------------------------------------------------------------
  echo
  echo -e "\033[1;34mCustom Templates:\033[0m"
  if [[ -d "$TEMPLATES_DIR" ]]; then
    if [[ -n "$(ls -A "$TEMPLATES_DIR" 2>/dev/null)" ]]; then
      for template_file in "$TEMPLATES_DIR"/*; do
        template_name=$(basename "$template_file")
        template_content=$(cat "$template_file")
        echo -e "  \033[1;32m$template_name\033[0m: $template_content"
      done
    else
      echo "  No custom templates found."
    fi
  else
    echo "  Templates directory not found."
  fi
  
  print_with_separator
  exit 0
}

#---------------------------------------------------------------------
# SAVE CURRENT LABELS AS TEMPLATE
#---------------------------------------------------------------------
save_template() {
  local template_name="$1"
  local template_content=""
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  if [[ -z "$template_name" ]]; then
    format-echo "ERROR" "Template name is required"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # CONTENT PREPARATION
  #---------------------------------------------------------------------
  # Combine all labels into a single string
  for label in "${LABELS[@]}"; do
    if [[ -n "$template_content" ]]; then
      template_content="$template_content,$label"
    else
      template_content="$label"
    fi
  done
  
  if [[ -z "$template_content" ]]; then
    format-echo "ERROR" "No labels specified to save as template"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # TEMPLATE STORAGE
  #---------------------------------------------------------------------
  # Save to template file
  echo "$template_content" > "$TEMPLATES_DIR/$template_name"
  
  format-echo "SUCCESS" "Template '$template_name' saved to $TEMPLATES_DIR/$template_name"
  return 0
}

#---------------------------------------------------------------------
# PROCESS A TEMPLATE
#---------------------------------------------------------------------
process_template() {
  local template="$1"
  format-echo "INFO" "Processing template: $template"
  
  #---------------------------------------------------------------------
  # BUILT-IN TEMPLATE HANDLING
  #---------------------------------------------------------------------
  # Check if it's a built-in template
  if [[ -n "${LABEL_TEMPLATES[$template]}" ]]; then
    local template_labels="${LABEL_TEMPLATES[$template]}"
    format-echo "INFO" "Using built-in template: $template_labels"
    
    # Split comma-separated labels
    IFS=',' read -ra TEMPLATE_LABELS <<< "$template_labels"
    for label in "${TEMPLATE_LABELS[@]}"; do
      LABELS+=("$label")
    done
    
    return 0
  fi
  
  #---------------------------------------------------------------------
  # CUSTOM TEMPLATE HANDLING
  #---------------------------------------------------------------------
  # Check if it's a custom template
  if [[ -f "$TEMPLATES_DIR/$template" ]]; then
    local template_content
    template_content=$(cat "$TEMPLATES_DIR/$template")
    format-echo "INFO" "Using custom template: $template_content"
    
    # Split comma-separated labels
    IFS=',' read -ra TEMPLATE_LABELS <<< "$template_content"
    for label in "${TEMPLATE_LABELS[@]}"; do
      LABELS+=("$label")
    done
    
    return 0
  fi
  
  format-echo "ERROR" "Template not found: $template"
  format-echo "INFO" "Use --list-templates to see available templates"
  return 1
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
# LABEL VALIDATION
#=====================================================================
#---------------------------------------------------------------------
# VALIDATE LABEL FORMAT
#---------------------------------------------------------------------
validate_label_format() {
  local label="$1"
  
  #---------------------------------------------------------------------
  # FORMAT CHECKS
  #---------------------------------------------------------------------
  # Check basic format: key=value
  if ! echo "$label" | grep -q "^[a-zA-Z0-9][-a-zA-Z0-9_.]*\/\?[a-zA-Z0-9][-a-zA-Z0-9_.]*="; then
    format-echo "ERROR" "Invalid label format: $label"
    format-echo "INFO" "Labels must follow the format: key=value"
    format-echo "INFO" "Keys can contain alphanumeric characters, '-', '_', and '.'"
    format-echo "INFO" "Keys can optionally have a prefix with a '/'"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # KEY LENGTH CHECK
  #---------------------------------------------------------------------
  # Check label key length
  local key
  key=$(echo "$label" | cut -d= -f1)
  if [[ ${#key} -gt 253 ]]; then
    format-echo "ERROR" "Label key too long: $key"
    format-echo "INFO" "Label keys must be 253 characters or less"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # VALUE FORMAT CHECK
  #---------------------------------------------------------------------
  # Check label value format
  local value
  value=$(echo "$label" | cut -d= -f2-)
  if [[ -n "$value" && ! "$value" =~ ^[a-zA-Z0-9][-a-zA-Z0-9_.]*$ && "$value" != "true" && "$value" != "false" ]]; then
    format-echo "WARNING" "Label value may be invalid: $value"
    format-echo "INFO" "Label values should contain alphanumeric characters, '-', '_', and '.'"
    format-echo "INFO" "Some special characters may be rejected by the API server"
  fi
  
  return 0
}

#---------------------------------------------------------------------
# VALIDATE ALL LABELS
#---------------------------------------------------------------------
validate_labels() {
  format-echo "INFO" "Validating label formats..."
  
  local valid_count=0
  
  for label in "${LABELS[@]}"; do
    if validate_label_format "$label"; then
      valid_count=$((valid_count + 1))
    fi
  done
  
  if [[ $valid_count -lt ${#LABELS[@]} ]]; then
    format-echo "WARNING" "Some labels have invalid format"
    if [[ "$FORCE" != true ]]; then
      read -p "Continue anyway? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        exit 1
      fi
    fi
  else
    format-echo "SUCCESS" "All labels have valid format."
  fi
}

#---------------------------------------------------------------------
# CHECK LABEL CONSISTENCY ACROSS NODES
#---------------------------------------------------------------------
check_label_consistency() {
  if [[ "$CHECK_CONSISTENCY" != true ]]; then
    format-echo "INFO" "Skipping consistency check as requested"
    return 0
  fi
  
  format-echo "INFO" "Checking label consistency across nodes..."
  
  #---------------------------------------------------------------------
  # CURRENT LABELS COLLECTION
  #---------------------------------------------------------------------
  local temp_file
  temp_file=$(mktemp)
  
  # Get current labels for all nodes
  for node in "${NODES[@]}"; do
    echo "Node: $node" >> "$temp_file"
    kubectl get node "$node" -o jsonpath='{.metadata.labels}' | jq . >> "$temp_file"
    echo "" >> "$temp_file"
  done
  
  #---------------------------------------------------------------------
  # CONFLICT DETECTION
  #---------------------------------------------------------------------
  # Check for conflicting role labels
  local has_conflicts=false
  
  # Check if we're adding conflicting environment labels
  local env_labels=("environment=production" "environment=development" "environment=test" "environment=staging")
  local found_env_labels=()
  
  for label in "${LABELS[@]}"; do
    for env_label in "${env_labels[@]}"; do
      if [[ "$label" == "$env_label" ]]; then
        found_env_labels+=("$label")
      fi
    done
  done
  
  if [[ ${#found_env_labels[@]} -gt 1 ]]; then
    format-echo "WARNING" "Conflicting environment labels detected: ${found_env_labels[*]}"
    has_conflicts=true
  fi
  
  # Check if we're adding conflicting role labels
  local role_labels=("node-role.kubernetes.io/worker=true" "node-role.kubernetes.io/master=true" "node-role.kubernetes.io/control-plane=true")
  local found_role_labels=()
  
  for label in "${LABELS[@]}"; do
    for role_label in "${role_labels[@]}"; do
      if [[ "$label" == "$role_label" ]]; then
        found_role_labels+=("$label")
      fi
    done
  done
  
  if [[ ${#found_role_labels[@]} -gt 1 ]]; then
    format-echo "WARNING" "Potentially conflicting role labels detected: ${found_role_labels[*]}"
    has_conflicts=true
  fi
  
  #---------------------------------------------------------------------
  # CONFLICT RESOLUTION
  #---------------------------------------------------------------------
  # Report conflicts
  if [[ "$has_conflicts" == true ]]; then
    format-echo "WARNING" "Label conflicts detected"
    if [[ "$FORCE" != true ]]; then
      read -p "Continue anyway? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        rm -f "$temp_file"
        exit 1
      fi
    fi
  else
    format-echo "SUCCESS" "No label conflicts detected."
  fi
  
  rm -f "$temp_file"
  return 0
}

#=====================================================================
# LABEL OPERATIONS
#=====================================================================
#---------------------------------------------------------------------
# APPLY LABELS TO A NODE
#---------------------------------------------------------------------
apply_labels() {
  local node="$1"
  format-echo "INFO" "Applying labels to node: $node"
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  if [[ ${#LABELS[@]} -eq 0 && ${#REMOVE_LABELS[@]} -eq 0 ]]; then
    format-echo "WARNING" "No labels to apply or remove"
    return 0
  fi
  
  #---------------------------------------------------------------------
  # ARGUMENTS PREPARATION
  #---------------------------------------------------------------------
  # Build label arguments
  local label_args=""
  for label in "${LABELS[@]}"; do
    label_args="$label_args $label"
  done
  
  # Build label removal arguments
  local remove_args=""
  for label in "${REMOVE_LABELS[@]}"; do
    remove_args="$remove_args $label-"
  done
  
  # Combine all arguments
  local all_args="$label_args $remove_args"
  
  if [[ -z "$all_args" ]]; then
    format-echo "WARNING" "No labels to apply or remove after validation"
    return 0
  fi
  
  #---------------------------------------------------------------------
  # LABEL APPLICATION
  #---------------------------------------------------------------------
  # Apply labels
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would run: kubectl label node $node $all_args --overwrite=$OVERWRITE"
    return 0
  fi
  
  if kubectl label node "$node" $all_args --overwrite="$OVERWRITE"; then
    format-echo "SUCCESS" "Labels applied to node $node successfully."
    return 0
  else
    format-echo "ERROR" "Failed to apply labels to node $node."
    return 1
  fi
}

#---------------------------------------------------------------------
# IMPORT LABELS FROM FILE
#---------------------------------------------------------------------
import_labels_from_file() {
  local file="$1"
  format-echo "INFO" "Importing labels from file: $file"
  
  #---------------------------------------------------------------------
  # FILE VALIDATION
  #---------------------------------------------------------------------
  if [[ ! -f "$file" ]]; then
    format-echo "ERROR" "Import file not found: $file"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # FILE PROCESSING
  #---------------------------------------------------------------------
  # Determine file type based on extension
  local file_ext="${file##*.}"
  local imported_labels=""
  
  case "$file_ext" in
    json)
      # Import from JSON
      if ! command_exists jq; then
        format-echo "ERROR" "jq is required for JSON import but not found"
        return 1
      fi
      
      imported_labels=$(jq -r 'to_entries | map(.key + "=" + .value) | join(" ")' "$file")
      ;;
    
    yaml|yml)
      # Import from YAML
      if ! command_exists yq; then
        format-echo "ERROR" "yq is required for YAML import but not found"
        return 1
      fi
      
      imported_labels=$(yq e '.labels | to_entries | map(.key + "=" + .value) | join(" ")' "$file")
      ;;
    
    *)
      # Assume it's a simple text file with one label per line
      imported_labels=$(cat "$file" | tr '\n' ' ')
      ;;
  esac
  
  if [[ -z "$imported_labels" ]]; then
    format-echo "ERROR" "No labels found in import file"
    return 1
  fi
  
  #---------------------------------------------------------------------
  # LABEL ADDITION
  #---------------------------------------------------------------------
  # Add imported labels to LABELS array
  for label in $imported_labels; do
    LABELS+=("$label")
  done
  
  format-echo "SUCCESS" "Imported ${#imported_labels} labels from $file"
  return 0
}

#---------------------------------------------------------------------
# EXPORT CURRENT NODE LABELS TO FILE
#---------------------------------------------------------------------
export_labels_to_file() {
  local file="$1"
  local nodes="${NODES[*]}"
  format-echo "INFO" "Exporting labels for nodes: $nodes to file: $file"
  
  #---------------------------------------------------------------------
  # FORMAT SELECTION
  #---------------------------------------------------------------------
  # Determine file type based on extension
  local file_ext="${file##*.}"
  
  case "$file_ext" in
    json)
      # Export to JSON
      echo "{" > "$file"
      local first_node=true
      
      for node in "${NODES[@]}"; do
        if [[ "$first_node" != true ]]; then
          echo "," >> "$file"
        fi
        first_node=false
        
        echo "  \"$node\": {" >> "$file"
        kubectl get node "$node" -o jsonpath='{.metadata.labels}' | jq . >> "$file"
        echo "  }" >> "$file"
      done
      
      echo "}" >> "$file"
      ;;
    
    yaml|yml)
      # Export to YAML
      echo "nodes:" > "$file"
      
      for node in "${NODES[@]}"; do
        echo "  $node:" >> "$file"
        echo "    labels:" >> "$file"
        kubectl get node "$node" -o jsonpath='{.metadata.labels}' | jq -r 'to_entries[] | "      " + .key + ": " + .value' >> "$file"
        echo "" >> "$file"
      done
      ;;
    
    *)
      # Export as simple text file with one label per line
      for node in "${NODES[@]}"; do
        echo "# Node: $node" >> "$file"
        kubectl get node "$node" -o jsonpath='{.metadata.labels}' | jq -r 'to_entries[] | .key + "=" + .value' >> "$file"
        echo "" >> "$file"
      done
      ;;
  esac
  
  format-echo "SUCCESS" "Exported labels to $file"
  return 0
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
      -l|--label)
        LABELS+=("$2")
        shift 2
        ;;
      -r|--remove)
        REMOVE_LABELS+=("$2")
        shift 2
        ;;
      -t|--template)
        TEMPLATE="$2"
        shift 2
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      --list-templates)
        list_templates
        ;;
      --save-template)
        SAVE_TEMPLATE="$2"
        shift 2
        ;;
      --import)
        IMPORT_FILE="$2"
        shift 2
        ;;
      --export)
        EXPORT_FILE="$2"
        shift 2
        ;;
      --overwrite)
        OVERWRITE=true
        shift
        ;;
      --no-consistency)
        CHECK_CONSISTENCY=false
        shift
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
  
  print_with_separator "Kubernetes Node Label Management Script"
  
  format-echo "INFO" "Starting node label management..."
  
  #---------------------------------------------------------------------
  # REQUIREMENT VERIFICATION
  #---------------------------------------------------------------------
  # Check requirements
  check_requirements
  
  #---------------------------------------------------------------------
  # TEMPLATE PROCESSING
  #---------------------------------------------------------------------
  # Process template if specified
  if [[ -n "$TEMPLATE" ]]; then
    process_template "$TEMPLATE"
  fi
  
  #---------------------------------------------------------------------
  # IMPORT PROCESSING
  #---------------------------------------------------------------------
  # Import labels from file if specified
  if [[ -n "$IMPORT_FILE" ]]; then
    import_labels_from_file "$IMPORT_FILE"
  fi
  
  #---------------------------------------------------------------------
  # NODE AND LABEL VALIDATION
  #---------------------------------------------------------------------
  # Validate nodes
  validate_nodes
  
  # Validate labels
  validate_labels
  
  # Check label consistency
  check_label_consistency
  
  #---------------------------------------------------------------------
  # TEMPLATE MANAGEMENT
  #---------------------------------------------------------------------
  # Save template if requested
  if [[ -n "$SAVE_TEMPLATE" ]]; then
    save_template "$SAVE_TEMPLATE"
  fi
  
  #---------------------------------------------------------------------
  # EXPORT PROCESSING
  #---------------------------------------------------------------------
  # Export labels if requested
  if [[ -n "$EXPORT_FILE" ]]; then
    export_labels_to_file "$EXPORT_FILE"
  fi
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Nodes:             ${NODES[*]}"
  format-echo "INFO" "  Labels to Apply:   ${LABELS[*]}"
  format-echo "INFO" "  Labels to Remove:  ${REMOVE_LABELS[*]}"
  format-echo "INFO" "  Overwrite:         $OVERWRITE"
  format-echo "INFO" "  Check Consistency: $CHECK_CONSISTENCY"
  format-echo "INFO" "  Dry Run:           $DRY_RUN"
  
  #---------------------------------------------------------------------
  # USER CONFIRMATION
  #---------------------------------------------------------------------
  # Confirm operation if not dry-run or forced
  if [[ "$DRY_RUN" != true && "$FORCE" != true ]]; then
    format-echo "WARNING" "You are about to modify labels on the following nodes: ${NODES[*]}"
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      format-echo "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  #---------------------------------------------------------------------
  # LABEL APPLICATION
  #---------------------------------------------------------------------
  # Apply labels to each node
  local success_count=0
  local failed_count=0
  
  for node in "${NODES[@]}"; do
    format-echo "INFO" "Processing node: $node"
    
    if apply_labels "$node"; then
      success_count=$((success_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
    
    echo  # Add a blank line for readability
  done
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Kubernetes Node Label Management"
  
  # Final summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "Dry run completed for \033[1;32m${#NODES[@]}\033[0m nodes."
  else
    echo -e "Processed \033[1;32m${#NODES[@]}\033[0m nodes: \033[1;32m$success_count\033[0m succeeded, \033[1;31m$failed_count\033[0m failed."
    
    if [[ "$failed_count" -gt 0 ]]; then
      echo -e "\033[1;31mWarning:\033[0m Some labels failed to apply. Review the logs for details."
    fi
  fi
  
  # Show how to view current labels
  echo -e "\nTo view current node labels:"
  echo -e "  \033[1mkubectl get nodes --show-labels\033[0m"
  echo -e "  \033[1mkubectl get node <node-name> -o jsonpath='{.metadata.labels}' | jq .\033[0m"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"
