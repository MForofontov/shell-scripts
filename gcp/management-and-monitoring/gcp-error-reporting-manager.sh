#!/usr/bin/env bash
# gcp-error-reporting-manager.sh
# Script to manage Google Cloud Error Reporting

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"

#=====================================================================
# DEFAULT VALUES
#=====================================================================
PROJECT_ID=""
COMMAND=""
SERVICE_NAME=""
VERSION=""
ERROR_GROUP_ID=""
TIME_RANGE=""
ORDER_BY=""
ALIGNMENT_PERIOD=""
PAGE_SIZE=""
FILTER=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Error Reporting Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Error Reporting for error tracking and monitoring."
  echo "  Provides capabilities for viewing, analyzing, and managing application errors."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-s, --service SERVICE_NAME\033[0m   Set service name"
  echo -e "  \033[1;33m-v, --version VERSION\033[0m       Set service version"
  echo -e "  \033[1;33m-g, --group ERROR_GROUP_ID\033[0m   Set error group ID"
  echo -e "  \033[1;33m-t, --time-range RANGE\033[0m      Set time range (1h, 24h, 7d, 30d)"
  echo -e "  \033[1;33m--order-by FIELD\033[0m            Set order by field"
  echo -e "  \033[1;33m--alignment-period PERIOD\033[0m   Set alignment period for stats"
  echo -e "  \033[1;33m--page-size SIZE\033[0m            Set page size for results"
  echo -e "  \033[1;33m-f, --filter FILTER\033[0m         Set filter expression"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mlist-groups\033[0m                 List error groups"
  echo -e "  \033[1;36mget-group\033[0m                   Get error group details"
  echo -e "  \033[1;36mlist-events\033[0m                 List error events"
  echo -e "  \033[1;36mget-event\033[0m                   Get error event details"
  echo -e "  \033[1;36mlist-services\033[0m               List services with errors"
  echo -e "  \033[1;36mget-service-stats\033[0m           Get service error statistics"
  echo -e "  \033[1;36mget-stats\033[0m                   Get error statistics"
  echo -e "  \033[1;36mreport-error\033[0m                Report a new error"
  echo -e "  \033[1;36mdelete-events\033[0m               Delete error events"
  echo -e "  \033[1;36mstatus\033[0m                      Check Error Reporting status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Error Reporting API"
  echo -e "  \033[1;36mget-config\033[0m                  Get Error Reporting configuration"
  echo -e "  \033[1;36msetup-client\033[0m                Show client setup instructions"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project list-groups"
  echo "  $0 -p my-project -s my-service list-events"
  echo "  $0 -p my-project -g group-123 get-group"
  echo "  $0 -p my-project -t 24h get-stats"
  echo "  $0 -p my-project -s my-service get-service-stats"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -p|--project)
        if [[ -n "${2:-}" ]]; then
          PROJECT_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --project"
          usage
        fi
        ;;
      -s|--service)
        if [[ -n "${2:-}" ]]; then
          SERVICE_NAME="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --service"
          usage
        fi
        ;;
      -v|--version)
        if [[ -n "${2:-}" ]]; then
          VERSION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --version"
          usage
        fi
        ;;
      -g|--group)
        if [[ -n "${2:-}" ]]; then
          ERROR_GROUP_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --group"
          usage
        fi
        ;;
      -t|--time-range)
        if [[ -n "${2:-}" ]]; then
          TIME_RANGE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --time-range"
          usage
        fi
        ;;
      --order-by)
        if [[ -n "${2:-}" ]]; then
          ORDER_BY="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --order-by"
          usage
        fi
        ;;
      --alignment-period)
        if [[ -n "${2:-}" ]]; then
          ALIGNMENT_PERIOD="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --alignment-period"
          usage
        fi
        ;;
      --page-size)
        if [[ -n "${2:-}" ]]; then
          PAGE_SIZE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --page-size"
          usage
        fi
        ;;
      -f|--filter)
        if [[ -n "${2:-}" ]]; then
          FILTER="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --filter"
          usage
        fi
        ;;
      -h|--help)
        usage
        ;;
      *)
        if [[ -z "$COMMAND" ]]; then
          COMMAND="$1"
          shift
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

#=====================================================================
# AUTHENTICATION AND PROJECT SETUP
#=====================================================================
check_auth() {
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    format-echo "ERROR" "Not authenticated with gcloud. Please run 'gcloud auth login'"
    exit 1
  fi
}

set_project() {
  if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [[ -z "$PROJECT_ID" ]]; then
      format-echo "ERROR" "No project set. Use -p flag or run 'gcloud config set project PROJECT_ID'"
      exit 1
    fi
  fi
  
  format-echo "INFO" "Using project: $PROJECT_ID"
  gcloud config set project "$PROJECT_ID" >/dev/null 2>&1
}

enable_apis() {
  format-echo "INFO" "Enabling required APIs..."
  
  local apis=(
    "clouderrorreporting.googleapis.com"
    "logging.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# ERROR REPORTING OPERATIONS
#=====================================================================
list_groups() {
  format-echo "INFO" "Listing error groups..."
  
  local cmd="gcloud error-reporting groups list --project='$PROJECT_ID'"
  
  if [[ -n "$SERVICE_NAME" ]]; then
    cmd="$cmd --filter='service=\"$SERVICE_NAME\"'"
  fi
  
  if [[ -n "$TIME_RANGE" ]]; then
    cmd="$cmd --time-range='$TIME_RANGE'"
  fi
  
  if [[ -n "$ORDER_BY" ]]; then
    cmd="$cmd --sort-by='$ORDER_BY'"
  fi
  
  if [[ -n "$PAGE_SIZE" ]]; then
    cmd="$cmd --page-size='$PAGE_SIZE'"
  fi
  
  print_with_separator "Error Groups"
  eval "$cmd"
  print_with_separator "End of Error Groups"
}

get_group() {
  format-echo "INFO" "Getting error group details..."
  
  if [[ -z "$ERROR_GROUP_ID" ]]; then
    format-echo "ERROR" "Error group ID is required"
    exit 1
  fi
  
  print_with_separator "Error Group: $ERROR_GROUP_ID"
  gcloud error-reporting groups describe "$ERROR_GROUP_ID" --project="$PROJECT_ID"
  print_with_separator "End of Error Group Details"
}

list_events() {
  format-echo "INFO" "Listing error events..."
  
  local cmd="gcloud error-reporting events list --project='$PROJECT_ID'"
  
  if [[ -n "$SERVICE_NAME" ]]; then
    cmd="$cmd --service='$SERVICE_NAME'"
  fi
  
  if [[ -n "$VERSION" ]]; then
    cmd="$cmd --service-version='$VERSION'"
  fi
  
  if [[ -n "$TIME_RANGE" ]]; then
    cmd="$cmd --time-range='$TIME_RANGE'"
  fi
  
  if [[ -n "$PAGE_SIZE" ]]; then
    cmd="$cmd --page-size='$PAGE_SIZE'"
  fi
  
  print_with_separator "Error Events"
  eval "$cmd"
  print_with_separator "End of Error Events"
}

get_event() {
  format-echo "INFO" "Getting error event details..."
  
  if [[ -z "$ERROR_GROUP_ID" ]]; then
    format-echo "ERROR" "Error group ID is required to get events"
    exit 1
  fi
  
  print_with_separator "Error Event Details"
  gcloud error-reporting events list --project="$PROJECT_ID" --group-id="$ERROR_GROUP_ID" --limit=1 --format="yaml"
  print_with_separator "End of Error Event Details"
}

list_services() {
  format-echo "INFO" "Listing services with errors..."
  
  print_with_separator "Services with Errors"
  gcloud error-reporting groups list --project="$PROJECT_ID" --format="table(service)" | sort -u
  print_with_separator "End of Services"
}

get_service_stats() {
  format-echo "INFO" "Getting service error statistics..."
  
  if [[ -z "$SERVICE_NAME" ]]; then
    format-echo "ERROR" "Service name is required"
    exit 1
  fi
  
  print_with_separator "Service Error Statistics: $SERVICE_NAME"
  
  # Get error groups for the service
  local groups
  groups=$(gcloud error-reporting groups list --project="$PROJECT_ID" --filter="service=\"$SERVICE_NAME\"" --format="value(groupId)")
  
  local group_count
  group_count=$(echo "$groups" | wc -l)
  format-echo "INFO" "Error groups: $group_count"
  
  # Get recent events
  format-echo "INFO" "Recent error events:"
  gcloud error-reporting events list \
    --project="$PROJECT_ID" \
    --service="$SERVICE_NAME" \
    --time-range="${TIME_RANGE:-24h}" \
    --limit=10 \
    --format="table(eventTime,message.truncate=80)"
  
  print_with_separator "End of Service Statistics"
}

get_stats() {
  format-echo "INFO" "Getting error statistics..."
  
  print_with_separator "Error Statistics"
  
  local time_range="${TIME_RANGE:-24h}"
  format-echo "INFO" "Time range: $time_range"
  
  # Get total error groups
  local total_groups
  total_groups=$(gcloud error-reporting groups list --project="$PROJECT_ID" --format="value(groupId)" | wc -l)
  format-echo "INFO" "Total error groups: $total_groups"
  
  # Get recent events count
  local recent_events
  recent_events=$(gcloud error-reporting events list --project="$PROJECT_ID" --time-range="$time_range" --format="value(eventTime)" | wc -l)
  format-echo "INFO" "Recent events ($time_range): $recent_events"
  
  # List top error groups
  echo
  echo "Top error groups by recent activity:"
  gcloud error-reporting groups list \
    --project="$PROJECT_ID" \
    --time-range="$time_range" \
    --sort-by="~count" \
    --limit=10 \
    --format="table(groupId,service,representative.message.truncate=60)"
  
  print_with_separator "End of Error Statistics"
}

report_error() {
  format-echo "INFO" "Reporting a new error..."
  
  format-echo "INFO" "This will create a sample error report"
  
  # Create a simple error report using curl
  local service_name="${SERVICE_NAME:-manual-report}"
  local version="${VERSION:-1.0.0}"
  local message="Manual error report created via gcp-error-reporting-manager"
  
  # Get access token
  local access_token
  access_token=$(gcloud auth print-access-token)
  
  local error_data
  error_data=$(cat <<EOF
{
  "serviceContext": {
    "service": "$service_name",
    "version": "$version"
  },
  "message": "$message",
  "context": {
    "reportLocation": {
      "filePath": "manual-report.sh",
      "lineNumber": 1,
      "functionName": "report_error"
    }
  }
}
EOF
)
  
  format-echo "INFO" "Sending error report..."
  
  if curl -s -X POST \
    "https://clouderrorreporting.googleapis.com/v1beta1/projects/$PROJECT_ID/events:report" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -d "$error_data" > /dev/null; then
    format-echo "SUCCESS" "Error report sent successfully"
  else
    format-echo "ERROR" "Failed to send error report"
  fi
}

delete_events() {
  format-echo "INFO" "Deleting error events..."
  
  if [[ -z "$ERROR_GROUP_ID" ]]; then
    format-echo "ERROR" "Error group ID is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will delete all events for error group: $ERROR_GROUP_ID"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  # Note: Error Reporting doesn't support direct event deletion via gcloud
  # Events are automatically cleaned up based on retention policy
  format-echo "INFO" "Error events are automatically cleaned up based on retention policy (30 days)"
  format-echo "INFO" "To manually manage errors, use the Cloud Console:"
  echo "https://console.cloud.google.com/errors?project=$PROJECT_ID"
}

check_status() {
  format-echo "INFO" "Checking Error Reporting status..."
  
  print_with_separator "Error Reporting Status"
  
  # Check if API is enabled
  if gcloud services list --enabled --filter="name:clouderrorreporting.googleapis.com" --format="value(name)" | grep -q "clouderrorreporting"; then
    format-echo "SUCCESS" "Error Reporting API is enabled"
  else
    format-echo "WARNING" "Error Reporting API is not enabled"
  fi
  
  # Count error groups
  local group_count
  group_count=$(gcloud error-reporting groups list --project="$PROJECT_ID" --format="value(groupId)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Total error groups: $group_count"
  
  # Count recent events
  local recent_count
  recent_count=$(gcloud error-reporting events list --project="$PROJECT_ID" --time-range="24h" --format="value(eventTime)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Events in last 24 hours: $recent_count"
  
  # Check services with errors
  local service_count
  service_count=$(gcloud error-reporting groups list --project="$PROJECT_ID" --format="value(service)" 2>/dev/null | sort -u | wc -l || echo "0")
  format-echo "INFO" "Services with errors: $service_count"
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling Error Reporting API..."
  enable_apis
  format-echo "SUCCESS" "Error Reporting API enabled"
}

get_config() {
  format-echo "INFO" "Getting Error Reporting configuration..."
  
  print_with_separator "Error Reporting Configuration"
  
  # Display project info
  format-echo "INFO" "Project: $PROJECT_ID"
  
  # Check API status
  if gcloud services list --enabled --filter="name:clouderrorreporting.googleapis.com" --format="value(name)" | grep -q "clouderrorreporting"; then
    format-echo "SUCCESS" "API Status: Enabled"
  else
    format-echo "WARNING" "API Status: Disabled"
  fi
  
  # Display configuration info
  echo
  echo "Default Configuration:"
  echo "- Error Retention: 30 days"
  echo "- Max Error Groups: 3000 per project"
  echo "- Rate Limit: 600 reports per minute"
  echo "- Auto-grouping: By error message and stack trace"
  
  echo
  echo "Error Reporting Console URL:"
  echo "https://console.cloud.google.com/errors?project=$PROJECT_ID"
  
  print_with_separator "End of Configuration"
}

setup_client() {
  format-echo "INFO" "Showing Error Reporting client setup instructions..."
  
  print_with_separator "Error Reporting Client Setup"
  
  echo "Language-specific setup:"
  echo
  echo "Java:"
  echo "  1. Add dependency: com.google.cloud:google-cloud-errorreporting"
  echo "  2. Configure logback or log4j with ErrorReportingAppender"
  echo "  3. Set environment: GOOGLE_CLOUD_PROJECT=$PROJECT_ID"
  echo
  echo "Python:"
  echo "  1. Install: pip install google-cloud-error-reporting"
  echo "  2. Import: from google.cloud import error_reporting"
  echo "  3. Setup logging handler: error_reporting.Client().setup_logging()"
  echo
  echo "Node.js:"
  echo "  1. Install: npm install @google-cloud/error-reporting"
  echo "  2. Require: const {ErrorReporting} = require('@google-cloud/error-reporting')"
  echo "  3. Initialize: const errors = new ErrorReporting()"
  echo
  echo "Go:"
  echo "  1. Import: cloud.google.com/go/errorreporting"
  echo "  2. Create client: errorreporting.NewClient()"
  echo
  echo "App Engine (automatic):"
  echo "  - Error Reporting is automatically enabled"
  echo "  - Errors are captured from standard logging"
  echo
  echo "Cloud Functions (automatic):"
  echo "  - Error Reporting is automatically enabled"
  echo "  - Uncaught exceptions are automatically reported"
  echo
  echo "Environment Variables:"
  echo "  GOOGLE_CLOUD_PROJECT=$PROJECT_ID"
  echo "  GOOGLE_APPLICATION_CREDENTIALS=path/to/credentials.json"
  
  print_with_separator "End of Setup Instructions"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    list-groups)
      list_groups
      ;;
    get-group)
      get_group
      ;;
    list-events)
      list_events
      ;;
    get-event)
      get_event
      ;;
    list-services)
      list_services
      ;;
    get-service-stats)
      get_service_stats
      ;;
    get-stats)
      get_stats
      ;;
    report-error)
      report_error
      ;;
    delete-events)
      delete_events
      ;;
    status)
      check_status
      ;;
    enable-api)
      enable_api
      ;;
    get-config)
      get_config
      ;;
    setup-client)
      setup_client
      ;;
    *)
      format-echo "ERROR" "Unknown command: $COMMAND"
      format-echo "INFO" "Use --help to see available commands"
      exit 1
      ;;
  esac
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"
  
  print_with_separator "GCP Error Reporting Manager"
  format-echo "INFO" "Starting Error Reporting management operations..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  if [[ -z "$COMMAND" ]]; then
    format-echo "ERROR" "Command is required."
    usage
  fi
  
  #---------------------------------------------------------------------
  # AUTHENTICATION AND SETUP
  #---------------------------------------------------------------------
  check_auth
  set_project
  
  #---------------------------------------------------------------------
  # COMMAND EXECUTION
  #---------------------------------------------------------------------
  execute_command
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "Error Reporting management operation completed successfully."
  print_with_separator "End of GCP Error Reporting Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
