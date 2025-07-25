#!/bin/bash
# rotate-certs.sh
# Script to rotate Kubernetes cluster certificates before expiration

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# Default values
CLUSTER_NAME=""
PROVIDER="auto"
KUBECONFIG_PATH=""
FORCE=false
DRY_RUN=false
DAYS_WARNING=30
BACKUP_DIR=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
SKIP_VALIDATION=false
RESTART_COMPONENTS=true
ROTATE_CA=false
TIMEOUT=600
VERBOSE=false

#=====================================================================
# PROVIDER CONFIGURATIONS
#=====================================================================
# Define provider-specific commands
declare -A PROVIDER_COMMANDS
PROVIDER_COMMANDS=(
  ["kubeadm"]="kubeadm certs renew all"
  ["k3s"]="systemctl restart k3s"
  ["rke"]="rke cert rotate"
  ["rke2"]="systemctl restart rke2-server"
  ["kops"]="kops update cluster --yes"
  ["minikube"]="minikube start --extra-config=apiserver.enable-admission-plugins=DefaultStorageClass"
  ["kind"]="kind export kubeconfig"
  ["k3d"]="k3d cluster restart"
)

#=====================================================================
# USAGE AND HELP
#=====================================================================
# Function to display usage instructions
usage() {
  print_with_separator "Kubernetes Certificate Rotation Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks and rotates Kubernetes cluster certificates before expiration."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-n, --name <NAME>\033[0m           (Optional) Cluster name"
  echo -e "  \033[1;33m-p, --provider <PROVIDER>\033[0m   (Optional) Provider: kubeadm, k3s, rke, rke2, kops, minikube, kind, k3d, eks, gke, aks"
  echo -e "  \033[1;33m--kubeconfig <PATH>\033[0m         (Optional) Path to kubeconfig file"
  echo -e "  \033[1;33m--warning-days <DAYS>\033[0m       (Optional) Warn about certificates expiring in DAYS (default: ${DAYS_WARNING})"
  echo -e "  \033[1;33m--backup-dir <DIR>\033[0m          (Optional) Directory to back up certificates"
  echo -e "  \033[1;33m--rotate-ca\033[0m                 (Optional) Rotate CA certificates (warning: destructive operation)"
  echo -e "  \033[1;33m--no-restart\033[0m                (Optional) Skip restarting components after rotation"
  echo -e "  \033[1;33m--skip-validation\033[0m           (Optional) Skip validation after rotation"
  echo -e "  \033[1;33m--timeout <SECONDS>\033[0m         (Optional) Timeout for operations (default: ${TIMEOUT}s)"
  echo -e "  \033[1;33m--dry-run\033[0m                   (Optional) Only check expiry and print what would be done"
  echo -e "  \033[1;33m-f, --force\033[0m                 (Optional) Rotate certificates even if not expiring soon"
  echo -e "  \033[1;33m-v, --verbose\033[0m               (Optional) Show more detailed output"
  echo -e "  \033[1;33m--log <FILE>\033[0m                (Optional) Log output to specified file"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --name my-cluster --provider kubeadm"
  echo "  $0 --warning-days 60 --backup-dir /tmp/certs-backup"
  echo "  $0 --dry-run --provider k3s"
  echo "  $0 --kubeconfig ~/.kube/config-prod --force"
  print_with_separator
  exit 1
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
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
  
  # Check for RKE2
  if command_exists rke2 || [ -f "/etc/systemd/system/rke2-server.service" ]; then
    format-echo "INFO" "Detected provider: rke2"
    echo "rke2"
    return 0
  fi
  
  # Check for kops
  if command_exists kops && kops get cluster &>/dev/null; then
    format-echo "INFO" "Detected provider: kops"
    echo "kops"
    return 0
  fi
  
  # Check for minikube
  if command_exists minikube && minikube status &>/dev/null; then
    format-echo "INFO" "Detected provider: minikube"
    echo "minikube"
    return 0
  fi
  
  # Check for kind
  if command_exists kind && kind get clusters &>/dev/null; then
    format-echo "INFO" "Detected provider: kind"
    echo "kind"
    return 0
  fi
  
  # Check for k3d
  if command_exists k3d && k3d cluster list &>/dev/null; then
    format-echo "INFO" "Detected provider: k3d"
    echo "k3d"
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
  fi
  
  format-echo "WARNING" "Could not detect provider automatically"
  echo "unknown"
  return 1
}

#=====================================================================
# CERTIFICATE BACKUP
#=====================================================================
# Back up certificates
backup_certificates() {
  local backup_dir="$1"
  local provider="$2"
  
  if [[ -z "$backup_dir" ]]; then
    backup_dir="/tmp/k8s-certs-backup-$(date +%Y%m%d-%H%M%S)"
  fi
  
  format-echo "INFO" "Backing up certificates to $backup_dir"
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would back up certificates to $backup_dir"
    return 0
  fi
  
  mkdir -p "$backup_dir"
  
  case "$provider" in
    kubeadm)
      # Backup kubeadm certificates
      if [[ -d "/etc/kubernetes/pki" ]]; then
        cp -r /etc/kubernetes/pki "$backup_dir/"
        cp /etc/kubernetes/admin.conf "$backup_dir/" 2>/dev/null || true
        cp /etc/kubernetes/kubelet.conf "$backup_dir/" 2>/dev/null || true
        cp /etc/kubernetes/controller-manager.conf "$backup_dir/" 2>/dev/null || true
        cp /etc/kubernetes/scheduler.conf "$backup_dir/" 2>/dev/null || true
        format-echo "SUCCESS" "Backed up kubeadm certificates to $backup_dir"
      else
        format-echo "WARNING" "Directory /etc/kubernetes/pki not found, skipping backup"
      fi
      ;;
      
    k3s)
      # Backup k3s certificates
      if [[ -d "/var/lib/rancher/k3s/server/tls" ]]; then
        cp -r /var/lib/rancher/k3s/server/tls "$backup_dir/"
        format-echo "SUCCESS" "Backed up k3s certificates to $backup_dir"
      else
        format-echo "WARNING" "Directory /var/lib/rancher/k3s/server/tls not found, skipping backup"
      fi
      ;;
      
    rke|rke2)
      # Backup RKE/RKE2 certificates
      if [[ -d "/etc/kubernetes/ssl" ]]; then
        cp -r /etc/kubernetes/ssl "$backup_dir/"
        format-echo "SUCCESS" "Backed up RKE certificates to $backup_dir"
      elif [[ -d "/var/lib/rancher/rke2/server/tls" ]]; then
        cp -r /var/lib/rancher/rke2/server/tls "$backup_dir/"
        format-echo "SUCCESS" "Backed up RKE2 certificates to $backup_dir"
      else
        format-echo "WARNING" "Certificate directories not found, skipping backup"
      fi
      ;;
      
    *)
      format-echo "WARNING" "Backup not supported for provider $provider"
      return 1
      ;;
  esac
  
  format-echo "INFO" "Certificates backed up to $backup_dir"
  return 0
}

#=====================================================================
# CERTIFICATE EXPIRATION CHECKING
#=====================================================================
# Check certificate expiration
check_certificate_expiration() {
  local provider="$1"
  local days_warning="$2"
  
  format-echo "INFO" "Checking certificate expiration for provider: $provider"
  
  local has_expiring=false
  local expiry_data=""
  local temp_file
  temp_file=$(mktemp)
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC EXPIRY CHECKS
  #---------------------------------------------------------------------
  case "$provider" in
    kubeadm)
      # Use kubeadm's built-in certificate check
      if command_exists kubeadm; then
        kubeadm certs check-expiration > "$temp_file"
        expiry_data=$(cat "$temp_file")
        
        # Check if any certificates are expiring soon
        if grep -q "CERTIFICATE.*< ${days_warning}d" "$temp_file"; then
          has_expiring=true
          format-echo "WARNING" "Some certificates will expire within $days_warning days:"
          grep -A1 "CERTIFICATE.*< ${days_warning}d" "$temp_file"
        else
          format-echo "SUCCESS" "No certificates will expire within $days_warning days"
        fi
      else
        format-echo "ERROR" "kubeadm not found, cannot check certificate expiration"
        return 1
      fi
      ;;
      
    k3s|rke|rke2)
      # Check using openssl for these providers
      local cert_dirs=()
      
      if [[ "$provider" == "k3s" && -d "/var/lib/rancher/k3s/server/tls" ]]; then
        cert_dirs+=("/var/lib/rancher/k3s/server/tls")
      elif [[ "$provider" == "rke" && -d "/etc/kubernetes/ssl" ]]; then
        cert_dirs+=("/etc/kubernetes/ssl")
      elif [[ "$provider" == "rke2" && -d "/var/lib/rancher/rke2/server/tls" ]]; then
        cert_dirs+=("/var/lib/rancher/rke2/server/tls")
      fi
      
      if [[ ${#cert_dirs[@]} -eq 0 ]]; then
        format-echo "ERROR" "Certificate directories not found for provider $provider"
        return 1
      fi
      
      echo "Certificate Expiration Check:" > "$temp_file"
      echo "---------------------------" >> "$temp_file"
      
      for cert_dir in "${cert_dirs[@]}"; do
        for cert_file in $(find "$cert_dir" -name "*.crt" -o -name "*.pem"); do
          # Skip CA bundle files and non-certificate files
          if ! openssl x509 -in "$cert_file" -noout 2>/dev/null; then
            continue
          fi
          
          local cert_name=$(basename "$cert_file")
          local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
          local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
          local now_epoch=$(date +%s)
          local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
          
          echo "CERTIFICATE $cert_name" >> "$temp_file"
          echo "  Expiration: $expiry_date ($days_left days left)" >> "$temp_file"
          
          if [[ $days_left -lt $days_warning ]]; then
            has_expiring=true
          fi
        done
      done
      
      expiry_data=$(cat "$temp_file")
      
      if [[ "$has_expiring" == true ]]; then
        format-echo "WARNING" "Some certificates will expire within $days_warning days"
        grep -A1 ".*($days_left days left).*" "$temp_file" | grep -B1 ".*([0-9]\{1,2\} days left).*"
      else
        format-echo "SUCCESS" "No certificates will expire within $days_warning days"
      fi
      ;;
      
    minikube|kind|k3d)
      # These providers usually handle certificate rotation automatically
      format-echo "INFO" "Certificate rotation for $provider is typically handled automatically"
      format-echo "INFO" "Checking API server certificate..."
      
      # Get the API server URL
      local api_server
      api_server=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
      
      # Check the API server certificate
      if [[ -n "$api_server" ]]; then
        local host_port
        host_port=$(echo "$api_server" | sed 's|https://||')
        
        echo "Certificate Expiration Check:" > "$temp_file"
        echo "---------------------------" >> "$temp_file"
        
        # Get the certificate from the API server
        if ! echo | openssl s_client -connect "$host_port" -servername "kubernetes" 2>/dev/null | \
             openssl x509 -noout -enddate -subject > /dev/null; then
          format-echo "ERROR" "Could not connect to API server at $host_port"
          return 1
        fi
        
        local cert_info
        cert_info=$(echo | openssl s_client -connect "$host_port" -servername "kubernetes" 2>/dev/null | \
                   openssl x509 -noout -enddate -subject)
        
        local expiry_date
        expiry_date=$(echo "$cert_info" | grep "notAfter=" | cut -d= -f2)
        
        local expiry_epoch
        expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
        
        local now_epoch
        now_epoch=$(date +%s)
        
        local days_left
        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
        
        echo "CERTIFICATE API Server" >> "$temp_file"
        echo "  Expiration: $expiry_date ($days_left days left)" >> "$temp_file"
        
        expiry_data=$(cat "$temp_file")
        
        if [[ $days_left -lt $days_warning ]]; then
          has_expiring=true
          format-echo "WARNING" "API server certificate will expire within $days_warning days"
        else
          format-echo "SUCCESS" "API server certificate will not expire within $days_warning days"
        fi
      else
        format-echo "ERROR" "Could not determine API server URL"
        return 1
      fi
      ;;
      
    eks|gke|aks)
      # Managed Kubernetes providers handle certificate rotation automatically
      format-echo "INFO" "Certificate rotation for $provider is handled by the cloud provider"
      format-echo "INFO" "Checking API server certificate..."
      
      # Get the API server URL
      local api_server
      api_server=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
      
      # Check the API server certificate
      if [[ -n "$api_server" ]]; then
        local host_port
        host_port=$(echo "$api_server" | sed 's|https://||')
        
        echo "Certificate Expiration Check:" > "$temp_file"
        echo "---------------------------" >> "$temp_file"
        
        # Get the certificate from the API server
        if ! echo | openssl s_client -connect "$host_port" -servername "kubernetes" 2>/dev/null | \
             openssl x509 -noout -enddate -subject > /dev/null; then
          format-echo "ERROR" "Could not connect to API server at $host_port"
          return 1
        fi
        
        local cert_info
        cert_info=$(echo | openssl s_client -connect "$host_port" -servername "kubernetes" 2>/dev/null | \
                   openssl x509 -noout -enddate -subject)
        
        local expiry_date
        expiry_date=$(echo "$cert_info" | grep "notAfter=" | cut -d= -f2)
        
        local expiry_epoch
        expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
        
        local now_epoch
        now_epoch=$(date +%s)
        
        local days_left
        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
        
        echo "CERTIFICATE API Server" >> "$temp_file"
        echo "  Expiration: $expiry_date ($days_left days left)" >> "$temp_file"
        
        expiry_data=$(cat "$temp_file")
        
        if [[ $days_left -lt $days_warning ]]; then
          has_expiring=true
          format-echo "WARNING" "API server certificate will expire within $days_warning days"
          format-echo "INFO" "Contact your cloud provider to handle certificate rotation"
        else
          format-echo "SUCCESS" "API server certificate will not expire within $days_warning days"
        fi
      else
        format-echo "ERROR" "Could not determine API server URL"
        return 1
      fi
      ;;
      
    *)
      format-echo "ERROR" "Certificate expiration check not supported for provider $provider"
      return 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # VERBOSE OUTPUT AND CLEANUP
  #---------------------------------------------------------------------
  # If verbose, show all expiry data
  if [[ "$VERBOSE" == true ]]; then
    format-echo "INFO" "Certificate expiration details:"
    echo "$expiry_data"
  fi
  
  rm -f "$temp_file"
  
  # Return status based on expiring certificates
  if [[ "$has_expiring" == true ]]; then
    return 10  # Special return code for expiring certificates
  else
    return 0
  fi
}

#=====================================================================
# CERTIFICATE ROTATION
#=====================================================================
# Rotate certificates
rotate_certificates() {
  local provider="$1"
  local rotate_ca="$2"
  
  format-echo "INFO" "Rotating certificates for provider: $provider"
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would rotate certificates for provider $provider"
    return 0
  fi
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC ROTATION
  #---------------------------------------------------------------------
  case "$provider" in
    kubeadm)
      # Use kubeadm to rotate certificates
      if [[ "$rotate_ca" == true ]]; then
        format-echo "WARNING" "Rotating CA certificates requires manual intervention and may break your cluster"
        format-echo "INFO" "Please refer to Kubernetes documentation for CA rotation"
        return 1
      else
        format-echo "INFO" "Rotating certificates using kubeadm..."
        if kubeadm certs renew all; then
          format-echo "SUCCESS" "Certificates rotated successfully with kubeadm"
          return 0
        else
          format-echo "ERROR" "Failed to rotate certificates with kubeadm"
          return 1
        fi
      fi
      ;;
      
    k3s)
      # K3s requires a restart to rotate certificates
      format-echo "INFO" "K3s requires a restart to rotate certificates"
      
      if [[ "$RESTART_COMPONENTS" != true ]]; then
        format-echo "WARNING" "Certificate rotation for k3s requires component restart, but --no-restart was specified"
        return 1
      fi
      
      format-echo "INFO" "Restarting k3s service..."
      if systemctl restart k3s; then
        format-echo "SUCCESS" "K3s restarted, certificates should be rotated"
        return 0
      else
        format-echo "ERROR" "Failed to restart k3s service"
        return 1
      fi
      ;;
      
    rke)
      # Use RKE to rotate certificates
      if command_exists rke; then
        local rotate_cmd="rke cert rotate"
        
        if [[ "$rotate_ca" == true ]]; then
          rotate_cmd="$rotate_cmd --rotate-ca"
        fi
        
        format-echo "INFO" "Rotating certificates using RKE..."
        if eval "$rotate_cmd"; then
          format-echo "SUCCESS" "Certificates rotated successfully with RKE"
          return 0
        else
          format-echo "ERROR" "Failed to rotate certificates with RKE"
          return 1
        fi
      else
        format-echo "ERROR" "rke command not found"
        return 1
      fi
      ;;
      
    rke2)
      # RKE2 requires a restart to rotate certificates
      format-echo "INFO" "RKE2 requires a restart to rotate certificates"
      
      if [[ "$RESTART_COMPONENTS" != true ]]; then
        format-echo "WARNING" "Certificate rotation for RKE2 requires component restart, but --no-restart was specified"
        return 1
      fi
      
      format-echo "INFO" "Restarting rke2-server service..."
      if systemctl restart rke2-server; then
        format-echo "SUCCESS" "RKE2 server restarted, certificates should be rotated"
        return 0
      else
        format-echo "ERROR" "Failed to restart rke2-server service"
        return 1
      fi
      ;;
      
    kops)
      # Use kops to rotate certificates
      if command_exists kops; then
        format-echo "INFO" "Rotating certificates using kops..."
        
        local cluster_name="$CLUSTER_NAME"
        if [[ -z "$cluster_name" ]]; then
          cluster_name=$(kops get cluster -o name)
          if [[ -z "$cluster_name" ]]; then
            format-echo "ERROR" "Could not determine kops cluster name"
            return 1
          fi
        fi
        
        if kops update cluster "$cluster_name" --yes; then
          format-echo "SUCCESS" "Certificates rotated successfully with kops"
          return 0
        else
          format-echo "ERROR" "Failed to rotate certificates with kops"
          return 1
        fi
      else
        format-echo "ERROR" "kops command not found"
        return 1
      fi
      ;;
      
    minikube)
      # Minikube requires a restart
      if command_exists minikube; then
        format-echo "INFO" "Restarting minikube to rotate certificates..."
        
        local minikube_profile="$CLUSTER_NAME"
        if [[ -z "$minikube_profile" ]]; then
          minikube_profile="minikube"
        fi
        
        if minikube stop -p "$minikube_profile" && \
           minikube start -p "$minikube_profile" --extra-config=apiserver.enable-admission-plugins=DefaultStorageClass; then
          format-echo "SUCCESS" "Minikube restarted, certificates should be rotated"
          return 0
        else
          format-echo "ERROR" "Failed to restart minikube"
          return 1
        fi
      else
        format-echo "ERROR" "minikube command not found"
        return 1
      fi
      ;;
      
    kind)
      # kind uses Docker certs, requires cluster recreation for full rotation
      format-echo "WARNING" "Full certificate rotation for kind requires cluster recreation"
      format-echo "INFO" "Exporting updated kubeconfig..."
      
      local kind_cluster="$CLUSTER_NAME"
      if [[ -z "$kind_cluster" ]]; then
        kind_cluster=$(kind get clusters | head -1)
        if [[ -z "$kind_cluster" ]]; then
          format-echo "ERROR" "Could not determine kind cluster name"
          return 1
        fi
      fi
      
      if kind export kubeconfig --name "$kind_cluster"; then
        format-echo "SUCCESS" "Updated kubeconfig for kind cluster $kind_cluster"
        return 0
      else
        format-echo "ERROR" "Failed to export kubeconfig for kind cluster"
        return 1
      fi
      ;;
      
    k3d)
      # k3d requires a restart
      if command_exists k3d; then
        format-echo "INFO" "Restarting k3d cluster to rotate certificates..."
        
        local k3d_cluster="$CLUSTER_NAME"
        if [[ -z "$k3d_cluster" ]]; then
          k3d_cluster=$(k3d cluster list -o json | jq -r '.[0].name')
          if [[ -z "$k3d_cluster" ]]; then
            format-echo "ERROR" "Could not determine k3d cluster name"
            return 1
          fi
        fi
        
        if k3d cluster restart "$k3d_cluster"; then
          format-echo "SUCCESS" "K3d cluster restarted, certificates should be rotated"
          return 0
        else
          format-echo "ERROR" "Failed to restart k3d cluster"
          return 1
        fi
      else
        format-echo "ERROR" "k3d command not found"
        return 1
      fi
      ;;
      
    eks|gke|aks)
      # Managed Kubernetes providers handle certificate rotation automatically
      format-echo "WARNING" "Certificate rotation for $provider is handled by the cloud provider"
      format-echo "INFO" "No action needed for managed Kubernetes services"
      return 0
      ;;
      
    *)
      format-echo "ERROR" "Certificate rotation not supported for provider $provider"
      return 1
      ;;
  esac
}

#=====================================================================
# COMPONENT MANAGEMENT
#=====================================================================
# Restart Kubernetes components
restart_components() {
  local provider="$1"
  
  if [[ "$RESTART_COMPONENTS" != true ]]; then
    format-echo "INFO" "Skipping component restart as requested"
    return 0
  fi
  
  format-echo "INFO" "Restarting Kubernetes components for provider: $provider"
  
  if [[ "$DRY_RUN" == true ]]; then
    format-echo "DRY-RUN" "Would restart components for provider $provider"
    return 0
  fi
  
  #---------------------------------------------------------------------
  # PROVIDER-SPECIFIC RESTART
  #---------------------------------------------------------------------
  case "$provider" in
    kubeadm)
      # Restart control plane components
      format-echo "INFO" "Restarting kubeadm control plane components..."
      
      local restart_failed=false
      
      # Check if we're on a control plane node
      if [[ -f "/etc/kubernetes/admin.conf" ]]; then
        # Restart kubelet
        if systemctl restart kubelet; then
          format-echo "SUCCESS" "Restarted kubelet"
        else
          format-echo "ERROR" "Failed to restart kubelet"
          restart_failed=true
        fi
        
        # For containerized control plane, we rely on kubelet to restart static pods
        format-echo "INFO" "Kubelet will automatically restart control plane components as static pods"
      else
        format-echo "WARNING" "Not on a control plane node, skipping control plane restart"
      fi
      
      if [[ "$restart_failed" == true ]]; then
        return 1
      fi
      return 0
      ;;
      
    k3s|rke2)
      # Already restarted during certificate rotation
      format-echo "INFO" "Components already restarted during certificate rotation"
      return 0
      ;;
      
    rke)
      # RKE manages its own components
      format-echo "INFO" "RKE manages its own components, no restart needed"
      return 0
      ;;
      
    kops|minikube|kind|k3d)
      # Already handled during certificate rotation
      format-echo "INFO" "Components already restarted during certificate rotation"
      return 0
      ;;
      
    eks|gke|aks)
      # Managed Kubernetes providers handle component management
      format-echo "INFO" "Component management for $provider is handled by the cloud provider"
      return 0
      ;;
      
    *)
      format-echo "WARNING" "Component restart not supported for provider $provider"
      return 0
      ;;
  esac
}

#=====================================================================
# VALIDATION
#=====================================================================
# Validate certificates after rotation
validate_certificates() {
  local provider="$1"
  
  if [[ "$SKIP_VALIDATION" == true ]]; then
    format-echo "INFO" "Skipping validation as requested"
    return 0
  fi
  
  format-echo "INFO" "Validating certificates after rotation for provider: $provider"
  
  #---------------------------------------------------------------------
  # API SERVER CONNECTIVITY CHECK
  #---------------------------------------------------------------------
  # Check API server connectivity
  format-echo "INFO" "Checking API server connectivity..."
  local start_time=$(date +%s)
  local end_time=$((start_time + 60))  # 60 second timeout
  local connected=false
  
  while [[ $(date +%s) -lt $end_time ]]; do
    if kubectl get nodes &>/dev/null; then
      connected=true
      break
    fi
    format-echo "INFO" "Waiting for API server to become available..."
    sleep 5
  done
  
  if [[ "$connected" != true ]]; then
    format-echo "ERROR" "API server is not responding after certificate rotation"
    return 1
  fi
  
  format-echo "SUCCESS" "API server is responding"
  
  #---------------------------------------------------------------------
  # COMPONENT STATUS CHECK
  #---------------------------------------------------------------------
  # Check component status
  format-echo "INFO" "Checking component status..."
  kubectl get componentstatuses
  
  #---------------------------------------------------------------------
  # CERTIFICATE VERIFICATION
  #---------------------------------------------------------------------
  # Re-check certificate expiration
  format-echo "INFO" "Verifying certificate expiration dates..."
  if ! check_certificate_expiration "$provider" "$DAYS_WARNING"; then
    if [[ $? -eq 10 ]]; then
      format-echo "WARNING" "Some certificates still appear to be expiring soon"
    else
      format-echo "ERROR" "Failed to verify certificate expiration dates"
      return 1
    fi
  fi
  
  format-echo "SUCCESS" "Certificate validation completed successfully"
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
      -n|--name)
        CLUSTER_NAME="$2"
        shift 2
        ;;
      -p|--provider)
        PROVIDER="$2"
        shift 2
        ;;
      --kubeconfig)
        KUBECONFIG_PATH="$2"
        export KUBECONFIG="$KUBECONFIG_PATH"
        shift 2
        ;;
      --warning-days)
        DAYS_WARNING="$2"
        shift 2
        ;;
      --backup-dir)
        BACKUP_DIR="$2"
        shift 2
        ;;
      --rotate-ca)
        ROTATE_CA=true
        shift
        ;;
      --no-restart)
        RESTART_COMPONENTS=false
        shift
        ;;
      --skip-validation)
        SKIP_VALIDATION=true
        shift
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

  print_with_separator "Kubernetes Certificate Rotation Script"
  
  setup_log_file
  
  format-echo "INFO" "Starting certificate rotation process..."
  
  #---------------------------------------------------------------------
  # PROVIDER DETECTION AND CONFIGURATION
  #---------------------------------------------------------------------
  # Auto-detect provider if not specified
  if [[ "$PROVIDER" == "auto" ]]; then
    PROVIDER=$(detect_provider)
    
    if [[ "$PROVIDER" == "unknown" ]]; then
      format-echo "ERROR" "Could not auto-detect provider, please specify with --provider"
      exit 1
    fi
  fi
  
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  Provider:           $PROVIDER"
  
  if [[ -n "$CLUSTER_NAME" ]]; then
    format-echo "INFO" "  Cluster Name:       $CLUSTER_NAME"
  fi
  
  if [[ -n "$KUBECONFIG_PATH" ]]; then
    format-echo "INFO" "  Kubeconfig Path:    $KUBECONFIG_PATH"
  fi
  
  format-echo "INFO" "  Warning Days:       $DAYS_WARNING"
  format-echo "INFO" "  Backup Directory:   ${BACKUP_DIR:-Auto-generated}"
  format-echo "INFO" "  Rotate CA:          $ROTATE_CA"
  format-echo "INFO" "  Restart Components: $RESTART_COMPONENTS"
  format-echo "INFO" "  Skip Validation:    $SKIP_VALIDATION"
  format-echo "INFO" "  Dry Run:            $DRY_RUN"
  format-echo "INFO" "  Force:              $FORCE"
  
  #---------------------------------------------------------------------
  # CERTIFICATE EXPIRATION CHECK
  #---------------------------------------------------------------------
  # Check if certificates need rotation
  local need_rotation=false
  
  format-echo "INFO" "Checking if certificates need rotation..."
  if ! check_certificate_expiration "$PROVIDER" "$DAYS_WARNING"; then
    exit_code=$?
    
    if [[ $exit_code -eq 10 ]]; then
      need_rotation=true
      format-echo "WARNING" "Certificates are expiring soon, rotation needed"
    else
      format-echo "ERROR" "Failed to check certificate expiration"
      exit 1
    fi
  elif [[ "$FORCE" == true ]]; then
    need_rotation=true
    format-echo "INFO" "Forcing certificate rotation as requested"
  else
    format-echo "SUCCESS" "Certificates are not expiring soon, rotation not needed"
    
    if [[ "$FORCE" != true ]]; then
      format-echo "INFO" "Use --force to rotate certificates anyway"
      exit 0
    fi
  fi
  
  #---------------------------------------------------------------------
  # CERTIFICATE ROTATION PROCESS
  #---------------------------------------------------------------------
  # If certificates need rotation and we're not in dry-run mode
  if [[ "$need_rotation" == true || "$FORCE" == true ]]; then
    # Confirm rotation if not forced
    if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
      format-echo "WARNING" "You are about to rotate certificates for your Kubernetes cluster"
      format-echo "WARNING" "This may cause temporary disruption to cluster operations"
      read -p "Do you want to continue? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        exit 0
      fi
    fi
    
    # Backup certificates
    if [[ "$DRY_RUN" != true ]]; then
      backup_certificates "$BACKUP_DIR" "$PROVIDER"
    else
      format-echo "DRY-RUN" "Would back up certificates to ${BACKUP_DIR:-auto-generated directory}"
    fi
    
    # Rotate certificates
    if ! rotate_certificates "$PROVIDER" "$ROTATE_CA"; then
      format-echo "ERROR" "Certificate rotation failed"
      exit 1
    fi
    
    # Restart components if needed
    if ! restart_components "$PROVIDER"; then
      format-echo "ERROR" "Component restart failed"
      exit 1
    fi
    
    # Validate certificates
    if ! validate_certificates "$PROVIDER"; then
      format-echo "ERROR" "Certificate validation failed"
      exit 1
    fi
    
    format-echo "SUCCESS" "Certificate rotation completed successfully"
  fi
  
  print_with_separator "End of Kubernetes Certificate Rotation"
  
  #---------------------------------------------------------------------
  # SUMMARY AND NEXT STEPS
  #---------------------------------------------------------------------
  # Final summary
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "Dry run completed for \033[1;32m$PROVIDER\033[0m provider."
    if [[ "$need_rotation" == true ]]; then
      echo -e "\033[1;33mCertificates need rotation.\033[0m"
    else
      echo -e "\033[1;32mCertificates do not need rotation.\033[0m"
    fi
  else
    if [[ "$need_rotation" == true || "$FORCE" == true ]]; then
      echo -e "Certificate rotation \033[1;32msuccessful\033[0m for \033[1;32m$PROVIDER\033[0m provider."
      if [[ -n "$BACKUP_DIR" ]]; then
        echo -e "Certificates backed up to: \033[1;32m$BACKUP_DIR\033[0m"
      fi
    else
      echo -e "Certificate rotation \033[1;33mskipped\033[0m for \033[1;32m$PROVIDER\033[0m provider."
      echo -e "Certificates are not expiring within \033[1;32m$DAYS_WARNING\033[0m days."
    fi
  fi
  
  # Remind about next steps
  echo -e "\nTo verify cluster health:"
  echo -e "  \033[1mkubectl get nodes\033[0m"
  echo -e "  \033[1mkubectl get componentstatuses\033[0m"
}

# Run the main function
main "$@"
