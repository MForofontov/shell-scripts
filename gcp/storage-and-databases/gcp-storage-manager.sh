#!/usr/bin/env bash
# gcp-storage-manager.sh
# Script to manage GCP Cloud Storage buckets, objects, and lifecycle policies.

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
OBJECT_NAME=""
SOURCE_PATH=""
DESTINATION_PATH=""
STORAGE_CLASS="STANDARD"
LOCATION="us-central1"
UNIFORM_BUCKET_ACCESS=false
VERSIONING=false
LABELS=""
LIFECYCLE_CONFIG=""
CORS_CONFIG=""
PUBLIC_ACCESS=false
RETENTION_PERIOD=""
ENCRYPTION_KEY=""
COPY_SOURCE=""
COPY_DESTINATION=""
ARCHIVE_DAYS="30"
DELETE_DAYS="365"
PREFIX=""
DELIMITER=""
RECURSIVE=false
FORCE_OVERWRITE=false
SIGNED_URL_DURATION="1h"
NOTIFICATION_CONFIG=""
NOTIFICATION_TOPIC=""
NOTIFICATION_PAYLOAD_FORMAT="JSON_API_V1"
NOTIFICATION_EVENT_TYPES=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Storage Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Cloud Storage buckets, objects, and configurations."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-bucket\033[0m            Create a Cloud Storage bucket"
  echo -e "  \033[1;33mdelete-bucket\033[0m            Delete a Cloud Storage bucket"
  echo -e "  \033[1;33mlist-buckets\033[0m             List all buckets"
  echo -e "  \033[1;33mget-bucket\033[0m               Get bucket details"
  echo -e "  \033[1;33mupload-object\033[0m            Upload an object to bucket"
  echo -e "  \033[1;33mdownload-object\033[0m          Download an object from bucket"
  echo -e "  \033[1;33mdelete-object\033[0m            Delete an object from bucket"
  echo -e "  \033[1;33mlist-objects\033[0m             List objects in bucket"
  echo -e "  \033[1;33mcopy-object\033[0m              Copy object within or between buckets"
  echo -e "  \033[1;33mmove-object\033[0m              Move object within or between buckets"
  echo -e "  \033[1;33msync-directories\033[0m         Sync directories with bucket"
  echo -e "  \033[1;33mset-lifecycle\033[0m            Set bucket lifecycle policy"
  echo -e "  \033[1;33mget-lifecycle\033[0m            Get bucket lifecycle policy"
  echo -e "  \033[1;33mset-cors\033[0m                 Set bucket CORS policy"
  echo -e "  \033[1;33mget-cors\033[0m                 Get bucket CORS policy"
  echo -e "  \033[1;33mset-iam-policy\033[0m           Set bucket IAM policy"
  echo -e "  \033[1;33mget-iam-policy\033[0m           Get bucket IAM policy"
  echo -e "  \033[1;33mgenerate-signed-url\033[0m      Generate signed URL for object"
  echo -e "  \033[1;33mset-public-access\033[0m        Make bucket/object publicly accessible"
  echo -e "  \033[1;33mset-retention-policy\033[0m     Set bucket retention policy"
  echo -e "  \033[1;33mcreate-notification\033[0m      Create Pub/Sub notification"
  echo -e "  \033[1;33mdelete-notification\033[0m      Delete Pub/Sub notification"
  echo -e "  \033[1;33mlist-notifications\033[0m       List bucket notifications"
  echo -e "  \033[1;33menable-versioning\033[0m        Enable bucket versioning"
  echo -e "  \033[1;33mdisable-versioning\033[0m       Disable bucket versioning"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--bucket <name>\033[0m                  (Required for bucket actions) Bucket name"
  echo -e "  \033[1;33m--object <name>\033[0m                  (Required for object actions) Object name"
  echo -e "  \033[1;33m--source <path>\033[0m                  (Optional) Source file/directory path"
  echo -e "  \033[1;33m--destination <path>\033[0m             (Optional) Destination path"
  echo -e "  \033[1;33m--storage-class <class>\033[0m          (Optional) Storage class: STANDARD, NEARLINE, COLDLINE, ARCHIVE (default: STANDARD)"
  echo -e "  \033[1;33m--location <location>\033[0m            (Optional) Bucket location (default: us-central1)"
  echo -e "  \033[1;33m--uniform-bucket-access\033[0m          (Optional) Enable uniform bucket-level access"
  echo -e "  \033[1;33m--versioning\033[0m                     (Optional) Enable bucket versioning"
  echo -e "  \033[1;33m--labels <labels>\033[0m                (Optional) Labels (key=value,key2=value2)"
  echo -e "  \033[1;33m--lifecycle-config <file>\033[0m        (Optional) Lifecycle configuration JSON file"
  echo -e "  \033[1;33m--cors-config <file>\033[0m             (Optional) CORS configuration JSON file"
  echo -e "  \033[1;33m--public-access\033[0m                  (Optional) Make publicly accessible"
  echo -e "  \033[1;33m--retention-period <seconds>\033[0m     (Optional) Retention period in seconds"
  echo -e "  \033[1;33m--encryption-key <key>\033[0m           (Optional) Customer-managed encryption key"
  echo -e "  \033[1;33m--copy-source <source>\033[0m           (Optional) Copy source (bucket/object)"
  echo -e "  \033[1;33m--copy-destination <dest>\033[0m        (Optional) Copy destination (bucket/object)"
  echo -e "  \033[1;33m--archive-days <days>\033[0m            (Optional) Days before archiving (default: 30)"
  echo -e "  \033[1;33m--delete-days <days>\033[0m             (Optional) Days before deletion (default: 365)"
  echo -e "  \033[1;33m--prefix <prefix>\033[0m                (Optional) Object name prefix filter"
  echo -e "  \033[1;33m--delimiter <delimiter>\033[0m          (Optional) Object name delimiter"
  echo -e "  \033[1;33m--recursive\033[0m                      (Optional) Recursive operation"
  echo -e "  \033[1;33m--force-overwrite\033[0m                (Optional) Force overwrite existing objects"
  echo -e "  \033[1;33m--signed-url-duration <duration>\033[0m (Optional) Signed URL duration (default: 1h)"
  echo -e "  \033[1;33m--notification-topic <topic>\033[0m     (Optional) Pub/Sub topic for notifications"
  echo -e "  \033[1;33m--notification-format <format>\033[0m   (Optional) Notification payload format (default: JSON_API_V1)"
  echo -e "  \033[1;33m--notification-events <events>\033[0m   (Optional) Comma-separated event types"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-buckets --project my-project"
  echo "  $0 create-bucket --project my-project --bucket my-bucket --location us-east1 --storage-class STANDARD"
  echo "  $0 upload-object --project my-project --bucket my-bucket --source ./file.txt --object data/file.txt"
  echo "  $0 download-object --project my-project --bucket my-bucket --object data/file.txt --destination ./downloaded-file.txt"
  echo "  $0 sync-directories --project my-project --bucket my-bucket --source ./local-dir --recursive"
  echo "  $0 generate-signed-url --project my-project --bucket my-bucket --object data/file.txt --signed-url-duration 2h"
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
      --object)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No object name provided after --object."
          usage
        fi
        OBJECT_NAME="$2"
        shift 2
        ;;
      --source)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source path provided after --source."
          usage
        fi
        SOURCE_PATH="$2"
        shift 2
        ;;
      --destination)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No destination path provided after --destination."
          usage
        fi
        DESTINATION_PATH="$2"
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
      --location)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No location provided after --location."
          usage
        fi
        LOCATION="$2"
        shift 2
        ;;
      --uniform-bucket-access)
        UNIFORM_BUCKET_ACCESS=true
        shift
        ;;
      --versioning)
        VERSIONING=true
        shift
        ;;
      --labels)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No labels provided after --labels."
          usage
        fi
        LABELS="$2"
        shift 2
        ;;
      --lifecycle-config)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No lifecycle config file provided after --lifecycle-config."
          usage
        fi
        LIFECYCLE_CONFIG="$2"
        shift 2
        ;;
      --cors-config)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No CORS config file provided after --cors-config."
          usage
        fi
        CORS_CONFIG="$2"
        shift 2
        ;;
      --public-access)
        PUBLIC_ACCESS=true
        shift
        ;;
      --retention-period)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No retention period provided after --retention-period."
          usage
        fi
        RETENTION_PERIOD="$2"
        shift 2
        ;;
      --encryption-key)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No encryption key provided after --encryption-key."
          usage
        fi
        ENCRYPTION_KEY="$2"
        shift 2
        ;;
      --copy-source)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No copy source provided after --copy-source."
          usage
        fi
        COPY_SOURCE="$2"
        shift 2
        ;;
      --copy-destination)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No copy destination provided after --copy-destination."
          usage
        fi
        COPY_DESTINATION="$2"
        shift 2
        ;;
      --archive-days)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No archive days provided after --archive-days."
          usage
        fi
        ARCHIVE_DAYS="$2"
        shift 2
        ;;
      --delete-days)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No delete days provided after --delete-days."
          usage
        fi
        DELETE_DAYS="$2"
        shift 2
        ;;
      --prefix)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No prefix provided after --prefix."
          usage
        fi
        PREFIX="$2"
        shift 2
        ;;
      --delimiter)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No delimiter provided after --delimiter."
          usage
        fi
        DELIMITER="$2"
        shift 2
        ;;
      --recursive)
        RECURSIVE=true
        shift
        ;;
      --force-overwrite)
        FORCE_OVERWRITE=true
        shift
        ;;
      --signed-url-duration)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No duration provided after --signed-url-duration."
          usage
        fi
        SIGNED_URL_DURATION="$2"
        shift 2
        ;;
      --notification-topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No notification topic provided after --notification-topic."
          usage
        fi
        NOTIFICATION_TOPIC="$2"
        shift 2
        ;;
      --notification-format)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No notification format provided after --notification-format."
          usage
        fi
        NOTIFICATION_PAYLOAD_FORMAT="$2"
        shift 2
        ;;
      --notification-events)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No notification events provided after --notification-events."
          usage
        fi
        NOTIFICATION_EVENT_TYPES="$2"
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
  if ! command_exists gsutil; then
    format-echo "ERROR" "gsutil is required but not installed."
    format-echo "INFO" "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  
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

# Function to validate configuration files
validate_config_files() {
  if [ -n "$LIFECYCLE_CONFIG" ] && [ ! -f "$LIFECYCLE_CONFIG" ]; then
    format-echo "ERROR" "Lifecycle config file not found: $LIFECYCLE_CONFIG"
    return 1
  fi
  
  if [ -n "$CORS_CONFIG" ] && [ ! -f "$CORS_CONFIG" ]; then
    format-echo "ERROR" "CORS config file not found: $CORS_CONFIG"
    return 1
  fi
  
  return 0
}

#=====================================================================
# BUCKET MANAGEMENT
#=====================================================================
# Function to create bucket
create_bucket() {
  local project="$1"
  local bucket="$2"
  
  format-echo "INFO" "Creating Cloud Storage bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create bucket:"
    format-echo "INFO" "  Name: $bucket"
    format-echo "INFO" "  Location: $LOCATION"
    format-echo "INFO" "  Storage class: $STORAGE_CLASS"
    [ "$UNIFORM_BUCKET_ACCESS" = true ] && format-echo "INFO" "  Uniform bucket access: enabled"
    [ "$VERSIONING" = true ] && format-echo "INFO" "  Versioning: enabled"
    return 0
  fi
  
  local create_cmd="gsutil mb"
  create_cmd+=" -p $project"
  create_cmd+=" -c $STORAGE_CLASS"
  create_cmd+=" -l $LOCATION"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd gs://$bucket"
  fi
  
  if ! eval "$create_cmd gs://$bucket"; then
    format-echo "ERROR" "Failed to create bucket: $bucket"
    return 1
  fi
  
  # Set uniform bucket-level access if requested
  if [ "$UNIFORM_BUCKET_ACCESS" = true ]; then
    if ! gsutil uniformbucketlevelaccess set on "gs://$bucket"; then
      format-echo "WARNING" "Failed to enable uniform bucket access"
    else
      format-echo "INFO" "Enabled uniform bucket-level access"
    fi
  fi
  
  # Enable versioning if requested
  if [ "$VERSIONING" = true ]; then
    if ! gsutil versioning set on "gs://$bucket"; then
      format-echo "WARNING" "Failed to enable versioning"
    else
      format-echo "INFO" "Enabled bucket versioning"
    fi
  fi
  
  # Set labels if provided
  if [ -n "$LABELS" ]; then
    if ! gsutil label ch -l "$LABELS" "gs://$bucket"; then
      format-echo "WARNING" "Failed to set bucket labels"
    else
      format-echo "INFO" "Set bucket labels: $LABELS"
    fi
  fi
  
  format-echo "SUCCESS" "Created Cloud Storage bucket: $bucket"
  return 0
}

# Function to delete bucket
delete_bucket() {
  local bucket="$1"
  
  format-echo "INFO" "Deleting Cloud Storage bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete bucket: $bucket"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will delete the bucket '$bucket' and all its contents."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gsutil rm -r "gs://$bucket"; then
    format-echo "ERROR" "Failed to delete bucket: $bucket"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Cloud Storage bucket: $bucket"
  return 0
}

# Function to list buckets
list_buckets() {
  local project="$1"
  
  format-echo "INFO" "Listing Cloud Storage buckets"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list buckets"
    return 0
  fi
  
  if ! gsutil ls -p "$project" -L; then
    format-echo "ERROR" "Failed to list buckets"
    return 1
  fi
  
  return 0
}

# Function to get bucket details
get_bucket() {
  local bucket="$1"
  
  format-echo "INFO" "Getting details for bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get bucket details: $bucket"
    return 0
  fi
  
  if ! gsutil ls -L -b "gs://$bucket"; then
    format-echo "ERROR" "Failed to get bucket details: $bucket"
    return 1
  fi
  
  return 0
}

#=====================================================================
# OBJECT MANAGEMENT
#=====================================================================
# Function to upload object
upload_object() {
  local bucket="$1"
  local source="$2"
  local object="${3:-$(basename "$source")}"
  
  format-echo "INFO" "Uploading object: $object to bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would upload:"
    format-echo "INFO" "  Source: $source"
    format-echo "INFO" "  Destination: gs://$bucket/$object"
    return 0
  fi
  
  if [ ! -f "$source" ] && [ ! -d "$source" ]; then
    format-echo "ERROR" "Source file or directory not found: $source"
    return 1
  fi
  
  local upload_cmd="gsutil"
  
  if [ -d "$source" ] || [ "$RECURSIVE" = true ]; then
    upload_cmd+=" -m cp -r"
  else
    upload_cmd+=" cp"
  fi
  
  if [ -n "$STORAGE_CLASS" ]; then
    upload_cmd+=" -o 'GSUtil:default_storage_class=$STORAGE_CLASS'"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $upload_cmd $source gs://$bucket/$object"
  fi
  
  if ! eval "$upload_cmd \"$source\" \"gs://$bucket/$object\""; then
    format-echo "ERROR" "Failed to upload object: $object"
    return 1
  fi
  
  format-echo "SUCCESS" "Uploaded object: $object to bucket: $bucket"
  return 0
}

# Function to download object
download_object() {
  local bucket="$1"
  local object="$2"
  local destination="${3:-$(basename "$object")}"
  
  format-echo "INFO" "Downloading object: $object from bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would download:"
    format-echo "INFO" "  Source: gs://$bucket/$object"
    format-echo "INFO" "  Destination: $destination"
    return 0
  fi
  
  local download_cmd="gsutil cp"
  
  if [ "$RECURSIVE" = true ]; then
    download_cmd="gsutil -m cp -r"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $download_cmd gs://$bucket/$object $destination"
  fi
  
  if ! eval "$download_cmd \"gs://$bucket/$object\" \"$destination\""; then
    format-echo "ERROR" "Failed to download object: $object"
    return 1
  fi
  
  format-echo "SUCCESS" "Downloaded object: $object to: $destination"
  return 0
}

# Function to delete object
delete_object() {
  local bucket="$1"
  local object="$2"
  
  format-echo "INFO" "Deleting object: $object from bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete object: gs://$bucket/$object"
    return 0
  fi
  
  local delete_cmd="gsutil rm"
  
  if [ "$RECURSIVE" = true ]; then
    delete_cmd="gsutil -m rm -r"
  fi
  
  if ! eval "$delete_cmd \"gs://$bucket/$object\""; then
    format-echo "ERROR" "Failed to delete object: $object"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted object: $object from bucket: $bucket"
  return 0
}

# Function to list objects
list_objects() {
  local bucket="$1"
  
  format-echo "INFO" "Listing objects in bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list objects in bucket: $bucket"
    return 0
  fi
  
  local list_cmd="gsutil ls"
  
  if [ "$RECURSIVE" = true ]; then
    list_cmd+=" -r"
  fi
  
  if [ -n "$PREFIX" ]; then
    list_cmd+=" \"gs://$bucket/$PREFIX*\""
  else
    list_cmd+=" \"gs://$bucket\""
  fi
  
  if [ "$VERBOSE" = true ]; then
    list_cmd+=" -l"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $list_cmd"
  fi
  
  if ! eval "$list_cmd"; then
    format-echo "ERROR" "Failed to list objects in bucket: $bucket"
    return 1
  fi
  
  return 0
}

# Function to copy object
copy_object() {
  local source="$1"
  local destination="$2"
  
  format-echo "INFO" "Copying object from $source to $destination"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would copy:"
    format-echo "INFO" "  Source: $source"
    format-echo "INFO" "  Destination: $destination"
    return 0
  fi
  
  local copy_cmd="gsutil cp"
  
  if [ "$RECURSIVE" = true ]; then
    copy_cmd="gsutil -m cp -r"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $copy_cmd $source $destination"
  fi
  
  if ! eval "$copy_cmd \"$source\" \"$destination\""; then
    format-echo "ERROR" "Failed to copy object"
    return 1
  fi
  
  format-echo "SUCCESS" "Copied object from $source to $destination"
  return 0
}

# Function to sync directories
sync_directories() {
  local bucket="$1"
  local source="$2"
  
  format-echo "INFO" "Syncing directory: $source with bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would sync:"
    format-echo "INFO" "  Source: $source"
    format-echo "INFO" "  Destination: gs://$bucket"
    return 0
  fi
  
  local sync_cmd="gsutil -m rsync"
  
  if [ "$RECURSIVE" = true ]; then
    sync_cmd+=" -r"
  fi
  
  if [ "$FORCE_OVERWRITE" = true ]; then
    sync_cmd+=" -d"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $sync_cmd $source gs://$bucket"
  fi
  
  if ! eval "$sync_cmd \"$source\" \"gs://$bucket\""; then
    format-echo "ERROR" "Failed to sync directory"
    return 1
  fi
  
  format-echo "SUCCESS" "Synced directory: $source with bucket: $bucket"
  return 0
}

#=====================================================================
# POLICY AND CONFIGURATION MANAGEMENT
#=====================================================================
# Function to set lifecycle policy
set_lifecycle() {
  local bucket="$1"
  local config_file="$2"
  
  format-echo "INFO" "Setting lifecycle policy for bucket: $bucket"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set lifecycle policy from: $config_file"
    return 0
  fi
  
  if [ -z "$config_file" ]; then
    # Create a default lifecycle policy
    local temp_config
    temp_config=$(mktemp)
    cat > "$temp_config" << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "NEARLINE"
        },
        "condition": {
          "age": $ARCHIVE_DAYS
        }
      },
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": $DELETE_DAYS
        }
      }
    ]
  }
}
EOF
    config_file="$temp_config"
  fi
  
  if ! gsutil lifecycle set "$config_file" "gs://$bucket"; then
    format-echo "ERROR" "Failed to set lifecycle policy"
    [ -n "${temp_config:-}" ] && rm -f "$temp_config"
    return 1
  fi
  
  [ -n "${temp_config:-}" ] && rm -f "$temp_config"
  format-echo "SUCCESS" "Set lifecycle policy for bucket: $bucket"
  return 0
}

# Function to generate signed URL
generate_signed_url() {
  local bucket="$1"
  local object="$2"
  local duration="$3"
  
  format-echo "INFO" "Generating signed URL for object: $object"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would generate signed URL:"
    format-echo "INFO" "  Object: gs://$bucket/$object"
    format-echo "INFO" "  Duration: $duration"
    return 0
  fi
  
  if ! gsutil signurl -d "$duration" "$HOME/.config/gcloud/legacy_credentials/$(gcloud config get-value account)/adc.json" "gs://$bucket/$object"; then
    format-echo "ERROR" "Failed to generate signed URL"
    return 1
  fi
  
  format-echo "SUCCESS" "Generated signed URL for object: $object"
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
  
  print_with_separator "GCP Cloud Storage Manager Script"
  format-echo "INFO" "Starting GCP Cloud Storage Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Cloud Storage Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Cloud Storage Manager Script"
    exit 1
  fi
  
  # Validate configuration files
  if ! validate_config_files; then
    print_with_separator "End of GCP Cloud Storage Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Cloud Storage Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-bucket|delete-bucket|get-bucket|list-objects|set-lifecycle|get-lifecycle|set-cors|get-cors|set-iam-policy|get-iam-policy|set-public-access|set-retention-policy|create-notification|delete-notification|list-notifications|enable-versioning|disable-versioning)
      if [ -z "$BUCKET_NAME" ]; then
        format-echo "ERROR" "Bucket name is required for action: $ACTION"
        exit 1
      fi
      ;;
    upload-object|download-object|delete-object|generate-signed-url)
      if [ -z "$BUCKET_NAME" ] || [ -z "$OBJECT_NAME" ]; then
        format-echo "ERROR" "Bucket name and object name are required for action: $ACTION"
        exit 1
      fi
      ;;
    sync-directories)
      if [ -z "$BUCKET_NAME" ] || [ -z "$SOURCE_PATH" ]; then
        format-echo "ERROR" "Bucket name and source path are required for action: $ACTION"
        exit 1
      fi
      ;;
    copy-object|move-object)
      if [ -z "$COPY_SOURCE" ] || [ -z "$COPY_DESTINATION" ]; then
        format-echo "ERROR" "Copy source and destination are required for action: $ACTION"
        exit 1
      fi
      ;;
    list-buckets)
      # No additional requirements for list actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-bucket, delete-bucket, list-buckets, get-bucket, upload-object, download-object, delete-object, list-objects, copy-object, move-object, sync-directories, set-lifecycle, get-lifecycle, set-cors, get-cors, set-iam-policy, get-iam-policy, generate-signed-url, set-public-access, set-retention-policy, create-notification, delete-notification, list-notifications, enable-versioning, disable-versioning"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-bucket)
      if create_bucket "$PROJECT_ID" "$BUCKET_NAME"; then
        format-echo "SUCCESS" "Bucket creation completed successfully"
      else
        format-echo "ERROR" "Failed to create bucket"
        exit 1
      fi
      ;;
    delete-bucket)
      if delete_bucket "$BUCKET_NAME"; then
        format-echo "SUCCESS" "Bucket deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete bucket"
        exit 1
      fi
      ;;
    list-buckets)
      if list_buckets "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed buckets successfully"
      else
        format-echo "ERROR" "Failed to list buckets"
        exit 1
      fi
      ;;
    get-bucket)
      if get_bucket "$BUCKET_NAME"; then
        format-echo "SUCCESS" "Retrieved bucket details successfully"
      else
        format-echo "ERROR" "Failed to get bucket details"
        exit 1
      fi
      ;;
    upload-object)
      if upload_object "$BUCKET_NAME" "$SOURCE_PATH" "$OBJECT_NAME"; then
        format-echo "SUCCESS" "Object upload completed successfully"
      else
        format-echo "ERROR" "Failed to upload object"
        exit 1
      fi
      ;;
    download-object)
      if download_object "$BUCKET_NAME" "$OBJECT_NAME" "$DESTINATION_PATH"; then
        format-echo "SUCCESS" "Object download completed successfully"
      else
        format-echo "ERROR" "Failed to download object"
        exit 1
      fi
      ;;
    delete-object)
      if delete_object "$BUCKET_NAME" "$OBJECT_NAME"; then
        format-echo "SUCCESS" "Object deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete object"
        exit 1
      fi
      ;;
    list-objects)
      if list_objects "$BUCKET_NAME"; then
        format-echo "SUCCESS" "Listed objects successfully"
      else
        format-echo "ERROR" "Failed to list objects"
        exit 1
      fi
      ;;
    copy-object)
      if copy_object "$COPY_SOURCE" "$COPY_DESTINATION"; then
        format-echo "SUCCESS" "Object copy completed successfully"
      else
        format-echo "ERROR" "Failed to copy object"
        exit 1
      fi
      ;;
    sync-directories)
      if sync_directories "$BUCKET_NAME" "$SOURCE_PATH"; then
        format-echo "SUCCESS" "Directory sync completed successfully"
      else
        format-echo "ERROR" "Failed to sync directories"
        exit 1
      fi
      ;;
    set-lifecycle)
      if set_lifecycle "$BUCKET_NAME" "$LIFECYCLE_CONFIG"; then
        format-echo "SUCCESS" "Lifecycle policy set successfully"
      else
        format-echo "ERROR" "Failed to set lifecycle policy"
        exit 1
      fi
      ;;
    generate-signed-url)
      if generate_signed_url "$BUCKET_NAME" "$OBJECT_NAME" "$SIGNED_URL_DURATION"; then
        format-echo "SUCCESS" "Signed URL generated successfully"
      else
        format-echo "ERROR" "Failed to generate signed URL"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Cloud Storage Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
