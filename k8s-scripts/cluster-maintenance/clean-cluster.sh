#!/bin/bash
# clean-cluster.sh
# Script to reset a Kubernetes cluster to a clean state by removing non-system workloads

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
# Default values
PRESERVED_NAMESPACES=("kube-system" "kube-public" "kube-node-lease" "default")
CLEAN_WORKLOADS=true
CLEAN_VOLUMES=false
CLEAN_CONFIG=false
FORCE=false
DRY_RUN=false
LOG_FILE="/dev/null"
TIMEOUT=300
ADDITIONAL_PRESERVED_NS=()
PRESERVE_PATTERNS=()
CLEAN_CRDS=false
CLEAN_SECRETS=false
CLEAN_CONFIGMAPS=false
KEEP_PVCS=true
KUBECONFIG_PATH=""
PROVIDER="auto"
ALL_NAMESPACES=false
VERBOSE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Cluster Cleaning Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script resets a Kubernetes cluster to a clean state by removing non-system workloads,"
  echo "  cleaning persistent volumes, and resetting custom configurations."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--preserve-ns <NAMESPACE>\033[0m     (Optional) Additional namespace to preserve (can be used multiple times)"
  echo -e "  \033[1;33m--preserve-pattern <PATTERN>\033[0m  (Optional) Preserve namespaces matching pattern (can be used multiple times)"
  echo -e "  \033[1;33m--no-workloads\033[0m                (Optional) Skip cleaning workloads"
  echo -e "  \033[1;33m--clean-volumes\033[0m               (Optional) Clean persistent volumes"
  echo -e "  \033[1;33m--clean-config\033[0m                (Optional) Clean custom configurations"
  echo -e "  \033[1;33m--clean-crds\033[0m                  (Optional) Remove custom resource definitions"
  echo -e "  \033[1;33m--clean-secrets\033[0m               (Optional) Remove secrets in cleaned namespaces"
  echo -e "  \033[1;33m--clean-configmaps\033[0m            (Optional) Remove configmaps in cleaned namespaces"
  echo -e "  \033[1;33m--remove-pvcs\033[0m                 (Optional) Remove persistent volume claims"
  echo -e "  \033[1;33m--all-namespaces\033[0m              (Optional) Clean all namespaces including default (dangerous)"
  echo -e "  \033[1;33m--provider <PROVIDER>\033[0m         (Optional) Cluster provider for provider-specific cleanup"
  echo -e "  \033[1;33m--kubeconfig <PATH>\033[0m           (Optional) Path to kubeconfig file"
  echo -e "  \033[1;33m--timeout <SECONDS>\033[0m           (Optional) Timeout for operations (default: ${TIMEOUT}s)"
  echo -e "  \033[1;33m--dry-run\033[0m                     (Optional) Only print what would be done"
  echo -e "  \033[1;33m-f, --force\033[0m                   (Optional) Skip confirmation prompts"
  echo -e "  \033[1;33m-v, --verbose\033[0m                 (Optional) Show more detailed output"
  echo -e "  \033[1;33m--log <FILE>\033[0m                  (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                        (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --dry-run"
  echo "  $0 --preserve-ns monitoring --preserve-ns logging"
  echo "  $0 --clean-volumes --clean-config --force"
  echo "  $0 --preserve-pattern 'kube-*' --preserve-pattern 'istio-*'"
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
# Check requirements
check_requirements() {
  format-echo "INFO" "Checking requirements..."
  
  if ! command_exists kubectl; then
    format-echo "ERROR" "kubectl not found. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
  
  # Check if we can connect to the cluster
  if ! kubectl get nodes &>/dev/null; then
    format-echo "ERROR" "Cannot connect to Kubernetes cluster. Check your connection and credentials."
    exit 1
  fi
  
  format-echo "SUCCESS" "All required tools are available."
}

#=====================================================================
# PROVIDER DETECTION
#=====================================================================
# Auto-detect provider
detect_provider() {
  format-echo "INFO" "Auto-detecting Kubernetes cluster provider..."
  
  # Check if kubeadm is installed and configured
  if command_exists kubeadm && kubeadm config view &>/dev/null; then
    format-echo "INFO" "Detected provider: kubeadm"
    echo "kubeadm"
    return 0
  fi
  
  # Check for k3s
  if command_exists k3s || [ -f "/etc/systemd/system/k3s.service" ]; then
    format-echo "INFO" "Detected provider: k3s"
    echo "k3s"
    return 0
  fi
  
  # Check for RKE
  if command_exists rke && [ -f "./cluster.yml" ]; then
    format-echo "INFO" "Detected provider: rke"
    echo "rke"
    return 0
  fi
  
  # Check for managed providers (this is approximate)
  context=$(kubectl config current-context 2>/dev/null)
  if [[ "$context" == *"eks"* ]]; then
    format-echo "INFO" "Detected provider: eks"
    echo "eks"
    return 0
  elif [[ "$context" == *"gke"* ]]; then
    format-echo "INFO" "Detected provider: gke"
    echo "gke"
    return 0
  elif [[ "$context" == *"aks"* ]]; then
    format-echo "INFO" "Detected provider: aks"
    echo "aks"
    return 0
  elif [[ "$context" == *"openshift"* ]]; then
    format-echo "INFO" "Detected provider: openshift"
    echo "openshift"
    return 0
  fi
  
  format-echo "WARNING" "Could not detect provider automatically, using generic approach"
  echo "generic"
  return 0
}

#---------------------------------------------------------------------
# PROVIDER-SPECIFIC NAMESPACES
#---------------------------------------------------------------------
# Get provider-specific system namespaces
get_provider_namespaces() {
  local provider="$1"
  local provider_ns=()
  
  case "$provider" in
    eks)
      provider_ns=("amazon-cloudwatch" "amazon-vpc-cni" "amazon-guardduty" "aws-observability" "aws-system")
      ;;
    gke)
      provider_ns=("gke-system" "gke-connect" "istio-system" "knative-serving" "config-management-system")
      ;;
    aks)
      provider_ns=("kube-system" "gatekeeper-system" "azure-arc" "azure-system")
      ;;
    openshift)
      provider_ns=("openshift" "openshift-*" "kube-*" "redhat-*")
      ;;
    k3s)
      provider_ns=("kube-system" "metallb-system" "traefik" "local-path-storage")
      ;;
    generic|*)
      provider_ns=()
      ;;
  esac
  
  echo "${provider_ns[@]}"
}

#=====================================================================
# NAMESPACE MANAGEMENT
#=====================================================================
# Get all namespaces to preserve
get_preserved_namespaces() {
  local ns_to_preserve=("${PRESERVED_NAMESPACES[@]}")
  
  # Add provider-specific namespaces
  local provider_ns=()
  readarray -t provider_ns <<< "$(get_provider_namespaces "$PROVIDER")"
  
  for ns in "${provider_ns[@]}"; do
    if [[ "$ns" == *"*"* ]]; then
      # For wildcard patterns, add to preserve patterns
      PRESERVE_PATTERNS+=("$ns")
    else
      # Add literal namespace
      ns_to_preserve+=("$ns")
    fi
  done
  
  # Add user-specified namespaces
  for ns in "${ADDITIONAL_PRESERVED_NS[@]}"; do
    ns_to_preserve+=("$ns")
  done
  
  # Handle all-namespaces flag
  if [[ "$ALL_NAMESPACES" == true ]]; then
    # Remove 'default' from preserved namespaces
    local new_preserved=()
    for ns in "${ns_to_preserve[@]}"; do
      if [[ "$ns" != "default" ]]; then
        new_preserved+=("$ns")
      fi
    done
    ns_to_preserve=("${new_preserved[@]}")
  fi
  
  if [[ "$VERBOSE" == true ]]; then
    format-echo "INFO" "Namespaces to preserve: ${ns_to_preserve[*]}"
    format-echo "INFO" "Namespace patterns to preserve: ${PRESERVE_PATTERNS[*]}"
  fi
  
  echo "${ns_to_preserve[@]}"
}

#---------------------------------------------------------------------
# NAMESPACE FILTERING
#---------------------------------------------------------------------
# Determine if namespace should be preserved
should_preserve_namespace() {
  local ns="$1"
  local preserved_namespaces=("$2")
  
  # Check if it's in the explicitly preserved list
  for preserved in "${preserved_namespaces[@]}"; do
    if [[ "$ns" == "$preserved" ]]; then
      return 0
    fi
  done
  
  # Check against patterns
  for pattern in "${PRESERVE_PATTERNS[@]}"; do
    if [[ "$ns" == ${pattern} ]]; then
      return 0
    fi
  done
  
  return 1
}

# Get namespaces to clean
get_namespaces_to_clean() {
  local all_ns=()
  local preserved_ns=()
  local ns_to_clean=()
  
  # Get all namespaces
  readarray -t all_ns <<< "$(kubectl get namespaces -o name | cut -d/ -f2)"
  
  # Get preserved namespaces
  IFS=" " read -r -a preserved_ns <<< "$(get_preserved_namespaces)"
  
  # Determine which namespaces to clean
  for ns in "${all_ns[@]}"; do
    if should_preserve_namespace "$ns" "${preserved_ns[*]}"; then
      format-echo "INFO" "Namespace $ns will be preserved"
    else
      ns_to_clean+=("$ns")
      format-echo "INFO" "Namespace $ns will be cleaned"
    fi
  done
  
  echo "${ns_to_clean[@]}"
}

#=====================================================================
# WORKLOAD CLEANING OPERATIONS
#=====================================================================
# Clean workloads in specified namespace
clean_namespace_workloads() {
  local namespace="$1"
  
  format-echo "INFO" "Cleaning workloads in namespace: $namespace"
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would delete all deployments, statefulsets, daemonsets, jobs, cronjobs, pods in namespace $namespace"
    return 0
  fi
  
  #---------------------------------------------------------------------
  # CONTROLLERS AND WORKLOADS
  #---------------------------------------------------------------------
  # Delete deployments
  format-echo "INFO" "Deleting deployments in $namespace"
  kubectl delete deployments --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all deployments in $namespace"
  
  # Delete statefulsets
  format-echo "INFO" "Deleting statefulsets in $namespace"
  kubectl delete statefulsets --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all statefulsets in $namespace"
  
  # Delete daemonsets
  format-echo "INFO" "Deleting daemonsets in $namespace"
  kubectl delete daemonsets --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all daemonsets in $namespace"
  
  # Delete jobs
  format-echo "INFO" "Deleting jobs in $namespace"
  kubectl delete jobs --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all jobs in $namespace"
  
  # Delete cronjobs
  format-echo "INFO" "Deleting cronjobs in $namespace"
  kubectl delete cronjobs --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all cronjobs in $namespace"
  
  # Delete any remaining pods
  format-echo "INFO" "Deleting remaining pods in $namespace"
  kubectl delete pods --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all pods in $namespace"
  
  #---------------------------------------------------------------------
  # CONFIGURATION RESOURCES
  #---------------------------------------------------------------------
  # Delete configmaps if requested
  if [[ "$CLEAN_CONFIGMAPS" == true ]]; then
    format-echo "INFO" "Deleting configmaps in $namespace"
    kubectl delete configmaps --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all configmaps in $namespace"
  fi
  
  # Delete secrets if requested
  if [[ "$CLEAN_SECRETS" == true ]]; then
    format-echo "INFO" "Deleting secrets in $namespace"
    kubectl delete secrets --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all secrets in $namespace"
  fi
  
  #---------------------------------------------------------------------
  # NETWORK RESOURCES
  #---------------------------------------------------------------------
  # Delete services
  format-echo "INFO" "Deleting services in $namespace"
  # Preserve kubernetes service in default namespace
  if [[ "$namespace" == "default" ]]; then
    kubectl get services -n default -o name | grep -v "service/kubernetes" | xargs -r kubectl delete -n default --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete services in default namespace"
  else
    kubectl delete services --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all services in $namespace"
  fi
  
  # Delete ingresses
  format-echo "INFO" "Deleting ingresses in $namespace"
  kubectl delete ingress --all -n "$namespace" --timeout="${TIMEOUT}s" 2>/dev/null || true
  
  # Delete network policies
  format-echo "INFO" "Deleting network policies in $namespace"
  kubectl delete networkpolicies --all -n "$namespace" --timeout="${TIMEOUT}s" 2>/dev/null || true
  
  #---------------------------------------------------------------------
  # AUTOSCALING AND STORAGE
  #---------------------------------------------------------------------
  # Delete HPA
  format-echo "INFO" "Deleting horizontal pod autoscalers in $namespace"
  kubectl delete hpa --all -n "$namespace" --timeout="${TIMEOUT}s" 2>/dev/null || true
  
  # Delete PVCs if requested
  if [[ "$KEEP_PVCS" != true ]]; then
    format-echo "INFO" "Deleting persistent volume claims in $namespace"
    kubectl delete pvc --all -n "$namespace" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete all PVCs in $namespace"
  fi
  
  format-echo "SUCCESS" "Cleaned workloads in namespace $namespace"
  return 0
}

#---------------------------------------------------------------------
# NAMESPACE DELETION
#---------------------------------------------------------------------
# Delete namespace
delete_namespace() {
  local namespace="$1"
  
  format-echo "INFO" "Deleting namespace: $namespace"
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would delete namespace $namespace"
    return 0
  fi
  
  # Delete the namespace
  if kubectl delete namespace "$namespace" --timeout="${TIMEOUT}s"; then
    format-echo "SUCCESS" "Deleted namespace $namespace"
    return 0
  else
    format-echo "ERROR" "Failed to delete namespace $namespace"
    
    # Try a force delete if it failed
    format-echo "INFO" "Attempting force delete of namespace $namespace"
    kubectl get namespace "$namespace" -o json | \
      tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" | \
      kubectl replace --raw "/api/v1/namespaces/$namespace/finalize" -f -
    
    # Check if namespace is gone
    if ! kubectl get namespace "$namespace" &>/dev/null; then
      format-echo "SUCCESS" "Force deleted namespace $namespace"
      return 0
    else
      format-echo "ERROR" "Failed to force delete namespace $namespace"
      return 1
    fi
  fi
}

#---------------------------------------------------------------------
# FULL WORKLOAD CLEANING
#---------------------------------------------------------------------
# Clean all workloads
clean_workloads() {
  format-echo "INFO" "Cleaning all non-system workloads..."
  
  # Get namespaces to clean
  local ns_to_clean=()
  IFS=" " read -r -a ns_to_clean <<< "$(get_namespaces_to_clean)"
  
  if [[ ${#ns_to_clean[@]} -eq 0 ]]; then
    format-echo "INFO" "No namespaces to clean"
    return 0
  fi
  
  # Process each namespace
  for ns in "${ns_to_clean[@]}"; do
    if [[ "$ns" != "default" ]]; then
      # For non-default namespaces, clean workloads and then delete the namespace
      clean_namespace_workloads "$ns"
      delete_namespace "$ns"
    else
      # For default namespace, just clean workloads but don't delete the namespace
      clean_namespace_workloads "$ns"
    fi
  done
  
  format-echo "SUCCESS" "All non-system workloads cleaned"
  return 0
}

#=====================================================================
# VOLUME MANAGEMENT
#=====================================================================
# Clean persistent volumes
clean_volumes() {
  if [[ "$CLEAN_VOLUMES" != true ]]; then
    format-echo "INFO" "Skipping volume cleaning"
    return 0
  fi
  
  format-echo "INFO" "Cleaning persistent volumes..."
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would clean all persistent volumes not bound to preserved namespaces"
    return 0
  fi
  
  # Get list of PVs
  local pvs=()
  readarray -t pvs <<< "$(kubectl get pv -o name | cut -d/ -f2)"
  
  if [[ ${#pvs[@]} -eq 0 ]]; then
    format-echo "INFO" "No persistent volumes found"
    return 0
  fi
  
  # Get preserved namespaces
  local preserved_ns=()
  IFS=" " read -r -a preserved_ns <<< "$(get_preserved_namespaces)"
  
  # Clean each PV
  for pv in "${pvs[@]}"; do
    # Get claim details
    local claim_info
    claim_info=$(kubectl get pv "$pv" -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}' 2>/dev/null)
    
    if [[ -z "$claim_info" || "$claim_info" == "/" ]]; then
      # Unbound PV
      format-echo "INFO" "PV $pv is unbound, deleting"
      if [[ "$DRY_RUN" != true ]]; then
        kubectl delete pv "$pv" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete PV $pv"
      fi
    else
      # Extract namespace
      local ns
      ns=$(echo "$claim_info" | cut -d/ -f1)
      
      # Check if namespace should be preserved
      if should_preserve_namespace "$ns" "${preserved_ns[*]}"; then
        format-echo "INFO" "Preserving PV $pv bound to claim in namespace $ns"
      else
        format-echo "INFO" "Deleting PV $pv bound to claim in namespace $ns"
        if [[ "$DRY_RUN" != true ]]; then
          # Patch PV to remove finalizer
          kubectl patch pv "$pv" -p '{"metadata":{"finalizers":null}}' --type=merge || true
          # Delete PV
          kubectl delete pv "$pv" --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete PV $pv"
        fi
      fi
    fi
  done
  
  format-echo "SUCCESS" "Persistent volumes cleaned"
  return 0
}

#=====================================================================
# CONFIGURATION CLEANING
#=====================================================================
# Clean custom configurations
clean_configurations() {
  if [[ "$CLEAN_CONFIG" != true ]]; then
    format-echo "INFO" "Skipping configuration cleaning"
    return 0
  fi
  
  format-echo "INFO" "Cleaning custom configurations..."
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would clean custom configurations like ClusterRoles, ClusterRoleBindings, StorageClasses, etc."
    return 0
  fi
  
  #---------------------------------------------------------------------
  # STORAGE RESOURCES
  #---------------------------------------------------------------------
  # Clean StorageClasses (except default)
  format-echo "INFO" "Cleaning non-default StorageClasses"
  local default_sc
  default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
  
  if [[ -n "$default_sc" ]]; then
    format-echo "INFO" "Preserving default StorageClass: $default_sc"
    kubectl get storageclass -o name | grep -v "storageclass.storage.k8s.io/$default_sc" | xargs -r kubectl delete --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete some StorageClasses"
  else
    format-echo "INFO" "No default StorageClass found"
  fi
  
  #---------------------------------------------------------------------
  # RBAC RESOURCES
  #---------------------------------------------------------------------
  # Clean ClusterRoles (except system ones)
  format-echo "INFO" "Cleaning custom ClusterRoles"
  kubectl get clusterrole -o name | grep -v "clusterrole.rbac.authorization.k8s.io/system:" | \
  grep -v "clusterrole.rbac.authorization.k8s.io/cluster-admin" | \
  grep -v "clusterrole.rbac.authorization.k8s.io/admin" | \
  grep -v "clusterrole.rbac.authorization.k8s.io/edit" | \
  grep -v "clusterrole.rbac.authorization.k8s.io/view" | \
  xargs -r kubectl delete --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete some ClusterRoles"
  
  # Clean ClusterRoleBindings (except system ones)
  format-echo "INFO" "Cleaning custom ClusterRoleBindings"
  kubectl get clusterrolebinding -o name | grep -v "clusterrolebinding.rbac.authorization.k8s.io/system:" | \
  grep -v "clusterrolebinding.rbac.authorization.k8s.io/cluster-admin" | \
  xargs -r kubectl delete --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete some ClusterRoleBindings"
  
  #---------------------------------------------------------------------
  # ADMISSION CONTROL RESOURCES
  #---------------------------------------------------------------------
  # Clean custom Webhooks
  format-echo "INFO" "Cleaning MutatingWebhookConfigurations"
  kubectl get mutatingwebhookconfiguration -o name | grep -v "mutatingwebhookconfiguration.admissionregistration.k8s.io/pod-policy.kubernetes.io" | \
  xargs -r kubectl delete --timeout="${TIMEOUT}s" 2>/dev/null || true
  
  format-echo "INFO" "Cleaning ValidatingWebhookConfigurations"
  kubectl get validatingwebhookconfiguration -o name | grep -v "validatingwebhookconfiguration.admissionregistration.k8s.io/validate.webhook.pod.security.kubernetes.io" | \
  xargs -r kubectl delete --timeout="${TIMEOUT}s" 2>/dev/null || true
  
  # Clean PodSecurityPolicies if the API is available
  if kubectl api-resources | grep -q "podsecuritypolicies"; then
    format-echo "INFO" "Cleaning PodSecurityPolicies"
    kubectl get psp -o name | grep -v "podsecuritypolicy.policy/kube-system" | \
    xargs -r kubectl delete --timeout="${TIMEOUT}s" 2>/dev/null || true
  fi
  
  #---------------------------------------------------------------------
  # API EXTENSION RESOURCES
  #---------------------------------------------------------------------
  # Clean CRDs if requested
  if [[ "$CLEAN_CRDS" == true ]]; then
    format-echo "INFO" "Cleaning Custom Resource Definitions"
    # Exclude potentially system-critical CRDs
    kubectl get crd -o name | grep -v "crd.apiextensions.k8s.io/podnetworks.kubernetes.io" | \
    xargs -r kubectl delete --timeout="${TIMEOUT}s" || format-echo "WARNING" "Failed to delete some CRDs"
  fi
  
  # Clean APIServices (non-system)
  format-echo "INFO" "Cleaning custom APIServices"
  kubectl get apiservice -o name | grep -v "apiservice.apiregistration.k8s.io/v1." | \
  grep -v "apiservice.apiregistration.k8s.io/v2." | \
  xargs -r kubectl delete --timeout="${TIMEOUT}s" 2>/dev/null || true
  
  format-echo "SUCCESS" "Custom configurations cleaned"
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
      --preserve-ns)
        ADDITIONAL_PRESERVED_NS+=("$2")
        shift 2
        ;;
      --preserve-pattern)
        PRESERVE_PATTERNS+=("$2")
        shift 2
        ;;
      --no-workloads)
        CLEAN_WORKLOADS=false
        shift
        ;;
      --clean-volumes)
        CLEAN_VOLUMES=true
        shift
        ;;
      --clean-config)
        CLEAN_CONFIG=true
        shift
        ;;
      --clean-crds)
        CLEAN_CRDS=true
        shift
        ;;
      --clean-secrets)
        CLEAN_SECRETS=true
        shift
        ;;
      --clean-configmaps)
        CLEAN_CONFIGMAPS=true
        shift
        ;;
      --remove-pvcs)
        KEEP_PVCS=false
        shift
        ;;
      --all-namespaces)
        ALL_NAMESPACES=true
        shift
        ;;
      --provider)
        PROVIDER="$2"
        shift 2
        ;;
      --kubeconfig)
        KUBECONFIG_PATH="$2"
        export KUBECONFIG="$KUBECONFIG_PATH"
        shift 2
        ;;
      --timeout)
        TIMEOUT="$2"
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
      -v|--verbose)
        VERBOSE=true
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
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
# Main function
main() {
  # Parse arguments
  parse_args "$@"

  print_with_separator "Kubernetes Cluster Cleaning Script"
  
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    # Redirect stdout/stderr to log file and console
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  format-echo "INFO" "Starting cluster cleaning process..."
  
  # Check requirements
  check_requirements
  
  # Auto-detect provider if set to auto
  if [[ "$PROVIDER" == "auto" ]]; then
    PROVIDER=$(detect_provider)
  fi
  
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Provider:           $PROVIDER"
  format-echo "INFO" "  Clean Workloads:    $CLEAN_WORKLOADS"
  format-echo "INFO" "  Clean Volumes:      $CLEAN_VOLUMES"
  format-echo "INFO" "  Clean Config:       $CLEAN_CONFIG"
  format-echo "INFO" "  Clean CRDs:         $CLEAN_CRDS"
  format-echo "INFO" "  Clean Secrets:      $CLEAN_SECRETS"
  format-echo "INFO" "  Clean ConfigMaps:   $CLEAN_CONFIGMAPS"
  format-echo "INFO" "  Keep PVCs:          $KEEP_PVCS"
  format-echo "INFO" "  All Namespaces:     $ALL_NAMESPACES"
  format-echo "INFO" "  Timeout:            ${TIMEOUT}s"
  format-echo "INFO" "  Dry Run:            $DRY_RUN"
  format-echo "INFO" "  Force:              $FORCE"
  
  if [[ ${#ADDITIONAL_PRESERVED_NS[@]} -gt 0 ]]; then
    format-echo "INFO" "  Additional Preserved Namespaces: ${ADDITIONAL_PRESERVED_NS[*]}"
  fi
  
  if [[ ${#PRESERVE_PATTERNS[@]} -gt 0 ]]; then
    format-echo "INFO" "  Preserve Patterns: ${PRESERVE_PATTERNS[*]}"
  fi
  
  #---------------------------------------------------------------------
  # CONFIRMATION AND EXECUTION
  #---------------------------------------------------------------------
  # Confirm operation if not forced or dry-run
  if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
    format-echo "WARNING" "This operation will remove all non-system workloads from your cluster"
    format-echo "WARNING" "Make sure you have backed up anything important before proceeding"
    
    if [[ "$CLEAN_VOLUMES" == true ]]; then
      format-echo "WARNING" "Persistent volumes will be deleted - THIS WILL CAUSE DATA LOSS"
    fi
    
    if [[ "$CLEAN_CONFIG" == true ]]; then
      format-echo "WARNING" "Custom configurations will be reset"
    fi
    
    if [[ "$CLEAN_CRDS" == true ]]; then
      format-echo "WARNING" "Custom Resource Definitions will be deleted"
    fi
    
    if [[ "$ALL_NAMESPACES" == true ]]; then
      format-echo "WARNING" "All namespaces including default will be cleaned"
    fi
    
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      format-echo "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  # Perform operations in the correct order
  
  # First clean workloads
  if [[ "$CLEAN_WORKLOADS" == true ]]; then
    clean_workloads
  else
    format-echo "INFO" "Skipping workload cleaning as requested"
  fi
  
  # Then clean volumes
  clean_volumes
  
  # Finally clean configurations
  clean_configurations
  
  print_with_separator "End of Kubernetes Cluster Cleaning"
  
  # Final summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "Dry run completed for cluster cleanup."
  else
    echo -e "Cluster cleaning \033[1;32mcompleted\033[0m."
    
    if [[ "$CLEAN_WORKLOADS" == true ]]; then
      echo -e "✓ Non-system workloads removed"
    fi
    
    if [[ "$CLEAN_VOLUMES" == true ]]; then
      echo -e "✓ Persistent volumes cleaned"
    fi
    
    if [[ "$CLEAN_CONFIG" == true ]]; then
      echo -e "✓ Custom configurations reset"
    fi
    
    if [[ "$CLEAN_CRDS" == true ]]; then
      echo -e "✓ Custom Resource Definitions removed"
    fi
  fi
  
  # Remind about next steps
  echo -e "\nTo verify cluster state:"
  echo -e "  \033[1mkubectl get namespaces\033[0m"
  echo -e "  \033[1mkubectl get pods --all-namespaces\033[0m"
  echo -e "  \033[1mkubectl get pv\033[0m"
}

# Run the main function
main "$@"