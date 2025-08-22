#!/usr/bin/env bash
# gcp-logging-manager.sh
# Script to manage GCP Cloud Logging operations, log entries, sinks, and metrics.

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
SINK_NAME=""
SINK_DESTINATION=""
SINK_FILTER=""
LOG_NAME=""
RESOURCE_TYPE=""
RESOURCE_LABELS=""
LOG_SEVERITY="INFO"
LOG_MESSAGE=""
LOG_JSON_PAYLOAD=""
LOG_ENTRIES_FILTER=""
LOG_ENTRIES_LIMIT="50"
LOG_ENTRIES_ORDER="timestamp desc"
BUCKET_NAME=""
TOPIC_NAME=""
DATASET_ID=""
TABLE_ID=""
METRIC_NAME=""
METRIC_FILTER=""
METRIC_DESCRIPTION=""
EXCLUSION_NAME=""
EXCLUSION_FILTER=""
EXCLUSION_DESCRIPTION=""
RETENTION_DAYS="30"
LOG_ROUTER_NAME=""
START_TIME=""
END_TIME=""
TIMESTAMP=""
FORMAT="json"
UNIQUE_WRITER_IDENTITY=false
INCLUDE_CHILDREN=false
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Logging Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Cloud Logging operations, log entries, sinks, and metrics."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mlist-logs\033[0m                List available logs"
  echo -e "  \033[1;33mread-logs\033[0m                Read log entries"
  echo -e "  \033[1;33mwrite-log\033[0m                Write log entry"
  echo -e "  \033[1;33mdelete-log\033[0m               Delete log"
  echo -e "  \033[1;33mcreate-sink\033[0m              Create log sink"
  echo -e "  \033[1;33mupdate-sink\033[0m              Update log sink"
  echo -e "  \033[1;33mdelete-sink\033[0m              Delete log sink"
  echo -e "  \033[1;33mlist-sinks\033[0m               List log sinks"
  echo -e "  \033[1;33mget-sink\033[0m                 Get sink details"
  echo -e "  \033[1;33mcreate-metric\033[0m            Create log-based metric"
  echo -e "  \033[1;33mupdate-metric\033[0m            Update log-based metric"
  echo -e "  \033[1;33mdelete-metric\033[0m            Delete log-based metric"
  echo -e "  \033[1;33mlist-metrics\033[0m             List log-based metrics"
  echo -e "  \033[1;33mget-metric\033[0m               Get metric details"
  echo -e "  \033[1;33mcreate-exclusion\033[0m         Create log exclusion"
  echo -e "  \033[1;33mupdate-exclusion\033[0m         Update log exclusion"
  echo -e "  \033[1;33mdelete-exclusion\033[0m         Delete log exclusion"
  echo -e "  \033[1;33mlist-exclusions\033[0m          List log exclusions"
  echo -e "  \033[1;33mget-exclusion\033[0m            Get exclusion details"
  echo -e "  \033[1;33mset-retention\033[0m            Set log retention policy"
  echo -e "  \033[1;33mget-retention\033[0m            Get log retention policy"
  echo -e "  \033[1;33mexport-logs\033[0m              Export logs to Cloud Storage"
  echo -e "  \033[1;33mstream-logs\033[0m              Stream logs in real-time"
  echo -e "  \033[1;33manalyze-logs\033[0m             Analyze log patterns"
  echo -e "  \033[1;33mgenerate-report\033[0m          Generate log analysis report"
  echo -e "  \033[1;33mtest-filter\033[0m              Test log filter expression"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--sink <name>\033[0m                    (Required for sink actions) Sink name"
  echo -e "  \033[1;33m--destination <dest>\033[0m             (Required for sink creation) Sink destination"
  echo -e "  \033[1;33m--filter <filter>\033[0m                (Optional) Log filter expression"
  echo -e "  \033[1;33m--log-name <name>\033[0m                (Required for log actions) Log name"
  echo -e "  \033[1;33m--resource-type <type>\033[0m           (Optional) Resource type"
  echo -e "  \033[1;33m--resource-labels <labels>\033[0m       (Optional) Resource labels (key=value,key2=value2)"
  echo -e "  \033[1;33m--severity <level>\033[0m               (Optional) Log severity: DEBUG, INFO, WARNING, ERROR, CRITICAL (default: INFO)"
  echo -e "  \033[1;33m--message <text>\033[0m                 (Required for write-log) Log message"
  echo -e "  \033[1;33m--json-payload <json>\033[0m            (Optional) JSON payload for log entry"
  echo -e "  \033[1;33m--entries-filter <filter>\033[0m        (Optional) Filter for reading log entries"
  echo -e "  \033[1;33m--limit <count>\033[0m                  (Optional) Limit number of log entries (default: 50)"
  echo -e "  \033[1;33m--order <order>\033[0m                  (Optional) Order of log entries (default: timestamp desc)"
  echo -e "  \033[1;33m--bucket <name>\033[0m                  (Optional) Cloud Storage bucket for export"
  echo -e "  \033[1;33m--topic <name>\033[0m                   (Optional) Pub/Sub topic name"
  echo -e "  \033[1;33m--dataset <id>\033[0m                   (Optional) BigQuery dataset ID"
  echo -e "  \033[1;33m--table <id>\033[0m                     (Optional) BigQuery table ID"
  echo -e "  \033[1;33m--metric <name>\033[0m                  (Required for metric actions) Metric name"
  echo -e "  \033[1;33m--metric-filter <filter>\033[0m         (Required for metric creation) Metric filter"
  echo -e "  \033[1;33m--metric-description <desc>\033[0m      (Optional) Metric description"
  echo -e "  \033[1;33m--exclusion <name>\033[0m               (Required for exclusion actions) Exclusion name"
  echo -e "  \033[1;33m--exclusion-filter <filter>\033[0m      (Required for exclusion creation) Exclusion filter"
  echo -e "  \033[1;33m--exclusion-description <desc>\033[0m   (Optional) Exclusion description"
  echo -e "  \033[1;33m--retention-days <days>\033[0m          (Optional) Log retention in days (default: 30)"
  echo -e "  \033[1;33m--start-time <time>\033[0m              (Optional) Start time for log queries (RFC3339)"
  echo -e "  \033[1;33m--end-time <time>\033[0m                (Optional) End time for log queries (RFC3339)"
  echo -e "  \033[1;33m--format <format>\033[0m                (Optional) Output format: json, table, csv (default: json)"
  echo -e "  \033[1;33m--unique-writer-identity\033[0m         (Optional) Use unique writer identity for sink"
  echo -e "  \033[1;33m--include-children\033[0m               (Optional) Include child resources in query"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mSeverity Levels:\033[0m"
  echo "  DEBUG, INFO, WARNING, ERROR, CRITICAL"
  echo
  echo -e "\033[1;34mDestination Types:\033[0m"
  echo "  Cloud Storage: gs://bucket-name"
  echo "  BigQuery: bigquery.googleapis.com/projects/PROJECT/datasets/DATASET"
  echo "  Pub/Sub: pubsub.googleapis.com/projects/PROJECT/topics/TOPIC"
  echo "  Cloud Logging: logging.googleapis.com/projects/PROJECT/logs/LOG"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-logs --project my-project"
  echo "  $0 read-logs --project my-project --entries-filter 'severity>=ERROR' --limit 100"
  echo "  $0 create-sink --project my-project --sink error-logs --destination gs://my-bucket --filter 'severity>=ERROR'"
  echo "  $0 write-log --project my-project --log-name application --message 'Test message' --severity INFO"
  echo "  $0 create-metric --project my-project --metric error-count --metric-filter 'severity>=ERROR'"
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
      --sink)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No sink name provided after --sink."
          usage
        fi
        SINK_NAME="$2"
        shift 2
        ;;
      --destination)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No destination provided after --destination."
          usage
        fi
        SINK_DESTINATION="$2"
        shift 2
        ;;
      --filter)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No filter provided after --filter."
          usage
        fi
        SINK_FILTER="$2"
        shift 2
        ;;
      --log-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log name provided after --log-name."
          usage
        fi
        LOG_NAME="$2"
        shift 2
        ;;
      --resource-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No resource type provided after --resource-type."
          usage
        fi
        RESOURCE_TYPE="$2"
        shift 2
        ;;
      --resource-labels)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No resource labels provided after --resource-labels."
          usage
        fi
        RESOURCE_LABELS="$2"
        shift 2
        ;;
      --severity)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No severity provided after --severity."
          usage
        fi
        LOG_SEVERITY="$2"
        shift 2
        ;;
      --message)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No message provided after --message."
          usage
        fi
        LOG_MESSAGE="$2"
        shift 2
        ;;
      --json-payload)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No JSON payload provided after --json-payload."
          usage
        fi
        LOG_JSON_PAYLOAD="$2"
        shift 2
        ;;
      --entries-filter)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No entries filter provided after --entries-filter."
          usage
        fi
        LOG_ENTRIES_FILTER="$2"
        shift 2
        ;;
      --limit)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No limit provided after --limit."
          usage
        fi
        LOG_ENTRIES_LIMIT="$2"
        shift 2
        ;;
      --order)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No order provided after --order."
          usage
        fi
        LOG_ENTRIES_ORDER="$2"
        shift 2
        ;;
      --bucket)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No bucket provided after --bucket."
          usage
        fi
        BUCKET_NAME="$2"
        shift 2
        ;;
      --topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No topic provided after --topic."
          usage
        fi
        TOPIC_NAME="$2"
        shift 2
        ;;
      --dataset)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No dataset provided after --dataset."
          usage
        fi
        DATASET_ID="$2"
        shift 2
        ;;
      --table)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No table provided after --table."
          usage
        fi
        TABLE_ID="$2"
        shift 2
        ;;
      --metric)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No metric name provided after --metric."
          usage
        fi
        METRIC_NAME="$2"
        shift 2
        ;;
      --metric-filter)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No metric filter provided after --metric-filter."
          usage
        fi
        METRIC_FILTER="$2"
        shift 2
        ;;
      --metric-description)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No metric description provided after --metric-description."
          usage
        fi
        METRIC_DESCRIPTION="$2"
        shift 2
        ;;
      --exclusion)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No exclusion name provided after --exclusion."
          usage
        fi
        EXCLUSION_NAME="$2"
        shift 2
        ;;
      --exclusion-filter)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No exclusion filter provided after --exclusion-filter."
          usage
        fi
        EXCLUSION_FILTER="$2"
        shift 2
        ;;
      --exclusion-description)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No exclusion description provided after --exclusion-description."
          usage
        fi
        EXCLUSION_DESCRIPTION="$2"
        shift 2
        ;;
      --retention-days)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No retention days provided after --retention-days."
          usage
        fi
        RETENTION_DAYS="$2"
        shift 2
        ;;
      --start-time)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No start time provided after --start-time."
          usage
        fi
        START_TIME="$2"
        shift 2
        ;;
      --end-time)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No end time provided after --end-time."
          usage
        fi
        END_TIME="$2"
        shift 2
        ;;
      --format)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No format provided after --format."
          usage
        fi
        FORMAT="$2"
        shift 2
        ;;
      --unique-writer-identity)
        UNIQUE_WRITER_IDENTITY=true
        shift
        ;;
      --include-children)
        INCLUDE_CHILDREN=true
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

# Function to validate log filter
validate_filter() {
  local filter="$1"
  
  if [ -z "$filter" ]; then
    return 0
  fi
  
  # Basic validation - check for common filter patterns
  if [[ ! "$filter" =~ (severity|timestamp|resource|labels|textPayload|jsonPayload) ]]; then
    format-echo "WARNING" "Filter may not be valid. Common fields: severity, timestamp, resource, labels, textPayload, jsonPayload"
  fi
  
  return 0
}

#=====================================================================
# LOG OPERATIONS
#=====================================================================
# Function to list logs
list_logs() {
  local project="$1"
  
  format-echo "INFO" "Listing available logs"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list logs in project: $project"
    return 0
  fi
  
  if ! gcloud logging logs list \
    --project="$project" \
    --format="table(name)"; then
    format-echo "ERROR" "Failed to list logs"
    return 1
  fi
  
  return 0
}

# Function to read log entries
read_logs() {
  local project="$1"
  
  format-echo "INFO" "Reading log entries"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would read logs with filter: ${LOG_ENTRIES_FILTER:-none}"
    return 0
  fi
  
  local read_cmd="gcloud logging read"
  
  if [ -n "$LOG_ENTRIES_FILTER" ]; then
    read_cmd+=" \"$LOG_ENTRIES_FILTER\""
  else
    read_cmd+=" \"\""
  fi
  
  read_cmd+=" --project=$project"
  read_cmd+=" --limit=$LOG_ENTRIES_LIMIT"
  read_cmd+=" --order=\"$LOG_ENTRIES_ORDER\""
  read_cmd+=" --format=$FORMAT"
  
  if [ "$INCLUDE_CHILDREN" = true ]; then
    read_cmd+=" --include-children"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $read_cmd"
  fi
  
  if ! eval "$read_cmd"; then
    format-echo "ERROR" "Failed to read log entries"
    return 1
  fi
  
  return 0
}

# Function to write log entry
write_log() {
  local project="$1"
  local log_name="$2"
  local message="$3"
  
  format-echo "INFO" "Writing log entry to: $log_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would write log entry:"
    format-echo "INFO" "  Log: $log_name"
    format-echo "INFO" "  Message: $message"
    format-echo "INFO" "  Severity: $LOG_SEVERITY"
    return 0
  fi
  
  local write_cmd="gcloud logging write $log_name \"$message\""
  write_cmd+=" --project=$project"
  write_cmd+=" --severity=$LOG_SEVERITY"
  
  if [ -n "$RESOURCE_TYPE" ]; then
    write_cmd+=" --resource=$RESOURCE_TYPE"
  fi
  
  if [ -n "$LOG_JSON_PAYLOAD" ]; then
    write_cmd+=" --payload-type=json --payload=\"$LOG_JSON_PAYLOAD\""
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $write_cmd"
  fi
  
  if ! eval "$write_cmd"; then
    format-echo "ERROR" "Failed to write log entry"
    return 1
  fi
  
  format-echo "SUCCESS" "Wrote log entry to: $log_name"
  return 0
}

# Function to delete log
delete_log() {
  local project="$1"
  local log_name="$2"
  
  format-echo "INFO" "Deleting log: $log_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete log: $log_name"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the log '$log_name' and all its entries."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud logging logs delete "$log_name" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete log: $log_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted log: $log_name"
  return 0
}

#=====================================================================
# SINK MANAGEMENT
#=====================================================================
# Function to create log sink
create_sink() {
  local project="$1"
  local sink_name="$2"
  local destination="$3"
  
  format-echo "INFO" "Creating log sink: $sink_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create log sink:"
    format-echo "INFO" "  Name: $sink_name"
    format-echo "INFO" "  Destination: $destination"
    format-echo "INFO" "  Filter: ${SINK_FILTER:-none}"
    return 0
  fi
  
  local create_cmd="gcloud logging sinks create $sink_name $destination"
  create_cmd+=" --project=$project"
  
  if [ -n "$SINK_FILTER" ]; then
    create_cmd+=" --log-filter=\"$SINK_FILTER\""
  fi
  
  if [ "$UNIQUE_WRITER_IDENTITY" = true ]; then
    create_cmd+=" --use-partitioned-tables"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create log sink: $sink_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created log sink: $sink_name"
  
  # Display service account for permissions
  format-echo "INFO" "Grant the following service account write permissions to the destination:"
  gcloud logging sinks describe "$sink_name" --project="$project" --format="value(writerIdentity)" 2>/dev/null || true
  
  return 0
}

# Function to update log sink
update_sink() {
  local project="$1"
  local sink_name="$2"
  
  format-echo "INFO" "Updating log sink: $sink_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would update log sink: $sink_name"
    return 0
  fi
  
  local update_cmd="gcloud logging sinks update $sink_name"
  update_cmd+=" --project=$project"
  
  if [ -n "$SINK_DESTINATION" ]; then
    update_cmd+=" $SINK_DESTINATION"
  fi
  
  if [ -n "$SINK_FILTER" ]; then
    update_cmd+=" --log-filter=\"$SINK_FILTER\""
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $update_cmd"
  fi
  
  if ! eval "$update_cmd"; then
    format-echo "ERROR" "Failed to update log sink: $sink_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Updated log sink: $sink_name"
  return 0
}

# Function to delete log sink
delete_sink() {
  local project="$1"
  local sink_name="$2"
  
  format-echo "INFO" "Deleting log sink: $sink_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete log sink: $sink_name"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the log sink '$sink_name'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud logging sinks delete "$sink_name" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete log sink: $sink_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted log sink: $sink_name"
  return 0
}

# Function to list log sinks
list_sinks() {
  local project="$1"
  
  format-echo "INFO" "Listing log sinks"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list log sinks"
    return 0
  fi
  
  if ! gcloud logging sinks list \
    --project="$project" \
    --format="table(name,destination,filter)"; then
    format-echo "ERROR" "Failed to list log sinks"
    return 1
  fi
  
  return 0
}

#=====================================================================
# METRIC MANAGEMENT
#=====================================================================
# Function to create log-based metric
create_metric() {
  local project="$1"
  local metric_name="$2"
  local metric_filter="$3"
  
  format-echo "INFO" "Creating log-based metric: $metric_name"
  
  if ! validate_filter "$metric_filter"; then
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create log-based metric:"
    format-echo "INFO" "  Name: $metric_name"
    format-echo "INFO" "  Filter: $metric_filter"
    return 0
  fi
  
  local create_cmd="gcloud logging metrics create $metric_name"
  create_cmd+=" --project=$project"
  create_cmd+=" --log-filter=\"$metric_filter\""
  
  if [ -n "$METRIC_DESCRIPTION" ]; then
    create_cmd+=" --description=\"$METRIC_DESCRIPTION\""
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create log-based metric: $metric_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created log-based metric: $metric_name"
  return 0
}

# Function to list log-based metrics
list_metrics() {
  local project="$1"
  
  format-echo "INFO" "Listing log-based metrics"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list log-based metrics"
    return 0
  fi
  
  if ! gcloud logging metrics list \
    --project="$project" \
    --format="table(name,description,filter)"; then
    format-echo "ERROR" "Failed to list log-based metrics"
    return 1
  fi
  
  return 0
}

# Function to stream logs in real-time
stream_logs() {
  local project="$1"
  
  format-echo "INFO" "Streaming logs in real-time (Press Ctrl+C to stop)"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would stream logs with filter: ${LOG_ENTRIES_FILTER:-none}"
    return 0
  fi
  
  local stream_cmd="gcloud logging tail"
  
  if [ -n "$LOG_ENTRIES_FILTER" ]; then
    stream_cmd+=" \"$LOG_ENTRIES_FILTER\""
  else
    stream_cmd+=" \"\""
  fi
  
  stream_cmd+=" --project=$project"
  stream_cmd+=" --format=$FORMAT"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $stream_cmd"
  fi
  
  if ! eval "$stream_cmd"; then
    format-echo "ERROR" "Failed to stream logs"
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
  
  print_with_separator "GCP Cloud Logging Manager Script"
  format-echo "INFO" "Starting GCP Cloud Logging Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Cloud Logging Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Cloud Logging Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Cloud Logging Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-sink|update-sink|delete-sink|get-sink)
      if [ -z "$SINK_NAME" ]; then
        format-echo "ERROR" "Sink name is required for action: $ACTION"
        exit 1
      fi
      if [ "$ACTION" = "create-sink" ] && [ -z "$SINK_DESTINATION" ]; then
        format-echo "ERROR" "Sink destination is required for sink creation"
        exit 1
      fi
      ;;
    write-log|delete-log)
      if [ -z "$LOG_NAME" ]; then
        format-echo "ERROR" "Log name is required for action: $ACTION"
        exit 1
      fi
      if [ "$ACTION" = "write-log" ] && [ -z "$LOG_MESSAGE" ]; then
        format-echo "ERROR" "Log message is required for writing log entry"
        exit 1
      fi
      ;;
    create-metric|update-metric|delete-metric|get-metric)
      if [ -z "$METRIC_NAME" ]; then
        format-echo "ERROR" "Metric name is required for action: $ACTION"
        exit 1
      fi
      if [ "$ACTION" = "create-metric" ] && [ -z "$METRIC_FILTER" ]; then
        format-echo "ERROR" "Metric filter is required for metric creation"
        exit 1
      fi
      ;;
    list-logs|read-logs|list-sinks|list-metrics|stream-logs)
      # No additional requirements for these actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: list-logs, read-logs, write-log, create-sink, delete-sink, create-metric, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    list-logs)
      if list_logs "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed logs successfully"
      else
        format-echo "ERROR" "Failed to list logs"
        exit 1
      fi
      ;;
    read-logs)
      if read_logs "$PROJECT_ID"; then
        format-echo "SUCCESS" "Read log entries successfully"
      else
        format-echo "ERROR" "Failed to read log entries"
        exit 1
      fi
      ;;
    write-log)
      if write_log "$PROJECT_ID" "$LOG_NAME" "$LOG_MESSAGE"; then
        format-echo "SUCCESS" "Log entry written successfully"
      else
        format-echo "ERROR" "Failed to write log entry"
        exit 1
      fi
      ;;
    delete-log)
      if delete_log "$PROJECT_ID" "$LOG_NAME"; then
        format-echo "SUCCESS" "Log deleted successfully"
      else
        format-echo "ERROR" "Failed to delete log"
        exit 1
      fi
      ;;
    create-sink)
      if create_sink "$PROJECT_ID" "$SINK_NAME" "$SINK_DESTINATION"; then
        format-echo "SUCCESS" "Log sink created successfully"
      else
        format-echo "ERROR" "Failed to create log sink"
        exit 1
      fi
      ;;
    update-sink)
      if update_sink "$PROJECT_ID" "$SINK_NAME"; then
        format-echo "SUCCESS" "Log sink updated successfully"
      else
        format-echo "ERROR" "Failed to update log sink"
        exit 1
      fi
      ;;
    delete-sink)
      if delete_sink "$PROJECT_ID" "$SINK_NAME"; then
        format-echo "SUCCESS" "Log sink deleted successfully"
      else
        format-echo "ERROR" "Failed to delete log sink"
        exit 1
      fi
      ;;
    list-sinks)
      if list_sinks "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed log sinks successfully"
      else
        format-echo "ERROR" "Failed to list log sinks"
        exit 1
      fi
      ;;
    create-metric)
      if create_metric "$PROJECT_ID" "$METRIC_NAME" "$METRIC_FILTER"; then
        format-echo "SUCCESS" "Log-based metric created successfully"
      else
        format-echo "ERROR" "Failed to create log-based metric"
        exit 1
      fi
      ;;
    list-metrics)
      if list_metrics "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed log-based metrics successfully"
      else
        format-echo "ERROR" "Failed to list log-based metrics"
        exit 1
      fi
      ;;
    stream-logs)
      if stream_logs "$PROJECT_ID"; then
        format-echo "SUCCESS" "Log streaming completed"
      else
        format-echo "ERROR" "Failed to stream logs"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Cloud Logging Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
