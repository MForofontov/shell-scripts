#!/bin/bash
# convert-cluster.sh
# Script to convert/migrate between Kubernetes cluster providers

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
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

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Conversion Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script assists in converting/migrating between Kubernetes cluster providers."
  echo "  It exports resources from a source cluster and imports them to a target cluster."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m--source-provider <PROVIDER>\033[0m    (Required) Source cluster provider (minikube, kind, k3d, eks, gke, aks)"
  echo -e "  \033[1;36m--target-provider <PROVIDER>\033[0m    (Required) Target cluster provider (minikube, kind, k3d, eks, gke, aks)"
  echo -e "  \033[1;36m--source-cluster <NAME>\033[0m         (Required) Source cluster name"
  echo -e "  \033[1;36m--target-cluster <NAME>\033[0m         (Required) Target cluster name"
  echo -e "  \033[1;33m--source-context <CONTEXT>\033[0m      (Optional) Source kubectl context (auto-detected if not provided)"
  echo -e "  \033[1;33m--target-context <CONTEXT>\033[0m      (Optional) Target kubectl context (auto-detected if not provided)"
  echo -e "  \033[1;33m--source-kubeconfig <PATH>\033[0m      (Optional) Path to source kubeconfig file"
  echo -e "  \033[1;33m--target-kubeconfig <PATH>\033[0m      (Optional) Path to target kubeconfig file"
  echo -e "  \033[1;33m--namespace <NAMESPACE>\033[0m         (Optional) Namespace to include (can be used multiple times)"
  echo -e "  \033[1;33m--all-namespaces\033[0m                (Optional) Include all namespaces"
  echo -e "  \033[1;33m--exclude-namespace <NAMESPACE>\033[0m (Optional) Namespace to exclude (can be used multiple times)"
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

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
#=====================================================================
# REQUIREMENTS CHECKING
#=====================================================================
# Check for required tools
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  # Check for kubectl
  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found. Please install it first."
    exit 1
  fi
  
  # Check for jq
  if ! command_exists jq; then
    format-echo "ERROR" "jq not found. Please install it first."
    exit 1
  fi
  
  # Check for yq
  if ! command_exists yq; then
    format-echo "WARNING" "yq not found. Some YAML processing capabilities may be limited."
  fi
  
  #---------------------------------------------------------------------
  # SOURCE PROVIDER REQUIREMENTS
  #---------------------------------------------------------------------
  # Check for provider-specific tools
  case "$SOURCE_PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        format-echo "ERROR" "minikube not found. Please install it to use minikube as source provider."
        exit 1
      fi
      ;;
    kind)
      if ! command_exists kind; then
        format-echo "ERROR" "kind not found. Please install it to use kind as source provider."
        exit 1
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        format-echo "ERROR" "k3d not found. Please install it to use k3d as source provider."
        exit 1
      fi
      ;;
    eks)
      if ! command_exists aws; then
        format-echo "ERROR" "AWS CLI not found. Please install it to use EKS as source provider."
        exit 1
      fi
      ;;
    gke)
      if ! command_exists gcloud; then
        format-echo "ERROR" "Google Cloud SDK not found. Please install it to use GKE as source provider."
        exit 1
      fi
      ;;
    aks)
      if ! command_exists az; then
        format-echo "ERROR" "Azure CLI not found. Please install it to use AKS as source provider."
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # TARGET PROVIDER REQUIREMENTS
  #---------------------------------------------------------------------
  case "$TARGET_PROVIDER" in
    minikube)
      if ! command_exists minikube; then
        format-echo "ERROR" "minikube not found. Please install it to use minikube as target provider."
        exit 1
      fi
      ;;
    kind)
      if ! command_exists kind; then
        format-echo "ERROR" "kind not found. Please install it to use kind as target provider."
        exit 1
      fi
      ;;
    k3d)
      if ! command_exists k3d; then
        format-echo "ERROR" "k3d not found. Please install it to use k3d as target provider."
        exit 1
      fi
      ;;
    eks)
      if ! command_exists aws; then
        format-echo "ERROR" "AWS CLI not found. Please install it to use EKS as target provider."
        exit 1
      fi
      ;;
    gke)
      if ! command_exists gcloud; then
        format-echo "ERROR" "Google Cloud SDK not found. Please install it to use GKE as target provider."
        exit 1
      fi
      ;;
    aks)
      if ! command_exists az; then
        format-echo "ERROR" "Azure CLI not found. Please install it to use AKS as target provider."
        exit 1
      fi
      ;;
  esac
  
  format-echo "SUCCESS" "All required tools are available."
}

#=====================================================================
# CLUSTER VALIDATION
#=====================================================================
# Validate cluster exists and is accessible
validate_cluster() {
  local provider="$1"
  local cluster="$2"
  local context="$3"
  local kubeconfig="$4"
  
  format-echo "INFO" "Validating $provider cluster '$cluster'..."
  
  # Set context if provided
  if [[ -n "$context" ]]; then
    if ! KUBECONFIG="$kubeconfig" kubectl config use-context "$context" &>/dev/null; then
      format-echo "ERROR" "Cannot switch to context '$context'. Please check it exists."
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
        format-echo "INFO" "Auto-detecting context for $provider cluster '$cluster'..."
        local contexts
        contexts=$(KUBECONFIG="$kubeconfig" kubectl config get-contexts -o name 2>/dev/null)
        
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
          format-echo "ERROR" "Cannot auto-detect context for $provider cluster '$cluster'."
          format-echo "ERROR" "Please specify the context explicitly with --source-context or --target-context."
          return 1
        else
          format-echo "INFO" "Auto-detected context: $context"
        fi
        ;;
    esac
    
    if ! KUBECONFIG="$kubeconfig" kubectl config use-context "$context" &>/dev/null; then
      format-echo "ERROR" "Cannot switch to auto-detected context '$context'. Please check it exists."
      return 1
    fi
  fi
  
  # Verify we can access the cluster
  if ! KUBECONFIG="$kubeconfig" kubectl get nodes &>/dev/null; then
    format-echo "ERROR" "Cannot access cluster using context '$context'."
    format-echo "ERROR" "Please check your cluster is running and accessible."
    return 1
  fi
  
  format-echo "SUCCESS" "Successfully validated $provider cluster '$cluster' using context '$context'."
  
  # Return the context (this allows caller to capture auto-detected context)
  echo "$context"
  return 0
}

#=====================================================================
# CLUSTER CREATION
#=====================================================================
# Create target cluster if it doesn't exist
create_target_cluster() {
  if [[ "$CREATE_TARGET" != true ]]; then
    return 0
  fi
  
  format-echo "INFO" "Checking if target cluster '$TARGET_CLUSTER' needs to be created..."
  
  # Check if cluster already exists
  local existing_context
  if existing_context=$(validate_cluster "$TARGET_PROVIDER" "$TARGET_CLUSTER" "$TARGET_CONTEXT" "$TARGET_KUBECONFIG" 2>/dev/null); then
    format-echo "INFO" "Target cluster already exists, skipping creation."
    TARGET_CONTEXT="$existing_context"
    return 0
  fi
  
  format-echo "INFO" "Creating target cluster '$TARGET_CLUSTER' with provider '$TARGET_PROVIDER'..."
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would create $TARGET_PROVIDER cluster '$TARGET_CLUSTER' with $TARGET_NODES nodes"
    return 0
  fi
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC CREATION
  #---------------------------------------------------------------------
  # Version flag for different providers
  local version_flag=""
  if [[ -n "$TARGET_K8S_VERSION" ]]; then
    case "$TARGET_PROVIDER" in
      minikube)
        version_flag="--kubernetes-version=$TARGET_K8S_VERSION"
        ;;
      kind)
        # kind uses its own node image versions, not direct k8s versions
        format-echo "WARNING" "kind doesn't support direct Kubernetes version selection. Using default version."
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
      format-echo "INFO" "Creating minikube cluster '$TARGET_CLUSTER'..."
      if ! minikube start -p "$TARGET_CLUSTER" $version_flag --nodes="$TARGET_NODES"; then
        format-echo "ERROR" "Failed to create minikube cluster '$TARGET_CLUSTER'."
        exit 1
      fi
      TARGET_CONTEXT="$TARGET_CLUSTER"
      ;;
    kind)
      format-echo "INFO" "Creating kind cluster '$TARGET_CLUSTER'..."
      if ! kind create cluster --name "$TARGET_CLUSTER"; then
        format-echo "ERROR" "Failed to create kind cluster '$TARGET_CLUSTER'."
        exit 1
      fi
      TARGET_CONTEXT="kind-$TARGET_CLUSTER"
      ;;
    k3d)
      format-echo "INFO" "Creating k3d cluster '$TARGET_CLUSTER'..."
      if ! k3d cluster create "$TARGET_CLUSTER" $version_flag --agents "$TARGET_NODES"; then
        format-echo "ERROR" "Failed to create k3d cluster '$TARGET_CLUSTER'."
        exit 1
      fi
      TARGET_CONTEXT="k3d-$TARGET_CLUSTER"
      ;;
    eks)
      format-echo "ERROR" "Creating EKS clusters is not supported in this script due to complexity."
      format-echo "ERROR" "Please create the EKS cluster manually or use eksctl."
      exit 1
      ;;
    gke)
      format-echo "ERROR" "Creating GKE clusters is not supported in this script due to complexity."
      format-echo "ERROR" "Please create the GKE cluster manually or use gcloud."
      exit 1
      ;;
    aks)
      format-echo "ERROR" "Creating AKS clusters is not supported in this script due to complexity."
      format-echo "ERROR" "Please create the AKS cluster manually or use az aks create."
      exit 1
      ;;
  esac
  
  format-echo "SUCCESS" "Successfully created target cluster '$TARGET_CLUSTER'."
  return 0
}

#=====================================================================
# NAMESPACE MANAGEMENT
#=====================================================================
# Get list of namespaces to migrate
get_namespaces() {
  format-echo "INFO" "Determining namespaces to migrate..."
  
  local ns_list=()
  local kubeconfig_flag=""
  
  if [[ -n "$SOURCE_KUBECONFIG" ]]; then
    kubeconfig_flag="--kubeconfig=$SOURCE_KUBECONFIG"
  fi
  
  # Switch to source context
  if ! kubectl config use-context "$SOURCE_CONTEXT" &>/dev/null; then
    format-echo "ERROR" "Cannot switch to source context '$SOURCE_CONTEXT'."
    exit 1
  fi
  
  # Get all namespaces if requested
  if [[ "$INCLUDE_ALL_NAMESPACES" == true ]]; then
    ns_list=($(kubectl get namespaces "$kubeconfig_flag" -o jsonpath='{.items[*].metadata.name}'))
    format-echo "INFO" "Found ${#ns_list[@]} namespaces in total."
  else
    # Use specified namespaces
    if [[ ${#NAMESPACES[@]} -eq 0 ]]; then
      format-echo "ERROR" "No namespaces specified. Use --namespace or --all-namespaces."
      exit 1
    fi
    ns_list=("${NAMESPACES[@]}")
  fi
  
  #---------------------------------------------------------------------
  # NAMESPACE FILTERING
  #---------------------------------------------------------------------
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
      format-echo "INFO" "Excluding namespace: $ns"
    fi
  done
  
  if [[ ${#filtered_ns[@]} -eq 0 ]]; then
    format-echo "ERROR" "No namespaces left after filtering. Please check your namespace options."
    exit 1
  fi
  
  format-echo "INFO" "Will migrate ${#filtered_ns[@]} namespaces: ${filtered_ns[*]}"
  echo "${filtered_ns[@]}"
}

#=====================================================================
# RESOURCE EXPORT
#=====================================================================
# Export resources from source cluster
export_resources() {
  local namespaces=("$@")
  format-echo "INFO" "Exporting resources from source cluster..."
  
  # Create backup directory if not specified
  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR=$(mktemp -d "/tmp/k8s-conversion-XXXXX")
    format-echo "INFO" "Created temporary backup directory: $BACKUP_DIR"
  else
    mkdir -p "$BACKUP_DIR"
    format-echo "INFO" "Using backup directory: $BACKUP_DIR"
  fi
  
  # Switch to source context
  if ! kubectl config use-context "$SOURCE_CONTEXT" &>/dev/null; then
    format-echo "ERROR" "Cannot switch to source context '$SOURCE_CONTEXT'."
    exit 1
  fi
  
  local kubeconfig_flag=""
  if [[ -n "$SOURCE_KUBECONFIG" ]]; then
    kubeconfig_flag="--kubeconfig=$SOURCE_KUBECONFIG"
  fi
  
  #---------------------------------------------------------------------
  # CRD EXPORT
  #---------------------------------------------------------------------
  # Export CRDs if requested
  if [[ "$CUSTOM_RESOURCES" == true ]]; then
    format-echo "INFO" "Exporting Custom Resource Definitions..."
    
    if [[ "$DRY_RUN" == true ]]; then
      format-echo "DRY-RUN" "Would export Custom Resource Definitions to $BACKUP_DIR/crds.yaml"
    else
      if ! kubectl get crds "$kubeconfig_flag" -o yaml > "$BACKUP_DIR/crds.yaml"; then
        format-echo "WARNING" "Failed to export Custom Resource Definitions."
      else
        format-echo "SUCCESS" "Exported Custom Resource Definitions to $BACKUP_DIR/crds.yaml"
      fi
    fi
  fi
  
  #---------------------------------------------------------------------
  # NAMESPACE RESOURCE EXPORT
  #---------------------------------------------------------------------
  # Export resources for each namespace
  for ns in "${namespaces[@]}"; do
    format-echo "INFO" "Exporting resources from namespace: $ns"
    
    # Create namespace directory
    mkdir -p "$BACKUP_DIR/$ns"
    
    # Export namespace definition
    if [[ "$DRY_RUN" == true ]]; then
      format-echo "DRY-RUN" "Would export namespace $ns to $BACKUP_DIR/$ns/namespace.yaml"
    else
      if ! kubectl get namespace "$ns" "$kubeconfig_flag" -o yaml > "$BACKUP_DIR/$ns/namespace.yaml"; then
        format-echo "WARNING" "Failed to export namespace definition for $ns."
      else
        format-echo "SUCCESS" "Exported namespace definition to $BACKUP_DIR/$ns/namespace.yaml"
      fi
    fi
    
    # Export each resource type
    for resource in "${RESOURCES[@]}"; do
      format-echo "INFO" "Exporting $resource from namespace $ns..."
      
      if [[ "$DRY_RUN" == true ]]; then
        format-echo "DRY-RUN" "Would export $resource from namespace $ns to $BACKUP_DIR/$ns/$resource.yaml"
      else
        # Check if resource exists in this namespace
        if kubectl get "$resource" "$kubeconfig_flag" -n "$ns" &>/dev/null; then
          if ! kubectl get "$resource" "$kubeconfig_flag" -n "$ns" -o yaml > "$BACKUP_DIR/$ns/$resource.yaml"; then
            format-echo "WARNING" "Failed to export $resource from namespace $ns."
          else
            format-echo "SUCCESS" "Exported $resource from namespace $ns to $BACKUP_DIR/$ns/$resource.yaml"
          fi
        else
          format-echo "INFO" "No $resource found in namespace $ns, skipping."
        fi
      fi
    done
    
    #---------------------------------------------------------------------
    # CUSTOM RESOURCE EXPORT
    #---------------------------------------------------------------------
    # Export custom resources if requested
    if [[ "$CUSTOM_RESOURCES" == true ]]; then
      format-echo "INFO" "Exporting custom resources from namespace $ns..."
      
      # Create custom resources directory
      mkdir -p "$BACKUP_DIR/$ns/custom-resources"
      
      # Get all CRDs
      local crds=$(kubectl get crds "$kubeconfig_flag" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
      
      for crd in $crds; do
        # Skip Kubernetes system CRDs
        if [[ "$crd" == *.k8s.io ]]; then
          continue
        fi
        
        # Check if this CRD has resources in this namespace
        if kubectl get "$crd" "$kubeconfig_flag" -n "$ns" &>/dev/null; then
          if [[ "$DRY_RUN" == true ]]; then
            format-echo "DRY-RUN" "Would export custom resource $crd from namespace $ns"
          else
            if ! kubectl get "$crd" "$kubeconfig_flag" -n "$ns" -o yaml > "$BACKUP_DIR/$ns/custom-resources/$crd.yaml"; then
              format-echo "WARNING" "Failed to export custom resource $crd from namespace $ns."
            else
              format-echo "SUCCESS" "Exported custom resource $crd from namespace $ns"
            fi
          fi
        fi
      done
    fi
  done
  
  format-echo "SUCCESS" "Export completed. Resources stored in $BACKUP_DIR"
}

#=====================================================================
# RESOURCE CLEANING
#=====================================================================
# Clean up exported resources to make them suitable for import
clean_resources() {
  format-echo "INFO" "Cleaning exported resources for import..."
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would clean up exported resources for import"
    return 0
  fi
  
  #---------------------------------------------------------------------
  # CRD CLEANING
  #---------------------------------------------------------------------
  # Process CRDs first if they exist
  if [[ -f "$BACKUP_DIR/crds.yaml" ]]; then
    format-echo "INFO" "Cleaning Custom Resource Definitions..."
    
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
    
    format-echo "SUCCESS" "Cleaned Custom Resource Definitions."
  fi
  
  #---------------------------------------------------------------------
  # NAMESPACE RESOURCE CLEANING
  #---------------------------------------------------------------------
  # Process each namespace directory
  for ns_dir in "$BACKUP_DIR"/*; do
    if [[ ! -d "$ns_dir" ]]; then
      continue
    fi
    
    local ns=$(basename "$ns_dir")
    format-echo "INFO" "Cleaning resources for namespace: $ns"
    
    # Process namespace definition
    if [[ -f "$ns_dir/namespace.yaml" ]]; then
      format-echo "INFO" "Cleaning namespace definition..."
      
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
      format-echo "INFO" "Cleaning $resource resources..."
      
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
    
    #---------------------------------------------------------------------
    # CUSTOM RESOURCE CLEANING
    #---------------------------------------------------------------------
    # Process custom resources
    if [[ -d "$ns_dir/custom-resources" ]]; then
      for cr_file in "$ns_dir/custom-resources"/*.yaml; do
        if [[ ! -f "$cr_file" ]]; then
          continue
        fi
        
        local cr=$(basename "$cr_file" .yaml)
        format-echo "INFO" "Cleaning custom resource $cr..."
        
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
  
  format-echo "SUCCESS" "Resources cleaned and prepared for import."
}

#=====================================================================
# RESOURCE IMPORT
#=====================================================================
# Import resources to target cluster
import_resources() {
  local namespaces=("$@")
  format-echo "INFO" "Importing resources to target cluster..."
  
  # Switch to target context
  if ! kubectl config use-context "$TARGET_CONTEXT" &>/dev/null; then
    format-echo "ERROR" "Cannot switch to target context '$TARGET_CONTEXT'."
    exit 1
  fi
  
  local kubeconfig_flag=""
  if [[ -n "$TARGET_KUBECONFIG" ]]; then
    kubeconfig_flag="--kubeconfig=$TARGET_KUBECONFIG"
  fi
  
  #---------------------------------------------------------------------
  # CRD IMPORT
  #---------------------------------------------------------------------
  # Import CRDs first if they exist
  if [[ -f "$BACKUP_DIR/crds.yaml" && "$CUSTOM_RESOURCES" == true ]]; then
    format-echo "INFO" "Importing Custom Resource Definitions..."
    
    if [[ "$DRY_RUN" == true ]]; then
      format-echo "DRY-RUN" "Would import Custom Resource Definitions from $BACKUP_DIR/crds.yaml"
    else
      if ! kubectl apply "$kubeconfig_flag" -f "$BACKUP_DIR/crds.yaml"; then
        format-echo "WARNING" "Failed to import some Custom Resource Definitions."
      else
        format-echo "SUCCESS" "Imported Custom Resource Definitions."
      fi
      
      # Wait for CRDs to be established
      format-echo "INFO" "Waiting for CRDs to be established..."
      sleep 10
    fi
  fi
  
  #---------------------------------------------------------------------
  # NAMESPACE IMPORT
  #---------------------------------------------------------------------
  # Import resources for each namespace
  for ns in "${namespaces[@]}"; do
    format-echo "INFO" "Importing resources for namespace: $ns"
    
    # Check if namespace directory exists
    if [[ ! -d "$BACKUP_DIR/$ns" ]]; then
      format-echo "WARNING" "No resources found for namespace $ns, skipping."
      continue
    fi
    
    # Create namespace first
    if [[ -f "$BACKUP_DIR/$ns/namespace.yaml" ]]; then
      format-echo "INFO" "Creating namespace: $ns"
      
      if [[ "$DRY_RUN" == true ]]; then
        format-echo "DRY-RUN" "Would create namespace $ns from $BACKUP_DIR/$ns/namespace.yaml"
      else
        if ! kubectl apply "$kubeconfig_flag" -f "$BACKUP_DIR/$ns/namespace.yaml"; then
          format-echo "WARNING" "Failed to create namespace $ns. Trying to create it directly."
          kubectl create namespace "$kubeconfig_flag" "$ns" || {
            format-echo "ERROR" "Failed to create namespace $ns. Skipping this namespace."
            continue
          }
        fi
      fi
    else
      format-echo "INFO" "Namespace definition not found, creating namespace $ns directly."
      
      if [[ "$DRY_RUN" == true ]]; then
        format-echo "DRY-RUN" "Would create namespace $ns"
      else
        kubectl create namespace "$kubeconfig_flag" "$ns" || {
          format-echo "ERROR" "Failed to create namespace $ns. Skipping this namespace."
          continue
        }
      fi
    fi
    
    #---------------------------------------------------------------------
    # RESOURCE IMPORT ORDERING
    #---------------------------------------------------------------------
    # Apply resources in correct order to handle dependencies
    local resource_order=("configmaps" "secrets" "pvc" "services" "deployments" "statefulsets" "daemonsets" "ingresses" "horizontalpodautoscalers")
    
    for resource in "${resource_order[@]}"; do
      if [[ -f "$BACKUP_DIR/$ns/$resource.yaml" ]]; then
        format-echo "INFO" "Importing $resource for namespace $ns..."
        
        if [[ "$DRY_RUN" == true ]]; then
          format-echo "DRY-RUN" "Would import $resource from $BACKUP_DIR/$ns/$resource.yaml"
        else
          # Special handling for PVCs
          if [[ "$resource" == "pvc" && "$RECREATE_PVCS" != true && "$TRANSFER_STORAGE" != true ]]; then
            format-echo "INFO" "Skipping PVCs as requested."
            continue
          fi
          
          if ! kubectl apply "$kubeconfig_flag" -f "$BACKUP_DIR/$ns/$resource.yaml"; then
            format-echo "WARNING" "Failed to import some $resource in namespace $ns."
          else
            format-echo "SUCCESS" "Imported $resource in namespace $ns."
          fi
        fi
      fi
    done
    
    #---------------------------------------------------------------------
    # CUSTOM RESOURCE IMPORT
    #---------------------------------------------------------------------
    # Import custom resources if they exist
    if [[ -d "$BACKUP_DIR/$ns/custom-resources" && "$CUSTOM_RESOURCES" == true ]]; then
      format-echo "INFO" "Importing custom resources for namespace $ns..."
      
      for cr_file in "$BACKUP_DIR/$ns/custom-resources"/*.yaml; do
        if [[ ! -f "$cr_file" ]]; then
          continue
        fi
        
        local cr=$(basename "$cr_file" .yaml)
        format-echo "INFO" "Importing custom resource $cr for namespace $ns..."
        
        if [[ "$DRY_RUN" == true ]]; then
          format-echo "DRY-RUN" "Would import custom resource $cr from $cr_file"
        else
          if ! kubectl apply "$kubeconfig_flag" -f "$cr_file"; then
            format-echo "WARNING" "Failed to import custom resource $cr in namespace $ns."
          else
            format-echo "SUCCESS" "Imported custom resource $cr in namespace $ns."
          fi
        fi
      done
    fi
  done
  
  format-echo "SUCCESS" "Import completed. Resources imported to target cluster."
}

#=====================================================================
# VERIFICATION
#=====================================================================
# Verify import by checking resources in target cluster
verify_import() {
  local namespaces=("$@")
  format-echo "INFO" "Verifying resource import in target cluster..."
  
  # Switch to target context
  if ! kubectl config use-context "$TARGET_CONTEXT" &>/dev/null; then
    format-echo "ERROR" "Cannot switch to target context '$TARGET_CONTEXT'."
    exit 1
  fi
  
  local kubeconfig_flag=""
  if [[ -n "$TARGET_KUBECONFIG" ]]; then
    kubeconfig_flag="--kubeconfig=$TARGET_KUBECONFIG"
  fi
  
  #---------------------------------------------------------------------
  # NAMESPACE VERIFICATION
  #---------------------------------------------------------------------
  # Check each namespace
  for ns in "${namespaces[@]}"; do
    format-echo "INFO" "Verifying resources in namespace: $ns"
    
    # Check if namespace exists
    if ! kubectl get namespace "$kubeconfig_flag" "$ns" &>/dev/null; then
      format-echo "ERROR" "Namespace $ns does not exist in target cluster."
      continue
    fi
    
    # Check each resource type
    for resource in "${RESOURCES[@]}"; do
      # Skip PVCs if not requested
      if [[ "$resource" == "pvc" && "$RECREATE_PVCS" != true && "$TRANSFER_STORAGE" != true ]]; then
        continue
      fi
      
      format-echo "INFO" "Checking $resource in namespace $ns..."
      
      # Get resource count in source
      local source_count=0
      if [[ -f "$BACKUP_DIR/$ns/$resource.yaml" ]]; then
        source_count=$(grep -c "^kind:" "$BACKUP_DIR/$ns/$resource.yaml" || echo 0)
      fi
      
      # Get resource count in target
      local target_count=0
      target_count=$(kubectl get "$resource" "$kubeconfig_flag" -n "$ns" --no-headers 2>/dev/null | wc -l || echo 0)
      target_count=$(echo $target_count) # Trim whitespace
      
      format-echo "INFO" "Found $target_count of $source_count $resource resources in namespace $ns."
      
      if [[ "$source_count" -gt 0 && "$target_count" -eq 0 ]]; then
        format-echo "WARNING" "No $resource resources found in namespace $ns in target cluster."
      elif [[ "$target_count" -lt "$source_count" ]]; then
        format-echo "WARNING" "Only $target_count of $source_count $resource resources found in namespace $ns."
      fi
    done
    
    #---------------------------------------------------------------------
    # POD STATUS VERIFICATION
    #---------------------------------------------------------------------
    # Check pod status
    format-echo "INFO" "Checking pod status in namespace $ns..."
    local pods_total=0
    local pods_running=0
    
    pods_total=$(kubectl get pods "$kubeconfig_flag" -n "$ns" --no-headers 2>/dev/null | wc -l || echo 0)
    pods_total=$(echo $pods_total) # Trim whitespace
    
    if [[ "$pods_total" -gt 0 ]]; then
      pods_running=$(kubectl get pods "$kubeconfig_flag" -n "$ns" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
      format-echo "INFO" "$pods_running of $pods_total pods are running in namespace $ns."
      
      if [[ "$pods_running" -lt "$pods_total" ]]; then
        format-echo "WARNING" "Some pods are not running in namespace $ns. Check with 'kubectl get pods -n $ns'."
      fi
    else
      format-echo "INFO" "No pods found in namespace $ns."
    fi
  done
  
  format-echo "SUCCESS" "Verification completed."
}

#=====================================================================
# STORAGE MANAGEMENT
#=====================================================================
# Transfer persistent volume data (if requested)
transfer_storage() {
  if [[ "$TRANSFER_STORAGE" != true ]]; then
    return 0
  fi
  
  format-echo "INFO" "Starting storage data transfer between clusters..."
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would transfer persistent volume data between clusters"
    return 0
  fi
  
  format-echo "WARNING" "Storage transfer is a complex operation that depends on many factors."
  format-echo "WARNING" "This script provides basic guidance but may not be suitable for all environments."
  
  #---------------------------------------------------------------------
  # ENVIRONMENT DETECTION
  #---------------------------------------------------------------------
  # Check if both clusters are local or cloud
  local source_is_local=false
  local target_is_local=false
  
  case "$SOURCE_PROVIDER" in
    minikube|kind|k3d) source_is_local=true ;;
  esac
  
  case "$TARGET_PROVIDER" in
    minikube|kind|k3d) target_is_local=true ;;
  esac
  
  #---------------------------------------------------------------------
  # LOCAL-TO-LOCAL TRANSFER
  #---------------------------------------------------------------------
  if [[ "$source_is_local" == true && "$target_is_local" == true ]]; then
    format-echo "INFO" "Both clusters are local. Using local data transfer approach."
    
    # This is a simplified approach for local clusters
    format-echo "INFO" "For local clusters, consider the following approaches:"
    format-echo "INFO" "1. For minikube: Use hostPath volumes and ensure they point to the same host directory."
    format-echo "INFO" "2. For kind/k3d: Use Docker volumes and bind them to the same host directory."
    format-echo "INFO" "3. For any local cluster: Set up a local NFS or MinIO server for storage."
    
    format-echo "WARNING" "Automated data transfer between local clusters is not implemented."
    format-echo "WARNING" "Please see the documentation for manual steps."
    
  #---------------------------------------------------------------------
  # CLOUD-TO-CLOUD TRANSFER
  #---------------------------------------------------------------------
  elif [[ "$source_is_local" == false && "$target_is_local" == false ]]; then
    format-echo "INFO" "Both clusters are cloud-based. Using cloud data transfer approach."
    
    # This would be provider-specific and complex
    format-echo "INFO" "For cloud clusters, consider the following approaches:"
    format-echo "INFO" "1. Use cloud-native storage options (EBS, Persistent Disk, Azure Disk)."
    format-echo "INFO" "2. Set up storage replication at the cloud provider level."
    format-echo "INFO" "3. Use a backup/restore solution like Velero."
    
    format-echo "WARNING" "Automated data transfer between cloud clusters is not implemented."
    format-echo "WARNING" "Please see the documentation for manual steps."
    
  #---------------------------------------------------------------------
  # MIXED ENVIRONMENT TRANSFER
  #---------------------------------------------------------------------
  else
    format-echo "INFO" "Transferring between local and cloud clusters."
    
    # This is even more complex
    format-echo "INFO" "For mixed local/cloud environments, consider:"
    format-echo "INFO" "1. Use S3-compatible storage that both clusters can access."
    format-echo "INFO" "2. Set up temporary replication through an intermediary service."
    format-echo "INFO" "3. Use a backup/restore solution like Velero."
    
    format-echo "WARNING" "Automated data transfer between local and cloud clusters is not implemented."
    format-echo "WARNING" "Please see the documentation for manual steps."
  fi
  
  format-echo "INFO" "For production workloads, consider using a dedicated migration tool like Velero."
  return 0
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
      --source-provider)
        SOURCE_PROVIDER="$2"
        case "$SOURCE_PROVIDER" in
          minikube|kind|k3d|eks|gke|aks) ;;
          *)
            format-echo "ERROR" "Unsupported source provider '${SOURCE_PROVIDER}'."
            format-echo "ERROR" "Supported providers: minikube, kind, k3d, eks, gke, aks"
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
            format-echo "ERROR" "Unsupported target provider '${TARGET_PROVIDER}'."
            format-echo "ERROR" "Supported providers: minikube, kind, k3d, eks, gke, aks"
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
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  #---------------------------------------------------------------------
  # ARGUMENT VALIDATION
  #---------------------------------------------------------------------
  # Validate required parameters
  if [[ -z "$SOURCE_PROVIDER" ]]; then
    format-echo "ERROR" "Source provider is required. Use --source-provider."
    exit 1
  fi
  
  if [[ -z "$TARGET_PROVIDER" ]]; then
    format-echo "ERROR" "Target provider is required. Use --target-provider."
    exit 1
  fi
  
  if [[ -z "$SOURCE_CLUSTER" ]]; then
    format-echo "ERROR" "Source cluster name is required. Use --source-cluster."
    exit 1
  fi
  
  if [[ -z "$TARGET_CLUSTER" ]]; then
    format-echo "ERROR" "Target cluster name is required. Use --target-cluster."
    exit 1
  fi
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
# Main function
main() {
  # Parse arguments
  parse_args "$@"

  print_with_separator "Kubernetes Cluster Conversion Script"
  
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  format-echo "INFO" "Starting cluster conversion from $SOURCE_PROVIDER to $TARGET_PROVIDER..."
  
  #---------------------------------------------------------------------
  # CONFIGURATION DISPLAY
  #---------------------------------------------------------------------
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Source Provider:    $SOURCE_PROVIDER"
  format-echo "INFO" "  Target Provider:    $TARGET_PROVIDER"
  format-echo "INFO" "  Source Cluster:     $SOURCE_CLUSTER"
  format-echo "INFO" "  Target Cluster:     $TARGET_CLUSTER"
  if [[ -n "$SOURCE_CONTEXT" ]]; then
    format-echo "INFO" "  Source Context:     $SOURCE_CONTEXT"
  fi
  if [[ -n "$TARGET_CONTEXT" ]]; then
    format-echo "INFO" "  Target Context:     $TARGET_CONTEXT"
  fi
  if [[ -n "$SOURCE_KUBECONFIG" ]]; then
    format-echo "INFO" "  Source Kubeconfig:  $SOURCE_KUBECONFIG"
  fi
  if [[ -n "$TARGET_KUBECONFIG" ]]; then
    format-echo "INFO" "  Target Kubeconfig:  $TARGET_KUBECONFIG"
  fi
  if [[ ${#NAMESPACES[@]} -gt 0 ]]; then
    format-echo "INFO" "  Namespaces:         ${NAMESPACES[*]}"
  fi
  if [[ "$INCLUDE_ALL_NAMESPACES" == true ]]; then
    format-echo "INFO" "  All Namespaces:     true (excluding ${EXCLUDE_NAMESPACES[*]})"
  fi
  format-echo "INFO" "  Custom Resources:   $CUSTOM_RESOURCES"
  format-echo "INFO" "  Transfer Storage:   $TRANSFER_STORAGE"
  format-echo "INFO" "  Recreate PVCs:      $RECREATE_PVCS"
  format-echo "INFO" "  Create Target:      $CREATE_TARGET"
  if [[ "$CREATE_TARGET" == true ]]; then
    format-echo "INFO" "  Target Nodes:       $TARGET_NODES"
    if [[ -n "$TARGET_K8S_VERSION" ]]; then
      format-echo "INFO" "  Target K8s Version: $TARGET_K8S_VERSION"
    fi
  fi
  format-echo "INFO" "  Dry Run:            $DRY_RUN"
  format-echo "INFO" "  Interactive:        $INTERACTIVE"
  format-echo "INFO" "  Force:              $FORCE"
  format-echo "INFO" "  Timeout:            ${TIMEOUT}s"
  if [[ -n "$BACKUP_DIR" ]]; then
    format-echo "INFO" "  Backup Directory:   $BACKUP_DIR"
  fi
  
  #---------------------------------------------------------------------
  # USER CONFIRMATION
  #---------------------------------------------------------------------
  # Confirm operation if interactive mode is enabled
  if [[ "$INTERACTIVE" == true && "$FORCE" != true && "$DRY_RUN" != true ]]; then
    format-echo "WARNING" "This operation will export resources from the source cluster and import them to the target cluster."
    format-echo "WARNING" "It may affect running workloads and services."
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      format-echo "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  #---------------------------------------------------------------------
  # EXECUTION PIPELINE
  #---------------------------------------------------------------------
  # Check requirements
  check_requirements
  
  # Validate source cluster and get context if not provided
  format-echo "INFO" "Validating source cluster..."
  if [[ -z "$SOURCE_CONTEXT" ]]; then
    SOURCE_CONTEXT=$(validate_cluster "$SOURCE_PROVIDER" "$SOURCE_CLUSTER" "" "$SOURCE_KUBECONFIG")
    if [[ $? -ne 0 ]]; then
      format-echo "ERROR" "Failed to validate source cluster."
      exit 1
    fi
  else
    if ! validate_cluster "$SOURCE_PROVIDER" "$SOURCE_CLUSTER" "$SOURCE_CONTEXT" "$SOURCE_KUBECONFIG" &>/dev/null; then
      format-echo "ERROR" "Failed to validate source cluster with provided context."
      exit 1
    fi
  fi
  
  # Create target cluster if requested
  if [[ "$CREATE_TARGET" == true ]]; then
    create_target_cluster
  else
    # Validate target cluster and get context if not provided
    format-echo "INFO" "Validating target cluster..."
    if [[ -z "$TARGET_CONTEXT" ]]; then
      TARGET_CONTEXT=$(validate_cluster "$TARGET_PROVIDER" "$TARGET_CLUSTER" "" "$TARGET_KUBECONFIG")
      if [[ $? -ne 0 ]]; then
        format-echo "ERROR" "Failed to validate target cluster."
        exit 1
      fi
    else
      if ! validate_cluster "$TARGET_PROVIDER" "$TARGET_CLUSTER" "$TARGET_CONTEXT" "$TARGET_KUBECONFIG" &>/dev/null; then
        format-echo "ERROR" "Failed to validate target cluster with provided context."
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
  
  format-echo "SUCCESS" "Cluster conversion completed successfully."
  
  if [[ -n "$BACKUP_DIR" && "$BACKUP_DIR" == /tmp/* ]]; then
    format-echo "INFO" "Temporary backup directory at $BACKUP_DIR"
    format-echo "INFO" "You may want to save these files before they are automatically cleaned up."
  fi
  
  print_with_separator "End of Kubernetes Cluster Conversion"
}

# Run the main function
main "$@"
