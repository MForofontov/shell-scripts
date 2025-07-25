#!/bin/bash
# export-kubeconfig.sh
# Script to export kubeconfig from Kubernetes clusters for sharing

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
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

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Kubeconfig Export Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script exports kubeconfig files from Kubernetes clusters for sharing."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
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

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Clean up temporary files on exit
cleanup() {
  format-echo "INFO" "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
}

# Register cleanup function to run on exit
trap cleanup EXIT

#=====================================================================
# REQUIREMENTS CHECKING
#=====================================================================
# Check for required tools
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
  
  if [[ -n "$EXPIRY" ]] && ! command_exists openssl; then
    format-echo "ERROR" "openssl not found but required for expiring credentials."
    exit 1
  fi
  
  format-echo "SUCCESS" "All required tools are available."
}

#=====================================================================
# CONTEXT MANAGEMENT
#=====================================================================
# List available contexts
list_contexts() {
  format-echo "INFO" "Listing available Kubernetes contexts..."
  
  local contexts=($(kubectl config get-contexts -o name))
  local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
  
  if [[ ${#contexts[@]} -eq 0 ]]; then
    format-echo "ERROR" "No Kubernetes contexts found."
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
    format-echo "ERROR" "No contexts match the specified filters."
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

#=====================================================================
# KUBECONFIG EXPORT OPERATIONS
#=====================================================================
# Export kubeconfig for specified context
export_kubeconfig() {
  local target_context="$1"
  local output_file="$2"
  
  format-echo "INFO" "Exporting kubeconfig for context: $target_context"
  
  # Check if context exists
  if ! kubectl config get-contexts -o name | grep -q "^${target_context}$"; then
    format-echo "ERROR" "Context '$target_context' does not exist."
    exit 1
  fi
  
  # Create temporary kubeconfig
  local temp_kubeconfig="$TEMP_DIR/kubeconfig-$target_context.yaml"
  
  # Export specific context to temp file
  if ! kubectl config view --minify --flatten --context="$target_context" > "$temp_kubeconfig"; then
    format-echo "ERROR" "Failed to export kubeconfig for context '$target_context'."
    exit 1
  fi
  
  # Apply namespace if specified
  if [[ -n "$NAMESPACE" ]]; then
    format-echo "INFO" "Setting default namespace to: $NAMESPACE"
    kubectl config set-context "$target_context" --namespace="$NAMESPACE" --kubeconfig="$temp_kubeconfig" > /dev/null
  fi
  
  # Apply user filter if specified
  if [[ -n "$USER_ONLY" ]]; then
    format-echo "INFO" "Filtering for user: $USER_ONLY"
    # This would require more complex manipulation of the kubeconfig file
    # For simplicity, we'll just note that this would need to be implemented
    format-echo "WARNING" "User filtering not fully implemented."
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
    format-echo "INFO" "Merging with existing kubeconfig at: $output_file"
    # Create a merged config
    local merged_config="$TEMP_DIR/merged-kubeconfig.yaml"
    KUBECONFIG="$output_file:$temp_kubeconfig" kubectl config view --flatten > "$merged_config"
    cp "$merged_config" "$temp_kubeconfig"
  fi
  
  # Copy final kubeconfig to output location
  if cp "$temp_kubeconfig" "$output_file"; then
    format-echo "SUCCESS" "Kubeconfig exported to: $output_file"
    
    # Show file permissions
    chmod 600 "$output_file"  # Ensure secure permissions
    ls -l "$output_file"
  else
    format-echo "ERROR" "Failed to write kubeconfig to: $output_file"
    exit 1
  fi
}

#=====================================================================
# KUBECONFIG MODIFICATION
#=====================================================================
# Sanitize kubeconfig to remove sensitive information
sanitize_kubeconfig() {
  local kubeconfig_file="$1"
  format-echo "INFO" "Sanitizing kubeconfig to remove sensitive information..."
  
  # Create a temporary file for the sanitized version
  local sanitized_file="$TEMP_DIR/sanitized-kubeconfig.yaml"
  
  # This is a simplified approach - a real implementation would need to parse the YAML more carefully
  # Here we just remove/replace common sensitive fields
  
  # Remove bearer tokens and basic auth passwords
  sed -E 's/(token: ).*/\1[REDACTED]/g; s/(password: ).*/\1[REDACTED]/g' "$kubeconfig_file" > "$sanitized_file"
  
  # Replace the original with the sanitized version
  mv "$sanitized_file" "$kubeconfig_file"
  
  format-echo "SUCCESS" "Kubeconfig sanitized successfully."
}

# Set credential expiry
set_expiry() {
  local kubeconfig_file="$1"
  local duration="$2"
  
  format-echo "INFO" "Setting credential expiry to: $duration"
  
  # This is a placeholder for credential expiry setting
  # In a real implementation, this would require deep changes to the credential data
  
  # For now, we'll just add a clear comment about the expiration
  local expiry_date=$(date -v+"$duration" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d +"$duration" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
  
  if [[ -n "$expiry_date" ]]; then
    sed -i.bak "1s/^/# CREDENTIALS EXPIRE: $expiry_date\n/" "$kubeconfig_file"
    rm "${kubeconfig_file}.bak"
    format-echo "SUCCESS" "Added expiry note: $expiry_date"
    format-echo "WARNING" "Actual token expiry is not modified - this is just a note."
  else
    format-echo "ERROR" "Failed to calculate expiry date from: $duration"
    format-echo "WARNING" "Please use formats like '24h' or '7d'"
  fi
}

#=====================================================================
# USER INTERACTION
#=====================================================================
# Interactive context selection for export
interactive_selection() {
  # List available contexts first
  list_contexts
  
  if [[ ${#AVAILABLE_CONTEXTS[@]} -eq 1 ]]; then
    format-echo "INFO" "Only one context available. Exporting automatically."
    export_kubeconfig "${AVAILABLE_CONTEXTS[0]}" "$OUTPUT_FILE"
    return
  fi
  
  echo
  echo -e "Enter the number of the context to export, or 'q' to quit:"
  read -p "> " selection
  
  # Validate input
  if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
    format-echo "INFO" "Operation cancelled by user."
    exit 0
  fi
  
  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#AVAILABLE_CONTEXTS[@]} ]; then
    format-echo "ERROR" "Invalid selection. Please enter a number between 1 and ${#AVAILABLE_CONTEXTS[@]}."
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
            format-echo "ERROR" "Unsupported provider '${PROVIDER}'."
            format-echo "ERROR" "Supported providers: minikube, kind, k3d"
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
        format-echo "ERROR" "Unknown option: $1"
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
        format-echo "ERROR" "No current context found and no context specified."
        format-echo "ERROR" "Please specify a context with --context or use --interactive."
        exit 1
      fi
    fi
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
# Main function
main() {
  # Parse arguments
  parse_args "$@"

  setup_log_file

  print_with_separator "Kubernetes Kubeconfig Export Script"
  
  format-echo "INFO" "Starting Kubernetes kubeconfig export..."
  
  # Display configuration
  format-echo "INFO" "Configuration:"
  [[ -n "$CONTEXT" ]] && format-echo "INFO" "  Context:    $CONTEXT"
  [[ -n "$CLUSTER_NAME" ]] && format-echo "INFO" "  Cluster:    $CLUSTER_NAME"
  [[ -n "$PROVIDER" ]] && format-echo "INFO" "  Provider:   $PROVIDER"
  [[ -n "$OUTPUT_FILE" ]] && format-echo "INFO" "  Output:     $OUTPUT_FILE"
  [[ "$SANITIZE" == true ]] && format-echo "INFO" "  Sanitize:   Yes"
  [[ -n "$EXPIRY" ]] && format-echo "INFO" "  Expire:     $EXPIRY"
  [[ -n "$NAMESPACE" ]] && format-echo "INFO" "  Namespace:  $NAMESPACE"
  [[ "$MERGE" == true ]] && format-echo "INFO" "  Merge:      Yes"
  
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
