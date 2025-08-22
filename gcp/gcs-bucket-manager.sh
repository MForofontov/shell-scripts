#!/usr/bin/env bash
# gcs-bucket-manager.sh
# Script to manage Google Cloud Storage buckets - create, delete, configure, and monitor buckets.

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
BUCKET_NAME=""
LOCATION="us-central1"
STORAGE_CLASS="STANDARD"
ACTION=""
LIFECYCLE_CONFIG=""
CORS_CONFIG=""
LABELS=""
VERSIONING=false
UNIFORM_ACCESS=false
PUBLIC_READ=false
RETENTION_PERIOD=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCS Bucket Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Storage buckets - create, delete, configure, and monitor."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate\033[0m         Create a new bucket"
  echo -e "  \033[1;33mdelete\033[0m         Delete an existing bucket"
  echo -e "  \033[1;33mlist\033[0m           List all buckets in project"
  echo -e "  \033[1;33minfo\033[0m           Show detailed bucket information"
  echo -e "  \033[1;33mconfigure\033[0m      Configure bucket settings"
  echo -e "  \033[1;33mversioning\033[0m     Enable/disable versioning"
  echo -e "  \033[1;33mlifecycle\033[0m      Configure lifecycle rules"
  echo -e "  \033[1;33mcors\033[0m           Configure CORS settings"
  echo -e "  \033[1;33mcleanup\033[0m        Clean up old versions/incomplete uploads"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--bucket <bucket-name>\033[0m       (Required for most actions) Bucket name"
  echo -e "  \033[1;33m--location <location>\033[0m        (Optional) Bucket location (default: us-central1)"
  echo -e "  \033[1;33m--storage-class <class>\033[0m      (Optional) Storage class (default: STANDARD)"
  echo -e "  \033[1;33m--labels <key=value,...>\033[0m     (Optional) Bucket labels"
  echo -e "  \033[1;33m--lifecycle <config-file>\033[0m    (Optional) Lifecycle configuration JSON file"
  echo -e "  \033[1;33m--cors <config-file>\033[0m         (Optional) CORS configuration JSON file"
  echo -e "  \033[1;33m--versioning\033[0m                 (Optional) Enable versioning"
  echo -e "  \033[1;33m--uniform-access\033[0m             (Optional) Enable uniform bucket-level access"
  echo -e "  \033[1;33m--public-read\033[0m                (Optional) Make bucket publicly readable"
  echo -e "  \033[1;33m--retention <seconds>\033[0m        (Optional) Retention period in seconds"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force deletion without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mStorage Classes:\033[0m"
  echo "  STANDARD, NEARLINE, COLDLINE, ARCHIVE"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list --project my-project"
  echo "  $0 create --project my-project --bucket my-bucket --location us-west1"
  echo "  $0 info --project my-project --bucket my-bucket"
  echo "  $0 configure --project my-project --bucket my-bucket --versioning --uniform-access"
  echo "  $0 delete --project my-project --bucket my-bucket --force"
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
      --bucket)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No bucket name provided after --bucket."
          usage
        fi
        BUCKET_NAME="$2"
        shift 2
        ;;
      --location)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No location provided after --location."
          usage
        fi
        LOCATION="$2"
        shift 2
        ;;
      --storage-class)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No storage class provided after --storage-class."
          usage
        fi
        STORAGE_CLASS="$2"
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
      --lifecycle)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No lifecycle config file provided after --lifecycle."
          usage
        fi
        LIFECYCLE_CONFIG="$2"
        shift 2
        ;;
      --cors)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No CORS config file provided after --cors."
          usage
        fi
        CORS_CONFIG="$2"
        shift 2
        ;;
      --retention)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No retention period provided after --retention."
          usage
        fi
        RETENTION_PERIOD="$2"
        shift 2
        ;;
      --versioning)
        VERSIONING=true
        shift
        ;;
      --uniform-access)
        UNIFORM_ACCESS=true
        shift
        ;;
      --public-read)
        PUBLIC_READ=true
        shift
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
  local missing_deps=()
  
  if ! command_exists gsutil; then
    missing_deps+=("gsutil")
  fi
  
  if ! command_exists gcloud; then
    missing_deps+=("gcloud")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    format-echo "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    format-echo "INFO" "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  
  return 0
}

# Function to validate bucket name
validate_bucket_name() {
  local bucket="$1"
  
  # Basic validation
  if [[ ${#bucket} -lt 3 || ${#bucket} -gt 63 ]]; then
    format-echo "ERROR" "Bucket name must be 3-63 characters long"
    return 1
  fi
  
  if [[ ! "$bucket" =~ ^[a-z0-9][a-z0-9._-]*[a-z0-9]$ ]]; then
    format-echo "ERROR" "Invalid bucket name format"
    return 1
  fi
  
  return 0
}

#=====================================================================
# ACTION FUNCTIONS
#=====================================================================
# Function to list buckets
list_buckets() {
  local project="$1"
  
  format-echo "INFO" "Listing buckets in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list buckets in project: $project"
    return 0
  fi
  
  if ! gsutil ls -p "$project" -L; then
    format-echo "ERROR" "Failed to list buckets"
    return 1
  fi
  
  return 0
}

# Function to show bucket information
show_bucket_info() {
  local bucket="$1"
  
  format-echo "INFO" "Getting information for bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would show info for bucket: $bucket"
    return 0
  fi
  
  if ! gsutil ls -L -b "gs://$bucket"; then
    format-echo "ERROR" "Failed to get bucket information"
    return 1
  fi
  
  if [ "$VERBOSE" = true ]; then
    echo
    format-echo "INFO" "Bucket Contents Summary:"
    if ! gsutil du -s "gs://$bucket"; then
      format-echo "WARNING" "Could not get bucket size"
    fi
  fi
  
  return 0
}

# Function to create bucket
create_bucket() {
  local project="$1"
  local bucket="$2"
  local location="$3"
  local storage_class="$4"
  
  format-echo "INFO" "Creating bucket: $bucket"
  
  if ! validate_bucket_name "$bucket"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create bucket:"
    format-echo "INFO" "  Name: $bucket"
    format-echo "INFO" "  Project: $project"
    format-echo "INFO" "  Location: $location"
    format-echo "INFO" "  Storage Class: $storage_class"
    [ -n "$LABELS" ] && format-echo "INFO" "  Labels: $LABELS"
    return 0
  fi
  
  # Create bucket
  local create_cmd="gsutil mb -p $project -c $storage_class -l $location"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd gs://$bucket"
  fi
  
  if ! $create_cmd "gs://$bucket"; then
    format-echo "ERROR" "Failed to create bucket: $bucket"
    return 1
  fi
  
  format-echo "SUCCESS" "Created bucket: $bucket"
  
  # Configure additional settings
  if [ "$VERSIONING" = true ]; then
    configure_versioning "$bucket" true
  fi
  
  if [ "$UNIFORM_ACCESS" = true ]; then
    configure_uniform_access "$bucket" true
  fi
  
  if [ "$PUBLIC_READ" = true ]; then
    configure_public_access "$bucket"
  fi
  
  if [ -n "$LABELS" ]; then
    configure_labels "$bucket" "$LABELS"
  fi
  
  if [ -n "$LIFECYCLE_CONFIG" ]; then
    configure_lifecycle "$bucket" "$LIFECYCLE_CONFIG"
  fi
  
  if [ -n "$CORS_CONFIG" ]; then
    configure_cors "$bucket" "$CORS_CONFIG"
  fi
  
  if [ -n "$RETENTION_PERIOD" ]; then
    configure_retention "$bucket" "$RETENTION_PERIOD"
  fi
  
  return 0
}

# Function to delete bucket
delete_bucket() {
  local bucket="$1"
  
  # Confirmation unless forced
  if [ "$FORCE" = false ]; then
    echo
    format-echo "WARNING" "This will permanently delete bucket: $bucket"
    format-echo "WARNING" "All data in the bucket will be lost!"
    echo
    read -p "Are you sure you want to delete this bucket? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      format-echo "INFO" "Bucket deletion cancelled"
      return 0
    fi
  fi
  
  format-echo "INFO" "Deleting bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete bucket: $bucket"
    return 0
  fi
  
  # Remove all objects first
  if ! gsutil -m rm -r "gs://$bucket/*" 2>/dev/null; then
    format-echo "INFO" "No objects to delete or bucket already empty"
  fi
  
  # Remove the bucket
  if ! gsutil rb "gs://$bucket"; then
    format-echo "ERROR" "Failed to delete bucket: $bucket"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted bucket: $bucket"
  return 0
}

# Function to configure versioning
configure_versioning() {
  local bucket="$1"
  local enable="$2"
  
  format-echo "INFO" "Configuring versioning for bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would ${enable:+enable}${enable:+disable} versioning"
    return 0
  fi
  
  if [ "$enable" = true ]; then
    if ! gsutil versioning set on "gs://$bucket"; then
      format-echo "ERROR" "Failed to enable versioning"
      return 1
    fi
    format-echo "SUCCESS" "Enabled versioning for bucket: $bucket"
  else
    if ! gsutil versioning set off "gs://$bucket"; then
      format-echo "ERROR" "Failed to disable versioning"
      return 1
    fi
    format-echo "SUCCESS" "Disabled versioning for bucket: $bucket"
  fi
  
  return 0
}

# Function to configure uniform bucket-level access
configure_uniform_access() {
  local bucket="$1"
  local enable="$2"
  
  format-echo "INFO" "Configuring uniform access for bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would ${enable:+enable}${enable:+disable} uniform access"
    return 0
  fi
  
  if [ "$enable" = true ]; then
    if ! gsutil uniformbucketlevelaccess set on "gs://$bucket"; then
      format-echo "ERROR" "Failed to enable uniform access"
      return 1
    fi
    format-echo "SUCCESS" "Enabled uniform access for bucket: $bucket"
  else
    if ! gsutil uniformbucketlevelaccess set off "gs://$bucket"; then
      format-echo "ERROR" "Failed to disable uniform access"
      return 1
    fi
    format-echo "SUCCESS" "Disabled uniform access for bucket: $bucket"
  fi
  
  return 0
}

# Function to configure public read access
configure_public_access() {
  local bucket="$1"
  
  format-echo "INFO" "Configuring public read access for bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would enable public read access"
    return 0
  fi
  
  if ! gsutil iam ch allUsers:objectViewer "gs://$bucket"; then
    format-echo "ERROR" "Failed to configure public access"
    return 1
  fi
  
  format-echo "SUCCESS" "Enabled public read access for bucket: $bucket"
  return 0
}

# Function to configure labels
configure_labels() {
  local bucket="$1"
  local labels="$2"
  
  format-echo "INFO" "Configuring labels for bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set labels: $labels"
    return 0
  fi
  
  if ! gsutil label set <(echo "{\"labels\":{$(echo "$labels" | sed 's/=/":"/g; s/,/","/g; s/^/"/; s/$/"/; s/":"/":/g')}}") "gs://$bucket"; then
    format-echo "ERROR" "Failed to set labels"
    return 1
  fi
  
  format-echo "SUCCESS" "Set labels for bucket: $bucket"
  return 0
}

# Function to configure lifecycle
configure_lifecycle() {
  local bucket="$1"
  local config_file="$2"
  
  format-echo "INFO" "Configuring lifecycle for bucket: $bucket"
  
  if [ ! -f "$config_file" ]; then
    format-echo "ERROR" "Lifecycle config file not found: $config_file"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set lifecycle config from: $config_file"
    return 0
  fi
  
  if ! gsutil lifecycle set "$config_file" "gs://$bucket"; then
    format-echo "ERROR" "Failed to set lifecycle configuration"
    return 1
  fi
  
  format-echo "SUCCESS" "Set lifecycle configuration for bucket: $bucket"
  return 0
}

# Function to configure CORS
configure_cors() {
  local bucket="$1"
  local config_file="$2"
  
  format-echo "INFO" "Configuring CORS for bucket: $bucket"
  
  if [ ! -f "$config_file" ]; then
    format-echo "ERROR" "CORS config file not found: $config_file"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set CORS config from: $config_file"
    return 0
  fi
  
  if ! gsutil cors set "$config_file" "gs://$bucket"; then
    format-echo "ERROR" "Failed to set CORS configuration"
    return 1
  fi
  
  format-echo "SUCCESS" "Set CORS configuration for bucket: $bucket"
  return 0
}

# Function to configure retention policy
configure_retention() {
  local bucket="$1"
  local period="$2"
  
  format-echo "INFO" "Configuring retention policy for bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set retention period: $period seconds"
    return 0
  fi
  
  if ! gsutil retention set "${period}s" "gs://$bucket"; then
    format-echo "ERROR" "Failed to set retention policy"
    return 1
  fi
  
  format-echo "SUCCESS" "Set retention policy for bucket: $bucket"
  return 0
}

# Function to cleanup old versions and incomplete uploads
cleanup_bucket() {
  local bucket="$1"
  
  format-echo "INFO" "Cleaning up bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would clean up old versions and incomplete uploads"
    return 0
  fi
  
  # Clean up incomplete multipart uploads
  format-echo "INFO" "Removing incomplete multipart uploads..."
  if ! gsutil -m rm "gs://$bucket/**" 2>/dev/null; then
    format-echo "INFO" "No incomplete uploads found"
  fi
  
  # Clean up old object versions (if versioning is enabled)
  format-echo "INFO" "Checking for old versions..."
  if gsutil ls -a "gs://$bucket/**" | grep -q "#"; then
    format-echo "INFO" "Removing old object versions..."
    if ! gsutil -m rm "gs://$bucket/**" 2>/dev/null; then
      format-echo "WARNING" "Some old versions could not be removed"
    fi
  else
    format-echo "INFO" "No old versions found"
  fi
  
  format-echo "SUCCESS" "Bucket cleanup completed"
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
  
  print_with_separator "GCS Bucket Manager Script"
  format-echo "INFO" "Starting GCS Bucket Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCS Bucket Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCS Bucket Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create|delete|info|configure|versioning|lifecycle|cors|cleanup)
      if [ -z "$BUCKET_NAME" ]; then
        format-echo "ERROR" "Bucket name is required for action: $ACTION"
        print_with_separator "End of GCS Bucket Manager Script"
        exit 1
      fi
      ;;
    list)
      # No bucket name required for list
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create, delete, list, info, configure, versioning, lifecycle, cors, cleanup"
      print_with_separator "End of GCS Bucket Manager Script"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    list)
      if list_buckets "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed buckets successfully"
      else
        format-echo "ERROR" "Failed to list buckets"
        exit 1
      fi
      ;;
    info)
      if show_bucket_info "$BUCKET_NAME"; then
        format-echo "SUCCESS" "Retrieved bucket information successfully"
      else
        format-echo "ERROR" "Failed to get bucket information"
        exit 1
      fi
      ;;
    create)
      if create_bucket "$PROJECT_ID" "$BUCKET_NAME" "$LOCATION" "$STORAGE_CLASS"; then
        format-echo "SUCCESS" "Bucket management completed successfully"
      else
        format-echo "ERROR" "Failed to create bucket"
        exit 1
      fi
      ;;
    delete)
      if delete_bucket "$BUCKET_NAME"; then
        format-echo "SUCCESS" "Bucket management completed successfully"
      else
        format-echo "ERROR" "Failed to delete bucket"
        exit 1
      fi
      ;;
    configure)
      format-echo "INFO" "Configuring bucket settings..."
      success=true
      
      if [ "$VERSIONING" = true ] && ! configure_versioning "$BUCKET_NAME" true; then
        success=false
      fi
      
      if [ "$UNIFORM_ACCESS" = true ] && ! configure_uniform_access "$BUCKET_NAME" true; then
        success=false
      fi
      
      if [ "$PUBLIC_READ" = true ] && ! configure_public_access "$BUCKET_NAME"; then
        success=false
      fi
      
      if [ -n "$LABELS" ] && ! configure_labels "$BUCKET_NAME" "$LABELS"; then
        success=false
      fi
      
      if [ -n "$LIFECYCLE_CONFIG" ] && ! configure_lifecycle "$BUCKET_NAME" "$LIFECYCLE_CONFIG"; then
        success=false
      fi
      
      if [ -n "$CORS_CONFIG" ] && ! configure_cors "$BUCKET_NAME" "$CORS_CONFIG"; then
        success=false
      fi
      
      if [ -n "$RETENTION_PERIOD" ] && ! configure_retention "$BUCKET_NAME" "$RETENTION_PERIOD"; then
        success=false
      fi
      
      if [ "$success" = true ]; then
        format-echo "SUCCESS" "Bucket configuration completed successfully"
      else
        format-echo "ERROR" "Some bucket configurations failed"
        exit 1
      fi
      ;;
    versioning)
      if configure_versioning "$BUCKET_NAME" "$VERSIONING"; then
        format-echo "SUCCESS" "Versioning configuration completed successfully"
      else
        format-echo "ERROR" "Failed to configure versioning"
        exit 1
      fi
      ;;
    lifecycle)
      if [ -z "$LIFECYCLE_CONFIG" ]; then
        format-echo "ERROR" "Lifecycle config file is required. Use --lifecycle"
        exit 1
      fi
      if configure_lifecycle "$BUCKET_NAME" "$LIFECYCLE_CONFIG"; then
        format-echo "SUCCESS" "Lifecycle configuration completed successfully"
      else
        format-echo "ERROR" "Failed to configure lifecycle"
        exit 1
      fi
      ;;
    cors)
      if [ -z "$CORS_CONFIG" ]; then
        format-echo "ERROR" "CORS config file is required. Use --cors"
        exit 1
      fi
      if configure_cors "$BUCKET_NAME" "$CORS_CONFIG"; then
        format-echo "SUCCESS" "CORS configuration completed successfully"
      else
        format-echo "ERROR" "Failed to configure CORS"
        exit 1
      fi
      ;;
    cleanup)
      if cleanup_bucket "$BUCKET_NAME"; then
        format-echo "SUCCESS" "Bucket cleanup completed successfully"
      else
        format-echo "ERROR" "Failed to cleanup bucket"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCS Bucket Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
