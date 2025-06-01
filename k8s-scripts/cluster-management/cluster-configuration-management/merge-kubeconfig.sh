#!/bin/bash
# merge-kubeconfig.sh
# Script to merge multiple kubeconfig files into a single file

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
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

#=====================================================================
# DEFAULT VALUES
#=====================================================================
# Default values
INPUT_FILES=()
OUTPUT_FILE="$HOME/.kube/merged-config.yaml"
BACKUP=true
ORGANIZE=true
DEDUPLICATE=true
VALIDATE=true
TEMP_DIR=$(mktemp -d)
LOG_FILE="/dev/null"
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Kubeconfig Merge Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script merges multiple kubeconfig files into a single file with deduplication."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options] \033[1;36m<input-files...>\033[0m"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<input-files...>\033[0m            (Required) Path(s) to kubeconfig files to merge"
  echo -e "  \033[1;33m-o, --output <FILE>\033[0m         (Optional) Output file path (default: $OUTPUT_FILE)"
  echo -e "  \033[1;33m-f, --force\033[0m                 (Optional) Overwrite output file without confirmation"
  echo -e "  \033[1;33m--no-backup\033[0m                 (Optional) Skip backup of existing config"
  echo -e "  \033[1;33m--no-organize\033[0m               (Optional) Skip organizing contexts by provider"
  echo -e "  \033[1;33m--no-deduplicate\033[0m            (Optional) Skip deduplication of contexts/clusters"
  echo -e "  \033[1;33m--no-validate\033[0m               (Optional) Skip validation of merged config"
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 ~/.kube/config-1.yaml ~/.kube/config-2.yaml"
  echo "  $0 -o ~/.kube/config ~/.kube/dev-config.yaml ~/.kube/prod-config.yaml"
  echo "  $0 --force ~/.kube/config-*.yaml"
  echo "  $0 --no-organize ~/.kube/config-1.yaml ~/.kube/config-2.yaml"
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

# Clean up temporary files on exit
cleanup() {
  log_message "INFO" "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
}

# Register cleanup function to run on exit
trap cleanup EXIT

#=====================================================================
# REQUIREMENTS CHECKING
#=====================================================================
# Check for required tools
check_requirements() {
  log_message "INFO" "Checking requirements..."
  
  if ! command_exists kubectl; then
    log_message "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
  
  if ! command_exists yq; then
    log_message "ERROR" "yq not found. Please install it first:"
    echo "https://github.com/mikefarah/yq#install"
    exit 1
  fi
  
  log_message "SUCCESS" "All required tools are available."
}

#=====================================================================
# INPUT VALIDATION
#=====================================================================
# Validate input files
validate_input_files() {
  log_message "INFO" "Validating input files..."
  
  if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
    log_message "ERROR" "No input files specified."
    usage
  fi
  
  local valid_count=0
  
  for file in "${INPUT_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
      log_message "ERROR" "Input file not found: $file"
      continue
    fi
    
    # Verify it's a valid YAML file
    if ! yq eval . "$file" > /dev/null 2>&1; then
      log_message "ERROR" "Invalid YAML file: $file"
      continue
    fi
    
    # Verify it's a kubeconfig file (has apiVersion and kind fields)
    if ! yq eval '.apiVersion == "v1" and .kind == "Config"' "$file" | grep -q "true"; then
      log_message "WARNING" "File may not be a valid kubeconfig: $file"
    fi
    
    valid_count=$((valid_count + 1))
  done
  
  if [[ $valid_count -eq 0 ]]; then
    log_message "ERROR" "No valid kubeconfig files found."
    exit 1
  fi
  
  log_message "SUCCESS" "Found $valid_count valid input files."
}

#=====================================================================
# FILE OPERATIONS
#=====================================================================
# Create backup of output file if it exists
backup_existing_config() {
  if [[ "$BACKUP" == true && -f "$OUTPUT_FILE" ]]; then
    local backup_file="${OUTPUT_FILE}.$(date +%Y%m%d%H%M%S).bak"
    log_message "INFO" "Creating backup of existing config: $backup_file"
    
    if cp "$OUTPUT_FILE" "$backup_file"; then
      log_message "SUCCESS" "Backup created successfully."
    else
      log_message "ERROR" "Failed to create backup."
      exit 1
    fi
  fi
}

# Merge kubeconfig files
merge_kubeconfig_files() {
  log_message "INFO" "Merging kubeconfig files..."
  
  # Create a temporary file for kubectl to use
  local merged_config="$TEMP_DIR/merged-kubeconfig.yaml"
  
  # Prepare KUBECONFIG environment variable with all input files
  local kubeconfig_env=$(IFS=:; echo "${INPUT_FILES[*]}")
  
  # Merge configs using kubectl
  log_message "INFO" "Running: KUBECONFIG=$kubeconfig_env kubectl config view --flatten"
  if KUBECONFIG=$kubeconfig_env kubectl config view --flatten > "$merged_config"; then
    log_message "SUCCESS" "Configurations merged successfully."
  else
    log_message "ERROR" "Failed to merge configurations."
    exit 1
  fi
  
  # Return the path to the merged config
  echo "$merged_config"
}

#=====================================================================
# PROCESSING FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# DEDUPLICATION
#---------------------------------------------------------------------
# Deduplicate contexts and clusters
deduplicate_entries() {
  local input_file="$1"
  log_message "INFO" "Deduplicating contexts and clusters..."
  
  if [[ "$DEDUPLICATE" != true ]]; then
    log_message "INFO" "Deduplication skipped."
    echo "$input_file"
    return
  fi
  
  local deduplicated_config="$TEMP_DIR/deduplicated-kubeconfig.yaml"
  
  # Create a copy of the input file
  cp "$input_file" "$deduplicated_config"
  
  # Get counts before deduplication
  local clusters_before=$(yq eval '.clusters | length' "$deduplicated_config")
  local contexts_before=$(yq eval '.contexts | length' "$deduplicated_config")
  local users_before=$(yq eval '.users | length' "$deduplicated_config")
  
  # Deduplicate clusters (by name)
  local unique_clusters="$TEMP_DIR/unique-clusters.yaml"
  yq eval '.clusters | unique_by(.name)' "$deduplicated_config" > "$unique_clusters"
  yq eval '.clusters = load("'"$unique_clusters"'")' -i "$deduplicated_config"
  
  # Deduplicate contexts (by name)
  local unique_contexts="$TEMP_DIR/unique-contexts.yaml"
  yq eval '.contexts | unique_by(.name)' "$deduplicated_config" > "$unique_contexts"
  yq eval '.contexts = load("'"$unique_contexts"'")' -i "$deduplicated_config"
  
  # Deduplicate users (by name)
  local unique_users="$TEMP_DIR/unique-users.yaml"
  yq eval '.users | unique_by(.name)' "$deduplicated_config" > "$unique_users"
  yq eval '.users = load("'"$unique_users"'")' -i "$deduplicated_config"
  
  # Get counts after deduplication
  local clusters_after=$(yq eval '.clusters | length' "$deduplicated_config")
  local contexts_after=$(yq eval '.contexts | length' "$deduplicated_config")
  local users_after=$(yq eval '.users | length' "$deduplicated_config")
  
  # Report deduplication results
  log_message "INFO" "Deduplication summary:"
  log_message "INFO" "  Clusters: $clusters_before → $clusters_after (removed $(($clusters_before - $clusters_after)))"
  log_message "INFO" "  Contexts: $contexts_before → $contexts_after (removed $(($contexts_before - $contexts_after)))"
  log_message "INFO" "  Users:    $users_before → $users_after (removed $(($users_before - $users_after)))"
  
  # Return the path to the deduplicated config
  echo "$deduplicated_config"
}

#---------------------------------------------------------------------
# ORGANIZATION
#---------------------------------------------------------------------
# Organize contexts by provider (add comments and sort)
organize_contexts_by_provider() {
  local input_file="$1"
  log_message "INFO" "Organizing contexts by provider..."
  
  if [[ "$ORGANIZE" != true ]]; then
    log_message "INFO" "Organization skipped."
    echo "$input_file"
    return
  fi
  
  local organized_config="$TEMP_DIR/organized-kubeconfig.yaml"
  
  # Create a copy of the input file
  cp "$input_file" "$organized_config"
  
  # Group contexts by provider
  local minikube_contexts=($(yq eval '.contexts[] | select(.name == "minikube" or .name | startswith("minikube-")) | .name' "$organized_config"))
  local kind_contexts=($(yq eval '.contexts[] | select(.name | startswith("kind-")) | .name' "$organized_config"))
  local k3d_contexts=($(yq eval '.contexts[] | select(.name | startswith("k3d-")) | .name' "$organized_config"))
  local other_contexts=($(yq eval '.contexts[] | select(.name != "minikube" and (.name | startswith("minikube-") | not) and (.name | startswith("kind-") | not) and (.name | startswith("k3d-") | not)) | .name' "$organized_config"))
  
  # Create a new organized contexts array
  local temp_contexts="$TEMP_DIR/temp-contexts.yaml"
  echo "[]" > "$temp_contexts"
  
  # Add provider comments and sort contexts
  if [[ ${#minikube_contexts[@]} -gt 0 ]]; then
    log_message "INFO" "  Found ${#minikube_contexts[@]} minikube contexts"
    echo "# Minikube Contexts" >> "$temp_contexts"
    for ctx in "${minikube_contexts[@]}"; do
      yq eval '.contexts[] | select(.name == "'"$ctx"'")' "$organized_config" >> "$temp_contexts"
    done
  fi
  
  if [[ ${#kind_contexts[@]} -gt 0 ]]; then
    log_message "INFO" "  Found ${#kind_contexts[@]} kind contexts"
    echo "# Kind Contexts" >> "$temp_contexts"
    for ctx in "${kind_contexts[@]}"; do
      yq eval '.contexts[] | select(.name == "'"$ctx"'")' "$organized_config" >> "$temp_contexts"
    done
  fi
  
  if [[ ${#k3d_contexts[@]} -gt 0 ]]; then
    log_message "INFO" "  Found ${#k3d_contexts[@]} k3d contexts"
    echo "# K3d Contexts" >> "$temp_contexts"
    for ctx in "${k3d_contexts[@]}"; do
      yq eval '.contexts[] | select(.name == "'"$ctx"'")' "$organized_config" >> "$temp_contexts"
    done
  fi
  
  if [[ ${#other_contexts[@]} -gt 0 ]]; then
    log_message "INFO" "  Found ${#other_contexts[@]} other contexts"
    echo "# Other Contexts" >> "$temp_contexts"
    for ctx in "${other_contexts[@]}"; do
      yq eval '.contexts[] | select(.name == "'"$ctx"'")' "$organized_config" >> "$temp_contexts"
    done
  fi
  
  # Update the organized config with the new contexts
  yq eval-all 'select(fileIndex == 0).contexts = select(fileIndex == 1) | select(fileIndex == 0)' "$organized_config" "$temp_contexts" > "$TEMP_DIR/updated-config.yaml"
  mv "$TEMP_DIR/updated-config.yaml" "$organized_config"
  
  # Return the path to the organized config
  echo "$organized_config"
}

#---------------------------------------------------------------------
# VALIDATION
#---------------------------------------------------------------------
# Validate merged config
validate_merged_config() {
  local input_file="$1"
  log_message "INFO" "Validating merged configuration..."
  
  if [[ "$VALIDATE" != true ]]; then
    log_message "INFO" "Validation skipped."
    echo "$input_file"
    return
  fi
  
  local validated_config="$TEMP_DIR/validated-kubeconfig.yaml"
  cp "$input_file" "$validated_config"
  
  # Check for basic structure
  if ! yq eval '.apiVersion == "v1" and .kind == "Config"' "$validated_config" | grep -q "true"; then
    log_message "ERROR" "Invalid kubeconfig: Missing required fields (apiVersion, kind)."
    exit 1
  fi
  
  # Check for empty arrays
  if [[ $(yq eval '.clusters | length' "$validated_config") -eq 0 ]]; then
    log_message "ERROR" "Invalid kubeconfig: No clusters found."
    exit 1
  fi
  
  if [[ $(yq eval '.contexts | length' "$validated_config") -eq 0 ]]; then
    log_message "ERROR" "Invalid kubeconfig: No contexts found."
    exit 1
  fi
  
  if [[ $(yq eval '.users | length' "$validated_config") -eq 0 ]]; then
    log_message "ERROR" "Invalid kubeconfig: No users found."
    exit 1
  fi
  
  # Check for references integrity
  log_message "INFO" "Checking context references..."
  
  # Extract all cluster names
  local cluster_names=($(yq eval '.clusters[].name' "$validated_config"))
  local cluster_lookup=""
  for name in "${cluster_names[@]}"; do
    cluster_lookup+="$name "
  done
  
  # Extract all user names
  local user_names=($(yq eval '.users[].name' "$validated_config"))
  local user_lookup=""
  for name in "${user_names[@]}"; do
    user_lookup+="$name "
  done
  
  # Check each context for valid references
  local context_count=$(yq eval '.contexts | length' "$validated_config")
  local invalid_contexts=0
  
  for ((i=0; i<context_count; i++)); do
    local context_name=$(yq eval ".contexts[$i].name" "$validated_config")
    local cluster_ref=$(yq eval ".contexts[$i].context.cluster" "$validated_config")
    local user_ref=$(yq eval ".contexts[$i].context.user" "$validated_config")
    
    if [[ -z "$cluster_ref" || ! "$cluster_lookup" =~ $cluster_ref ]]; then
      log_message "WARNING" "  Context '$context_name' references non-existent cluster: $cluster_ref"
      invalid_contexts=$((invalid_contexts + 1))
    fi
    
    if [[ -z "$user_ref" || ! "$user_lookup" =~ $user_ref ]]; then
      log_message "WARNING" "  Context '$context_name' references non-existent user: $user_ref"
      invalid_contexts=$((invalid_contexts + 1))
    fi
  done
  
  if [[ $invalid_contexts -gt 0 ]]; then
    log_message "WARNING" "Found $invalid_contexts contexts with invalid references."
    
    # Optional: Attempt to fix invalid contexts
    # This would require more complex logic to update or remove invalid contexts
  else
    log_message "SUCCESS" "All contexts have valid references."
  fi
  
  log_message "SUCCESS" "Merged configuration validated successfully."
  echo "$validated_config"
}

#=====================================================================
# OUTPUT HANDLING
#=====================================================================
# Write final config to output file
write_output_file() {
  local input_file="$1"
  log_message "INFO" "Writing merged configuration to: $OUTPUT_FILE"
  
  # Check if output file exists and we're not forcing overwrite
  if [[ -f "$OUTPUT_FILE" && "$FORCE" != true ]]; then
    log_message "WARNING" "Output file already exists: $OUTPUT_FILE"
    read -p "Do you want to overwrite it? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      log_message "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  # Ensure output directory exists
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  
  # Create backup if needed
  backup_existing_config
  
  # Write the final config
  if cp "$input_file" "$OUTPUT_FILE"; then
    # Set secure permissions
    chmod 600 "$OUTPUT_FILE"
    log_message "SUCCESS" "Merged configuration written to: $OUTPUT_FILE"
    ls -l "$OUTPUT_FILE"
  else
    log_message "ERROR" "Failed to write configuration to: $OUTPUT_FILE"
    exit 1
  fi
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
      -o|--output)
        OUTPUT_FILE="$2"
        shift 2
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      --no-backup)
        BACKUP=false
        shift
        ;;
      --no-organize)
        ORGANIZE=false
        shift
        ;;
      --no-deduplicate)
        DEDUPLICATE=false
        shift
        ;;
      --no-validate)
        VALIDATE=false
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
        # Treat remaining arguments as input files
        INPUT_FILES+=("$1")
        shift
        ;;
    esac
  done
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
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

  print_with_separator "Kubernetes Kubeconfig Merge Script"
  
  log_message "INFO" "Starting kubeconfig merge process..."
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Input Files: ${#INPUT_FILES[@]}"
  for file in "${INPUT_FILES[@]}"; do
    log_message "INFO" "    - $file"
  done
  log_message "INFO" "  Output File: $OUTPUT_FILE"
  log_message "INFO" "  Backup:      $BACKUP"
  log_message "INFO" "  Organize:    $ORGANIZE"
  log_message "INFO" "  Deduplicate: $DEDUPLICATE"
  log_message "INFO" "  Validate:    $VALIDATE"
  log_message "INFO" "  Force:       $FORCE"
  
  # Check requirements
  check_requirements
  
  # Validate input files
  validate_input_files
  
  # Process the kubeconfig files
  TEMP_CONFIG=$(merge_kubeconfig_files)
  TEMP_CONFIG=$(deduplicate_entries "$TEMP_CONFIG")
  TEMP_CONFIG=$(organize_contexts_by_provider "$TEMP_CONFIG")
  TEMP_CONFIG=$(validate_merged_config "$TEMP_CONFIG")
  
  # Write the final config
  write_output_file "$TEMP_CONFIG"
  
  print_with_separator "End of Kubernetes Kubeconfig Merge"
  
  # Final summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  echo -e "Merged \033[1;32m${#INPUT_FILES[@]}\033[0m kubeconfig files into: \033[1;32m$OUTPUT_FILE\033[0m"
  echo -e "To use this config: \033[1mexport KUBECONFIG=$OUTPUT_FILE\033[0m"
  echo -e "Or to test: \033[1mkubectl --kubeconfig=$OUTPUT_FILE get contexts\033[0m"
}

# Run the main function
main "$@"