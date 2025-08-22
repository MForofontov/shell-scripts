#!/usr/bin/env bash
# setup-gcs-pubsub-notifications.sh
# Script to set up GCS bucket notifications to Pub/Sub topics without deleting existing ones.

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
BUCKET=""
TOPIC=""
SUBSCRIPTION=""
DELETE_OLD=false
EVENT_TYPE="OBJECT_FINALIZE"
PAYLOAD_FORMAT="json"
VERBOSE=false
DRY_RUN=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCS Pub/Sub Notifications Setup Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script sets up GCS bucket notifications to Pub/Sub topics."
  echo "  By default, it preserves existing notifications unless --delete-old is specified."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 --project <project-id> --bucket <bucket-name> --topic <topic-name>"
  echo "     [--subscription <sub-name>] [--event-type <type>] [--payload-format <format>]"
  echo "     [--delete-old] [--dry-run] [--verbose] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--bucket <bucket-name>\033[0m       (Required) GCS bucket name"
  echo -e "  \033[1;33m--topic <topic-name>\033[0m         (Required) Pub/Sub topic name"
  echo -e "  \033[1;33m--subscription <sub-name>\033[0m    (Optional) Create Pub/Sub subscription"
  echo -e "  \033[1;33m--event-type <type>\033[0m          (Optional) Event type (default: OBJECT_FINALIZE)"
  echo -e "  \033[1;33m--payload-format <format>\033[0m    (Optional) Payload format: json, none (default: json)"
  echo -e "  \033[1;33m--delete-old\033[0m                 (Optional) Delete existing notifications before creating new ones"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done without making changes"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save the log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mEvent Types:\033[0m"
  echo "  OBJECT_FINALIZE, OBJECT_DELETE, OBJECT_METADATA_UPDATE, OBJECT_ARCHIVE"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --project my-project --bucket my-bucket --topic my-topic"
  echo "  $0 --project my-project --bucket my-bucket --topic my-topic --subscription my-sub"
  echo "  $0 --project my-project --bucket my-bucket --topic my-topic --delete-old --verbose"
  echo "  $0 --project my-project --bucket my-bucket --topic my-topic --event-type OBJECT_DELETE --dry-run"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
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
        BUCKET="$2"
        shift 2
        ;;
      --topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No topic name provided after --topic."
          usage
        fi
        TOPIC="$2"
        shift 2
        ;;
      --subscription)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No subscription name provided after --subscription."
          usage
        fi
        SUBSCRIPTION="$2"
        shift 2
        ;;
      --event-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No event type provided after --event-type."
          usage
        fi
        EVENT_TYPE="$2"
        shift 2
        ;;
      --payload-format)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^(json|none)$ ]]; then
          format-echo "ERROR" "Invalid payload format: $2. Must be 'json' or 'none'."
          usage
        fi
        PAYLOAD_FORMAT="$2"
        shift 2
        ;;
      --delete-old)
        DELETE_OLD=true
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
# Function to check if a command exists
check_dependencies() {
  local missing_deps=()
  
  if ! command_exists gcloud; then
    missing_deps+=("gcloud")
  fi
  
  if ! command_exists gsutil; then
    missing_deps+=("gsutil")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    format-echo "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    format-echo "INFO" "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  
  return 0
}

# Function to validate GCP authentication
validate_auth() {
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    format-echo "ERROR" "No active GCP authentication found."
    format-echo "INFO" "Please run: gcloud auth login"
    return 1
  fi
  
  return 0
}

# Function to check if project exists and is accessible
validate_project() {
  local project="$1"
  
  if ! gcloud projects describe "$project" >/dev/null 2>&1; then
    format-echo "ERROR" "Project '$project' not found or not accessible."
    return 1
  fi
  
  return 0
}

# Function to check if bucket exists
validate_bucket() {
  local bucket="$1"
  
  if ! gsutil ls -b "gs://$bucket" >/dev/null 2>&1; then
    format-echo "ERROR" "Bucket 'gs://$bucket' not found or not accessible."
    return 1
  fi
  
  return 0
}

#=====================================================================
# MAIN FUNCTIONS
#=====================================================================
# Function to set up the project
setup_project() {
  local project="$1"
  
  format-echo "INFO" "Setting up project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set project to: $project"
    return 0
  fi
  
  if ! gcloud config set project "$project" >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to set project to: $project"
    return 1
  fi
  
  format-echo "SUCCESS" "Project set to: $project"
  return 0
}

# Function to create Pub/Sub topic
create_topic() {
  local project="$1"
  local topic="$2"
  
  if gcloud pubsub topics describe "$topic" --project "$project" >/dev/null 2>&1; then
    format-echo "INFO" "Topic already exists: $topic"
    return 0
  fi
  
  format-echo "INFO" "Creating Pub/Sub topic: $topic"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create topic: $topic"
    return 0
  fi
  
  if ! gcloud pubsub topics create "$topic" --project "$project" >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to create topic: $topic"
    return 1
  fi
  
  format-echo "SUCCESS" "Created topic: $topic"
  return 0
}

# Function to create Pub/Sub subscription
create_subscription() {
  local project="$1"
  local topic="$2"
  local subscription="$3"
  
  if [ -z "$subscription" ]; then
    format-echo "INFO" "No subscription specified, skipping subscription creation"
    return 0
  fi
  
  if gcloud pubsub subscriptions describe "$subscription" --project "$project" >/dev/null 2>&1; then
    format-echo "INFO" "Subscription already exists: $subscription"
    return 0
  fi
  
  format-echo "INFO" "Creating Pub/Sub subscription: $subscription"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create subscription: $subscription"
    return 0
  fi
  
  if ! gcloud pubsub subscriptions create "$subscription" \
    --topic="$topic" \
    --project="$project" >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to create subscription: $subscription"
    return 1
  fi
  
  format-echo "SUCCESS" "Created subscription: $subscription"
  return 0
}

# Function to grant permissions to GCS service account
grant_permissions() {
  local project="$1"
  local topic="$2"
  
  format-echo "INFO" "Granting permissions to GCS service account"
  
  # Get project number
  local project_number
  if ! project_number=$(gcloud projects describe "$project" --format="value(projectNumber)" 2>/dev/null); then
    format-echo "ERROR" "Failed to get project number for: $project"
    return 1
  fi
  
  local service_account="service-${project_number}@gs-project-accounts.iam.gserviceaccount.com"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Service account: $service_account"
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would grant pubsub.publisher role to: $service_account"
    return 0
  fi
  
  if ! gcloud pubsub topics add-iam-policy-binding "$topic" \
    --member="serviceAccount:$service_account" \
    --role="roles/pubsub.publisher" \
    --project="$project" >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to grant permissions to service account"
    return 1
  fi
  
  format-echo "SUCCESS" "Granted Pub/Sub publisher role to GCS service account"
  return 0
}

# Function to delete old notifications
delete_old_notifications() {
  local bucket="$1"
  
  if [ "$DELETE_OLD" = false ]; then
    format-echo "INFO" "Preserving existing notifications (use --delete-old to remove them)"
    return 0
  fi
  
  format-echo "INFO" "Checking for existing notifications on bucket: $bucket"
  
  local existing_notifications
  if ! existing_notifications=$(gsutil notification list "gs://$bucket" 2>/dev/null); then
    format-echo "WARNING" "Failed to list existing notifications"
    return 0
  fi
  
  if [ -z "$existing_notifications" ] || ! echo "$existing_notifications" | grep -q "notificationConfigs"; then
    format-echo "INFO" "No existing notifications found"
    return 0
  fi
  
  format-echo "INFO" "Found existing notifications, deleting them..."
  
  echo "$existing_notifications" | grep "notificationConfigs" | awk -F/ '{print $NF}' | while read -r notification_id; do
    if [ -n "$notification_id" ]; then
      if [ "$DRY_RUN" = true ]; then
        format-echo "INFO" "[DRY RUN] Would delete notification ID: $notification_id"
      else
        format-echo "INFO" "Deleting notification ID: $notification_id"
        if ! gsutil notification delete -i "$notification_id" "gs://$bucket" >/dev/null 2>&1; then
          format-echo "WARNING" "Failed to delete notification ID: $notification_id"
        fi
      fi
    fi
  done
  
  format-echo "SUCCESS" "Processed existing notifications"
  return 0
}

# Function to create notification
create_notification() {
  local project="$1"
  local bucket="$2"
  local topic="$3"
  local event_type="$4"
  local payload_format="$5"
  
  format-echo "INFO" "Creating notification on bucket: $bucket"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Event type: $event_type"
    format-echo "INFO" "Payload format: $payload_format"
    format-echo "INFO" "Topic: projects/$project/topics/$topic"
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create notification with:"
    format-echo "INFO" "  Topic: projects/$project/topics/$topic"
    format-echo "INFO" "  Event: $event_type"
    format-echo "INFO" "  Format: $payload_format"
    format-echo "INFO" "  Bucket: gs://$bucket"
    return 0
  fi
  
  if ! gsutil notification create \
    -t "projects/$project/topics/$topic" \
    -f "$payload_format" \
    -e "$event_type" \
    "gs://$bucket" >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to create notification"
    return 1
  fi
  
  format-echo "SUCCESS" "Created notification successfully"
  return 0
}

# Function to list current notifications
list_notifications() {
  local bucket="$1"
  
  format-echo "INFO" "Current bucket notifications:"
  
  local notifications
  if ! notifications=$(gsutil notification list "gs://$bucket" 2>/dev/null); then
    format-echo "WARNING" "Failed to list notifications"
    return 0
  fi
  
  if [ -z "$notifications" ] || ! echo "$notifications" | grep -q "notificationConfigs"; then
    format-echo "INFO" "No notifications configured"
  else
    echo "$notifications"
  fi
  
  return 0
}

# Function to run the setup process
run_setup() {
  format-echo "INFO" "Setting up GCS → Pub/Sub notifications"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Configuration:"
    format-echo "INFO" "  Project: $PROJECT_ID"
    format-echo "INFO" "  Bucket: $BUCKET"
    format-echo "INFO" "  Topic: $TOPIC"
    format-echo "INFO" "  Subscription: ${SUBSCRIPTION:-none}"
    format-echo "INFO" "  Event Type: $EVENT_TYPE"
    format-echo "INFO" "  Payload Format: $PAYLOAD_FORMAT"
    format-echo "INFO" "  Delete Old: $DELETE_OLD"
    format-echo "INFO" "  Dry Run: $DRY_RUN"
  fi
  
  # Set up project
  setup_project "$PROJECT_ID" || return 1
  
  # Create topic
  create_topic "$PROJECT_ID" "$TOPIC" || return 1
  
  # Create subscription if specified
  create_subscription "$PROJECT_ID" "$TOPIC" "$SUBSCRIPTION" || return 1
  
  # Grant permissions
  grant_permissions "$PROJECT_ID" "$TOPIC" || return 1
  
  # Handle old notifications
  delete_old_notifications "$BUCKET" || return 1
  
  # Create new notification
  create_notification "$PROJECT_ID" "$BUCKET" "$TOPIC" "$EVENT_TYPE" "$PAYLOAD_FORMAT" || return 1
  
  # List current notifications
  if [ "$DRY_RUN" = false ]; then
    list_notifications "$BUCKET"
  fi
  
  format-echo "SUCCESS" "Setup completed successfully!"
  
  if [ "$DRY_RUN" = false ]; then
    echo
    format-echo "INFO" "Test the setup:"
    format-echo "INFO" "  1. Upload a file: gsutil cp ./test.txt gs://$BUCKET/"
    if [ -n "$SUBSCRIPTION" ]; then
      format-echo "INFO" "  2. Pull message: gcloud pubsub subscriptions pull $SUBSCRIPTION --project=$PROJECT_ID --auto-ack --limit=1"
    else
      format-echo "INFO" "  2. Create a subscription and pull messages from topic: $TOPIC"
    fi
  fi
  
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
  
  print_with_separator "GCS Pub/Sub Notifications Setup Script"
  format-echo "INFO" "Starting GCS Pub/Sub Notifications Setup..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
    exit 1
  fi
  
  if [ -z "$BUCKET" ]; then
    format-echo "ERROR" "Bucket name is required. Use --bucket <bucket-name>"
    print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
    exit 1
  fi
  
  if [ -z "$TOPIC" ]; then
    format-echo "ERROR" "Topic name is required. Use --topic <topic-name>"
    print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
    exit 1
  fi
  
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
    exit 1
  fi
  
  # Validate project access
  if ! validate_project "$PROJECT_ID"; then
    print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
    exit 1
  fi
  
  # Validate bucket access
  if ! validate_bucket "$BUCKET"; then
    print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  if run_setup; then
    format-echo "SUCCESS" "GCS Pub/Sub notifications setup completed successfully."
  else
    format-echo "ERROR" "Failed to set up GCS Pub/Sub notifications."
    print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCS Pub/Sub Notifications Setup Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
