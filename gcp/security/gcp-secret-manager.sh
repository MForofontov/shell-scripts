#!/usr/bin/env bash
# gcp-secret-manager.sh
# Script to manage GCP Secret Manager secrets and versions.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
PROJECT_ID=""
SECRET_NAME=""
SECRET_VALUE=""
SECRET_FILE=""
VERSION_ID=""
LABELS=""
REPLICATION_POLICY="automatic"
LOCATIONS=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Secret Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Secret Manager secrets and versions."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-secret\033[0m     Create a new secret"
  echo -e "  \033[1;33mdelete-secret\033[0m     Delete a secret"
  echo -e "  \033[1;33madd-version\033[0m       Add a new version to an existing secret"
  echo -e "  \033[1;33mget-secret\033[0m        Get the latest secret value"
  echo -e "  \033[1;33mget-version\033[0m       Get a specific secret version"
  echo -e "  \033[1;33mlist-secrets\033[0m      List all secrets"
  echo -e "  \033[1;33mlist-versions\033[0m     List all versions of a secret"
  echo -e "  \033[1;33mdestroy-version\033[0m   Destroy a specific secret version"
  echo -e "  \033[1;33mdisable-version\033[0m   Disable a specific secret version"
  echo -e "  \033[1;33menable-version\033[0m    Enable a specific secret version"
  echo -e "  \033[1;33mupdate-secret\033[0m     Update secret metadata"
  echo -e "  \033[1;33mbackup-secrets\033[0m    Export all secrets to files"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--secret <name>\033[0m              (Required for most actions) Secret name"
  echo -e "  \033[1;33m--value <value>\033[0m              (Optional) Secret value (use with --file for file input)"
  echo -e "  \033[1;33m--file <path>\033[0m                (Optional) Read secret value from file"
  echo -e "  \033[1;33m--version <id>\033[0m               (Optional) Version ID (default: latest)"
  echo -e "  \033[1;33m--labels <key=value>\033[0m         (Optional) Labels in key=value format (comma-separated)"
  echo -e "  \033[1;33m--replication <policy>\033[0m       (Optional) Replication policy: automatic, user-managed (default: automatic)"
  echo -e "  \033[1;33m--locations <regions>\033[0m        (Optional) Locations for user-managed replication (comma-separated)"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-secrets --project my-project"
  echo "  $0 create-secret --project my-project --secret my-secret --value 'secret-value'"
  echo "  $0 create-secret --project my-project --secret my-secret --file /path/to/secret.txt"
  echo "  $0 add-version --project my-project --secret my-secret --value 'new-value'"
  echo "  $0 get-secret --project my-project --secret my-secret"
  echo "  $0 get-version --project my-project --secret my-secret --version 2"
  echo "  $0 update-secret --project my-project --secret my-secret --labels env=prod,team=backend"
  echo "  $0 backup-secrets --project my-project"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  if [[ "$#" -eq 0 ]]; then
    usage
  fi
  
  ACTION="$1"
  shift
  
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --project)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No project ID provided after --project."
          usage
        fi
        PROJECT_ID="$2"
        shift 2
        ;;
      --secret)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No secret name provided after --secret."
          usage
        fi
        SECRET_NAME="$2"
        shift 2
        ;;
      --value)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No secret value provided after --value."
          usage
        fi
        SECRET_VALUE="$2"
        shift 2
        ;;
      --file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No file path provided after --file."
          usage
        fi
        SECRET_FILE="$2"
        shift 2
        ;;
      --version)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No version ID provided after --version."
          usage
        fi
        VERSION_ID="$2"
        shift 2
        ;;
      --labels)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No labels provided after --labels."
          usage
        fi
        LABELS="$2"
        shift 2
        ;;
      --replication)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No replication policy provided after --replication."
          usage
        fi
        REPLICATION_POLICY="$2"
        shift 2
        ;;
      --locations)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No locations provided after --locations."
          usage
        fi
        LOCATIONS="$2"
        shift 2
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Function to check dependencies
check_dependencies() {
  if ! command_exists gcloud; then
    format-echo "ERROR" "gcloud CLI is required but not installed."
    format-echo "INFO" "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  return 0
}

# Function to validate authentication
validate_auth() {
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    format-echo "ERROR" "No active GCP authentication found."
    format-echo "INFO" "Please run: gcloud auth login"
    return 1
  fi
  return 0
}

# Function to get secret value from file or parameter
get_secret_value() {
  if [ -n "$SECRET_FILE" ]; then
    if [ ! -f "$SECRET_FILE" ]; then
      format-echo "ERROR" "Secret file not found: $SECRET_FILE"
      return 1
    fi
    SECRET_VALUE="$(cat "$SECRET_FILE")"
  fi
  
  if [ -z "$SECRET_VALUE" ]; then
    format-echo "ERROR" "No secret value provided. Use --value or --file"
    return 1
  fi
  
  return 0
}

#=====================================================================
# SECRET MANAGEMENT FUNCTIONS
#=====================================================================
# Function to create secret
create_secret() {
  local project="$1"
  local secret="$2"
  
  format-echo "INFO" "Creating secret: $secret"
  
  if ! get_secret_value; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create secret:"
    format-echo "INFO" "  Name: $secret"
    format-echo "INFO" "  Replication: $REPLICATION_POLICY"
    [ -n "$LABELS" ] && format-echo "INFO" "  Labels: $LABELS"
    [ -n "$LOCATIONS" ] && format-echo "INFO" "  Locations: $LOCATIONS"
    return 0
  fi
  
  # Build create command
  local create_cmd="gcloud secrets create $secret --project=$project"
  
  # Add replication policy
  if [ "$REPLICATION_POLICY" = "automatic" ]; then
    create_cmd+=" --replication-policy=automatic"
  elif [ "$REPLICATION_POLICY" = "user-managed" ]; then
    if [ -z "$LOCATIONS" ]; then
      format-echo "ERROR" "Locations are required for user-managed replication"
      return 1
    fi
    create_cmd+=" --replication-policy=user-managed --locations=$LOCATIONS"
  fi
  
  # Add labels if provided
  if [ -n "$LABELS" ]; then
    create_cmd+=" --labels=$LABELS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  # Create the secret
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create secret: $secret"
    return 1
  fi
  
  # Add initial version
  if ! echo "$SECRET_VALUE" | gcloud secrets versions add "$secret" \
    --project="$project" \
    --data-file=-; then
    format-echo "ERROR" "Failed to add initial version to secret: $secret"
    return 1
  fi
  
  format-echo "SUCCESS" "Created secret: $secret with initial version"
  return 0
}

# Function to delete secret
delete_secret() {
  local project="$1"
  local secret="$2"
  
  # Confirmation unless forced
  if [ "$FORCE" = false ]; then
    echo
    format-echo "WARNING" "This will permanently delete secret: $secret"
    format-echo "WARNING" "All versions of this secret will be lost!"
    echo
    read -p "Are you sure you want to delete this secret? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      format-echo "INFO" "Secret deletion cancelled"
      return 0
    fi
  fi
  
  format-echo "INFO" "Deleting secret: $secret"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete secret: $secret"
    return 0
  fi
  
  if ! gcloud secrets delete "$secret" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete secret: $secret"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted secret: $secret"
  return 0
}

# Function to add version
add_version() {
  local project="$1"
  local secret="$2"
  
  format-echo "INFO" "Adding new version to secret: $secret"
  
  if ! get_secret_value; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would add new version to secret: $secret"
    return 0
  fi
  
  if ! echo "$SECRET_VALUE" | gcloud secrets versions add "$secret" \
    --project="$project" \
    --data-file=-; then
    format-echo "ERROR" "Failed to add version to secret: $secret"
    return 1
  fi
  
  format-echo "SUCCESS" "Added new version to secret: $secret"
  return 0
}

# Function to get secret value
get_secret() {
  local project="$1"
  local secret="$2"
  local version="${3:-latest}"
  
  format-echo "INFO" "Getting secret value: $secret (version: $version)"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get secret: $secret"
    return 0
  fi
  
  if ! gcloud secrets versions access "$version" \
    --secret="$secret" \
    --project="$project"; then
    format-echo "ERROR" "Failed to get secret: $secret"
    return 1
  fi
  
  return 0
}

# Function to list secrets
list_secrets() {
  local project="$1"
  
  format-echo "INFO" "Listing secrets in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list secrets"
    return 0
  fi
  
  if ! gcloud secrets list \
    --project="$project" \
    --format="table(name,createTime,replication.automatic:label=AUTO_REPLICATION,replication.userManaged.replicas.location:label=LOCATIONS)"; then
    format-echo "ERROR" "Failed to list secrets"
    return 1
  fi
  
  return 0
}

# Function to list versions
list_versions() {
  local project="$1"
  local secret="$2"
  
  format-echo "INFO" "Listing versions for secret: $secret"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list versions for secret: $secret"
    return 0
  fi
  
  if ! gcloud secrets versions list "$secret" \
    --project="$project" \
    --format="table(name,state,createTime,destroyTime)"; then
    format-echo "ERROR" "Failed to list versions for secret: $secret"
    return 1
  fi
  
  return 0
}

# Function to destroy version
destroy_version() {
  local project="$1"
  local secret="$2"
  local version="$3"
  
  format-echo "INFO" "Destroying version $version of secret: $secret"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would destroy version $version of secret: $secret"
    return 0
  fi
  
  if ! gcloud secrets versions destroy "$version" \
    --secret="$secret" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to destroy version $version of secret: $secret"
    return 1
  fi
  
  format-echo "SUCCESS" "Destroyed version $version of secret: $secret"
  return 0
}

# Function to disable version
disable_version() {
  local project="$1"
  local secret="$2"
  local version="$3"
  
  format-echo "INFO" "Disabling version $version of secret: $secret"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would disable version $version of secret: $secret"
    return 0
  fi
  
  if ! gcloud secrets versions disable "$version" \
    --secret="$secret" \
    --project="$project"; then
    format-echo "ERROR" "Failed to disable version $version of secret: $secret"
    return 1
  fi
  
  format-echo "SUCCESS" "Disabled version $version of secret: $secret"
  return 0
}

# Function to enable version
enable_version() {
  local project="$1"
  local secret="$2"
  local version="$3"
  
  format-echo "INFO" "Enabling version $version of secret: $secret"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would enable version $version of secret: $secret"
    return 0
  fi
  
  if ! gcloud secrets versions enable "$version" \
    --secret="$secret" \
    --project="$project"; then
    format-echo "ERROR" "Failed to enable version $version of secret: $secret"
    return 1
  fi
  
  format-echo "SUCCESS" "Enabled version $version of secret: $secret"
  return 0
}

# Function to update secret metadata
update_secret() {
  local project="$1"
  local secret="$2"
  
  format-echo "INFO" "Updating secret metadata: $secret"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would update secret: $secret"
    [ -n "$LABELS" ] && format-echo "INFO" "  Labels: $LABELS"
    return 0
  fi
  
  local update_cmd="gcloud secrets update $secret --project=$project"
  
  if [ -n "$LABELS" ]; then
    update_cmd+=" --update-labels=$LABELS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $update_cmd"
  fi
  
  if ! eval "$update_cmd"; then
    format-echo "ERROR" "Failed to update secret: $secret"
    return 1
  fi
  
  format-echo "SUCCESS" "Updated secret: $secret"
  return 0
}

# Function to backup secrets
backup_secrets() {
  local project="$1"
  local backup_dir="./secrets-backup-$(date +%Y%m%d-%H%M%S)"
  
  format-echo "INFO" "Backing up all secrets from project: $project"
  format-echo "INFO" "Backup directory: $backup_dir"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would backup secrets to: $backup_dir"
    return 0
  fi
  
  # Create backup directory
  if ! mkdir -p "$backup_dir"; then
    format-echo "ERROR" "Failed to create backup directory: $backup_dir"
    return 1
  fi
  
  # Get list of secrets
  local secrets
  if ! secrets=$(gcloud secrets list --project="$project" --format="value(name)" 2>/dev/null); then
    format-echo "ERROR" "Failed to list secrets for backup"
    return 1
  fi
  
  if [ -z "$secrets" ]; then
    format-echo "INFO" "No secrets found to backup"
    return 0
  fi
  
  local count=0
  # Backup each secret
  while IFS= read -r secret; do
    if [ -n "$secret" ]; then
      local secret_name
      secret_name=$(basename "$secret")
      format-echo "INFO" "Backing up secret: $secret_name"
      
      if gcloud secrets versions access latest \
        --secret="$secret_name" \
        --project="$project" \
        > "$backup_dir/$secret_name.txt" 2>/dev/null; then
        ((count++))
        [ "$VERBOSE" = true ] && format-echo "SUCCESS" "Backed up: $secret_name"
      else
        format-echo "WARNING" "Failed to backup secret: $secret_name"
      fi
    fi
  done <<< "$secrets"
  
  format-echo "SUCCESS" "Backed up $count secrets to: $backup_dir"
  return 0
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"
  
  setup_log_file
  
  print_with_separator "GCP Secret Manager Script"
  format-echo "INFO" "Starting GCP Secret Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Secret Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Secret Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Secret Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-secret|delete-secret|add-version|get-secret|list-versions|update-secret)
      if [ -z "$SECRET_NAME" ]; then
        format-echo "ERROR" "Secret name is required for action: $ACTION"
        exit 1
      fi
      ;;
    get-version|destroy-version|disable-version|enable-version)
      if [ -z "$SECRET_NAME" ] || [ -z "$VERSION_ID" ]; then
        format-echo "ERROR" "Secret name and version ID are required for action: $ACTION"
        exit 1
      fi
      ;;
    list-secrets|backup-secrets)
      # No additional requirements for list/backup actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-secret, delete-secret, add-version, get-secret, get-version, list-secrets, list-versions, destroy-version, disable-version, enable-version, update-secret, backup-secrets"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-secret)
      if create_secret "$PROJECT_ID" "$SECRET_NAME"; then
        format-echo "SUCCESS" "Secret creation completed successfully"
      else
        format-echo "ERROR" "Failed to create secret"
        exit 1
      fi
      ;;
    delete-secret)
      if delete_secret "$PROJECT_ID" "$SECRET_NAME"; then
        format-echo "SUCCESS" "Secret deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete secret"
        exit 1
      fi
      ;;
    add-version)
      if add_version "$PROJECT_ID" "$SECRET_NAME"; then
        format-echo "SUCCESS" "Version addition completed successfully"
      else
        format-echo "ERROR" "Failed to add version"
        exit 1
      fi
      ;;
    get-secret)
      if get_secret "$PROJECT_ID" "$SECRET_NAME" "${VERSION_ID:-latest}"; then
        format-echo "SUCCESS" "Retrieved secret successfully" >&2
      else
        format-echo "ERROR" "Failed to get secret"
        exit 1
      fi
      ;;
    get-version)
      if get_secret "$PROJECT_ID" "$SECRET_NAME" "$VERSION_ID"; then
        format-echo "SUCCESS" "Retrieved secret version successfully" >&2
      else
        format-echo "ERROR" "Failed to get secret version"
        exit 1
      fi
      ;;
    list-secrets)
      if list_secrets "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed secrets successfully"
      else
        format-echo "ERROR" "Failed to list secrets"
        exit 1
      fi
      ;;
    list-versions)
      if list_versions "$PROJECT_ID" "$SECRET_NAME"; then
        format-echo "SUCCESS" "Listed versions successfully"
      else
        format-echo "ERROR" "Failed to list versions"
        exit 1
      fi
      ;;
    destroy-version)
      if destroy_version "$PROJECT_ID" "$SECRET_NAME" "$VERSION_ID"; then
        format-echo "SUCCESS" "Version destruction completed successfully"
      else
        format-echo "ERROR" "Failed to destroy version"
        exit 1
      fi
      ;;
    disable-version)
      if disable_version "$PROJECT_ID" "$SECRET_NAME" "$VERSION_ID"; then
        format-echo "SUCCESS" "Version disabling completed successfully"
      else
        format-echo "ERROR" "Failed to disable version"
        exit 1
      fi
      ;;
    enable-version)
      if enable_version "$PROJECT_ID" "$SECRET_NAME" "$VERSION_ID"; then
        format-echo "SUCCESS" "Version enabling completed successfully"
      else
        format-echo "ERROR" "Failed to enable version"
        exit 1
      fi
      ;;
    update-secret)
      if update_secret "$PROJECT_ID" "$SECRET_NAME"; then
        format-echo "SUCCESS" "Secret update completed successfully"
      else
        format-echo "ERROR" "Failed to update secret"
        exit 1
      fi
      ;;
    backup-secrets)
      if backup_secrets "$PROJECT_ID"; then
        format-echo "SUCCESS" "Secrets backup completed successfully"
      else
        format-echo "ERROR" "Failed to backup secrets"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Secret Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
