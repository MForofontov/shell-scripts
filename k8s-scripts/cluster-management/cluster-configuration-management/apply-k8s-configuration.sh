#!/bin/bash
# apply-k8s-configuration.sh
# Script to apply Kubernetes manifests in order (no cluster creation)

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../../functions/print-functions/print-with-separator.sh"

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

MANIFEST_ROOT="k8s"
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Apply Kubernetes Configuration Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script applies Kubernetes manifests in order (no cluster creation)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-m, --manifests <DIR>\033[0m      (Optional) Root directory for manifests (default: k8s)"
  echo -e "  \033[1;33m--log <FILE>\033[0m               (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Show this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --manifests my-manifests"
  echo "  $0 --log apply.log"
  print_with_separator
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      -m|--manifests)
        MANIFEST_ROOT="$2"
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
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Apply Kubernetes Configuration Script"

  log_message "INFO" "Starting to apply Kubernetes manifests from $MANIFEST_ROOT"

  apply_manifests
  print_with_separator "Application Deployment Complete"
  log_message "SUCCESS" "Manifests applied."
}

main "$@"