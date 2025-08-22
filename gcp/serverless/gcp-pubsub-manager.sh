#!/usr/bin/env bash
# gcp-pubsub-manager.sh
# Script to manage GCP Pub/Sub topics, subscriptions, and schemas.

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
TOPIC_NAME=""
SUBSCRIPTION_NAME=""
SCHEMA_NAME=""
SCHEMA_TYPE="AVRO"
SCHEMA_DEFINITION=""
SCHEMA_FILE=""
MESSAGE_RETENTION_DURATION="604800s"
TTL_DURATION=""
ACK_DEADLINE="10s"
ENABLE_MESSAGE_ORDERING=false
PUSH_ENDPOINT=""
PUSH_AUTH_SERVICE_ACCOUNT=""
DEAD_LETTER_TOPIC=""
MAX_DELIVERY_ATTEMPTS="5"
RETRY_POLICY_MIN_BACKOFF="10s"
RETRY_POLICY_MAX_BACKOFF="600s"
LABELS=""
FILTER=""
MESSAGE_BODY=""
MESSAGE_ATTRIBUTES=""
NUM_MESSAGES="1"
MAX_MESSAGES="10"
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Pub/Sub Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Pub/Sub topics, subscriptions, schemas, and messaging."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-topic\033[0m             Create a Pub/Sub topic"
  echo -e "  \033[1;33mdelete-topic\033[0m             Delete a Pub/Sub topic"
  echo -e "  \033[1;33mlist-topics\033[0m              List all Pub/Sub topics"
  echo -e "  \033[1;33mget-topic\033[0m                Get topic details"
  echo -e "  \033[1;33mcreate-subscription\033[0m      Create a subscription"
  echo -e "  \033[1;33mdelete-subscription\033[0m      Delete a subscription"
  echo -e "  \033[1;33mlist-subscriptions\033[0m       List all subscriptions"
  echo -e "  \033[1;33mget-subscription\033[0m         Get subscription details"
  echo -e "  \033[1;33mmodify-subscription\033[0m      Modify subscription settings"
  echo -e "  \033[1;33mpublish-message\033[0m          Publish a message to topic"
  echo -e "  \033[1;33mpull-messages\033[0m            Pull messages from subscription"
  echo -e "  \033[1;33mcreate-schema\033[0m            Create a Pub/Sub schema"
  echo -e "  \033[1;33mdelete-schema\033[0m            Delete a Pub/Sub schema"
  echo -e "  \033[1;33mlist-schemas\033[0m             List all schemas"
  echo -e "  \033[1;33mget-schema\033[0m               Get schema details"
  echo -e "  \033[1;33mset-iam-policy\033[0m           Set IAM policy for topic/subscription"
  echo -e "  \033[1;33mget-iam-policy\033[0m           Get IAM policy for topic/subscription"
  echo -e "  \033[1;33mcreate-snapshot\033[0m          Create a subscription snapshot"
  echo -e "  \033[1;33mdelete-snapshot\033[0m          Delete a subscription snapshot"
  echo -e "  \033[1;33mlist-snapshots\033[0m           List all snapshots"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--topic <name>\033[0m                   (Required for topic actions) Topic name"
  echo -e "  \033[1;33m--subscription <name>\033[0m            (Required for subscription actions) Subscription name"
  echo -e "  \033[1;33m--schema <name>\033[0m                  (Required for schema actions) Schema name"
  echo -e "  \033[1;33m--schema-type <type>\033[0m             (Optional) Schema type: AVRO, PROTOCOL_BUFFER (default: AVRO)"
  echo -e "  \033[1;33m--schema-definition <definition>\033[0m (Optional) Schema definition string"
  echo -e "  \033[1;33m--schema-file <file>\033[0m             (Optional) Schema definition file"
  echo -e "  \033[1;33m--retention <duration>\033[0m           (Optional) Message retention duration (default: 604800s)"
  echo -e "  \033[1;33m--ttl <duration>\033[0m                 (Optional) Topic TTL duration"
  echo -e "  \033[1;33m--ack-deadline <duration>\033[0m        (Optional) Acknowledgment deadline (default: 10s)"
  echo -e "  \033[1;33m--enable-ordering\033[0m                (Optional) Enable message ordering"
  echo -e "  \033[1;33m--push-endpoint <url>\033[0m            (Optional) Push endpoint URL"
  echo -e "  \033[1;33m--push-auth-service-account <email>\033[0m (Optional) Push auth service account"
  echo -e "  \033[1;33m--dead-letter-topic <topic>\033[0m      (Optional) Dead letter topic"
  echo -e "  \033[1;33m--max-delivery-attempts <count>\033[0m  (Optional) Max delivery attempts (default: 5)"
  echo -e "  \033[1;33m--retry-min-backoff <duration>\033[0m   (Optional) Min retry backoff (default: 10s)"
  echo -e "  \033[1;33m--retry-max-backoff <duration>\033[0m   (Optional) Max retry backoff (default: 600s)"
  echo -e "  \033[1;33m--labels <labels>\033[0m                (Optional) Labels (key=value,key2=value2)"
  echo -e "  \033[1;33m--filter <expression>\033[0m            (Optional) Message filter expression"
  echo -e "  \033[1;33m--message-body <text>\033[0m            (Optional) Message body text"
  echo -e "  \033[1;33m--message-attributes <attrs>\033[0m     (Optional) Message attributes (key=value,key2=value2)"
  echo -e "  \033[1;33m--num-messages <count>\033[0m           (Optional) Number of messages to publish (default: 1)"
  echo -e "  \033[1;33m--max-messages <count>\033[0m           (Optional) Max messages to pull (default: 10)"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-topics --project my-project"
  echo "  $0 create-topic --project my-project --topic my-topic --retention 86400s"
  echo "  $0 create-subscription --project my-project --topic my-topic --subscription my-sub --ack-deadline 30s"
  echo "  $0 publish-message --project my-project --topic my-topic --message-body 'Hello World'"
  echo "  $0 pull-messages --project my-project --subscription my-sub --max-messages 5"
  echo "  $0 create-schema --project my-project --schema my-schema --schema-type AVRO --schema-file schema.avsc"
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
      --topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No topic name provided after --topic."
          usage
        fi
        TOPIC_NAME="$2"
        shift 2
        ;;
      --subscription)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No subscription name provided after --subscription."
          usage
        fi
        SUBSCRIPTION_NAME="$2"
        shift 2
        ;;
      --schema)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No schema name provided after --schema."
          usage
        fi
        SCHEMA_NAME="$2"
        shift 2
        ;;
      --schema-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No schema type provided after --schema-type."
          usage
        fi
        SCHEMA_TYPE="$2"
        shift 2
        ;;
      --schema-definition)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No schema definition provided after --schema-definition."
          usage
        fi
        SCHEMA_DEFINITION="$2"
        shift 2
        ;;
      --schema-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No schema file provided after --schema-file."
          usage
        fi
        SCHEMA_FILE="$2"
        shift 2
        ;;
      --retention)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No retention duration provided after --retention."
          usage
        fi
        MESSAGE_RETENTION_DURATION="$2"
        shift 2
        ;;
      --ttl)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No TTL duration provided after --ttl."
          usage
        fi
        TTL_DURATION="$2"
        shift 2
        ;;
      --ack-deadline)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No ack deadline provided after --ack-deadline."
          usage
        fi
        ACK_DEADLINE="$2"
        shift 2
        ;;
      --enable-ordering)
        ENABLE_MESSAGE_ORDERING=true
        shift
        ;;
      --push-endpoint)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No push endpoint provided after --push-endpoint."
          usage
        fi
        PUSH_ENDPOINT="$2"
        shift 2
        ;;
      --push-auth-service-account)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No service account provided after --push-auth-service-account."
          usage
        fi
        PUSH_AUTH_SERVICE_ACCOUNT="$2"
        shift 2
        ;;
      --dead-letter-topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No dead letter topic provided after --dead-letter-topic."
          usage
        fi
        DEAD_LETTER_TOPIC="$2"
        shift 2
        ;;
      --max-delivery-attempts)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max delivery attempts provided after --max-delivery-attempts."
          usage
        fi
        MAX_DELIVERY_ATTEMPTS="$2"
        shift 2
        ;;
      --retry-min-backoff)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No min backoff provided after --retry-min-backoff."
          usage
        fi
        RETRY_POLICY_MIN_BACKOFF="$2"
        shift 2
        ;;
      --retry-max-backoff)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max backoff provided after --retry-max-backoff."
          usage
        fi
        RETRY_POLICY_MAX_BACKOFF="$2"
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
      --filter)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No filter provided after --filter."
          usage
        fi
        FILTER="$2"
        shift 2
        ;;
      --message-body)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No message body provided after --message-body."
          usage
        fi
        MESSAGE_BODY="$2"
        shift 2
        ;;
      --message-attributes)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No message attributes provided after --message-attributes."
          usage
        fi
        MESSAGE_ATTRIBUTES="$2"
        shift 2
        ;;
      --num-messages)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No number of messages provided after --num-messages."
          usage
        fi
        NUM_MESSAGES="$2"
        shift 2
        ;;
      --max-messages)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max messages provided after --max-messages."
          usage
        fi
        MAX_MESSAGES="$2"
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

# Function to validate schema file
validate_schema_file() {
  if [ -n "$SCHEMA_FILE" ] && [ ! -f "$SCHEMA_FILE" ]; then
    format-echo "ERROR" "Schema file not found: $SCHEMA_FILE"
    return 1
  fi
  return 0
}

#=====================================================================
# TOPIC MANAGEMENT
#=====================================================================
# Function to create Pub/Sub topic
create_topic() {
  local project="$1"
  local topic="$2"
  
  format-echo "INFO" "Creating Pub/Sub topic: $topic"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create topic:"
    format-echo "INFO" "  Name: $topic"
    format-echo "INFO" "  Retention: $MESSAGE_RETENTION_DURATION"
    [ -n "$TTL_DURATION" ] && format-echo "INFO" "  TTL: $TTL_DURATION"
    [ "$ENABLE_MESSAGE_ORDERING" = true ] && format-echo "INFO" "  Message ordering: enabled"
    return 0
  fi
  
  local create_cmd="gcloud pubsub topics create $topic"
  create_cmd+=" --project=$project"
  
  if [ -n "$MESSAGE_RETENTION_DURATION" ]; then
    create_cmd+=" --message-retention-duration=$MESSAGE_RETENTION_DURATION"
  fi
  
  if [ -n "$TTL_DURATION" ]; then
    create_cmd+=" --topic-retention-duration=$TTL_DURATION"
  fi
  
  if [ "$ENABLE_MESSAGE_ORDERING" = true ]; then
    create_cmd+=" --message-ordering"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --labels=$LABELS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create topic: $topic"
    return 1
  fi
  
  format-echo "SUCCESS" "Created Pub/Sub topic: $topic"
  return 0
}

# Function to delete Pub/Sub topic
delete_topic() {
  local project="$1"
  local topic="$2"
  
  format-echo "INFO" "Deleting Pub/Sub topic: $topic"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete topic: $topic"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will delete the topic '$topic' and all its subscriptions."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud pubsub topics delete "$topic" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete topic: $topic"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Pub/Sub topic: $topic"
  return 0
}

# Function to list Pub/Sub topics
list_topics() {
  local project="$1"
  
  format-echo "INFO" "Listing Pub/Sub topics"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list topics"
    return 0
  fi
  
  if ! gcloud pubsub topics list \
    --project="$project" \
    --format="table(name.basename(),labels,messageRetentionDuration)"; then
    format-echo "ERROR" "Failed to list topics"
    return 1
  fi
  
  return 0
}

# Function to get topic details
get_topic() {
  local project="$1"
  local topic="$2"
  
  format-echo "INFO" "Getting details for topic: $topic"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get topic details: $topic"
    return 0
  fi
  
  if ! gcloud pubsub topics describe "$topic" \
    --project="$project"; then
    format-echo "ERROR" "Failed to get topic details: $topic"
    return 1
  fi
  
  return 0
}

#=====================================================================
# SUBSCRIPTION MANAGEMENT
#=====================================================================
# Function to create subscription
create_subscription() {
  local project="$1"
  local topic="$2"
  local subscription="$3"
  
  format-echo "INFO" "Creating subscription: $subscription for topic: $topic"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create subscription:"
    format-echo "INFO" "  Name: $subscription"
    format-echo "INFO" "  Topic: $topic"
    format-echo "INFO" "  Ack deadline: $ACK_DEADLINE"
    [ -n "$PUSH_ENDPOINT" ] && format-echo "INFO" "  Push endpoint: $PUSH_ENDPOINT"
    return 0
  fi
  
  local create_cmd="gcloud pubsub subscriptions create $subscription"
  create_cmd+=" --topic=$topic"
  create_cmd+=" --project=$project"
  create_cmd+=" --ack-deadline=$ACK_DEADLINE"
  
  if [ -n "$PUSH_ENDPOINT" ]; then
    create_cmd+=" --push-endpoint=$PUSH_ENDPOINT"
    
    if [ -n "$PUSH_AUTH_SERVICE_ACCOUNT" ]; then
      create_cmd+=" --push-auth-service-account=$PUSH_AUTH_SERVICE_ACCOUNT"
    fi
  fi
  
  if [ -n "$DEAD_LETTER_TOPIC" ]; then
    create_cmd+=" --dead-letter-topic=$DEAD_LETTER_TOPIC"
    create_cmd+=" --max-delivery-attempts=$MAX_DELIVERY_ATTEMPTS"
  fi
  
  if [ -n "$RETRY_POLICY_MIN_BACKOFF" ]; then
    create_cmd+=" --min-retry-delay=$RETRY_POLICY_MIN_BACKOFF"
  fi
  
  if [ -n "$RETRY_POLICY_MAX_BACKOFF" ]; then
    create_cmd+=" --max-retry-delay=$RETRY_POLICY_MAX_BACKOFF"
  fi
  
  if [ -n "$FILTER" ]; then
    create_cmd+=" --message-filter='$FILTER'"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --labels=$LABELS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create subscription: $subscription"
    return 1
  fi
  
  format-echo "SUCCESS" "Created subscription: $subscription"
  return 0
}

# Function to delete subscription
delete_subscription() {
  local project="$1"
  local subscription="$2"
  
  format-echo "INFO" "Deleting subscription: $subscription"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete subscription: $subscription"
    return 0
  fi
  
  if ! gcloud pubsub subscriptions delete "$subscription" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete subscription: $subscription"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted subscription: $subscription"
  return 0
}

# Function to list subscriptions
list_subscriptions() {
  local project="$1"
  
  format-echo "INFO" "Listing Pub/Sub subscriptions"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list subscriptions"
    return 0
  fi
  
  if ! gcloud pubsub subscriptions list \
    --project="$project" \
    --format="table(name.basename(),topic.basename(),ackDeadlineSeconds,pushConfig.pushEndpoint)"; then
    format-echo "ERROR" "Failed to list subscriptions"
    return 1
  fi
  
  return 0
}

#=====================================================================
# MESSAGE OPERATIONS
#=====================================================================
# Function to publish message
publish_message() {
  local project="$1"
  local topic="$2"
  
  format-echo "INFO" "Publishing message(s) to topic: $topic"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would publish $NUM_MESSAGES message(s):"
    format-echo "INFO" "  Topic: $topic"
    [ -n "$MESSAGE_BODY" ] && format-echo "INFO" "  Body: $MESSAGE_BODY"
    [ -n "$MESSAGE_ATTRIBUTES" ] && format-echo "INFO" "  Attributes: $MESSAGE_ATTRIBUTES"
    return 0
  fi
  
  local publish_cmd="gcloud pubsub topics publish $topic"
  publish_cmd+=" --project=$project"
  
  if [ -n "$MESSAGE_BODY" ]; then
    publish_cmd+=" --message='$MESSAGE_BODY'"
  fi
  
  if [ -n "$MESSAGE_ATTRIBUTES" ]; then
    publish_cmd+=" --attribute=$MESSAGE_ATTRIBUTES"
  fi
  
  local count=0
  while [ $count -lt "$NUM_MESSAGES" ]; do
    if [ "$VERBOSE" = true ]; then
      format-echo "INFO" "Publishing message $((count + 1))/$NUM_MESSAGES"
    fi
    
    if ! eval "$publish_cmd"; then
      format-echo "ERROR" "Failed to publish message $((count + 1))"
      return 1
    fi
    
    count=$((count + 1))
  done
  
  format-echo "SUCCESS" "Published $NUM_MESSAGES message(s) to topic: $topic"
  return 0
}

# Function to pull messages
pull_messages() {
  local project="$1"
  local subscription="$2"
  
  format-echo "INFO" "Pulling messages from subscription: $subscription"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would pull up to $MAX_MESSAGES messages from: $subscription"
    return 0
  fi
  
  local pull_cmd="gcloud pubsub subscriptions pull $subscription"
  pull_cmd+=" --project=$project"
  pull_cmd+=" --max-messages=$MAX_MESSAGES"
  pull_cmd+=" --auto-ack"
  pull_cmd+=" --format='table(message.data.decode(base64),message.attributes,message.messageId)'"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $pull_cmd"
  fi
  
  if ! eval "$pull_cmd"; then
    format-echo "ERROR" "Failed to pull messages from subscription: $subscription"
    return 1
  fi
  
  format-echo "SUCCESS" "Pulled messages from subscription: $subscription"
  return 0
}

#=====================================================================
# SCHEMA MANAGEMENT
#=====================================================================
# Function to create schema
create_schema() {
  local project="$1"
  local schema="$2"
  
  format-echo "INFO" "Creating Pub/Sub schema: $schema"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create schema:"
    format-echo "INFO" "  Name: $schema"
    format-echo "INFO" "  Type: $SCHEMA_TYPE"
    return 0
  fi
  
  local create_cmd="gcloud pubsub schemas create $schema"
  create_cmd+=" --project=$project"
  create_cmd+=" --type=$SCHEMA_TYPE"
  
  if [ -n "$SCHEMA_DEFINITION" ]; then
    create_cmd+=" --definition='$SCHEMA_DEFINITION'"
  elif [ -n "$SCHEMA_FILE" ]; then
    create_cmd+=" --definition-file=$SCHEMA_FILE"
  else
    format-echo "ERROR" "Schema definition or file is required"
    return 1
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create schema: $schema"
    return 1
  fi
  
  format-echo "SUCCESS" "Created Pub/Sub schema: $schema"
  return 0
}

# Function to delete schema
delete_schema() {
  local project="$1"
  local schema="$2"
  
  format-echo "INFO" "Deleting Pub/Sub schema: $schema"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete schema: $schema"
    return 0
  fi
  
  if ! gcloud pubsub schemas delete "$schema" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete schema: $schema"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Pub/Sub schema: $schema"
  return 0
}

# Function to list schemas
list_schemas() {
  local project="$1"
  
  format-echo "INFO" "Listing Pub/Sub schemas"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list schemas"
    return 0
  fi
  
  if ! gcloud pubsub schemas list \
    --project="$project" \
    --format="table(name.basename(),type)"; then
    format-echo "ERROR" "Failed to list schemas"
    return 1
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
  
  print_with_separator "GCP Pub/Sub Manager Script"
  format-echo "INFO" "Starting GCP Pub/Sub Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Pub/Sub Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Pub/Sub Manager Script"
    exit 1
  fi
  
  # Validate schema file if provided
  if ! validate_schema_file; then
    print_with_separator "End of GCP Pub/Sub Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Pub/Sub Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-topic|delete-topic|get-topic|publish-message)
      if [ -z "$TOPIC_NAME" ]; then
        format-echo "ERROR" "Topic name is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-subscription|delete-subscription|get-subscription|modify-subscription|pull-messages)
      if [ -z "$SUBSCRIPTION_NAME" ]; then
        format-echo "ERROR" "Subscription name is required for action: $ACTION"
        exit 1
      fi
      if [ "$ACTION" = "create-subscription" ] && [ -z "$TOPIC_NAME" ]; then
        format-echo "ERROR" "Topic name is required for creating subscription"
        exit 1
      fi
      ;;
    create-schema|delete-schema|get-schema)
      if [ -z "$SCHEMA_NAME" ]; then
        format-echo "ERROR" "Schema name is required for action: $ACTION"
        exit 1
      fi
      ;;
    list-topics|list-subscriptions|list-schemas|list-snapshots)
      # No additional requirements for list actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-topic, delete-topic, list-topics, get-topic, create-subscription, delete-subscription, list-subscriptions, get-subscription, modify-subscription, publish-message, pull-messages, create-schema, delete-schema, list-schemas, get-schema"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-topic)
      if create_topic "$PROJECT_ID" "$TOPIC_NAME"; then
        format-echo "SUCCESS" "Topic creation completed successfully"
      else
        format-echo "ERROR" "Failed to create topic"
        exit 1
      fi
      ;;
    delete-topic)
      if delete_topic "$PROJECT_ID" "$TOPIC_NAME"; then
        format-echo "SUCCESS" "Topic deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete topic"
        exit 1
      fi
      ;;
    list-topics)
      if list_topics "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed topics successfully"
      else
        format-echo "ERROR" "Failed to list topics"
        exit 1
      fi
      ;;
    get-topic)
      if get_topic "$PROJECT_ID" "$TOPIC_NAME"; then
        format-echo "SUCCESS" "Retrieved topic details successfully"
      else
        format-echo "ERROR" "Failed to get topic details"
        exit 1
      fi
      ;;
    create-subscription)
      if create_subscription "$PROJECT_ID" "$TOPIC_NAME" "$SUBSCRIPTION_NAME"; then
        format-echo "SUCCESS" "Subscription creation completed successfully"
      else
        format-echo "ERROR" "Failed to create subscription"
        exit 1
      fi
      ;;
    delete-subscription)
      if delete_subscription "$PROJECT_ID" "$SUBSCRIPTION_NAME"; then
        format-echo "SUCCESS" "Subscription deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete subscription"
        exit 1
      fi
      ;;
    list-subscriptions)
      if list_subscriptions "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed subscriptions successfully"
      else
        format-echo "ERROR" "Failed to list subscriptions"
        exit 1
      fi
      ;;
    publish-message)
      if publish_message "$PROJECT_ID" "$TOPIC_NAME"; then
        format-echo "SUCCESS" "Message publishing completed successfully"
      else
        format-echo "ERROR" "Failed to publish message"
        exit 1
      fi
      ;;
    pull-messages)
      if pull_messages "$PROJECT_ID" "$SUBSCRIPTION_NAME"; then
        format-echo "SUCCESS" "Message pulling completed successfully"
      else
        format-echo "ERROR" "Failed to pull messages"
        exit 1
      fi
      ;;
    create-schema)
      if create_schema "$PROJECT_ID" "$SCHEMA_NAME"; then
        format-echo "SUCCESS" "Schema creation completed successfully"
      else
        format-echo "ERROR" "Failed to create schema"
        exit 1
      fi
      ;;
    delete-schema)
      if delete_schema "$PROJECT_ID" "$SCHEMA_NAME"; then
        format-echo "SUCCESS" "Schema deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete schema"
        exit 1
      fi
      ;;
    list-schemas)
      if list_schemas "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed schemas successfully"
      else
        format-echo "ERROR" "Failed to list schemas"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Pub/Sub Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
