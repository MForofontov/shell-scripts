#!/bin/bash
# export-kubeconfig.sh
# Script to export kubeconfig from Kubernetes clusters for sharing

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
CONTEXT=""
CLUSTER_NAME=""
PROVIDER=""
OUTPUT_FILE=""
TEMP_DIR=$(mktemp -d)
SANITIZE=false
EXPIRY=""
NAMESPACE=""
USER_ONLY=""
MERGE=false
LOG_FILE="/dev/null"
INTERACTIVE=false

# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Kubeconfig Export Tool"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script exports kubeconfig files from Kubernetes clusters for sharing."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-c, --context <CONTEXT>\033[0m       (Optional) Export specified context"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m             (Optional) Export config for cluster with this name"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m     (Optional) Filter by provider (minikube, kind, k3d)"
  echo -e "  \033[1;33m-i, --interactive\033[0m             (Optional) Select context interactively"
  echo -e "  \033[1;33m-o, --output <FILE>\033[0m           (Optional) Output file (default: ./kubeconfig-CONTEXT.yaml)"
  echo -e "  \033[1;33m-s, --sanitize\033[0m                (Optional) Remove sensitive data (tokens, passwords)"
  echo -e "  \033[1;33m-e, --expire <DURATION>\033[0m       (Optional) Set credential expiry (e.g. 24h, 7d)"
  echo -e "  \033[1;33m--namespace <NAMESPACE>\033[0m       (Optional) Set default namespace"
  echo -e "  \033[1;33m--user <USER>\033[0m                 (Optional) Include only specified user credentials"
  echo -e "  \033[1;33m--merge\033[0m                       (Optional) Merge with existing output file"
  echo -e "  \033[1;33m--log <FILE>\033[0m                  (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                        (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --context minikube --output ./minikube-config.yaml"
  echo "  $0 --provider kind --sanitize"
  echo "  $0 --interactive --expire 24h"
  echo "  $0 --context kind-dev --namespace development"
  print_with_separator
  exit 1
}

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

# Check for required tools
check_requirements() {
  log_message "INFO" "Checking requirements..."
  
  if ! command_exists kubectl; then
    log_message "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
  
  if [[ -n "$EXPIRY" ]] && ! command_exists openssl; then
    log_message "ERROR" "openssl not found but required for expiring credentials."
    exit 1
  fi
  
  log_message "SUCCESS" "All required tools are available."
}

# List available contexts
list_contexts() {
  log_message "INFO" "Listing available Kubernetes contexts..."
  
  local contexts=($(kubectl config get-contexts -o name))
  local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
  
  if [[ ${#contexts[@]} -eq 0 ]]; then
    log_message "ERROR" "No Kubernetes contexts found."
    exit 1
  fi
  
  # Apply filtering based on provider
  local filtered_contexts=()
  
  for ctx in "${contexts[@]}"; do
    local include=true
    
    # Filter by provider if specified
    if [[ -n "$PROVIDER" ]]; then
      case "$PROVIDER" in
        minikube)
          if [[ "$ctx" != "minikube" && "$ctx" != "$PROVIDER-"* ]]; then
            include=false
          fi
          ;;
        kind)
          if [[ "$ctx" != "kind-"* ]]; then
            include=false
          fi
          ;;
        k3d)
          if [[ "$ctx" != "k3d-"* ]]; then
            include=false
          fi
          ;;
      esac
    fi
    
    # Filter by cluster name if specified
    if [[ -n "$CLUSTER_NAME" ]]; then
      local cluster_from_context=$(kubectl config view -o jsonpath='{.contexts[?(@.name=="'"$ctx"'")].context.cluster}')
      if [[ "$cluster_from_context" != *"$CLUSTER_NAME"* ]]; then
        include=false
      fi
    fi
    
    if [[ "$include" == true ]]; then
      filtered_contexts+=("$ctx")
    fi
  done
  
  # Display filtered contexts
  if [[ ${#filtered_contexts[@]} -eq 0 ]]; then
    log_message "ERROR" "No contexts match the specified filters."
    exit 1
  fi
  
  echo -e "\033[1;34mAvailable Kubernetes Contexts:\033[0m"
  printf "\033[1m%-3s %-30s %-30s %-20s\033[0m\n" "#" "CONTEXT" "CLUSTER" "USER"
  
  for i in "${!filtered_contexts[@]}"; do
    local ctx="${filtered_contexts[$i]}"
    local marker=" "
    if [[ "$ctx" == "$current_context" ]]; then
      marker="*"
    fi
    
    local cluster=$(kubectl config view -o jsonpath='{.contexts[?(@.name=="'"$ctx"'")].context.cluster}')
    local user=$(kubectl config view -o jsonpath='{.contexts[?(@.name=="'"$ctx"'")].context.user}')
    
    printf "%-3s %-30s %-30s %-20s\n" "$marker$((i+1))" "$ctx" "$cluster" "$user"
  done
  
  echo
  echo -e "Current context: \033[1;32m$current_context\033[0m"
  
  # Return the filtered contexts
  AVAILABLE_CONTEXTS=("${filtered_contexts[@]}")
}

# Export kubeconfig for specified context
export_kubeconfig() {
  local target_context="$1"
  local output_file="$2"
  
  log_message "INFO" "Exporting kubeconfig for context: $target_context"
  
  # Check if context exists
  if ! kubectl config get-contexts -o name | grep -q "^${target_context}$"; then
    log_message "ERROR" "Context '$target_context' does not exist."
    exit 1
  fi
  
  # Create temporary kubeconfig
  local temp_kubeconfig="$TEMP_DIR/kubeconfig-$target_context.yaml"
  
  # Export specific context to temp file
  if ! kubectl config view --minify --flatten --context="$target_context" > "$temp_kubeconfig"; then
    log_message "ERROR" "Failed to export kubeconfig for context '$target_context'."
    exit 1
  fi
  
  # Apply namespace if specified
  if [[ -n "$NAMESPACE" ]]; then
    log_message "INFO" "Setting default namespace to: $NAMESPACE"
    kubectl config set-context "$target_context" --namespace="$NAMESPACE" --kubeconfig="$temp_kubeconfig" > /dev/null
  fi
  
  # Apply user filter if specified
  if [[ -n "$USER_ONLY" ]]; then
    log_message "INFO" "Filtering for user: $USER_ONLY"
    # This would require more complex manipulation of the kubeconfig file
    # For simplicity, we'll just note that this would need to be implemented
    log_message "WARNING" "User filtering not fully implemented."
  fi
  
  # Apply expiry if specified
  if [[ -n "$EXPIRY" ]]; then
    set_expiry "$temp_kubeconfig" "$EXPIRY"
  fi
  
  # Sanitize if requested
  if [[ "$SANITIZE" == true ]]; then
    sanitize_kubeconfig "$temp_kubeconfig"
  fi
  
  # Determine the output file name if not specified
  if [[ -z "$output_file" ]]; then
    output_file="./kubeconfig-$target_context.yaml"
  fi
  
  # Merge with existing config if requested
  if [[ "$MERGE" == true && -f "$output_file" ]]; then
    log_message "INFO" "Merging with existing kubeconfig at: $output_file"
    # Create a merged config
    local merged_config="$TEMP_DIR/merged-kubeconfig.yaml"
    KUBECONFIG="$output_file:$temp_kubeconfig" kubectl config view --flatten > "$merged_config"
    cp "$merged_config" "$temp_kubeconfig"
  fi
  
  # Copy final kubeconfig to output location
  if cp "$temp_kubeconfig" "$output_file"; then
    log_message "SUCCESS" "Kubeconfig exported to: $output_file"
    
    # Show file permissions
    chmod 600 "$output_file"  # Ensure secure permissions
    ls -l "$output_file"
  else
    log_message "ERROR" "Failed to write kubeconfig to: $output_file"
    exit 1
  fi
}

# Sanitize kubeconfig to remove sensitive information
sanitize_kubeconfig() {
  local kubeconfig_file="$1"
  log_message "INFO" "Sanitizing kubeconfig to remove sensitive information..."
  
  # Create a temporary file for the sanitized version
  local sanitized_file="$TEMP_DIR/sanitized-kubeconfig.yaml"
  
  # This is a simplified approach - a real implementation would need to parse the YAML more carefully
  # Here we just remove/replace common sensitive fields
  
  # Remove bearer tokens and basic auth passwords
  sed -E 's/(token: ).*/\1[REDACTED]/g; s/(password: ).*/\1[REDACTED]/g' "$kubeconfig_file" > "$sanitized_file"
  
  # Replace the original with the sanitized version
  mv "$sanitized_file" "$kubeconfig_file"
  
  log_message "SUCCESS" "Kubeconfig sanitized successfully."
}

# Set credential expiry
set_expiry() {
  local kubeconfig_file="$1"
  local duration="$2"
  
  log_message "INFO" "Setting credential expiry to: $duration"
  
  # This is a placeholder for credential expiry setting
  # In a real implementation, this would require deep changes to the credential data
  
  # For now, we'll just add a clear comment about the expiration
  local expiry_date=$(date -v+"$duration" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d +"$duration" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
  
  if [[ -n "$expiry_date" ]]; then
    sed -i.bak "1s/^/# CREDENTIALS EXPIRE: $expiry_date\n/" "$kubeconfig_file"
    rm "${kubeconfig_file}.bak"
    log_message "SUCCESS" "Added expiry note: $expiry_date"
    log_message "WARNING" "Actual token expiry is not modified - this is just a note."
  else
    log_message "ERROR" "Failed to calculate expiry date from: $duration"
    log_message "WARNING" "Please use formats like '24h' or '7d'"
  fi
}

# Interactive context selection for export
interactive_selection() {
  # List available contexts first
  list_contexts
  
  if [[ ${#AVAILABLE_CONTEXTS[@]} -eq 1 ]]; then
    log_message "INFO" "Only one context available. Exporting automatically."
    export_kubeconfig "${AVAILABLE_CONTEXTS[0]}" "$OUTPUT_FILE"
    return
  fi
  
  echo
  echo -e "Enter the number of the context to export, or 'q' to quit:"
  read -p "> " selection
  
  # Validate input
  if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
    log_message "INFO" "Operation cancelled by user."
    exit 0
  fi
  
  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#AVAILABLE_CONTEXTS[@]} ]; then
    log_message "ERROR" "Invalid selection. Please enter a number between 1 and ${#AVAILABLE_CONTEXTS[@]}."
    exit 1
  fi
  
  # Export selected context
  local selected_context="${AVAILABLE_CONTEXTS[$((selection-1))]}"
  
  # If output file is not specified, generate one based on the context name
  if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="./kubeconfig-$selected_context.yaml"
  fi
  
  export_kubeconfig "$selected_context" "$OUTPUT_FILE"
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      -c|--context)
        CONTEXT="$2"
        shift 2
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
            log_message "ERROR" "Unsupported provider '${PROVIDER}'."
            log_message "ERROR" "Supported providers: minikube, kind, k3d"
            exit 1
            ;;
        esac
        shift 2
        ;;
      -i|--interactive)
        INTERACTIVE=true
        shift
        ;;
      -o|--output)
        OUTPUT_FILE="$2"
        shift 2
        ;;
      -s|--sanitize)
        SANITIZE=true
        shift
        ;;
      -e|--expire)
        EXPIRY="$2"
        shift 2
        ;;
      --namespace)
        NAMESPACE="$2"
        shift 2
        ;;
      --user)
        USER_ONLY="$2"
        shift 2
        ;;
      --merge)
        MERGE=true
        shift
        ;;
      --log)
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        log_message "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  # If no context specified and not interactive, check if we can determine it
  if [[ -z "$CONTEXT" && "$INTERACTIVE" == false ]]; then
    if [[ -n "$CLUSTER_NAME" || -n "$PROVIDER" ]]; then
      # We have filters but no specific context, we'll need to list and pick one
      INTERACTIVE=true
    else
      # No filters and no context, default to current context
      CONTEXT=$(kubectl config current-context 2>/dev/null)
      if [[ -z "$CONTEXT" ]]; then
        log_message "ERROR" "No current context found and no context specified."
        log_message "ERROR" "Please specify a context with --context or use --interactive."
        exit 1
      fi
    fi
  fi
}

# Main function
main() {
  print_with_separator "Kubernetes Kubeconfig Export"
  
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
  
  log_message "INFO" "Starting Kubernetes kubeconfig export..."
  
  # Display configuration
  log_message "INFO" "Configuration:"
  [[ -n "$CONTEXT" ]] && log_message "INFO" "  Context:    $CONTEXT"
  [[ -n "$CLUSTER_NAME" ]] && log_message "INFO" "  Cluster:    $CLUSTER_NAME"
  [[ -n "$PROVIDER" ]] && log_message "INFO" "  Provider:   $PROVIDER"
  [[ -n "$OUTPUT_FILE" ]] && log_message "INFO" "  Output:     $OUTPUT_FILE"
  [[ "$SANITIZE" == true ]] && log_message "INFO" "  Sanitize:   Yes"
  [[ -n "$EXPIRY" ]] && log_message "INFO" "  Expire:     $EXPIRY"
  [[ -n "$NAMESPACE" ]] && log_message "INFO" "  Namespace:  $NAMESPACE"
  [[ "$MERGE" == true ]] && log_message "INFO" "  Merge:      Yes"
  
  # Check requirements
  check_requirements
  
  # Handle interactive mode
  if [[ "$INTERACTIVE" == true ]]; then
    interactive_selection
  else
    # If output file not specified, generate one based on context
    if [[ -z "$OUTPUT_FILE" ]]; then
      OUTPUT_FILE="./kubeconfig-$CONTEXT.yaml"
    fi
    
    # Direct export of specified context
    export_kubeconfig "$CONTEXT" "$OUTPUT_FILE"
  fi
  
  print_with_separator "End of Kubernetes Kubeconfig Export"
  
  # Summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  echo -e "Kubeconfig exported to: \033[1;32m$OUTPUT_FILE\033[0m"
  echo -e "To use this config: \033[1mexport KUBECONFIG=$OUTPUT_FILE\033[0m"
  echo -e "Or to test: \033[1mkubectl --kubeconfig=$OUTPUT_FILE get nodes\033[0m"
}

# Run the main function
main "$@"