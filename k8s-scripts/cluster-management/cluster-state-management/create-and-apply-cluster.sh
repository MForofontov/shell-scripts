#!/bin/bash
# create-and-apply-cluster.sh
# Script to create a Kubernetes cluster (minikube, kind, k3d) and apply manifests in order

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/print-functions/print-with-separator.sh"

# Source logging and utility functions
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Default values
CLUSTER_NAME="k8s-cluster"
PROVIDER="minikube"
NODE_COUNT=1
K8S_VERSION="latest"
CONFIG_FILE=""
WAIT_TIMEOUT=300
MANIFEST_ROOT="k8s"
LOG_FILE="/dev/null"
SWITCH_CONTEXT=true

usage() {
  print_with_separator "Create and Apply Kubernetes Cluster Script"
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m          Cluster name (default: ${CLUSTER_NAME})"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m  Provider: minikube, kind, k3d (default: ${PROVIDER})"
  echo -e "  \033[1;33m-c, --nodes <COUNT>\033[0m        Number of nodes (default: ${NODE_COUNT})"
  echo -e "  \033[1;33m-v, --version <VERSION>\033[0m    Kubernetes version (default: ${K8S_VERSION})"
  echo -e "  \033[1;33m-f, --config <FILE>\033[0m        Path to provider config file"
  echo -e "  \033[1;33m-m, --manifests <DIR>\033[0m      Root directory for manifests (default: k8s)"
  echo -e "  \033[1;33m-t, --timeout <SECONDS>\033[0m    Timeout for cluster readiness (default: ${WAIT_TIMEOUT})"
  echo -e "  \033[1;33m--log <FILE>\033[0m               Log output to specified file"
  echo -e "  \033[1;33m--no-context-switch\033[0m        Do not switch kubectl context after cluster creation"
  echo -e "  \033[1;33m--help\033[0m                     Show this help message"
  print_with_separator
  exit 1
}

# Parse arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      -n|--name)
        CLUSTER_NAME="$2"
        shift 2
        ;;
      -p|--provider)
        PROVIDER="$2"
        shift 2
        ;;
      -c|--nodes)
        NODE_COUNT="$2"
        shift 2
        ;;
      -v|--version)
        K8S_VERSION="$2"
        shift 2
        ;;
      -f|--config)
        CONFIG_FILE="$2"
        shift 2
        ;;
      -m|--manifests)
        MANIFEST_ROOT="$2"
        shift 2
        ;;
      -t|--timeout)
        WAIT_TIMEOUT="$2"
        shift 2
        ;;
      --log)
        LOG_FILE="$2"
        shift 2
        ;;
      --no-context-switch)
        SWITCH_CONTEXT=false
        shift 1
        ;;
      *)
        log_message "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

# Switch kubectl context to the new cluster
switch_kubectl_context() {
  if [ "$SWITCH_CONTEXT" = true ]; then
    case "$PROVIDER" in
      minikube)
        log_message "INFO" "Switching kubectl context to minikube profile: $CLUSTER_NAME"
        kubectl config use-context "$CLUSTER_NAME" || true
        ;;
      kind)
        log_message "INFO" "Switching kubectl context to kind cluster: kind-$CLUSTER_NAME"
        kubectl config use-context "kind-$CLUSTER_NAME" || true
        ;;
      k3d)
        log_message "INFO" "Switching kubectl context to k3d cluster: k3d-$CLUSTER_NAME"
        kubectl config use-context "k3d-$CLUSTER_NAME" || true
        ;;
    esac
  fi
}

# Create cluster using the existing script
create_cluster() {
  log_message "INFO" "Creating cluster with provider: $PROVIDER"
  "$SCRIPT_DIR/create-cluster-local.sh" \
    --name "$CLUSTER_NAME" \
    --provider "$PROVIDER" \
    --nodes "$NODE_COUNT" \
    --version "$K8S_VERSION" \
    ${CONFIG_FILE:+--config "$CONFIG_FILE"} \
    --timeout "$WAIT_TIMEOUT" \
    --log "$LOG_FILE"
}

# Wait for all deployments and statefulsets to be ready
wait_for_resources_ready() {
  local ns
  for ns in $(kubectl get ns --no-headers -o custom-columns=":metadata.name"); do
    for deploy in $(kubectl get deploy -n "$ns" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true); do
      log_message "INFO" "Waiting for deployment/$deploy in namespace $ns to be ready..."
      kubectl wait --for=condition=available --timeout=180s deployment/"$deploy" -n "$ns" || true
    done
    for sts in $(kubectl get statefulset -n "$ns" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true); do
      log_message "INFO" "Waiting for statefulset/$sts in namespace $ns to be ready..."
      kubectl wait --for=condition=ready --timeout=180s statefulset/"$sts" -n "$ns" || true
    done
  done
}

# Apply manifests in order
apply_manifests() {
  print_with_separator "Applying Kubernetes Manifests"
  local ns_dir="$MANIFEST_ROOT/namespace"
  local cm_dir="$MANIFEST_ROOT/configmaps"
  local secret_dir="$MANIFEST_ROOT/secrets"
  local pvc_dir="$MANIFEST_ROOT/persistentvolumeclaims"
  local svc_dir="$MANIFEST_ROOT/services"
  local deploy_dir="$MANIFEST_ROOT/deployments"
  local sts_dir="$MANIFEST_ROOT/statefulsets"
  local ingress_dir="$MANIFEST_ROOT/ingress"
  local daemonset_dir="$MANIFEST_ROOT/daemonsets"
  local job_dir="$MANIFEST_ROOT/jobs"
  local cronjob_dir="$MANIFEST_ROOT/cronjobs"
  local netpol_dir="$MANIFEST_ROOT/networkpolicies"
  local sa_dir="$MANIFEST_ROOT/serviceaccounts"
  local role_dir="$MANIFEST_ROOT/roles"
  local rolebinding_dir="$MANIFEST_ROOT/rolebindings"
  local clusterrole_dir="$MANIFEST_ROOT/clusterroles"
  local clusterrolebinding_dir="$MANIFEST_ROOT/clusterrolebindings"
  local quota_dir="$MANIFEST_ROOT/resourcequotas"
  local limitrange_dir="$MANIFEST_ROOT/limitranges"
  local hpa_dir="$MANIFEST_ROOT/horizontalpodautoscalers"
  local pdb_dir="$MANIFEST_ROOT/poddisruptionbudgets"
  local crd_dir="$MANIFEST_ROOT/customresourcedefinitions"

  if [ -d "$ns_dir" ]; then
    log_message "INFO" "Applying Namespaces..."
    kubectl apply -f "$ns_dir"
  fi
  if [ -d "$cm_dir" ]; then
    log_message "INFO" "Applying ConfigMaps..."
    kubectl apply -f "$cm_dir"
  fi
  if [ -d "$secret_dir" ]; then
    log_message "INFO" "Applying Secrets..."
    kubectl apply -f "$secret_dir"
  fi
  if [ -d "$pvc_dir" ]; then
    log_message "INFO" "Applying PersistentVolumeClaims..."
    kubectl apply -f "$pvc_dir"
  fi
  if [ -d "$svc_dir" ]; then
    log_message "INFO" "Applying Services..."
    kubectl apply -f "$svc_dir"
  fi
  if [ -d "$deploy_dir" ]; then
    log_message "INFO" "Applying Deployments..."
    kubectl apply -f "$deploy_dir"
  fi
  if [ -d "$sts_dir" ]; then
    log_message "INFO" "Applying StatefulSets..."
    kubectl apply -f "$sts_dir"
  fi
  if [ -d "$ingress_dir" ]; then
    log_message "INFO" "Applying Ingress..."
    kubectl apply -f "$ingress_dir"
  fi
  if [ -d "$daemonset_dir" ]; then
    log_message "INFO" "Applying DaemonSets..."
    kubectl apply -f "$daemonset_dir"
  fi
  if [ -d "$job_dir" ]; then
    log_message "INFO" "Applying Jobs..."
    kubectl apply -f "$job_dir"
  fi
  if [ -d "$cronjob_dir" ]; then
    log_message "INFO" "Applying CronJobs..."
    kubectl apply -f "$cronjob_dir"
  fi
  if [ -d "$netpol_dir" ]; then
    log_message "INFO" "Applying NetworkPolicies..."
    kubectl apply -f "$netpol_dir"
  fi
  if [ -d "$sa_dir" ]; then
    log_message "INFO" "Applying ServiceAccounts..."
    kubectl apply -f "$sa_dir"
  fi
  if [ -d "$role_dir" ]; then
    log_message "INFO" "Applying Roles..."
    kubectl apply -f "$role_dir"
  fi
  if [ -d "$rolebinding_dir" ]; then
    log_message "INFO" "Applying RoleBindings..."
    kubectl apply -f "$rolebinding_dir"
  fi
  if [ -d "$clusterrole_dir" ]; then
    log_message "INFO" "Applying ClusterRoles..."
    kubectl apply -f "$clusterrole_dir"
  fi
  if [ -d "$clusterrolebinding_dir" ]; then
    log_message "INFO" "Applying ClusterRoleBindings..."
    kubectl apply -f "$clusterrolebinding_dir"
  fi
  if [ -d "$quota_dir" ]; then
    log_message "INFO" "Applying ResourceQuotas..."
    kubectl apply -f "$quota_dir"
  fi
  if [ -d "$limitrange_dir" ]; then
    log_message "INFO" "Applying LimitRanges..."
    kubectl apply -f "$limitrange_dir"
  fi
  if [ -d "$hpa_dir" ]; then
    log_message "INFO" "Applying HorizontalPodAutoscalers..."
    kubectl apply -f "$hpa_dir"
  fi
  if [ -d "$pdb_dir" ]; then
    log_message "INFO" "Applying PodDisruptionBudgets..."
    kubectl apply -f "$pdb_dir"
  fi
  if [ -d "$crd_dir" ]; then
    log_message "INFO" "Applying CustomResourceDefinitions..."
    kubectl apply -f "$crd_dir"
  fi

  wait_for_resources_ready

  print_with_separator "All manifests applied"
  kubectl get all --all-namespaces
}

main() {
  print_with_separator "Create and Apply Kubernetes Cluster"
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  create_cluster
  switch_kubectl_context
  apply_manifests

  print_with_separator "Cluster and Application Deployment Complete"
  log_message "SUCCESS" "Cluster created and manifests applied."
}

main "$@"