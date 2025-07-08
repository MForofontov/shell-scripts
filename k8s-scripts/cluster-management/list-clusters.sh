#!/bin/bash
# list-clusters.sh
# Script to list all Kubernetes clusters across various providers, both local and cloud

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
PROVIDER="all"       # Default is to list clusters from all providers
FORMAT="table"       # Output format: table, json, yaml
SHOW_DETAILS=false   # Show detailed information
LOG_FILE="/dev/null"
FILTER=""            # Filter clusters by name
REGION=""            # Region for cloud providers
PROFILE=""           # Profile for cloud providers

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster List Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script lists all Kubernetes clusters across local and cloud providers."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m  (Optional) Provider to list clusters from:"
  echo -e "                                   Local: minikube, kind, k3d"
  echo -e "                                   Cloud: eks, gke, aks"
  echo -e "                                   Special: all, local, cloud (default: ${PROVIDER})"
  echo -e "  \033[1;33m-f, --format <FORMAT>\033[0m      (Optional) Output format (table, json, yaml) (default: ${FORMAT})"
  echo -e "  \033[1;33m-d, --details\033[0m              (Optional) Show detailed information"
  echo -e "  \033[1;33m--filter <PATTERN>\033[0m         (Optional) Filter clusters by name pattern"
  echo -e "  \033[1;33m--region <REGION>\033[0m          (Optional) Region for cloud providers"
  echo -e "  \033[1;33m--profile <PROFILE>\033[0m        (Optional) Profile for cloud providers (AWS, GCP)"
  echo -e "  \033[1;33m--log <FILE>\033[0m               (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0"
  echo "  $0 --provider eks --region us-west-2"
  echo "  $0 --provider cloud --format json --details"
  echo "  $0 --filter 'prod-*' --details"
  echo "  $0 --provider gke --profile production"
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

#=====================================================================
# REQUIREMENTS CHECKING
#=====================================================================
# Check for required tools
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  local all_tools_available=true
  
  #---------------------------------------------------------------------
  # LOCAL PROVIDER REQUIREMENTS
  #---------------------------------------------------------------------
  # Check for local providers
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "local" || "$PROVIDER" == "minikube" ]]; then
    if ! command_exists minikube; then
      format-echo "WARNING" "minikube not found. Minikube clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "local" || "$PROVIDER" == "kind" ]]; then
    if ! command_exists kind; then
      format-echo "WARNING" "kind not found. Kind clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "local" || "$PROVIDER" == "k3d" ]]; then
    if ! command_exists k3d; then
      format-echo "WARNING" "k3d not found. K3d clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  #---------------------------------------------------------------------
  # CLOUD PROVIDER REQUIREMENTS
  #---------------------------------------------------------------------
  # Check for cloud providers
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "cloud" || "$PROVIDER" == "eks" ]]; then
    if ! command_exists aws; then
      format-echo "WARNING" "AWS CLI not found. EKS clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "cloud" || "$PROVIDER" == "gke" ]]; then
    if ! command_exists gcloud; then
      format-echo "WARNING" "Google Cloud SDK not found. GKE clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "cloud" || "$PROVIDER" == "aks" ]]; then
    if ! command_exists az; then
      format-echo "WARNING" "Azure CLI not found. AKS clusters will not be listed."
      all_tools_available=false
    fi
  fi
  
  #---------------------------------------------------------------------
  # OUTPUT FORMAT REQUIREMENTS
  #---------------------------------------------------------------------
  # Check for formatting dependencies
  if [[ "$FORMAT" == "json" || "$FORMAT" == "yaml" ]]; then
    if ! command_exists jq; then
      format-echo "ERROR" "jq is required for JSON/YAML output but not found. Please install it first."
      exit 1
    fi
    
    if [[ "$FORMAT" == "yaml" ]] && ! command_exists yq; then
      format-echo "ERROR" "yq is required for YAML output but not found. Please install it first."
      exit 1
    fi
  fi
  
  if $all_tools_available; then
    format-echo "SUCCESS" "All required tools are available."
  else
    format-echo "WARNING" "Some provider tools are missing. Only available providers will be listed."
  fi
}

#=====================================================================
# CLOUD PROVIDER FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# AWS EKS CLUSTERS
#---------------------------------------------------------------------
# Get EKS clusters
get_eks_clusters() {
  if ! command_exists aws; then
    return
  fi
  
  format-echo "INFO" "Getting EKS clusters..."
  
  # Build AWS command with optional region and profile
  local aws_cmd="aws eks list-clusters"
  
  if [[ -n "$REGION" ]]; then
    aws_cmd+=" --region $REGION"
  fi
  
  if [[ -n "$PROFILE" ]]; then
    aws_cmd+=" --profile $PROFILE"
  fi
  
  # Get clusters
  local eks_clusters=""
  if ! eks_clusters=$(eval "$aws_cmd" 2>/dev/null); then
    format-echo "WARNING" "Failed to get EKS clusters."
    return
  fi
  
  # Check if empty or invalid JSON
  if [[ -z "$eks_clusters" || "$(echo "$eks_clusters" | jq -r '.clusters | length')" -eq 0 ]]; then
    format-echo "INFO" "No EKS clusters found."
    return
  fi
  
  # Process each cluster
  for name in $(echo "$eks_clusters" | jq -r '.clusters[]'); do
    # Apply filter if provided
    if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
      continue
    fi
    
    # Build command to describe cluster
    local describe_cmd="aws eks describe-cluster --name $name"
    
    if [[ -n "$REGION" ]]; then
      describe_cmd+=" --region $REGION"
    fi
    
    if [[ -n "$PROFILE" ]]; then
      describe_cmd+=" --profile $PROFILE"
    fi
    
    # Get cluster details
    local cluster_details=""
    if ! cluster_details=$(eval "$describe_cmd" 2>/dev/null); then
      format-echo "WARNING" "Failed to get details for EKS cluster $name."
      continue
    fi
    
    local status=$(echo "$cluster_details" | jq -r '.cluster.status')
    local k8s_version=$(echo "$cluster_details" | jq -r '.cluster.version')
    local region=$(echo "$cluster_details" | jq -r '.cluster.arn' | cut -d':' -f4)
    
    # Get node count
    local node_count=0
    if [[ "$status" == "ACTIVE" ]]; then
      # Build command to get node groups
      local nodegroups_cmd="aws eks list-nodegroups --cluster-name $name"
      
      if [[ -n "$REGION" ]]; then
        nodegroups_cmd+=" --region $REGION"
      fi
      
      if [[ -n "$PROFILE" ]]; then
        nodegroups_cmd+=" --profile $PROFILE"
      fi
      
      # Get node groups
      local nodegroups=""
      if nodegroups=$(eval "$nodegroups_cmd" 2>/dev/null); then
        for ng in $(echo "$nodegroups" | jq -r '.nodegroups[]'); do
          # Build command to describe node group
          local describe_ng_cmd="aws eks describe-nodegroup --cluster-name $name --nodegroup-name $ng"
          
          if [[ -n "$REGION" ]]; then
            describe_ng_cmd+=" --region $REGION"
          fi
          
          if [[ -n "$PROFILE" ]]; then
            describe_ng_cmd+=" --profile $PROFILE"
          fi
          
          # Get node group details
          local ng_details=""
          if ng_details=$(eval "$describe_ng_cmd" 2>/dev/null); then
            local ng_count=$(echo "$ng_details" | jq -r '.nodegroup.scalingConfig.desiredSize')
            node_count=$((node_count + ng_count))
          fi
        done
      fi
    fi
    
    # Store basic info for table format
    CLUSTER_NAMES+=("$name")
    CLUSTER_PROVIDERS+=("eks")
    CLUSTER_STATUSES+=("$status")
    CLUSTER_VERSIONS+=("$k8s_version")
    CLUSTER_NODE_COUNTS+=("$node_count")
    
    # Store detailed info for JSON/YAML and when details flag is set
    if $SHOW_DETAILS; then
      local created=$(echo "$cluster_details" | jq -r '.cluster.createdAt')
      local endpoint=$(echo "$cluster_details" | jq -r '.cluster.endpoint')
      local vpc_id=$(echo "$cluster_details" | jq -r '.cluster.resourcesVpcConfig.vpcId')
      
      CLUSTER_DETAILS+=("Provider: EKS, Region: $region, Created: $created, Endpoint: $endpoint, VPC: $vpc_id")
    else
      CLUSTER_DETAILS+=("")
    fi
  done
}

#---------------------------------------------------------------------
# GOOGLE GKE CLUSTERS
#---------------------------------------------------------------------
# Get GKE clusters
get_gke_clusters() {
  if ! command_exists gcloud; then
    return
  fi
  
  format-echo "INFO" "Getting GKE clusters..."
  
  # Build GCloud command with optional region and profile/project
  local project_flag=""
  if [[ -n "$PROFILE" ]]; then
    project_flag="--project=$PROFILE"
  fi
  
  local region_flag=""
  if [[ -n "$REGION" ]]; then
    region_flag="--region=$REGION"
  else
    # List from all regions if not specified
    region_flag="--all-regions"
  fi
  
  # Get clusters
  local gke_clusters=""
  if ! gke_clusters=$(gcloud container clusters list --format=json $project_flag $region_flag 2>/dev/null); then
    format-echo "WARNING" "Failed to get GKE clusters."
    return
  fi
  
  # Check if empty or invalid JSON
  if [[ -z "$gke_clusters" || "$gke_clusters" == "[]" ]]; then
    format-echo "INFO" "No GKE clusters found."
    return
  fi
  
  # Process each cluster
  echo "$gke_clusters" | jq -c '.[]' | while read -r cluster; do
    local name=$(echo "$cluster" | jq -r '.name')
    
    # Apply filter if provided
    if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
      continue
    fi
    
    local status=$(echo "$cluster" | jq -r '.status')
    local k8s_version=$(echo "$cluster" | jq -r '.currentMasterVersion')
    local location=$(echo "$cluster" | jq -r '.location')
    local node_count=$(echo "$cluster" | jq -r '.currentNodeCount')
    
    # Store basic info for table format
    CLUSTER_NAMES+=("$name")
    CLUSTER_PROVIDERS+=("gke")
    CLUSTER_STATUSES+=("$status")
    CLUSTER_VERSIONS+=("$k8s_version")
    CLUSTER_NODE_COUNTS+=("$node_count")
    
    # Store detailed info for JSON/YAML and when details flag is set
    if $SHOW_DETAILS; then
      local created=$(echo "$cluster" | jq -r '.createTime')
      local network=$(echo "$cluster" | jq -r '.network')
      local project=$(echo "$cluster" | jq -r '.projectId')
      local zone=$(echo "$cluster" | jq -r '.zone')
      
      CLUSTER_DETAILS+=("Provider: GKE, Project: $project, Zone: $zone, Created: $created, Network: $network")
    else
      CLUSTER_DETAILS+=("")
    fi
  done
}

#---------------------------------------------------------------------
# AZURE AKS CLUSTERS
#---------------------------------------------------------------------
# Get AKS clusters
get_aks_clusters() {
  if ! command_exists az; then
    return
  fi
  
  format-echo "INFO" "Getting AKS clusters..."
  
  # Build Azure command with optional resource group
  local az_cmd="az aks list"
  
  if [[ -n "$REGION" ]]; then
    az_cmd+=" --resource-group $REGION"
  fi
  
  # Get clusters
  local aks_clusters=""
  if ! aks_clusters=$(eval "$az_cmd" 2>/dev/null); then
    format-echo "WARNING" "Failed to get AKS clusters."
    return
  fi
  
  # Check if empty or invalid JSON
  if [[ -z "$aks_clusters" || "$aks_clusters" == "[]" ]]; then
    format-echo "INFO" "No AKS clusters found."
    return
  fi
  
  # Process each cluster
  echo "$aks_clusters" | jq -c '.[]' | while read -r cluster; do
    local name=$(echo "$cluster" | jq -r '.name')
    
    # Apply filter if provided
    if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
      continue
    fi
    
    local status=$(echo "$cluster" | jq -r '.provisioningState')
    local k8s_version=$(echo "$cluster" | jq -r '.kubernetesVersion')
    local location=$(echo "$cluster" | jq -r '.location')
    local resource_group=$(echo "$cluster" | jq -r '.resourceGroup')
    
    # Get node count
    local node_count=0
    local agent_pools=$(echo "$cluster" | jq -r '.agentPoolProfiles')
    if [[ -n "$agent_pools" && "$agent_pools" != "null" ]]; then
      node_count=$(echo "$agent_pools" | jq -r 'map(.count) | add')
    fi
    
    # Store basic info for table format
    CLUSTER_NAMES+=("$name")
    CLUSTER_PROVIDERS+=("aks")
    CLUSTER_STATUSES+=("$status")
    CLUSTER_VERSIONS+=("$k8s_version")
    CLUSTER_NODE_COUNTS+=("$node_count")
    
    # Store detailed info for JSON/YAML and when details flag is set
    if $SHOW_DETAILS; then
      local created=$(echo "$cluster" | jq -r '.creationData // "N/A"')
      local dns_prefix=$(echo "$cluster" | jq -r '.dnsPrefix')
      
      CLUSTER_DETAILS+=("Provider: AKS, Resource Group: $resource_group, Location: $location, DNS Prefix: $dns_prefix")
    else
      CLUSTER_DETAILS+=("")
    fi
  done
}

#=====================================================================
# LOCAL PROVIDER FUNCTIONS
#=====================================================================

#---------------------------------------------------------------------
# MINIKUBE CLUSTERS
#---------------------------------------------------------------------
# Get minikube clusters
get_minikube_clusters() {
  if ! command_exists minikube; then
    return
  fi
  
  format-echo "INFO" "Getting minikube clusters..."
  
  # Get clusters as JSON
  local minikube_clusters=""
  if ! minikube_clusters=$(minikube profile list -o json 2>/dev/null); then
    format-echo "WARNING" "Failed to get minikube profiles."
    return
  fi
  
  # Check if empty or invalid JSON
  if [[ -z "$minikube_clusters" || "$minikube_clusters" == "[]" ]]; then
    format-echo "INFO" "No minikube clusters found."
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

#---------------------------------------------------------------------
# KIND CLUSTERS
#---------------------------------------------------------------------
# Get kind clusters
get_kind_clusters() {
  if ! command_exists kind; then
    return
  fi
  
  format-echo "INFO" "Getting kind clusters..."
  
  # Get clusters
  local kind_clusters=""
  if ! kind_clusters=$(kind get clusters 2>/dev/null); then
    format-echo "WARNING" "Failed to get kind clusters."
    return
  fi
  
  # Check if empty
  if [[ -z "$kind_clusters" ]]; then
    format-echo "INFO" "No kind clusters found."
    return
  fi
  
  # Process each cluster
  while read -r name; do
    # Apply filter if provided
    if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
      continue
    fi
    
    # Store basic info for table format
    CLUSTER_NAMES+=("$name")
    CLUSTER_PROVIDERS+=("kind")
    
    # Check if the cluster is running by getting nodes
    local nodes=""
    if nodes=$(kind get nodes --name "$name" 2>/dev/null); then
      CLUSTER_STATUSES+=("Running")
      local node_count=$(echo "$nodes" | wc -l | tr -d ' ')
      CLUSTER_NODE_COUNTS+=("$node_count")
      
      # Get Kubernetes version from the node container
      local k8s_version="Unknown"
      local node_image=$(echo "$nodes" | head -1 | xargs docker inspect --format='{{.Config.Image}}' 2>/dev/null || echo "")
      if [[ -n "$node_image" ]]; then
        k8s_version=$(echo "$node_image" | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | tr -d 'v' || echo "Unknown")
      fi
      CLUSTER_VERSIONS+=("$k8s_version")
      
      # Store detailed info
      if $SHOW_DETAILS; then
        local created=$(docker inspect --format='{{.Created}}' "$(echo "$nodes" | head -1)" 2>/dev/null || echo "N/A")
        CLUSTER_DETAILS+=("Provider: kind, Nodes: $node_count, Created: $created, Image: $node_image")
      else
        CLUSTER_DETAILS+=("")
      fi
    else
      CLUSTER_STATUSES+=("Unknown")
      CLUSTER_VERSIONS+=("Unknown")
      CLUSTER_NODE_COUNTS+=("0")
      CLUSTER_DETAILS+=("")
    fi
  done <<< "$kind_clusters"
}

#---------------------------------------------------------------------
# K3D CLUSTERS
#---------------------------------------------------------------------
# Get k3d clusters
get_k3d_clusters() {
  if ! command_exists k3d; then
    return
  fi
  
  format-echo "INFO" "Getting k3d clusters..."
  
  # Get clusters as JSON
  local k3d_clusters=""
  if ! k3d_clusters=$(k3d cluster list -o json 2>/dev/null); then
    format-echo "WARNING" "Failed to get k3d clusters."
    return
  fi
  
  # Check if empty or invalid JSON
  if [[ -z "$k3d_clusters" || "$k3d_clusters" == "[]" ]]; then
    format-echo "INFO" "No k3d clusters found."
    return
  fi
  
  # Process each cluster
  echo "$k3d_clusters" | jq -c '.[]' | while read -r cluster; do
    local name=$(echo "$cluster" | jq -r '.name')
    
    # Apply filter if provided
    if [[ -n "$FILTER" && ! "$name" =~ $FILTER ]]; then
      continue
    fi
    
    local status="Running"  # k3d doesn't provide status directly
    
    # Get nodes
    local node_count=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$name\")] | length")
    
    # Get Kubernetes version
    local k8s_version="Unknown"
    local server_node=$(k3d node list -o json | jq -r ".[] | select(.clusterAssociation.cluster==\"$name\" and .role.server==true) | .name" | head -1)
    
    if [[ -n "$server_node" ]]; then
      local node_image=$(docker inspect --format='{{.Config.Image}}' "$server_node" 2>/dev/null || echo "")
      if [[ -n "$node_image" ]]; then
        k8s_version=$(echo "$node_image" | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | tr -d 'v' || echo "Unknown")
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
      local server_count=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$name\" and .role.server==true)] | length")
      local agent_count=$(k3d node list -o json | jq -r "[.[] | select(.clusterAssociation.cluster==\"$name\" and .role.agent==true)] | length")
      local created="N/A"
      
      if [[ -n "$server_node" ]]; then
        created=$(docker inspect --format='{{.Created}}' "$server_node" 2>/dev/null || echo "N/A")
      fi
      
      CLUSTER_DETAILS+=("Provider: k3d, Servers: $server_count, Agents: $agent_count, Created: $created")
    else
      CLUSTER_DETAILS+=("")
    fi
  done
}

#=====================================================================
# OUTPUT FORMATTING
#=====================================================================
#---------------------------------------------------------------------
# TABLE OUTPUT FORMAT
#---------------------------------------------------------------------
# Format output as table
format_table_output() {
  # Print table header
  printf "\033[1m%-30s %-10s %-12s %-15s %-10s\033[0m\n" "NAME" "PROVIDER" "STATUS" "VERSION" "NODES"
  printf "%-30s %-10s %-12s %-15s %-10s\n" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..12})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..10})"
  
  # Print table rows
  for i in "${!CLUSTER_NAMES[@]}"; do
    printf "%-30s %-10s %-12s %-15s %-10s\n" "${CLUSTER_NAMES[$i]}" "${CLUSTER_PROVIDERS[$i]}" "${CLUSTER_STATUSES[$i]}" "${CLUSTER_VERSIONS[$i]}" "${CLUSTER_NODE_COUNTS[$i]}"
    
    # Print details if requested
    if $SHOW_DETAILS && [[ -n "${CLUSTER_DETAILS[$i]}" ]]; then
      printf "  \033[3m%s\033[0m\n" "${CLUSTER_DETAILS[$i]}"
      echo ""
    fi
  done
}

#---------------------------------------------------------------------
# JSON OUTPUT FORMAT
#---------------------------------------------------------------------
# Format output as JSON
format_json_output() {
  local json="["
  
  for i in "${!CLUSTER_NAMES[@]}"; do
    if [[ $i -gt 0 ]]; then
      json+=","
    fi
    
    json+="{"
    json+="\"name\":\"${CLUSTER_NAMES[$i]}\","
    json+="\"provider\":\"${CLUSTER_PROVIDERS[$i]}\","
    json+="\"status\":\"${CLUSTER_STATUSES[$i]}\","
    json+="\"version\":\"${CLUSTER_VERSIONS[$i]}\","
    json+="\"nodes\":${CLUSTER_NODE_COUNTS[$i]}"
    
    if $SHOW_DETAILS && [[ -n "${CLUSTER_DETAILS[$i]}" ]]; then
      json+=",\"details\":\"${CLUSTER_DETAILS[$i]}\""
    fi
    
    json+="}"
  done
  
  json+="]"
  
  # Print formatted JSON
  echo "$json" | jq '.'
}

#---------------------------------------------------------------------
# YAML OUTPUT FORMAT
#---------------------------------------------------------------------
# Format output as YAML
format_yaml_output() {
  local yaml=""
  
  for i in "${!CLUSTER_NAMES[@]}"; do
    yaml+="- name: ${CLUSTER_NAMES[$i]}\n"
    yaml+="  provider: ${CLUSTER_PROVIDERS[$i]}\n"
    yaml+="  status: ${CLUSTER_STATUSES[$i]}\n"
    yaml+="  version: ${CLUSTER_VERSIONS[$i]}\n"
    yaml+="  nodes: ${CLUSTER_NODE_COUNTS[$i]}\n"
    
    if $SHOW_DETAILS && [[ -n "${CLUSTER_DETAILS[$i]}" ]]; then
      yaml+="  details: \"${CLUSTER_DETAILS[$i]}\"\n"
    fi
    
    yaml+="\n"
  done
  
  # Print YAML
  echo -e "$yaml" | yq e -P '.'
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
      -p|--provider)
        PROVIDER="$2"
        case "$PROVIDER" in
          all|local|cloud|minikube|kind|k3d|eks|gke|aks) ;;
          *)
            format-echo "ERROR" "Unsupported provider '${PROVIDER}'."
            format-echo "ERROR" "Supported providers: all, local, cloud, minikube, kind, k3d, eks, gke, aks"
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
            format-echo "ERROR" "Unsupported format '${FORMAT}'."
            format-echo "ERROR" "Supported formats: table, json, yaml"
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
      --region)
        REGION="$2"
        shift 2
        ;;
      --profile)
        PROFILE="$2"
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
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Kubernetes Clusters List Script"
  
  format-echo "INFO" "Listing Kubernetes clusters..."
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Provider:   $PROVIDER"
  format-echo "INFO" "  Format:     $FORMAT"
  format-echo "INFO" "  Details:    $SHOW_DETAILS"
  if [[ -n "$FILTER" ]]; then
    format-echo "INFO" "  Filter:     $FILTER"
  fi
  if [[ -n "$REGION" ]]; then
    format-echo "INFO" "  Region:     $REGION"
  fi
  if [[ -n "$PROFILE" ]]; then
    format-echo "INFO" "  Profile:    $PROFILE"
  fi
  
  # Check requirements
  check_requirements
  
  #---------------------------------------------------------------------
  # DATA COLLECTION
  #---------------------------------------------------------------------
  # Initialize arrays to store cluster information
  CLUSTER_NAMES=()
  CLUSTER_PROVIDERS=()
  CLUSTER_STATUSES=()
  CLUSTER_VERSIONS=()
  CLUSTER_NODE_COUNTS=()
  CLUSTER_DETAILS=()
  
  # Get clusters from local providers
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "local" || "$PROVIDER" == "minikube" ]]; then
    get_minikube_clusters
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "local" || "$PROVIDER" == "kind" ]]; then
    get_kind_clusters
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "local" || "$PROVIDER" == "k3d" ]]; then
    get_k3d_clusters
  fi
  
  # Get clusters from cloud providers
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "cloud" || "$PROVIDER" == "eks" ]]; then
    get_eks_clusters
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "cloud" || "$PROVIDER" == "gke" ]]; then
    get_gke_clusters
  fi
  
  if [[ "$PROVIDER" == "all" || "$PROVIDER" == "cloud" || "$PROVIDER" == "aks" ]]; then
    get_aks_clusters
  fi
  
  #---------------------------------------------------------------------
  # RESULTS PROCESSING
  #---------------------------------------------------------------------
  # Check if we found any clusters
  if [[ ${#CLUSTER_NAMES[@]} -eq 0 ]]; then
    format-echo "INFO" "No clusters found for the specified criteria."
    print_with_separator
    exit 0
  fi
  
  # Format and display output
  format-echo "INFO" "Found ${#CLUSTER_NAMES[@]} clusters."
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
