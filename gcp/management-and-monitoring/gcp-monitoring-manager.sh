#!/usr/bin/env bash
# gcp-monitoring-manager.sh
# Script to manage GCP monitoring resources - alerts, dashboards, uptime checks, and notification channels.

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
ALERT_POLICY_NAME=""
NOTIFICATION_CHANNEL=""
DASHBOARD_NAME=""
UPTIME_CHECK_NAME=""
METRIC_NAME=""
RESOURCE_TYPE=""
THRESHOLD=""
DURATION="60s"
COMPARISON="COMPARISON_GREATER_THAN"
EMAIL=""
SLACK_WEBHOOK=""
DISPLAY_NAME=""
CONFIG_FILE=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Monitoring Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP monitoring resources - alerts, dashboards, uptime checks, and notifications."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-alert\033[0m         Create an alert policy"
  echo -e "  \033[1;33mdelete-alert\033[0m         Delete an alert policy"
  echo -e "  \033[1;33mlist-alerts\033[0m          List all alert policies"
  echo -e "  \033[1;33mcreate-notification\033[0m  Create a notification channel"
  echo -e "  \033[1;33mdelete-notification\033[0m  Delete a notification channel"
  echo -e "  \033[1;33mlist-notifications\033[0m   List all notification channels"
  echo -e "  \033[1;33mcreate-uptime-check\033[0m  Create an uptime check"
  echo -e "  \033[1;33mdelete-uptime-check\033[0m  Delete an uptime check"
  echo -e "  \033[1;33mlist-uptime-checks\033[0m   List all uptime checks"
  echo -e "  \033[1;33mlist-metrics\033[0m         List available metrics"
  echo -e "  \033[1;33mget-metrics\033[0m          Get metric data"
  echo -e "  \033[1;33mcreate-dashboard\033[0m     Create a custom dashboard"
  echo -e "  \033[1;33mlist-dashboards\033[0m      List all dashboards"
  echo -e "  \033[1;33mexport-config\033[0m        Export monitoring configuration"
  echo -e "  \033[1;33mimport-config\033[0m        Import monitoring configuration"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--alert-policy <name>\033[0m        (Required for alert actions) Alert policy name"
  echo -e "  \033[1;33m--notification-channel <id>\033[0m  (Optional) Notification channel ID"
  echo -e "  \033[1;33m--dashboard <name>\033[0m           (Optional) Dashboard name"
  echo -e "  \033[1;33m--uptime-check <name>\033[0m        (Required for uptime actions) Uptime check name"
  echo -e "  \033[1;33m--metric <name>\033[0m              (Optional) Metric name for alerts/queries"
  echo -e "  \033[1;33m--resource-type <type>\033[0m       (Optional) Resource type filter"
  echo -e "  \033[1;33m--threshold <value>\033[0m          (Optional) Alert threshold value"
  echo -e "  \033[1;33m--duration <duration>\033[0m        (Optional) Alert duration (default: 60s)"
  echo -e "  \033[1;33m--comparison <type>\033[0m          (Optional) Comparison type (default: COMPARISON_GREATER_THAN)"
  echo -e "  \033[1;33m--email <email>\033[0m              (Optional) Email for notifications"
  echo -e "  \033[1;33m--slack-webhook <url>\033[0m        (Optional) Slack webhook URL"
  echo -e "  \033[1;33m--display-name <name>\033[0m        (Optional) Display name for resources"
  echo -e "  \033[1;33m--config-file <path>\033[0m         (Optional) Configuration file path"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-alerts --project my-project"
  echo "  $0 create-notification --project my-project --email admin@example.com --display-name 'Admin Email'"
  echo "  $0 create-alert --project my-project --alert-policy 'High CPU' --metric 'compute.googleapis.com/instance/cpu/utilization' --threshold 0.8"
  echo "  $0 create-uptime-check --project my-project --uptime-check 'Website Check' --display-name 'https://example.com'"
  echo "  $0 export-config --project my-project --config-file monitoring-config.json"
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
      --alert-policy)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No alert policy name provided after --alert-policy."
          usage
        fi
        ALERT_POLICY_NAME="$2"
        shift 2
        ;;
      --notification-channel)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No notification channel provided after --notification-channel."
          usage
        fi
        NOTIFICATION_CHANNEL="$2"
        shift 2
        ;;
      --dashboard)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No dashboard name provided after --dashboard."
          usage
        fi
        DASHBOARD_NAME="$2"
        shift 2
        ;;
      --uptime-check)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No uptime check name provided after --uptime-check."
          usage
        fi
        UPTIME_CHECK_NAME="$2"
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
      --resource-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No resource type provided after --resource-type."
          usage
        fi
        RESOURCE_TYPE="$2"
        shift 2
        ;;
      --threshold)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No threshold provided after --threshold."
          usage
        fi
        THRESHOLD="$2"
        shift 2
        ;;
      --duration)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No duration provided after --duration."
          usage
        fi
        DURATION="$2"
        shift 2
        ;;
      --comparison)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No comparison type provided after --comparison."
          usage
        fi
        COMPARISON="$2"
        shift 2
        ;;
      --email)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No email provided after --email."
          usage
        fi
        EMAIL="$2"
        shift 2
        ;;
      --slack-webhook)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No slack webhook provided after --slack-webhook."
          usage
        fi
        SLACK_WEBHOOK="$2"
        shift 2
        ;;
      --display-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No display name provided after --display-name."
          usage
        fi
        DISPLAY_NAME="$2"
        shift 2
        ;;
      --config-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No config file provided after --config-file."
          usage
        fi
        CONFIG_FILE="$2"
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

#=====================================================================
# ALERT POLICY FUNCTIONS
#=====================================================================
# Function to create alert policy
create_alert_policy() {
  local project="$1"
  local policy_name="$2"
  
  format-echo "INFO" "Creating alert policy: $policy_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create alert policy:"
    format-echo "INFO" "  Name: $policy_name"
    [ -n "$METRIC_NAME" ] && format-echo "INFO" "  Metric: $METRIC_NAME"
    [ -n "$THRESHOLD" ] && format-echo "INFO" "  Threshold: $THRESHOLD"
    return 0
  fi
  
  # Create temporary policy file
  local policy_file="/tmp/alert-policy-$$.json"
  cat > "$policy_file" << EOF
{
  "displayName": "$policy_name",
  "conditions": [
    {
      "displayName": "$policy_name condition",
      "conditionThreshold": {
        "filter": "metric.type=\"${METRIC_NAME:-compute.googleapis.com/instance/cpu/utilization}\"",
        "comparison": "$COMPARISON",
        "thresholdValue": ${THRESHOLD:-0.8},
        "duration": "$DURATION"
      }
    }
  ],
  "enabled": true,
  "combiner": "OR"
}
EOF
  
  if [ -n "$NOTIFICATION_CHANNEL" ]; then
    # Add notification channels to policy
    local temp_file="/tmp/policy-with-notifications-$$.json"
    jq --arg channel "$NOTIFICATION_CHANNEL" '.notificationChannels = [$channel]' "$policy_file" > "$temp_file"
    mv "$temp_file" "$policy_file"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Policy configuration:"
    cat "$policy_file"
  fi
  
  if ! gcloud alpha monitoring policies create \
    --project="$project" \
    --policy-from-file="$policy_file"; then
    format-echo "ERROR" "Failed to create alert policy: $policy_name"
    rm -f "$policy_file"
    return 1
  fi
  
  rm -f "$policy_file"
  format-echo "SUCCESS" "Created alert policy: $policy_name"
  return 0
}

# Function to delete alert policy
delete_alert_policy() {
  local project="$1"
  local policy_name="$2"
  
  format-echo "INFO" "Deleting alert policy: $policy_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete alert policy: $policy_name"
    return 0
  fi
  
  # Get policy ID by name
  local policy_id
  if ! policy_id=$(gcloud alpha monitoring policies list \
    --project="$project" \
    --filter="displayName:$policy_name" \
    --format="value(name)" 2>/dev/null | head -1); then
    format-echo "ERROR" "Failed to find alert policy: $policy_name"
    return 1
  fi
  
  if [ -z "$policy_id" ]; then
    format-echo "ERROR" "Alert policy not found: $policy_name"
    return 1
  fi
  
  if ! gcloud alpha monitoring policies delete "$policy_id" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete alert policy: $policy_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted alert policy: $policy_name"
  return 0
}

# Function to list alert policies
list_alert_policies() {
  local project="$1"
  
  format-echo "INFO" "Listing alert policies in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list alert policies"
    return 0
  fi
  
  if ! gcloud alpha monitoring policies list \
    --project="$project" \
    --format="table(displayName,enabled,combiner,conditions.len():label=CONDITIONS)"; then
    format-echo "ERROR" "Failed to list alert policies"
    return 1
  fi
  
  return 0
}

#=====================================================================
# NOTIFICATION CHANNEL FUNCTIONS
#=====================================================================
# Function to create notification channel
create_notification_channel() {
  local project="$1"
  
  format-echo "INFO" "Creating notification channel"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create notification channel:"
    [ -n "$EMAIL" ] && format-echo "INFO" "  Email: $EMAIL"
    [ -n "$SLACK_WEBHOOK" ] && format-echo "INFO" "  Slack webhook: $SLACK_WEBHOOK"
    return 0
  fi
  
  local channel_file="/tmp/notification-channel-$$.json"
  
  if [ -n "$EMAIL" ]; then
    cat > "$channel_file" << EOF
{
  "type": "email",
  "displayName": "${DISPLAY_NAME:-Email Notification}",
  "labels": {
    "email_address": "$EMAIL"
  },
  "enabled": true
}
EOF
  elif [ -n "$SLACK_WEBHOOK" ]; then
    cat > "$channel_file" << EOF
{
  "type": "slack",
  "displayName": "${DISPLAY_NAME:-Slack Notification}",
  "labels": {
    "url": "$SLACK_WEBHOOK"
  },
  "enabled": true
}
EOF
  else
    format-echo "ERROR" "Either --email or --slack-webhook must be provided"
    return 1
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Notification channel configuration:"
    cat "$channel_file"
  fi
  
  if ! gcloud alpha monitoring channels create \
    --project="$project" \
    --channel-content-from-file="$channel_file"; then
    format-echo "ERROR" "Failed to create notification channel"
    rm -f "$channel_file"
    return 1
  fi
  
  rm -f "$channel_file"
  format-echo "SUCCESS" "Created notification channel"
  return 0
}

# Function to list notification channels
list_notification_channels() {
  local project="$1"
  
  format-echo "INFO" "Listing notification channels in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list notification channels"
    return 0
  fi
  
  if ! gcloud alpha monitoring channels list \
    --project="$project" \
    --format="table(displayName,type,enabled,labels.email_address,labels.url)"; then
    format-echo "ERROR" "Failed to list notification channels"
    return 1
  fi
  
  return 0
}

#=====================================================================
# UPTIME CHECK FUNCTIONS
#=====================================================================
# Function to create uptime check
create_uptime_check() {
  local project="$1"
  local check_name="$2"
  local url="${DISPLAY_NAME:-https://example.com}"
  
  format-echo "INFO" "Creating uptime check: $check_name for URL: $url"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create uptime check:"
    format-echo "INFO" "  Name: $check_name"
    format-echo "INFO" "  URL: $url"
    return 0
  fi
  
  local check_file="/tmp/uptime-check-$$.json"
  cat > "$check_file" << EOF
{
  "displayName": "$check_name",
  "httpCheck": {
    "path": "/",
    "port": 443,
    "useSsl": true
  },
  "monitoredResource": {
    "type": "uptime_url",
    "labels": {
      "project_id": "$project",
      "host": "$(echo "$url" | sed 's|https\?://||' | sed 's|/.*||')"
    }
  },
  "timeout": "10s",
  "period": "60s"
}
EOF
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Uptime check configuration:"
    cat "$check_file"
  fi
  
  if ! gcloud monitoring uptime create \
    --project="$project" \
    --config-from-file="$check_file"; then
    format-echo "ERROR" "Failed to create uptime check: $check_name"
    rm -f "$check_file"
    return 1
  fi
  
  rm -f "$check_file"
  format-echo "SUCCESS" "Created uptime check: $check_name"
  return 0
}

# Function to list uptime checks
list_uptime_checks() {
  local project="$1"
  
  format-echo "INFO" "Listing uptime checks in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list uptime checks"
    return 0
  fi
  
  if ! gcloud monitoring uptime list \
    --project="$project" \
    --format="table(displayName,timeout,period,httpCheck.path)"; then
    format-echo "ERROR" "Failed to list uptime checks"
    return 1
  fi
  
  return 0
}

#=====================================================================
# METRICS FUNCTIONS
#=====================================================================
# Function to list metrics
list_metrics() {
  local project="$1"
  
  format-echo "INFO" "Listing available metrics in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list metrics"
    return 0
  fi
  
  local filter=""
  if [ -n "$RESOURCE_TYPE" ]; then
    filter="--filter=resource.type=$RESOURCE_TYPE"
  fi
  
  if ! gcloud logging metrics list \
    --project="$project" \
    "$filter" \
    --format="table(name,description,filter)"; then
    format-echo "WARNING" "Failed to list custom metrics, trying built-in metrics"
    
    # List some common built-in metrics
    echo "Common GCP Metrics:"
    echo "- compute.googleapis.com/instance/cpu/utilization"
    echo "- compute.googleapis.com/instance/disk/read_bytes_count"
    echo "- compute.googleapis.com/instance/disk/write_bytes_count"
    echo "- compute.googleapis.com/instance/network/received_bytes_count"
    echo "- compute.googleapis.com/instance/network/sent_bytes_count"
    echo "- storage.googleapis.com/api/request_count"
    echo "- cloudsql.googleapis.com/database/cpu/utilization"
  fi
  
  return 0
}

#=====================================================================
# CONFIGURATION EXPORT/IMPORT FUNCTIONS
#=====================================================================
# Function to export monitoring configuration
export_monitoring_config() {
  local project="$1"
  local config_file="${2:-monitoring-config-$(date +%Y%m%d-%H%M%S).json}"
  
  format-echo "INFO" "Exporting monitoring configuration to: $config_file"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would export configuration to: $config_file"
    return 0
  fi
  
  local temp_dir="/tmp/monitoring-export-$$"
  mkdir -p "$temp_dir"
  
  # Export alert policies
  format-echo "INFO" "Exporting alert policies..."
  if gcloud alpha monitoring policies list \
    --project="$project" \
    --format="json" > "$temp_dir/alert-policies.json" 2>/dev/null; then
    format-echo "SUCCESS" "Exported alert policies"
  else
    format-echo "WARNING" "Failed to export alert policies"
    echo "[]" > "$temp_dir/alert-policies.json"
  fi
  
  # Export notification channels
  format-echo "INFO" "Exporting notification channels..."
  if gcloud alpha monitoring channels list \
    --project="$project" \
    --format="json" > "$temp_dir/notification-channels.json" 2>/dev/null; then
    format-echo "SUCCESS" "Exported notification channels"
  else
    format-echo "WARNING" "Failed to export notification channels"
    echo "[]" > "$temp_dir/notification-channels.json"
  fi
  
  # Export uptime checks
  format-echo "INFO" "Exporting uptime checks..."
  if gcloud monitoring uptime list \
    --project="$project" \
    --format="json" > "$temp_dir/uptime-checks.json" 2>/dev/null; then
    format-echo "SUCCESS" "Exported uptime checks"
  else
    format-echo "WARNING" "Failed to export uptime checks"
    echo "[]" > "$temp_dir/uptime-checks.json"
  fi
  
  # Combine all exports into single file
  cat > "$config_file" << EOF
{
  "project": "$project",
  "exportDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "alertPolicies": $(cat "$temp_dir/alert-policies.json"),
  "notificationChannels": $(cat "$temp_dir/notification-channels.json"),
  "uptimeChecks": $(cat "$temp_dir/uptime-checks.json")
}
EOF
  
  rm -rf "$temp_dir"
  format-echo "SUCCESS" "Exported monitoring configuration to: $config_file"
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
  
  print_with_separator "GCP Monitoring Manager Script"
  format-echo "INFO" "Starting GCP Monitoring Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Monitoring Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Monitoring Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Monitoring Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-alert|delete-alert)
      if [ -z "$ALERT_POLICY_NAME" ]; then
        format-echo "ERROR" "Alert policy name is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-uptime-check|delete-uptime-check)
      if [ -z "$UPTIME_CHECK_NAME" ]; then
        format-echo "ERROR" "Uptime check name is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-notification)
      if [ -z "$EMAIL" ] && [ -z "$SLACK_WEBHOOK" ]; then
        format-echo "ERROR" "Either --email or --slack-webhook is required for creating notification channel"
        exit 1
      fi
      ;;
    import-config)
      if [ -z "$CONFIG_FILE" ]; then
        format-echo "ERROR" "Config file is required for import action"
        exit 1
      fi
      ;;
    list-alerts|list-notifications|list-uptime-checks|list-metrics|export-config)
      # No additional requirements for list actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-alert, delete-alert, list-alerts, create-notification, delete-notification, list-notifications, create-uptime-check, delete-uptime-check, list-uptime-checks, list-metrics, get-metrics, create-dashboard, list-dashboards, export-config, import-config"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-alert)
      if create_alert_policy "$PROJECT_ID" "$ALERT_POLICY_NAME"; then
        format-echo "SUCCESS" "Alert policy creation completed successfully"
      else
        format-echo "ERROR" "Failed to create alert policy"
        exit 1
      fi
      ;;
    delete-alert)
      if delete_alert_policy "$PROJECT_ID" "$ALERT_POLICY_NAME"; then
        format-echo "SUCCESS" "Alert policy deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete alert policy"
        exit 1
      fi
      ;;
    list-alerts)
      if list_alert_policies "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed alert policies successfully"
      else
        format-echo "ERROR" "Failed to list alert policies"
        exit 1
      fi
      ;;
    create-notification)
      if create_notification_channel "$PROJECT_ID"; then
        format-echo "SUCCESS" "Notification channel creation completed successfully"
      else
        format-echo "ERROR" "Failed to create notification channel"
        exit 1
      fi
      ;;
    list-notifications)
      if list_notification_channels "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed notification channels successfully"
      else
        format-echo "ERROR" "Failed to list notification channels"
        exit 1
      fi
      ;;
    create-uptime-check)
      if create_uptime_check "$PROJECT_ID" "$UPTIME_CHECK_NAME"; then
        format-echo "SUCCESS" "Uptime check creation completed successfully"
      else
        format-echo "ERROR" "Failed to create uptime check"
        exit 1
      fi
      ;;
    list-uptime-checks)
      if list_uptime_checks "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed uptime checks successfully"
      else
        format-echo "ERROR" "Failed to list uptime checks"
        exit 1
      fi
      ;;
    list-metrics)
      if list_metrics "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed metrics successfully"
      else
        format-echo "ERROR" "Failed to list metrics"
        exit 1
      fi
      ;;
    export-config)
      if export_monitoring_config "$PROJECT_ID" "$CONFIG_FILE"; then
        format-echo "SUCCESS" "Configuration export completed successfully"
      else
        format-echo "ERROR" "Failed to export configuration"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Monitoring Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
