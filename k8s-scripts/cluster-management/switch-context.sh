#!/bin/bash
# switch-context.sh
# Script to easily switch between Kubernetes contexts

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
FORMAT_ECHO_FILE="$SCRIPT_DIR/../../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"
COMMON_FUNCTION_FILE="$SCRIPT_DIR/../../functions/utility.sh"

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

if [ -f "$COMMON_FUNCTION_FILE" ]; then
  source "$COMMON_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $COMMON_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
CONTEXT=""
PROVIDER=""
INTERACTIVE=false
LOG_FILE="/dev/null"
FILTER=""
SHOW_ALL=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Context Switching Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script makes it easy to switch between different Kubernetes contexts."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-c, --context <CONTEXT>\033[0m    (Optional) Switch to specified context"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m  (Optional) Filter contexts by provider (minikube, kind, k3d)"
  echo -e "  \033[1;33m-i, --interactive\033[0m          (Optional) Select context interactively"
  echo -e "  \033[1;33m-a, --all\033[0m                  (Optional) Show all contexts (including non-cluster contexts)"
  echo -e "  \033[1;33m--filter <PATTERN>\033[0m         (Optional) Filter contexts by name pattern"
  echo -e "  \033[1;33m--log <FILE>\033[0m               (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --context minikube"
  echo "  $0 --provider kind"
  echo "  $0 --interactive"
  echo "  $0 --filter 'dev-*'"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
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
  
  format-echo "SUCCESS" "All required tools are available."
}

#=====================================================================
# CONTEXT LISTING AND FILTERING
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
  
  #---------------------------------------------------------------------
  # CONTEXT FILTERING
  #---------------------------------------------------------------------
  # Apply filtering based on provider
  local filtered_contexts=()
  local filtered_providers=()
  local filtered_clusters=()
  
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
    
    # Apply name pattern filter if specified
    if [[ -n "$FILTER" && "$ctx" != *"$FILTER"* ]]; then
      include=false
    fi
    
    # Exclude non-cluster contexts unless --all is specified
    if [[ "$SHOW_ALL" == false ]]; then
      # Get cluster name for this context
      local cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$ctx\")].context.cluster}")
      if [[ -z "$cluster" || "$cluster" == "none" ]]; then
        include=false
      fi
    fi
    
    if [[ "$include" == true ]]; then
      filtered_contexts+=("$ctx")
      
      # Determine provider for each context
      local provider="unknown"
      if [[ "$ctx" == "minikube" || "$ctx" == minikube-* ]]; then
        provider="minikube"
      elif [[ "$ctx" == kind-* ]]; then
        provider="kind"
      elif [[ "$ctx" == k3d-* ]]; then
        provider="k3d"
      fi
      filtered_providers+=("$provider")
      
      # Get cluster name
      local cluster=$(kubectl config view -o jsonpath="{.contexts[?(@.name==\"$ctx\")].context.cluster}")
      filtered_clusters+=("$cluster")
    fi
  done
  
  #---------------------------------------------------------------------
  # CONTEXT DISPLAY
  #---------------------------------------------------------------------
  # Display filtered contexts
  if [[ ${#filtered_contexts[@]} -eq 0 ]]; then
    format-echo "ERROR" "No contexts match the specified filters."
    exit 1
  fi
  
  echo -e "\033[1;34mAvailable Kubernetes Contexts:\033[0m"
  printf "\033[1m%-3s %-30s %-10s %-30s\033[0m\n" "#" "CONTEXT" "PROVIDER" "CLUSTER"
  
  for i in "${!filtered_contexts[@]}"; do
    local marker=" "
    if [[ "${filtered_contexts[$i]}" == "$current_context" ]]; then
      marker="*"
    fi
    printf "%-3s %-30s %-10s %-30s\n" "$marker$((i+1))" "${filtered_contexts[$i]}" "${filtered_providers[$i]}" "${filtered_clusters[$i]}"
  done
  
  echo
  echo -e "Current context: \033[1;32m$current_context\033[0m"
  
  # Return the filtered contexts
  AVAILABLE_CONTEXTS=("${filtered_contexts[@]}")
}

#=====================================================================
# CONTEXT SWITCHING
#=====================================================================
# Switch to specified context
switch_context() {
  local target_context="$1"
  
  format-echo "INFO" "Switching to context: $target_context"
  
  #---------------------------------------------------------------------
  # CONTEXT VALIDATION
  #---------------------------------------------------------------------
  # Check if context exists
  if ! kubectl config get-contexts -o name | grep -q "^${target_context}$"; then
    format-echo "ERROR" "Context '$target_context' does not exist."
    exit 1
  fi
  
  # Get current context for comparison
  local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
  
  # Don't switch if already on the target context
  if [[ "$current_context" == "$target_context" ]]; then
    format-echo "INFO" "Already using context '$target_context'."
    return 0
  fi
  
  #---------------------------------------------------------------------
  # CONTEXT SWITCH EXECUTION
  #---------------------------------------------------------------------
  # Switch context
  if kubectl config use-context "$target_context" &>/dev/null; then
    format-echo "SUCCESS" "Switched to context: $target_context"
    
    #---------------------------------------------------------------------
    # CONTEXT INFORMATION DISPLAY
    #---------------------------------------------------------------------
    # Display some basic info about the new context
    echo
    echo -e "\033[1;34mContext Information:\033[0m"
    
    # Show cluster info
    echo -e "\033[1mCluster:\033[0m $(kubectl config view -o jsonpath='{.contexts[?(@.name=="'"$target_context"'")].context.cluster}')"
    echo -e "\033[1mUser:\033[0m $(kubectl config view -o jsonpath='{.contexts[?(@.name=="'"$target_context"'")].context.user}')"
    echo -e "\033[1mNamespace:\033[0m $(kubectl config view -o jsonpath='{.contexts[?(@.name=="'"$target_context"'")].context.namespace}' || echo "default")"

    #---------------------------------------------------------------------
    # CONNECTION TESTING
    #---------------------------------------------------------------------
    # Test connection to the cluster
    echo
    echo -e "\033[1;34mConnection Test:\033[0m"
    if kubectl cluster-info &>/dev/null; then
      format-echo "SUCCESS" "Connected to Kubernetes cluster."
      # Show minimal cluster info
      kubectl version --short
    else
      format-echo "WARNING" "Could not connect to Kubernetes cluster. The context may be valid but the cluster is not accessible."
    fi
    
    return 0
  else
    format-echo "ERROR" "Failed to switch to context: $target_context"
    exit 1
  fi
}

#=====================================================================
# INTERACTIVE SELECTION
#=====================================================================
# Interactive context selection
interactive_selection() {
  #---------------------------------------------------------------------
  # CONTEXT LISTING
  #---------------------------------------------------------------------
  # List available contexts first
  list_contexts
  
  #---------------------------------------------------------------------
  # SINGLE CONTEXT HANDLING
  #---------------------------------------------------------------------
  if [[ ${#AVAILABLE_CONTEXTS[@]} -eq 1 ]]; then
    format-echo "INFO" "Only one context available. Switching automatically."
    switch_context "${AVAILABLE_CONTEXTS[0]}"
    return
  fi
  
  #---------------------------------------------------------------------
  # USER SELECTION PROMPT
  #---------------------------------------------------------------------
  echo
  echo -e "Enter the number of the context to switch to, or 'q' to quit:"
  read -p "> " selection
  
  #---------------------------------------------------------------------
  # INPUT VALIDATION
  #---------------------------------------------------------------------
  # Validate input
  if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
    format-echo "INFO" "Operation cancelled by user."
    exit 0
  fi
  
  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#AVAILABLE_CONTEXTS[@]} ]; then
    format-echo "ERROR" "Invalid selection. Please enter a number between 1 and ${#AVAILABLE_CONTEXTS[@]}."
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # CONTEXT SELECTION
  #---------------------------------------------------------------------
  # Switch to selected context
  local selected_context="${AVAILABLE_CONTEXTS[$((selection-1))]}"
  switch_context "$selected_context"
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
      -a|--all)
        SHOW_ALL=true
        shift
        ;;
      --filter)
        FILTER="$2"
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
  # DEFAULT BEHAVIOR
  #---------------------------------------------------------------------
  # If no specific action is requested, default to interactive mode
  if [[ -z "$CONTEXT" && "$INTERACTIVE" == false ]]; then
    INTERACTIVE=true
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
# Main function
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  # Parse arguments
  parse_args "$@"
  
  #---------------------------------------------------------------------
  # LOG CONFIGURATION
  #---------------------------------------------------------------------
  setup_log_file
  fi
  
  print_with_separator "Kubernetes Context Switcher Script"

  format-echo "INFO" "Starting Kubernetes context switching..."
  
  #---------------------------------------------------------------------
  # PREREQUISITES CHECKING
  #---------------------------------------------------------------------
  # Check requirements
  check_requirements
  
  #---------------------------------------------------------------------
  # MODE SELECTION
  #---------------------------------------------------------------------
  # Handle interactive mode
  if [[ "$INTERACTIVE" == true ]]; then
    interactive_selection
  else
    # Direct switch to specified context
    switch_context "$CONTEXT"
  fi
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Kubernetes Context Switching"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
# Run the main function
main "$@"
