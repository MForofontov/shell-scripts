#!/bin/bash
# apply-k8s-configuration.sh
# Script to apply Kubernetes manifests in order (no cluster creation)

#=====================================================================
# SCRIPT SETUP AND ERROR HANDLING
#=====================================================================
set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
MANIFEST_ROOT="k8s"
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
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
      -m|--manifests)
        MANIFEST_ROOT="$2"
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
# RESOURCE MANAGEMENT
#=====================================================================
# Wait for resources to become ready
wait_for_resources_ready() {
  format-echo "INFO" "Waiting for resources to be ready..."
  
  local ns
  for ns in $(kubectl get ns --no-headers -o custom-columns=":metadata.name"); do
    # Wait for deployments to be ready
    for deploy in $(kubectl get deploy -n "$ns" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true); do
      format-echo "INFO" "Waiting for deployment/$deploy in namespace $ns to be ready..."
      kubectl wait --for=condition=available --timeout=180s deployment/"$deploy" -n "$ns" || true
    done
    
    # Wait for statefulsets to be ready
    for sts in $(kubectl get statefulset -n "$ns" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true); do
      format-echo "INFO" "Waiting for statefulset/$sts in namespace $ns to be ready..."
      kubectl wait --for=condition=ready --timeout=180s statefulset/"$sts" -n "$ns" || true
    done
  done
  
  format-echo "SUCCESS" "Resource readiness check completed."
}

#=====================================================================
# MANIFEST APPLICATION
#=====================================================================
# Apply Kubernetes manifests in the proper order
apply_manifests() {
  print_with_separator "Applying Kubernetes Manifests"
  
  #---------------------------------------------------------------------
  # DIRECTORY SETUP
  #---------------------------------------------------------------------
  # Define directories for each resource type
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

  #---------------------------------------------------------------------
  # NAMESPACE RESOURCES
  #---------------------------------------------------------------------
  # Apply namespace resources first
  if [ -d "$ns_dir" ]; then
    format-echo "INFO" "Applying Namespaces..."
    kubectl apply -f "$ns_dir"
  fi

  #---------------------------------------------------------------------
  # CLUSTER-WIDE RESOURCES
  #---------------------------------------------------------------------
  # Apply CRDs and cluster-level RBAC
  if [ -d "$crd_dir" ]; then
    format-echo "INFO" "Applying CustomResourceDefinitions..."
    kubectl apply -f "$crd_dir"
  fi
  
  if [ -d "$clusterrole_dir" ]; then
    format-echo "INFO" "Applying ClusterRoles..."
    kubectl apply -f "$clusterrole_dir"
  fi
  
  if [ -d "$clusterrolebinding_dir" ]; then
    format-echo "INFO" "Applying ClusterRoleBindings..."
    kubectl apply -f "$clusterrolebinding_dir"
  fi

  #---------------------------------------------------------------------
  # NAMESPACE CONFIGURATION
  #---------------------------------------------------------------------
  # Apply namespace-level configuration resources
  if [ -d "$quota_dir" ]; then
    format-echo "INFO" "Applying ResourceQuotas..."
    kubectl apply -f "$quota_dir"
  fi
  
  if [ -d "$limitrange_dir" ]; then
    format-echo "INFO" "Applying LimitRanges..."
    kubectl apply -f "$limitrange_dir"
  fi
  
  if [ -d "$netpol_dir" ]; then
    format-echo "INFO" "Applying NetworkPolicies..."
    kubectl apply -f "$netpol_dir"
  fi

  #---------------------------------------------------------------------
  # RBAC RESOURCES
  #---------------------------------------------------------------------
  # Apply RBAC resources
  if [ -d "$sa_dir" ]; then
    format-echo "INFO" "Applying ServiceAccounts..."
    kubectl apply -f "$sa_dir"
  fi
  
  if [ -d "$role_dir" ]; then
    format-echo "INFO" "Applying Roles..."
    kubectl apply -f "$role_dir"
  fi
  
  if [ -d "$rolebinding_dir" ]; then
    format-echo "INFO" "Applying RoleBindings..."
    kubectl apply -f "$rolebinding_dir"
  fi

  #---------------------------------------------------------------------
  # CONFIGURATION RESOURCES
  #---------------------------------------------------------------------
  # Apply configuration resources
  if [ -d "$cm_dir" ]; then
    format-echo "INFO" "Applying ConfigMaps..."
    kubectl apply -f "$cm_dir"
  fi
  
  if [ -d "$secret_dir" ]; then
    format-echo "INFO" "Applying Secrets..."
    kubectl apply -f "$secret_dir"
  fi
  
  if [ -d "$pvc_dir" ]; then
    format-echo "INFO" "Applying PersistentVolumeClaims..."
    kubectl apply -f "$pvc_dir"
  fi

  #---------------------------------------------------------------------
  # SERVICE RESOURCES
  #---------------------------------------------------------------------
  # Apply service resources
  if [ -d "$svc_dir" ]; then
    format-echo "INFO" "Applying Services..."
    kubectl apply -f "$svc_dir"
  fi

  #---------------------------------------------------------------------
  # WORKLOAD RESOURCES
  #---------------------------------------------------------------------
  # Apply workload resources
  if [ -d "$deploy_dir" ]; then
    format-echo "INFO" "Applying Deployments..."
    kubectl apply -f "$deploy_dir"
  fi
  
  if [ -d "$sts_dir" ]; then
    format-echo "INFO" "Applying StatefulSets..."
    kubectl apply -f "$sts_dir"
  fi
  
  if [ -d "$daemonset_dir" ]; then
    format-echo "INFO" "Applying DaemonSets..."
    kubectl apply -f "$daemonset_dir"
  fi
  
  if [ -d "$job_dir" ]; then
    format-echo "INFO" "Applying Jobs..."
    kubectl apply -f "$job_dir"
  fi
  
  if [ -d "$cronjob_dir" ]; then
    format-echo "INFO" "Applying CronJobs..."
    kubectl apply -f "$cronjob_dir"
  fi

  #---------------------------------------------------------------------
  # SCALING AND AVAILABILITY
  #---------------------------------------------------------------------
  # Apply scaling and availability resources
  if [ -d "$hpa_dir" ]; then
    format-echo "INFO" "Applying HorizontalPodAutoscalers..."
    kubectl apply -f "$hpa_dir"
  fi
  
  if [ -d "$pdb_dir" ]; then
    format-echo "INFO" "Applying PodDisruptionBudgets..."
    kubectl apply -f "$pdb_dir"
  fi

  #---------------------------------------------------------------------
  # NETWORKING RESOURCES
  #---------------------------------------------------------------------
  # Apply networking resources last
  if [ -d "$ingress_dir" ]; then
    format-echo "INFO" "Applying Ingress..."
    kubectl apply -f "$ingress_dir"
  fi

  # Wait for all resources to be ready
  wait_for_resources_ready

  print_with_separator "All manifests applied"
  kubectl get all --all-namespaces
}

#=====================================================================
# MAIN EXECUTION
#=====================================================================
# Main function
main() {
  # Parse arguments
  parse_args "$@"

  setup_log_file
  fi

  print_with_separator "Apply Kubernetes Configuration Script"
  
  format-echo "INFO" "Starting to apply Kubernetes manifests from $MANIFEST_ROOT"
  
  # Apply manifests in order
  apply_manifests
  
  print_with_separator "Application Deployment Complete"
  format-echo "SUCCESS" "All manifests applied successfully."
  
  # Show deployment status summary
  echo
  echo -e "\033[1;34mDeployment Summary:\033[0m"
  echo -e "Manifests applied from: \033[1;32m$MANIFEST_ROOT\033[0m"
  echo -e "To check status: \033[1mkubectl get all --all-namespaces\033[0m"
}

# Run the main function
main "$@"
