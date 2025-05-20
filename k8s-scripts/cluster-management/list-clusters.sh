#!/bin/bash
# list-clusters.sh
# Script to list all Kubernetes clusters across various providers

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
PROVIDER="all"       # Default is to list clusters from all providers
FORMAT="table"       # Output format: table, json, yaml
SHOW_DETAILS=false   # Show detailed information
LOG_FILE="/dev/null"
FILTER=""            # Filter clusters by name

# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster List Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script lists all Kubernetes clusters created with various providers (minikube, kind, k3d)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --provider\033[0m PROVIDER  Provider to list (minikube, kind, k3d, all) (default: ${PROVIDER})"
  echo -e "  \033[1;33m-f, --format\033[0m FORMAT      Output format (table, json, yaml) (default: ${FORMAT})"
  echo -e "  \033[1;33m-d, --details\033[0m            Show detailed information"
  echo -e "  \033[1;33m--filter\033[0m PATTERN         Filter clusters by name pattern"
  echo -e "  \033[1;33m--log\033[0m FILE               Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                   Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0"
  echo "  $0 --provider kind"
  echo "  $0 --format json --details"
  echo "  $0 --filter 'dev-*' --details"
  print_with_separator
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required tools
check_requirements() {
  log_message "INFO" "Checking requirements..."
  
  local all_tools_available=true
  
  # Only check for providers that were requested
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "minikube" ]]; then
    if ! command_exists minikube; then
      log_message "WARNING" "minikube not found. Minikube clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "kind" ]]; then
    if ! command_exists kind; then
      log_message "WARNING" "kind not found. Kind clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "k3d" ]]; then
    if ! command_exists k3d; then
      log_message "WARNING" "k3d not found. K3d clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  # Check for formatting dependencies
  if [[ "$FORMAT" == "json" || "$FORMAT" == "yaml" ]]; then
    if ! command_exists jq; then
      log_message "ERROR" "jq is required for JSON/YAML output but not found. Please install it first."
      exit 1
    fi
    
    if [[ "$FORMAT" == "yaml" ]] && ! command_exists yq; then
      log_message "ERROR" "yq is required for YAML output but not found. Please install it first."
      exit 1
    fi
  fi
  
  if $all_tools_available; then
    log_message "SUCCESS" "All required tools are available."
  else
    log_message "WARNING" "Some provider tools are missing. Only available providers will be listed."
  fi
}

# Get minikube clusters
get_minikube_clusters() {
  if ! command_exists minikube; then
    return
  fi
  
  log_message "INFO" "Getting minikube clusters..."
  
  # Get clusters as JSON
  local minikube_clusters=""
  if ! minikube_clusters=$(minikube profile list -o json 2>/dev/null); then
    log_message "WARNING" "Failed to get minikube profiles."
    return
  fi
  
  # Check if empty or invalid JSON
  if [[ -z "$minikube_clusters" || "$minikube_clusters" == "[]" ]]; then
    log_message "INFO" "No minikube clusters found."
    return
  fi
  
  # Process each cluster
  echo "$minikube_clusters" | jq -c '.[]' | while read -r cluster; do
    local name=$(echo "$cluster" | jq -r '.Name')
    
    # Apply filter if provided
    if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
      continue
    fi
    
    local status=$(echo "$cluster" | jq -r '.Status')
    local k8s_version=$(echo "$cluster" | jq -r '.Config.KubernetesConfig.KubernetesVersion')
    
    # Get node count
    local node_count=0
    if [[ "$status" == "Running" ]]; then
      node_count=$(minikube node list -p "$name" 2>/dev/null | wc -l | tr -d ' ')
    fi
    
    # Store basic info for table format
    CLUSTER_NAMES+=("$name")
    CLUSTER_PROVIDERS+=("minikube")
    CLUSTER_STATUSES+=("$status")
    CLUSTER_VERSIONS+=("$k8s_version")
    CLUSTER_NODE_COUNTS+=("$node_count")
    
    # Store detailed info for JSON/YAML and when details flag is set
    if $SHOW_DETAILS; then
      local created=""
      local ip=""
      local cpu=""
      local memory=""
      local disk=""
      
      if [[ "$status" == "Running" ]]; then
        ip=$(minikube ip -p "$name" 2>/dev/null || echo "N/A")
        
        # Try to get resource info
        if node_info=$(minikube ssh -p "$name" "cat /proc/cpuinfo | grep -c processor; free -m | grep Mem | awk '{print \$2}'; df -h / | grep / | awk '{print \$2}'" 2>/dev/null); then
          cpu=$(echo "$node_info" | head -1)
          memory=$(echo "$node_info" | head -2 | tail -1)
          disk=$(echo "$node_info" | tail -1)
        else
          cpu="N/A"
          memory="N/A"
          disk="N/A"
        fi
      fi
      
      CLUSTER_DETAILS+=("Provider: minikube, IP: $ip, CPU: ${cpu}cores, Memory: ${memory}MB, Disk: $disk")
    else
      CLUSTER_DETAILS+=("")
    fi
  done
}

# Get kind clusters
get_kind_clusters() {
  if ! command_exists kind; then
    return
  fi
  
  log_message "INFO" "Getting kind clusters..."
  
  # Get clusters
  local kind_clusters=""
  if ! kind_clusters=$(kind get clusters 2>/dev/null); then
    log_message "WARNING" "Failed to get kind clusters."
    return
  fi
  
  # Check if empty
  if [[ -z "$kind_clusters" ]]; then
    log_message "INFO" "No kind clusters found."
    return
  fi
  
  # Process each cluster
  echo "$kind_clusters" | while read -r name; do
    # Apply filter if provided
    if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
      continue
    fi
    
    # Get nodes to determine status and count
    local nodes=""
    if ! nodes=$(kind get nodes --name "$name" 2>/dev/null); then
      log_message "WARNING" "Failed to get nodes for kind cluster $name."
      continue
    fi
    
    local node_count=$(echo "$nodes" | wc -l | tr -d ' ')
    local status="Running"
    
    # Check if nodes are actually running
    for node in $nodes; do
      if ! docker inspect --format='{{.State.Running}}' "$node" &>/dev/null; then
        status="Stopped"
        break
      fi
    done
    
    # Get Kubernetes version
    local k8s_version="Unknown"
    if [[ "$status" == "Running" ]]; then
      # Get the node image to extract the version
      local node_image=""
      if node=$(echo "$nodes" | head -1); then
        if node_image=$(docker inspect --format='{{.Config.Image}}' "$node" 2>/dev/null); then
          k8s_version=$(echo "$node_image" | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | tr -d 'v')
        fi
      fi
    fi
    
    # Store basic info for table format
    CLUSTER_NAMES+=("$name")
    CLUSTER_PROVIDERS+=("kind")
    CLUSTER_STATUSES+=("$status")
    CLUSTER_VERSIONS+=("$k8s_version")
    CLUSTER_NODE_COUNTS+=("$node_count")
    
    # Store detailed info for JSON/YAML and when details flag is set
    if $SHOW_DETAILS && [[ "$status" == "Running" ]]; then
      local created=$(docker inspect --format='{{.Created}}' "$(echo "$nodes" | head -1)" 2>/dev/null || echo "N/A")
      local ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$(echo "$nodes" | head -1)" 2>/dev/null || echo "N/A")
      
      CLUSTER_DETAILS+=("Provider: kind, Created: $created, IP: $ip")
    else
      CLUSTER_DETAILS+=("")
    fi
  done
}

# Get k3d clusters
get_k3d_clusters() {
  if ! command_exists k3d; then
    return
  fi
  
  log_message "INFO" "Getting k3d clusters..."
  
  # Get clusters as JSON
  local k3d_clusters=""
  if ! k3d_clusters=$(k3d cluster list -o json 2>/dev/null); then
    log_message "WARNING" "Failed to get k3d clusters."
    return
  fi
  
  # Check if empty or invalid JSON
  if [[ -z "$k3d_clusters" || "$k3d_clusters" == "[]" ]]; then
    log_message "INFO" "No k3d clusters found."
    return
  fi
  
  # Process each cluster
  echo "$k3d_clusters" | jq -c '.[]' | while read -r cluster; do
    local name=$(echo "$cluster" | jq -r '.name')
    
    # Apply filter if provided
    if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
      continue
    fi
    
    local status=$(echo "$cluster" | jq -r '.serversRunning')
    if [[ "$status" -gt 0 ]]; then
      status="Running"
    else
      status="Stopped"
    fi
    
    local server_count=$(echo "$cluster" | jq -r '.serversCount')
    local agent_count=$(echo "$cluster" | jq -r '.agentsCount')
    local node_count=$((server_count + agent_count))
    
    # Get Kubernetes version
    local k8s_version="Unknown"
    if [[ "$status" == "Running" ]]; then
      # Try to get version from kubectl
      if k8s_version_raw=$(kubectl --context="k3d-$name" version -o json 2>/dev/null); then
        k8s_version=$(echo "$k8s_version_raw" | jq -r '.serverVersion.gitVersion' | tr -d 'v')
      fi
    fi
    
    # Store basic info for table format
    CLUSTER_NAMES+=("$name")
    CLUSTER_PROVIDERS+=("k3d")
    CLUSTER_STATUSES+=("$status")
    CLUSTER_VERSIONS+=("$k8s_version")
    CLUSTER_NODE_COUNTS+=("$node_count")
    
    # Store detailed info for JSON/YAML and when details flag is set
    if $SHOW_DETAILS; then
      local created=$(echo "$cluster" | jq -r '.created' 2>/dev/null || echo "N/A")
      local network=$(echo "$cluster" | jq -r '.network' 2>/dev/null || echo "N/A")
      
      CLUSTER_DETAILS+=("Provider: k3d, Created: $created, Network: $network, Servers: $server_count, Agents: $agent_count")
    else
      CLUSTER_DETAILS+=("")
    fi
  done
}

# Format output as table
format_table_output() {
  local format_title="\033[1m%-20s %-10s %-10s %-15s %-10s\033[0m"
  local format_row="%-20s %-10s %-10s %-15s %-10s"
  
  printf "$format_title\n" "NAME" "PROVIDER" "STATUS" "VERSION" "NODES"
  
  for i in "${!CLUSTER_NAMES[@]}"; do
    printf "$format_row\n" "${CLUSTER_NAMES[$i]}" "${CLUSTER_PROVIDERS[$i]}" "${CLUSTER_STATUSES[$i]}" "${CLUSTER_VERSIONS[$i]}" "${CLUSTER_NODE_COUNTS[$i]}"
    
    # If details are requested, print them on the next line
    if $SHOW_DETAILS && [[ -n "${CLUSTER_DETAILS[$i]}" ]]; then
      echo "  ${CLUSTER_DETAILS[$i]}"
      echo
    fi
  done
}

# Format output as JSON
format_json_output() {
  local clusters_json="["
  
  for i in "${!CLUSTER_NAMES[@]}"; do
    if [[ $i -gt 0 ]]; then
      clusters_json+=","
    fi
    
    clusters_json+=$(cat <<EOF
{
  "name": "${CLUSTER_NAMES[$i]}",
  "provider": "${CLUSTER_PROVIDERS[$i]}",
  "status": "${CLUSTER_STATUSES[$i]}",
  "version": "${CLUSTER_VERSIONS[$i]}",
  "nodes": ${CLUSTER_NODE_COUNTS[$i]}
EOF
    )
    
    # Add details if available
    if $SHOW_DETAILS && [[ -n "${CLUSTER_DETAILS[$i]}" ]]; then
      # Parse details into a proper JSON object
      local details="${CLUSTER_DETAILS[$i]}"
      local details_obj="{"
      
      # Split by commas and process each key-value pair
      IFS=', ' read -r -a detail_parts <<< "$details"
      for j in "${!detail_parts[@]}"; do
        # Split key-value by colon
        IFS=': ' read -r key value <<< "${detail_parts[$j]}"
        
        if [[ $j -gt 0 ]]; then
          details_obj+=","
        fi
        
        # Clean up key-value pair for JSON
        key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        details_obj+="\"$key\": \"$value\""
      done
      
      details_obj+="}"
      clusters_json+=", \"details\": $details_obj"
    fi
    
    clusters_json+="}"
  done
  
  clusters_json+="]"
  
  echo "$clusters_json" | jq '.'
}

# Format output as YAML
format_yaml_output() {
  # Convert from JSON to YAML
  format_json_output | yq eval -P '.'
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      -p|--provider)
        PROVIDER="$2"
        case "$PROVIDER" in
          all|minikube|kind|k3d) ;;
          *)
            log_message "ERROR" "Unsupported provider '${PROVIDER}'."
            log_message "ERROR" "Supported providers: all, minikube, kind, k3d"
            exit 1
            ;;
        esac
        shift 2
        ;;
      -f|--format)
        FORMAT="$2"
        case "$FORMAT" in
          table|json|yaml) ;;
          *)
            log_message "ERROR" "Unsupported format '${FORMAT}'."
            log_message "ERROR" "Supported formats: table, json, yaml"
            exit 1
            ;;
        esac
        shift 2
        ;;
      -d|--details)
        SHOW_DETAILS=true
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
        log_message "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

# Main function
main() {
  print_with_separator "Kubernetes Clusters List"
  
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
  
  log_message "INFO" "Listing Kubernetes clusters..."
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Provider:   $PROVIDER"
  log_message "INFO" "  Format:     $FORMAT"
  log_message "INFO" "  Details:    $SHOW_DETAILS"
  if [[ -n "$FILTER" ]]; then
    log_message "INFO" "  Filter:     $FILTER"
  fi
  
  # Check requirements
  check_requirements
  
  # Initialize arrays to store cluster information
  CLUSTER_NAMES=()
  CLUSTER_PROVIDERS=()
  CLUSTER_STATUSES=()
  CLUSTER_VERSIONS=()
  CLUSTER_NODE_COUNTS=()
  CLUSTER_DETAILS=()
  
  # Get clusters from each provider
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "minikube" ]]; then
    get_minikube_clusters
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "kind" ]]; then
    get_kind_clusters
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "k3d" ]]; then
    get_k3d_clusters
  fi
  
  # Check if we found any clusters
  if [[ ${#CLUSTER_NAMES[@]} -eq 0 ]]; then
    log_message "INFO" "No clusters found for the specified criteria."
    print_with_separator
    exit 0
  fi
  
  # Format and display output
  log_message "INFO" "Found ${#CLUSTER_NAMES[@]} clusters."
  print_with_separator "Cluster List"
  
  case "$FORMAT" in
    table)
      format_table_output
      ;;
    json)
      format_json_output
      ;;
    yaml)
      format_yaml_output
      ;;
  esac
  
  print_with_separator "End of Kubernetes Clusters List"
}

# Run the main function
main "$@"