#!/bin/bash
# convert-cluster.sh
# Script to convert/migrate between Kubernetes cluster providers

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
SOURCE_PROVIDER=""
TARGET_PROVIDER=""
SOURCE_CLUSTER=""
TARGET_CLUSTER=""
SOURCE_CONTEXT=""
TARGET_CONTEXT=""
SOURCE_KUBECONFIG=""
TARGET_KUBECONFIG=""
NAMESPACES=()
INCLUDE_ALL_NAMESPACES=false
EXCLUDE_NAMESPACES=("kube-system" "kube-public" "kube-node-lease")
RESOURCES=("deployments" "statefulsets" "daemonsets" "configmaps" "secrets" "services" "ingresses" "horizontalpodautoscalers" "pvc")
CUSTOM_RESOURCES=true
TRANSFER_STORAGE=false
RECREATE_PVCS=false
CREATE_TARGET=false
TARGET_NODES=3
TARGET_K8S_VERSION=""
DRY_RUN=false
INTERACTIVE=false
FORCE=false
TIMEOUT=600
BACKUP_DIR=""
LOG_FILE="/dev/null"

# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Conversion Tool"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script assists in converting/migrating between Kubernetes cluster providers."
  echo "  It exports resources from a source cluster and imports them to a target cluster."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <options>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--source-provider <PROVIDER>\033[0m    Source cluster provider (minikube, kind, k3d, eks, gke, aks)"
  echo -e "  \033[1;33m--target-provider <PROVIDER>\033[0m    Target cluster provider (minikube, kind, k3d, eks, gke, aks)"
  echo -e "  \033[1;33m--source-cluster <NAME>\033[0m         Source cluster name"
  echo -e "  \033[1;33m--target-cluster <NAME>\033[0m         Target cluster name"
  echo -e "  \033[1;33m--source-context <CONTEXT>\033[0m      (Optional) Source kubectl context (auto-detected if not provided)"
  echo -e "  \033[1;33m--target-context <CONTEXT>\033[0m      (Optional) Target kubectl context (auto-detected if not provided)"
  echo -e "  \033[1;33m--source-kubeconfig <PATH>\033[0m      (Optional) Path to source kubeconfig file"
  echo -e "  \033[1;33m--target-kubeconfig <PATH>\033[0m      (Optional) Path to target kubeconfig file"
  echo -e "  \033[1;33m--namespace <NAMESPACE>\033[0m         (Optional) Namespace to include (can be used multiple times)"
  echo -e "  \033[1;33m--all-namespaces\033[0m                (Optional) Include all namespaces"
  echo -e "  \033[1;33m--exclude-namespace <NAMESPACE>\033[0m  (Optional) Namespace to exclude (can be used multiple times)"
  echo -e "  \033[1;33m--resource <RESOURCE>\033[0m           (Optional) Resource type to include (can be used multiple times)"
  echo -e "  \033[1;33m--include-custom-resources\033[0m      (Optional) Include custom resource definitions and resources"
  echo -e "  \033[1;33m--transfer-storage\033[0m              (Optional) Attempt to transfer persistent volumes"
  echo -e "  \033[1;33m--recreate-pvcs\033[0m                 (Optional) Recreate PVCs in target cluster without data transfer"
  echo -e "  \033[1;33m--create-target\033[0m                 (Optional) Create target cluster if it doesn't exist"
  echo -e "  \033[1;33m--target-nodes <COUNT>\033[0m          (Optional) Number of nodes for target cluster if created (default: ${TARGET_NODES})"
  echo -e "  \033[1;33m--target-k8s-version <VERSION>\033[0m  (Optional) Kubernetes version for target cluster if created"
  echo -e "  \033[1;33m--dry-run\033[0m                       (Optional) Only print what would be done without making changes"
  echo -e "  \033[1;33m--interactive\033[0m                   (Optional) Run in interactive mode with confirmations"
  echo -e "  \033[1;33m--force\033[0m                         (Optional) Skip confirmations"
  echo -e "  \033[1;33m--timeout <SECONDS>\033[0m             (Optional) Timeout for operations (default: ${TIMEOUT}s)"
  echo -e "  \033[1;33m--backup-dir <PATH>\033[0m             (Optional) Directory to store backup files (default: temporary directory)"
  echo -e "  \033[1;33m--log <FILE>\033[0m                    (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                          (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --source-provider minikube --target-provider kind --source-cluster minikube --target-cluster kind-cluster"
  echo "  $0 --source-provider kind --target-provider eks --source-cluster kind-cluster --target-cluster production --namespace app"
  echo "  $0 --source-provider eks --target-provider gke --source-cluster dev --target-cluster prod --all-namespaces"
  echo "  $0 --source-provider gke --target-provider aks --source-context gke_project_zone_cluster --target-context aks-cluster --interactive"
  print_with_separator
  exit 1
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for required tools
check_requirements() {
  log_message "INFO" "Checking requirements..."
  
  # Check for kubectl
  if ! command_exists kubectl; then
    log_message "ERROR" "kubectl not found. Please install it first."
    exit 1
  fi
  
  # Check for jq
  if ! command_exists jq; then
    log_message "ERROR" "jq not found. Please install it first."
    exit 1
  fi
  
  # Check for yq
  if ! command_exists yq; then
    log_message "WARNING" "yq not found. Some YAML processing capabilities may be limited."
  fi
  
  # Check for provider-specific tools
  case "$SOURCE_PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        log_message "ERROR" "minikube not found. Please install it to use minikube as source provider."
        exit 1
      fi
      ;;
    kind)
      if ! command_exists kind; then
        log_message "ERROR" "kind not found. Please install it to use kind as source provider."
        exit 1
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        log_message "ERROR" "k3d not found. Please install it to use k3d as source provider."
        exit 1
      fi
      ;;
    eks)
      if ! command_exists aws; then
        log_message "ERROR" "AWS CLI not found. Please install it to use EKS as source provider."
        exit 1
      fi
      ;;
    gke)
      if ! command_exists gcloud; then
        log_message "ERROR" "Google Cloud SDK not found. Please install it to use GKE as source provider."
        exit 1
      fi
      ;;
    aks)
      if ! command_exists az; then
        log_message "ERROR" "Azure CLI not found. Please install it to use AKS as source provider."
        exit 1
      fi
      ;;
  esac
  
  case "$TARGET_PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        log_message "ERROR" "minikube not found. Please install it to use minikube as target provider."
        exit 1
      fi
      ;;
    kind)
      if ! command_exists kind; then
        log_message "ERROR" "kind not found. Please install it to use kind as target provider."
        exit 1
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        log_message "ERROR" "k3d not found. Please install it to use k3d as target provider."
        exit 1
      fi
      ;;
    eks)
      if ! command_exists aws; then
        log_message "ERROR" "AWS CLI not found. Please install it to use EKS as target provider."
        exit 1
      fi
      ;;
    gke)
      if ! command_exists gcloud; then
        log_message "ERROR" "Google Cloud SDK not found. Please install it to use GKE as target provider."
        exit 1
      fi
      ;;
    aks)
      if ! command_exists az; then
        log_message "ERROR" "Azure CLI not found. Please install it to use AKS as target provider."
        exit 1
      fi
      ;;
  esac
  
  log_message "SUCCESS" "All required tools are available."
}

# Validate cluster exists and is accessible
validate_cluster() {
  local provider="$1"
  local cluster="$2"
  local context="$3"
  local kubeconfig="$4"
  local temp_env=""
  
  log_message "INFO" "Validating $provider cluster '$cluster'..."
  
  # Set KUBECONFIG if provided
  if [[ -n "$kubeconfig" ]]; then
    temp_env="KUBECONFIG=$kubeconfig"
  fi
  
  # Set context if provided
  if [[ -n "$context" ]]; then
    if ! eval "$temp_env kubectl config use-context '$context'" &>/dev/null; then
      log_message "ERROR" "Cannot switch to context '$context'. Please check it exists."
      return 1
    fi
  else
    # Auto-detect context based on provider and cluster
    case "$provider" in
      minikube)
        context="$cluster"
        ;;
      kind)
        context="kind-$cluster"
        ;;
      k3d)
        context="k3d-$cluster"
        ;;
      eks|gke|aks)
        # For cloud providers, we need to check if the cluster exists
        log_message "INFO" "Auto-detecting context for $provider cluster '$cluster'..."
        local contexts
        contexts=$(eval "$temp_env kubectl config get-contexts -o name" 2>/dev/null)
        
        # Try to find a context matching the cluster name pattern
        case "$provider" in
          eks)
            context=$(echo "$contexts" | grep "^arn:aws:eks.*$cluster" || echo "$contexts" | grep "$cluster")
            ;;
          gke)
            context=$(echo "$contexts" | grep "gke.*$cluster")
            ;;
          aks)
            context=$(echo "$contexts" | grep "$cluster")
            ;;
        esac
        
        if [[ -z "$context" ]]; then
          log_message "ERROR" "Cannot auto-detect context for $provider cluster '$cluster'."
          log_message "ERROR" "Please specify the context explicitly with --source-context or --target-context."
          return 1
        else
          log_message "INFO" "Auto-detected context: $context"
        fi
        ;;
    esac
    
    if ! eval "$temp_env kubectl config use-context '$context'" &>/dev/null; then
      log_message "ERROR" "Cannot switch to auto-detected context '$context'. Please check it exists."
      return 1
    fi
  fi
  
  # Verify we can access the cluster
  if ! eval "$temp_env kubectl get nodes" &>/dev/null; then
    log_message "ERROR" "Cannot access cluster using context '$context'."
    log_message "ERROR" "Please check your cluster is running and accessible."
    return 1
  fi
  
  log_message "SUCCESS" "Successfully validated $provider cluster '$cluster' using context '$context'."
  
  # Return the context (this allows caller to capture auto-detected context)
  echo "$context"
  return 0
}

# Create target cluster if it doesn't exist
create_target_cluster() {
  if [[ "$CREATE_TARGET" != true ]]; then
    return 0
  fi
  
  log_message "INFO" "Checking if target cluster '$TARGET_CLUSTER' needs to be created..."
  
  # Check if cluster already exists
  local existing_context
  if existing_context=$(validate_cluster "$TARGET_PROVIDER" "$TARGET_CLUSTER" "$TARGET_CONTEXT" "$TARGET_KUBECONFIG" 2>/dev/null); then
    log_message "INFO" "Target cluster already exists, skipping creation."
    TARGET_CONTEXT="$existing_context"
    return 0
  fi
  
  log_message "INFO" "Creating target cluster '$TARGET_CLUSTER' with provider '$TARGET_PROVIDER'..."
  
  if [[ "$DRY_RUN" == true ]]; then
    log_message "DRY-RUN" "Would create $TARGET_PROVIDER cluster '$TARGET_CLUSTER' with $TARGET_NODES nodes"
    return 0
  fi
  
  # Version flag for different providers
  local version_flag=""
  if [[ -n "$TARGET_K8S_VERSION" ]]; then
    case "$TARGET_PROVIDER" in
      minikube)
        version_flag="--kubernetes-version=$TARGET_K8S_VERSION"
        ;;
      kind)
        # kind uses its own node image versions, not direct k8s versions
        log_message "WARNING" "kind doesn't support direct Kubernetes version selection. Using default version."
        version_flag=""
        ;;
      k3d)
        version_flag="--image=rancher/k3s:v$TARGET_K8S_VERSION-k3s1"
        ;;
      eks)
        version_flag="--kubernetes-version=$TARGET_K8S_VERSION"
        ;;
      gke)
        version_flag="--cluster-version=$TARGET_K8S_VERSION"
        ;;
      aks)
        version_flag="--kubernetes-version=$TARGET_K8S_VERSION"
        ;;
    esac
  fi
  
  # Create cluster based on provider
  case "$TARGET_PROVIDER" in
    minikube)
      log_message "INFO" "Creating minikube cluster '$TARGET_CLUSTER'..."
      if ! minikube start -p "$TARGET_CLUSTER" $version_flag --nodes="$TARGET_NODES"; then
        log_message "ERROR" "Failed to create minikube cluster '$TARGET_CLUSTER'."
        exit 1
      fi
      TARGET_CONTEXT="$TARGET_CLUSTER"
      ;;
    kind)
      log_message "INFO" "Creating kind cluster '$TARGET_CLUSTER'..."
      if ! kind create cluster --name "$TARGET_CLUSTER"; then
        log_message "ERROR" "Failed to create kind cluster '$TARGET_CLUSTER'."
        exit 1
      fi
      TARGET_CONTEXT="kind-$TARGET_CLUSTER"
      ;;
    k3d)
      log_message "INFO" "Creating k3d cluster '$TARGET_CLUSTER'..."
      if ! k3d cluster create "$TARGET_CLUSTER" $version_flag --agents "$TARGET_NODES"; then
        log_message "ERROR" "Failed to create k3d cluster '$TARGET_CLUSTER'."
        exit 1
      fi
      TARGET_CONTEXT="k3d-$TARGET_CLUSTER"
      ;;
    eks)
      log_message "ERROR" "Creating EKS clusters is not supported in this script due to complexity."
      log_message "ERROR" "Please create the EKS cluster manually or use eksctl."
      exit 1
      ;;
    gke)
      log_message "ERROR" "Creating GKE clusters is not supported in this script due to complexity."
      log_message "ERROR" "Please create the GKE cluster manually or use gcloud."
      exit 1
      ;;
    aks)
      log_message "ERROR" "Creating AKS clusters is not supported in this script due to complexity."
      log_message "ERROR" "Please create the AKS cluster manually or use az aks create."
      exit 1
      ;;
  esac
  
  log_message "SUCCESS" "Successfully created target cluster '$TARGET_CLUSTER'."
  return 0
}

# Get list of namespaces to migrate
get_namespaces() {
  log_message "INFO" "Determining namespaces to migrate..."
  
  local ns_list=()
  local kubeconfig_flag=""
  
  if [[ -n "$SOURCE_KUBECONFIG" ]]; then
    kubeconfig_flag="--kubeconfig=$SOURCE_KUBECONFIG"
  fi
  
  # Switch to source context
  if ! kubectl config use-context "$SOURCE_CONTEXT" &>/dev/null; then
    log_message "ERROR" "Cannot switch to source context '$SOURCE_CONTEXT'."
    exit 1
  fi
  
  # Get all namespaces if requested
  if [[ "$INCLUDE_ALL_NAMESPACES" == true ]]; then
    ns_list=($(kubectl get namespaces $kubeconfig_flag -o jsonpath='{.items[*].metadata.name}'))
    log_message "INFO" "Found ${#ns_list[@]} namespaces in total."
  else
    # Use specified namespaces
    if [[ ${#NAMESPACES[@]} -eq 0 ]]; then
      log_message "ERROR" "No namespaces specified. Use --namespace or --all-namespaces."
      exit 1
    fi
    ns_list=("${NAMESPACES[@]}")
  fi
  
  # Filter out excluded namespaces
  local filtered_ns=()
  for ns in "${ns_list[@]}"; do
    local excluded=false
    for excluded_ns in "${EXCLUDE_NAMESPACES[@]}"; do
      if [[ "$ns" == "$excluded_ns" ]]; then
        excluded=true
        break
      fi
    done
    
    if [[ "$excluded" == false ]]; then
      filtered_ns+=("$ns")
    else
      log_message "INFO" "Excluding namespace: $ns"
    fi
  done
  
  if [[ ${#filtered_ns[@]} -eq 0 ]]; then
    log_message "ERROR" "No namespaces left after filtering. Please check your namespace options."
    exit 1
  fi
  
  log_message "INFO" "Will migrate ${#filtered_ns[@]} namespaces: ${filtered_ns[*]}"
  echo "${filtered_ns[@]}"
}

# Export resources from source cluster
export_resources() {
  local namespaces=("$@")
  log_message "INFO" "Exporting resources from source cluster..."
  
  # Create backup directory if not specified
  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR=$(mktemp -d "/tmp/k8s-conversion-XXXXX")
    log_message "INFO" "Created temporary backup directory: $BACKUP_DIR"
  else
    mkdir -p "$BACKUP_DIR"
    log_message "INFO" "Using backup directory: $BACKUP_DIR"
  fi
  
  # Switch to source context
  if ! kubectl config use-context "$SOURCE_CONTEXT" &>/dev/null; then
    log_message "ERROR" "Cannot switch to source context '$SOURCE_CONTEXT'."
    exit 1
  fi
  
  local kubeconfig_flag=""
  if [[ -n "$SOURCE_KUBECONFIG" ]]; then
    kubeconfig_flag="--kubeconfig=$SOURCE_KUBECONFIG"
  fi
  
  # Export CRDs if requested
  if [[ "$CUSTOM_RESOURCES" == true ]]; then
    log_message "INFO" "Exporting Custom Resource Definitions..."
    
    if [[ "$DRY_RUN" == true ]]; then
      log_message "DRY-RUN" "Would export Custom Resource Definitions to $BACKUP_DIR/crds.yaml"
    else
      if ! kubectl get crds $kubeconfig_flag -o yaml > "$BACKUP_DIR/crds.yaml"; then
        log_message "WARNING" "Failed to export Custom Resource Definitions."
      else
        log_message "SUCCESS" "Exported Custom Resource Definitions to $BACKUP_DIR/crds.yaml"
      fi
    fi
  fi
  
  # Export resources for each namespace
  for ns in "${namespaces[@]}"; do
    log_message "INFO" "Exporting resources from namespace: $ns"
    
    # Create namespace directory
    mkdir -p "$BACKUP_DIR/$ns"
    
    # Export namespace definition
    if [[ "$DRY_RUN" == true ]]; then
      log_message "DRY-RUN" "Would export namespace $ns to $BACKUP_DIR/$ns/namespace.yaml"
    else
      if ! kubectl get namespace $ns $kubeconfig_flag -o yaml > "$BACKUP_DIR/$ns/namespace.yaml"; then
        log_message "WARNING" "Failed to export namespace definition for $ns."
      else
        log_message "SUCCESS" "Exported namespace definition to $BACKUP_DIR/$ns/namespace.yaml"
      fi
    fi
    
    # Export each resource type
    for resource in "${RESOURCES[@]}"; do
      log_message "INFO" "Exporting $resource from namespace $ns..."
      
      if [[ "$DRY_RUN" == true ]]; then
        log_message "DRY-RUN" "Would export $resource from namespace $ns to $BACKUP_DIR/$ns/$resource.yaml"
      else
        # Check if resource exists in this namespace
        if kubectl get "$resource" $kubeconfig_flag -n "$ns" &>/dev/null; then
          if ! kubectl get "$resource" $kubeconfig_flag -n "$ns" -o yaml > "$BACKUP_DIR/$ns/$resource.yaml"; then
            log_message "WARNING" "Failed to export $resource from namespace $ns."
          else
            log_message "SUCCESS" "Exported $resource from namespace $ns to $BACKUP_DIR/$ns/$resource.yaml"
          fi
        else
          log_message "INFO" "No $resource found in namespace $ns, skipping."
        fi
      fi
    done
    
    # Export custom resources if requested
    if [[ "$CUSTOM_RESOURCES" == true ]]; then
      log_message "INFO" "Exporting custom resources from namespace $ns..."
      
      # Create custom resources directory
      mkdir -p "$BACKUP_DIR/$ns/custom-resources"
      
      # Get all CRDs
      local crds=$(kubectl get crds $kubeconfig_flag -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      
      for crd in $crds; do
        # Skip Kubernetes system CRDs
        if [[ "$crd" == *.k8s.io ]]; then
          continue
        fi
        
        # Check if this CRD has resources in this namespace
        if kubectl get "$crd" $kubeconfig_flag -n "$ns" &>/dev/null; then
          if [[ "$DRY_RUN" == true ]]; then
            log_message "DRY-RUN" "Would export custom resource $crd from namespace $ns"
          else
            if ! kubectl get "$crd" $kubeconfig_flag -n "$ns" -o yaml > "$BACKUP_DIR/$ns/custom-resources/$crd.yaml"; then
              log_message "WARNING" "Failed to export custom resource $crd from namespace $ns."
            else
              log_message "SUCCESS" "Exported custom resource $crd from namespace $ns"
            fi
          fi
        fi
      done
    fi
  done
  
  log_message "SUCCESS" "Export completed. Resources stored in $BACKUP_DIR"
}

# Clean up exported resources to make them suitable for import
clean_resources() {
  log_message "INFO" "Cleaning exported resources for import..."
  
  if [[ "$DRY_RUN" == true ]]; then
    log_message "DRY-RUN" "Would clean up exported resources for import"
    return 0
  fi
  
  # Process CRDs first if they exist
  if [[ -f "$BACKUP_DIR/crds.yaml" ]]; then
    log_message "INFO" "Cleaning Custom Resource Definitions..."
    
    # Clean CRDs using yq if available, otherwise use sed and grep
    if command_exists yq; then
      yq e '
        .items[] |= (
          del(.metadata.creationTimestamp) |
          del(.metadata.uid) |
          del(.metadata.resourceVersion) |
          del(.metadata.generation) |
          del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") |
          del(.status)
        )
      ' "$BACKUP_DIR/crds.yaml" > "$BACKUP_DIR/crds.yaml.clean"
      mv "$BACKUP_DIR/crds.yaml.clean" "$BACKUP_DIR/crds.yaml"
    else
      # Backup original file
      cp "$BACKUP_DIR/crds.yaml" "$BACKUP_DIR/crds.yaml.bak"
      
      # Use sed to remove fields (this is a simplified approach)
      sed -i'.tmp' -e '/creationTimestamp:/d' \
                   -e '/uid:/d' \
                   -e '/resourceVersion:/d' \
                   -e '/generation:/d' \
                   -e '/kubectl.kubernetes.io\/last-applied-configuration:/d' \
                   -e '/status:/d' "$BACKUP_DIR/crds.yaml"
      
      # Remove temporary files
      rm -f "$BACKUP_DIR/crds.yaml.tmp"
    fi
    
    log_message "SUCCESS" "Cleaned Custom Resource Definitions."
  fi
  
  # Process each namespace directory
  for ns_dir in "$BACKUP_DIR"/*; do
    if [[ ! -d "$ns_dir" ]]; then
      continue
    fi
    
    local ns=$(basename "$ns_dir")
    log_message "INFO" "Cleaning resources for namespace: $ns"
    
    # Process namespace definition
    if [[ -f "$ns_dir/namespace.yaml" ]]; then
      log_message "INFO" "Cleaning namespace definition..."
      
      if command_exists yq; then
        yq e '
          del(.metadata.creationTimestamp) |
          del(.metadata.uid) |
          del(.metadata.resourceVersion) |
          del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") |
          del(.spec.finalizers) |
          del(.status)
        ' "$ns_dir/namespace.yaml" > "$ns_dir/namespace.yaml.clean"
        mv "$ns_dir/namespace.yaml.clean" "$ns_dir/namespace.yaml"
      else
        # Backup original file
        cp "$ns_dir/namespace.yaml" "$ns_dir/namespace.yaml.bak"
        
        # Use sed to remove fields
        sed -i'.tmp' -e '/creationTimestamp:/d' \
                     -e '/uid:/d' \
                     -e '/resourceVersion:/d' \
                     -e '/kubectl.kubernetes.io\/last-applied-configuration:/d' \
                     -e '/finalizers:/d' \
                     -e '/status:/d' "$ns_dir/namespace.yaml"
        
        # Remove temporary files
        rm -f "$ns_dir/namespace.yaml.tmp"
      fi
    fi
    
    # Process each resource file
    for resource_file in "$ns_dir"/*.yaml; do
      if [[ ! -f "$resource_file" || "$resource_file" == *"namespace.yaml" ]]; then
        continue
      fi
      
      local resource=$(basename "$resource_file" .yaml)
      log_message "INFO" "Cleaning $resource resources..."
      
      if command_exists yq; then
        yq e '
          .items[] |= (
            del(.metadata.creationTimestamp) |
            del(.metadata.uid) |
            del(.metadata.resourceVersion) |
            del(.metadata.generation) |
            del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") |
            del(.spec.clusterIP) |
            del(.spec.clusterIPs) |
            del(.status)
          )
        ' "$resource_file" > "$resource_file.clean"
        mv "$resource_file.clean" "$resource_file"
      else
        # Backup original file
        cp "$resource_file" "$resource_file.bak"
        
        # Use sed to remove fields
        sed -i'.tmp' -e '/creationTimestamp:/d' \
                     -e '/uid:/d' \
                     -e '/resourceVersion:/d' \
                     -e '/generation:/d' \
                     -e '/kubectl.kubernetes.io\/last-applied-configuration:/d' \
                     -e '/clusterIP:/d' \
                     -e '/clusterIPs:/d' \
                     -e '/status:/d' "$resource_file"
        
        # Remove temporary files
        rm -f "$resource_file.tmp"
      fi
    done
    
    # Process custom resources
    if [[ -d "$ns_dir/custom-resources" ]]; then
      for cr_file in "$ns_dir/custom-resources"/*.yaml; do
        if [[ ! -f "$cr_file" ]]; then
          continue
        fi
        
        local cr=$(basename "$cr_file" .yaml)
        log_message "INFO" "Cleaning custom resource $cr..."
        
        if command_exists yq; then
          yq e '
            .items[] |= (
              del(.metadata.creationTimestamp) |
              del(.metadata.uid) |
              del(.metadata.resourceVersion) |
              del(.metadata.generation) |
              del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") |
              del(.status)
            )
          ' "$cr_file" > "$cr_file.clean"
          mv "$cr_file.clean" "$cr_file"
        else
          # Backup original file
          cp "$cr_file" "$cr_file.bak"
          
          # Use sed to remove fields
          sed -i'.tmp' -e '/creationTimestamp:/d' \
                       -e '/uid:/d' \
                       -e '/resourceVersion:/d' \
                       -e '/generation:/d' \
                       -e '/kubectl.kubernetes.io\/last-applied-configuration:/d' \
                       -e '/status:/d' "$cr_file"
          
          # Remove temporary files
          rm -f "$cr_file.tmp"
        fi
      done
    fi
  done
  
  log_message "SUCCESS" "Resources cleaned and prepared for import."
}

# Import resources to target cluster
import_resources() {
  local namespaces=("$@")
  log_message "INFO" "Importing resources to target cluster..."
  
  # Switch to target context
  if ! kubectl config use-context "$TARGET_CONTEXT" &>/dev/null; then
    log_message "ERROR" "Cannot switch to target context '$TARGET_CONTEXT'."
    exit 1
  fi
  
  local kubeconfig_flag=""
  if [[ -n "$TARGET_KUBECONFIG" ]]; then
    kubeconfig_flag="--kubeconfig=$TARGET_KUBECONFIG"
  fi
  
  # Import CRDs first if they exist
  if [[ -f "$BACKUP_DIR/crds.yaml" && "$CUSTOM_RESOURCES" == true ]]; then
    log_message "INFO" "Importing Custom Resource Definitions..."
    
    if [[ "$DRY_RUN" == true ]]; then
      log_message "DRY-RUN" "Would import Custom Resource Definitions from $BACKUP_DIR/crds.yaml"
    else
      if ! kubectl apply $kubeconfig_flag -f "$BACKUP_DIR/crds.yaml"; then
        log_message "WARNING" "Failed to import some Custom Resource Definitions."
      else
        log_message "SUCCESS" "Imported Custom Resource Definitions."
      fi
      
      # Wait for CRDs to be established
      log_message "INFO" "Waiting for CRDs to be established..."
      sleep 10
    fi
  fi
  
  # Import resources for each namespace
  for ns in "${namespaces[@]}"; do
    log_message "INFO" "Importing resources for namespace: $ns"
    
    # Check if namespace directory exists
    if [[ ! -d "$BACKUP_DIR/$ns" ]]; then
      log_message "WARNING" "No resources found for namespace $ns, skipping."
      continue
    fi
    
    # Create namespace first
    if [[ -f "$BACKUP_DIR/$ns/namespace.yaml" ]]; then
      log_message "INFO" "Creating namespace: $ns"
      
      if [[ "$DRY_RUN" == true ]]; then
        log_message "DRY-RUN" "Would create namespace $ns from $BACKUP_DIR/$ns/namespace.yaml"
      else
        if ! kubectl apply $kubeconfig_flag -f "$BACKUP_DIR/$ns/namespace.yaml"; then
          log_message "WARNING" "Failed to create namespace $ns. Trying to create it directly."
          kubectl create namespace $kubeconfig_flag "$ns" || {
            log_message "ERROR" "Failed to create namespace $ns. Skipping this namespace."
            continue
          }
        fi
      fi
    else
      log_message "INFO" "Namespace definition not found, creating namespace $ns directly."
      
      if [[ "$DRY_RUN" == true ]]; then
        log_message "DRY-RUN" "Would create namespace $ns"
      else
        kubectl create namespace $kubeconfig_flag "$ns" || {
          log_message "ERROR" "Failed to create namespace $ns. Skipping this namespace."
          continue
        }
      fi
    fi
    
    # Apply resources in correct order to handle dependencies
    local resource_order=("configmaps" "secrets" "pvc" "services" "deployments" "statefulsets" "daemonsets" "ingresses" "horizontalpodautoscalers")
    
    for resource in "${resource_order[@]}"; do
      if [[ -f "$BACKUP_DIR/$ns/$resource.yaml" ]]; then
        log_message "INFO" "Importing $resource for namespace $ns..."
        
        if [[ "$DRY_RUN" == true ]]; then
          log_message "DRY-RUN" "Would import $resource from $BACKUP_DIR/$ns/$resource.yaml"
        else
          # Special handling for PVCs
          if [[ "$resource" == "pvc" && "$RECREATE_PVCS" != true && "$TRANSFER_STORAGE" != true ]]; then
            log_message "INFO" "Skipping PVCs as requested."
            continue
          fi
          
          if ! kubectl apply $kubeconfig_flag -f "$BACKUP_DIR/$ns/$resource.yaml"; then
            log_message "WARNING" "Failed to import some $resource in namespace $ns."
          else
            log_message "SUCCESS" "Imported $resource in namespace $ns."
          fi
        fi
      fi
    done
    
    # Import custom resources if they exist
    if [[ -d "$BACKUP_DIR/$ns/custom-resources" && "$CUSTOM_RESOURCES" == true ]]; then
      log_message "INFO" "Importing custom resources for namespace $ns..."
      
      for cr_file in "$BACKUP_DIR/$ns/custom-resources"/*.yaml; do
        if [[ ! -f "$cr_file" ]]; then
          continue
        fi
        
        local cr=$(basename "$cr_file" .yaml)
        log_message "INFO" "Importing custom resource $cr for namespace $ns..."
        
        if [[ "$DRY_RUN" == true ]]; then
          log_message "DRY-RUN" "Would import custom resource $cr from $cr_file"
        else
          if ! kubectl apply $kubeconfig_flag -f "$cr_file"; then
            log_message "WARNING" "Failed to import custom resource $cr in namespace $ns."
          else
            log_message "SUCCESS" "Imported custom resource $cr in namespace $ns."
          fi
        fi
      done
    fi
  done
  
  log_message "SUCCESS" "Import completed. Resources imported to target cluster."
}

# Verify import by checking resources in target cluster
verify_import() {
  local namespaces=("$@")
  log_message "INFO" "Verifying resource import in target cluster..."
  
  # Switch to target context
  if ! kubectl config use-context "$TARGET_CONTEXT" &>/dev/null; then
    log_message "ERROR" "Cannot switch to target context '$TARGET_CONTEXT'."
    exit 1
  fi
  
  local kubeconfig_flag=""
  if [[ -n "$TARGET_KUBECONFIG" ]]; then
    kubeconfig_flag="--kubeconfig=$TARGET_KUBECONFIG"
  fi
  
  # Check each namespace
  for ns in "${namespaces[@]}"; do
    log_message "INFO" "Verifying resources in namespace: $ns"
    
    # Check if namespace exists
    if ! kubectl get namespace $kubeconfig_flag "$ns" &>/dev/null; then
      log_message "ERROR" "Namespace $ns does not exist in target cluster."
      continue
    fi
    
    # Check each resource type
    for resource in "${RESOURCES[@]}"; do
      # Skip PVCs if not requested
      if [[ "$resource" == "pvc" && "$RECREATE_PVCS" != true && "$TRANSFER_STORAGE" != true ]]; then
        continue
      fi
      
      log_message "INFO" "Checking $resource in namespace $ns..."
      
      # Get resource count in source
      local source_count=0
      if [[ -f "$BACKUP_DIR/$ns/$resource.yaml" ]]; then
        source_count=$(grep -c "^kind:" "$BACKUP_DIR/$ns/$resource.yaml" || echo 0)
      fi
      
      # Get resource count in target
      local target_count=0
      target_count=$(kubectl get $resource $kubeconfig_flag -n "$ns" --no-headers 2>/dev/null | wc -l || echo 0)
      target_count=$(echo $target_count) # Trim whitespace
      
      log_message "INFO" "Found $target_count of $source_count $resource resources in namespace $ns."
      
      if [[ "$source_count" -gt 0 && "$target_count" -eq 0 ]]; then
        log_message "WARNING" "No $resource resources found in namespace $ns in target cluster."
      elif [[ "$target_count" -lt "$source_count" ]]; then
        log_message "WARNING" "Only $target_count of $source_count $resource resources found in namespace $ns."
      fi
    done
    
    # Check pod status
    log_message "INFO" "Checking pod status in namespace $ns..."
    local pods_total=0
    local pods_running=0
    
    pods_total=$(kubectl get pods $kubeconfig_flag -n "$ns" --no-headers 2>/dev/null | wc -l || echo 0)
    pods_total=$(echo $pods_total) # Trim whitespace
    
    if [[ "$pods_total" -gt 0 ]]; then
      pods_running=$(kubectl get pods $kubeconfig_flag -n "$ns" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
      log_message "INFO" "$pods_running of $pods_total pods are running in namespace $ns."
      
      if [[ "$pods_running" -lt "$pods_total" ]]; then
        log_message "WARNING" "Some pods are not running in namespace $ns. Check with 'kubectl get pods -n $ns'."
      fi
    else
      log_message "INFO" "No pods found in namespace $ns."
    fi
  done
  
  log_message "SUCCESS" "Verification completed."
}

# Transfer persistent volume data (if requested)
transfer_storage() {
  if [[ "$TRANSFER_STORAGE" != true ]]; then
    return 0
  fi
  
  log_message "INFO" "Starting storage data transfer between clusters..."
  
  if [[ "$DRY_RUN" == true ]]; then
    log_message "DRY-RUN" "Would transfer persistent volume data between clusters"
    return 0
  fi
  
  log_message "WARNING" "Storage transfer is a complex operation that depends on many factors."
  log_message "WARNING" "This script provides basic guidance but may not be suitable for all environments."
  
  # Check if both clusters are local or cloud
  local source_is_local=false
  local target_is_local=false
  
  case "$SOURCE_PROVIDER" in
    minikube|kind|k3d) source_is_local=true ;;
  esac
  
  case "$TARGET_PROVIDER" in
    minikube|kind|k3d) target_is_local=true ;;
  esac
  
  if [[ "$source_is_local" == true && "$target_is_local" == true ]]; then
    log_message "INFO" "Both clusters are local. Using local data transfer approach."
    
    # This is a simplified approach for local clusters
    log_message "INFO" "For local clusters, consider the following approaches:"
    log_message "INFO" "1. For minikube: Use hostPath volumes and ensure they point to the same host directory."
    log_message "INFO" "2. For kind/k3d: Use Docker volumes and bind them to the same host directory."
    log_message "INFO" "3. For any local cluster: Set up a local NFS or MinIO server for storage."
    
    log_message "WARNING" "Automated data transfer between local clusters is not implemented."
    log_message "WARNING" "Please see the documentation for manual steps."
    
  elif [[ "$source_is_local" == false && "$target_is_local" == false ]]; then
    log_message "INFO" "Both clusters are cloud-based. Using cloud data transfer approach."
    
    # This would be provider-specific and complex
    log_message "INFO" "For cloud clusters, consider the following approaches:"
    log_message "INFO" "1. Use cloud-native storage options (EBS, Persistent Disk, Azure Disk)."
    log_message "INFO" "2. Set up storage replication at the cloud provider level."
    log_message "INFO" "3. Use a backup/restore solution like Velero."
    
    log_message "WARNING" "Automated data transfer between cloud clusters is not implemented."
    log_message "WARNING" "Please see the documentation for manual steps."
    
  else
    log_message "INFO" "Transferring between local and cloud clusters."
    
    # This is even more complex
    log_message "INFO" "For mixed local/cloud environments, consider:"
    log_message "INFO" "1. Use S3-compatible storage that both clusters can access."
    log_message "INFO" "2. Set up temporary replication through an intermediary service."
    log_message "INFO" "3. Use a backup/restore solution like Velero."
    
    log_message "WARNING" "Automated data transfer between local and cloud clusters is not implemented."
    log_message "WARNING" "Please see the documentation for manual steps."
  fi
  
  log_message "INFO" "For production workloads, consider using a dedicated migration tool like Velero."
  return 0
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --source-provider)
        SOURCE_PROVIDER="$2"
        case "$SOURCE_PROVIDER" in
          minikube|kind|k3d|eks|gke|aks) ;;
          *)
            log_message "ERROR" "Unsupported source provider '${SOURCE_PROVIDER}'."
            log_message "ERROR" "Supported providers: minikube, kind, k3d, eks, gke, aks"
            exit 1
            ;;
        esac
        shift 2
        ;;
      --target-provider)
        TARGET_PROVIDER="$2"
        case "$TARGET_PROVIDER" in
          minikube|kind|k3d|eks|gke|aks) ;;
          *)
            log_message "ERROR" "Unsupported target provider '${TARGET_PROVIDER}'."
            log_message "ERROR" "Supported providers: minikube, kind, k3d, eks, gke, aks"
            exit 1
            ;;
        esac
        shift 2
        ;;
      --source-cluster)
        SOURCE_CLUSTER="$2"
        shift 2
        ;;
      --target-cluster)
        TARGET_CLUSTER="$2"
        shift 2
        ;;
      --source-context)
        SOURCE_CONTEXT="$2"
        shift 2
        ;;
      --target-context)
        TARGET_CONTEXT="$2"
        shift 2
        ;;
      --source-kubeconfig)
        SOURCE_KUBECONFIG="$2"
        shift 2
        ;;
      --target-kubeconfig)
        TARGET_KUBECONFIG="$2"
        shift 2
        ;;
      --namespace)
        NAMESPACES+=("$2")
        shift 2
        ;;
      --all-namespaces)
        INCLUDE_ALL_NAMESPACES=true
        shift
        ;;
      --exclude-namespace)
        EXCLUDE_NAMESPACES+=("$2")
        shift 2
        ;;
      --resource)
        RESOURCES+=("$2")
        shift 2
        ;;
      --include-custom-resources)
        CUSTOM_RESOURCES=true
        shift
        ;;
      --transfer-storage)
        TRANSFER_STORAGE=true
        shift
        ;;
      --recreate-pvcs)
        RECREATE_PVCS=true
        shift
        ;;
      --create-target)
        CREATE_TARGET=true
        shift
        ;;
      --target-nodes)
        TARGET_NODES="$2"
        shift 2
        ;;
      --target-k8s-version)
        TARGET_K8S_VERSION="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --interactive)
        INTERACTIVE=true
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
      --backup-dir)
        BACKUP_DIR="$2"
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
  
  # Validate required parameters
  if [[ -z "$SOURCE_PROVIDER" ]]; then
    log_message "ERROR" "Source provider is required. Use --source-provider."
    exit 1
  fi
  
  if [[ -z "$TARGET_PROVIDER" ]]; then
    log_message "ERROR" "Target provider is required. Use --target-provider."
    exit 1
  fi
  
  if [[ -z "$SOURCE_CLUSTER" ]]; then
    log_message "ERROR" "Source cluster name is required. Use --source-cluster."
    exit 1
  fi
  
  if [[ -z "$TARGET_CLUSTER" ]]; then
    log_message "ERROR" "Target cluster name is required. Use --target-cluster."
    exit 1
  fi
}

# Main function
main() {
  print_with_separator "Kubernetes Cluster Conversion"
  
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
  
  log_message "INFO" "Starting cluster conversion from $SOURCE_PROVIDER to $TARGET_PROVIDER..."
  
  # Display configuration
  log_message "INFO" "Configuration:"
  log_message "INFO" "  Source Provider:    $SOURCE_PROVIDER"
  log_message "INFO" "  Target Provider:    $TARGET_PROVIDER"
  log_message "INFO" "  Source Cluster:     $SOURCE_CLUSTER"
  log_message "INFO" "  Target Cluster:     $TARGET_CLUSTER"
  if [[ -n "$SOURCE_CONTEXT" ]]; then
    log_message "INFO" "  Source Context:     $SOURCE_CONTEXT"
  fi
  if [[ -n "$TARGET_CONTEXT" ]]; then
    log_message "INFO" "  Target Context:     $TARGET_CONTEXT"
  fi
  if [[ -n "$SOURCE_KUBECONFIG" ]]; then
    log_message "INFO" "  Source Kubeconfig:  $SOURCE_KUBECONFIG"
  fi
  if [[ -n "$TARGET_KUBECONFIG" ]]; then
    log_message "INFO" "  Target Kubeconfig:  $TARGET_KUBECONFIG"
  fi
  if [[ ${#NAMESPACES[@]} -gt 0 ]]; then
    log_message "INFO" "  Namespaces:         ${NAMESPACES[*]}"
  fi
  if [[ "$INCLUDE_ALL_NAMESPACES" == true ]]; then
    log_message "INFO" "  All Namespaces:     true (excluding ${EXCLUDE_NAMESPACES[*]})"
  fi
  log_message "INFO" "  Custom Resources:   $CUSTOM_RESOURCES"
  log_message "INFO" "  Transfer Storage:   $TRANSFER_STORAGE"
  log_message "INFO" "  Recreate PVCs:      $RECREATE_PVCS"
  log_message "INFO" "  Create Target:      $CREATE_TARGET"
  if [[ "$CREATE_TARGET" == true ]]; then
    log_message "INFO" "  Target Nodes:       $TARGET_NODES"
    if [[ -n "$TARGET_K8S_VERSION" ]]; then
      log_message "INFO" "  Target K8s Version: $TARGET_K8S_VERSION"
    fi
  fi
  log_message "INFO" "  Dry Run:            $DRY_RUN"
  log_message "INFO" "  Interactive:        $INTERACTIVE"
  log_message "INFO" "  Force:              $FORCE"
  log_message "INFO" "  Timeout:            ${TIMEOUT}s"
  if [[ -n "$BACKUP_DIR" ]]; then
    log_message "INFO" "  Backup Directory:   $BACKUP_DIR"
  fi
  
  # Confirm operation if interactive mode is enabled
  if [[ "$INTERACTIVE" == true && "$FORCE" != true && "$DRY_RUN" != true ]]; then
    log_message "WARNING" "This operation will export resources from the source cluster and import them to the target cluster."
    log_message "WARNING" "It may affect running workloads and services."
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      log_message "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  # Check requirements
  check_requirements
  
  # Validate source cluster and get context if not provided
  log_message "INFO" "Validating source cluster..."
  if [[ -z "$SOURCE_CONTEXT" ]]; then
    SOURCE_CONTEXT=$(validate_cluster "$SOURCE_PROVIDER" "$SOURCE_CLUSTER" "" "$SOURCE_KUBECONFIG")
    if [[ $? -ne 0 ]]; then
      log_message "ERROR" "Failed to validate source cluster."
      exit 1
    fi
  else
    if ! validate_cluster "$SOURCE_PROVIDER" "$SOURCE_CLUSTER" "$SOURCE_CONTEXT" "$SOURCE_KUBECONFIG" &>/dev/null; then
      log_message "ERROR" "Failed to validate source cluster with provided context."
      exit 1
    fi
  fi
  
  # Create target cluster if requested
  if [[ "$CREATE_TARGET" == true ]]; then
    create_target_cluster
  else
    # Validate target cluster and get context if not provided
    log_message "INFO" "Validating target cluster..."
    if [[ -z "$TARGET_CONTEXT" ]]; then
      TARGET_CONTEXT=$(validate_cluster "$TARGET_PROVIDER" "$TARGET_CLUSTER" "" "$TARGET_KUBECONFIG")
      if [[ $? -ne 0 ]]; then
        log_message "ERROR" "Failed to validate target cluster."
        exit 1
      fi
    else
      if ! validate_cluster "$TARGET_PROVIDER" "$TARGET_CLUSTER" "$TARGET_CONTEXT" "$TARGET_KUBECONFIG" &>/dev/null; then
        log_message "ERROR" "Failed to validate target cluster with provided context."
        exit 1
      fi
    fi
  fi
  
  # Get namespaces to migrate
  MIGRATE_NAMESPACES=($(get_namespaces))
  
  # Export resources from source cluster
  export_resources "${MIGRATE_NAMESPACES[@]}"
  
  # Clean up resources for import
  clean_resources
  
  # Import resources to target cluster
  import_resources "${MIGRATE_NAMESPACES[@]}"
  
  # Transfer storage if requested
  transfer_storage
  
  # Verify import
  verify_import "${MIGRATE_NAMESPACES[@]}"
  
  log_message "SUCCESS" "Cluster conversion completed successfully."
  
  if [[ -n "$BACKUP_DIR" && "$BACKUP_DIR" == /tmp/* ]]; then
    log_message "INFO" "Temporary backup directory at $BACKUP_DIR"
    log_message "INFO" "You may want to save these files before they are automatically cleaned up."
  fi
  
  print_with_separator "End of Kubernetes Cluster Conversion"
}

# Run the main function
main "$@"