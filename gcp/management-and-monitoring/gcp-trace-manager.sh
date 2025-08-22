#!/usr/bin/env bash
# gcp-trace-manager.sh
# Script to manage Google Cloud Trace

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
TRACE_ID=""
SPAN_ID=""
START_TIME=""
END_TIME=""
FILTER=""
SERVICE_NAME=""
VERSION=""
ORDER_BY=""
LIMIT=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Trace Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Trace for distributed tracing."
  echo "  Provides capabilities for viewing, analyzing, and managing trace data."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-t, --trace-id TRACE_ID\033[0m     Set trace ID"
  echo -e "  \033[1;33m-s, --span-id SPAN_ID\033[0m       Set span ID"
  echo -e "  \033[1;33m--start-time TIME\033[0m           Set start time (RFC3339 format)"
  echo -e "  \033[1;33m--end-time TIME\033[0m             Set end time (RFC3339 format)"
  echo -e "  \033[1;33m-f, --filter FILTER\033[0m         Set filter expression"
  echo -e "  \033[1;33m--service SERVICE_NAME\033[0m      Set service name filter"
  echo -e "  \033[1;33m-v, --version VERSION\033[0m       Set version filter"
  echo -e "  \033[1;33m--order-by FIELD\033[0m            Set order by field"
  echo -e "  \033[1;33m-l, --limit LIMIT\033[0m           Set result limit"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mlist-traces\033[0m                 List traces"
  echo -e "  \033[1;36mget-trace\033[0m                   Get trace details"
  echo -e "  \033[1;36mlist-spans\033[0m                  List spans for a trace"
  echo -e "  \033[1;36mget-span\033[0m                    Get span details"
  echo -e "  \033[1;36manalyze-trace\033[0m               Analyze trace performance"
  echo -e "  \033[1;36mlist-services\033[0m               List services with traces"
  echo -e "  \033[1;36mget-service-stats\033[0m           Get service tracing statistics"
  echo -e "  \033[1;36msearch-traces\033[0m               Search traces with filters"
  echo -e "  \033[1;36mget-latency-stats\033[0m           Get latency statistics"
  echo -e "  \033[1;36mstatus\033[0m                      Check tracing status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Cloud Trace API"
  echo -e "  \033[1;36mget-config\033[0m                  Get trace configuration"
  echo -e "  \033[1;36msetup-agent\033[0m                 Show agent setup instructions"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project list-traces"
  echo "  $0 -p my-project -t abc123 get-trace"
  echo "  $0 -p my-project --service my-service search-traces"
  echo "  $0 -p my-project --start-time 2024-01-01T00:00:00Z list-traces"
  echo "  $0 -p my-project --service my-service get-latency-stats"
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
      -t|--trace-id)
        if [[ -n "${2:-}" ]]; then
          TRACE_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --trace-id"
          usage
        fi
        ;;
      -s|--span-id)
        if [[ -n "${2:-}" ]]; then
          SPAN_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --span-id"
          usage
        fi
        ;;
      --start-time)
        if [[ -n "${2:-}" ]]; then
          START_TIME="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --start-time"
          usage
        fi
        ;;
      --end-time)
        if [[ -n "${2:-}" ]]; then
          END_TIME="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --end-time"
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
      --service)
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
      --order-by)
        if [[ -n "${2:-}" ]]; then
          ORDER_BY="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --order-by"
          usage
        fi
        ;;
      -l|--limit)
        if [[ -n "${2:-}" ]]; then
          LIMIT="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --limit"
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
    "cloudtrace.googleapis.com"
    "logging.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# CLOUD TRACE OPERATIONS
#=====================================================================
list_traces() {
  format-echo "INFO" "Listing traces..."
  
  local cmd="gcloud trace traces list --project='$PROJECT_ID'"
  
  if [[ -n "$START_TIME" ]]; then
    cmd="$cmd --start-time='$START_TIME'"
  fi
  
  if [[ -n "$END_TIME" ]]; then
    cmd="$cmd --end-time='$END_TIME'"
  fi
  
  if [[ -n "$FILTER" ]]; then
    cmd="$cmd --filter='$FILTER'"
  fi
  
  if [[ -n "$ORDER_BY" ]]; then
    cmd="$cmd --sort-by='$ORDER_BY'"
  fi
  
  if [[ -n "$LIMIT" ]]; then
    cmd="$cmd --limit='$LIMIT'"
  else
    cmd="$cmd --limit=50"
  fi
  
  print_with_separator "Traces"
  eval "$cmd"
  print_with_separator "End of Traces"
}

get_trace() {
  format-echo "INFO" "Getting trace details..."
  
  if [[ -z "$TRACE_ID" ]]; then
    format-echo "ERROR" "Trace ID is required"
    exit 1
  fi
  
  print_with_separator "Trace: $TRACE_ID"
  gcloud trace traces describe "$TRACE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Trace Details"
}

list_spans() {
  format-echo "INFO" "Listing spans for trace..."
  
  if [[ -z "$TRACE_ID" ]]; then
    format-echo "ERROR" "Trace ID is required"
    exit 1
  fi
  
  print_with_separator "Spans for Trace: $TRACE_ID"
  gcloud trace spans list "$TRACE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Spans"
}

get_span() {
  format-echo "INFO" "Getting span details..."
  
  if [[ -z "$TRACE_ID" ]] || [[ -z "$SPAN_ID" ]]; then
    format-echo "ERROR" "Trace ID and Span ID are required"
    exit 1
  fi
  
  print_with_separator "Span: $SPAN_ID"
  gcloud trace spans describe "$SPAN_ID" --trace="$TRACE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Span Details"
}

analyze_trace() {
  format-echo "INFO" "Analyzing trace performance..."
  
  if [[ -z "$TRACE_ID" ]]; then
    format-echo "ERROR" "Trace ID is required"
    exit 1
  fi
  
  print_with_separator "Trace Analysis: $TRACE_ID"
  
  # Get trace details
  local trace_data
  trace_data=$(gcloud trace traces describe "$TRACE_ID" --project="$PROJECT_ID" --format="json")
  
  # Extract basic information
  local root_span_id
  root_span_id=$(echo "$trace_data" | jq -r '.spans[] | select(.parentSpanId == null or .parentSpanId == "") | .spanId')
  
  if [[ -n "$root_span_id" ]]; then
    format-echo "INFO" "Root span ID: $root_span_id"
  fi
  
  # Get spans summary
  echo "Span summary:"
  gcloud trace spans list "$TRACE_ID" --project="$PROJECT_ID" --format="table(
    spanId:label=SPAN_ID,
    displayName.value:label=NAME,
    startTime:label=START_TIME,
    endTime:label=END_TIME
  )"
  
  # Calculate total duration if possible
  local start_time end_time
  start_time=$(echo "$trace_data" | jq -r '.spans | sort_by(.startTime) | .[0].startTime')
  end_time=$(echo "$trace_data" | jq -r '.spans | sort_by(.endTime) | .[-1].endTime')
  
  if [[ "$start_time" != "null" ]] && [[ "$end_time" != "null" ]]; then
    format-echo "INFO" "Trace duration: $start_time to $end_time"
  fi
  
  print_with_separator "End of Trace Analysis"
}

list_services() {
  format-echo "INFO" "Listing services with traces..."
  
  print_with_separator "Services with Traces"
  
  # Note: This is a simplified approach since gcloud doesn't have a direct command
  # for listing services. We extract from recent traces.
  gcloud trace traces list --project="$PROJECT_ID" --limit=100 --format="json" | \
    jq -r '.[] | .spans[]? | .displayName.value' | \
    grep -E '^[A-Za-z0-9_-]+$' | \
    sort -u | \
    head -20
  
  print_with_separator "End of Services"
}

get_service_stats() {
  format-echo "INFO" "Getting service tracing statistics..."
  
  if [[ -z "$SERVICE_NAME" ]]; then
    format-echo "ERROR" "Service name is required"
    exit 1
  fi
  
  print_with_separator "Service Statistics: $SERVICE_NAME"
  
  # Get recent traces for the service
  local filter="span_name:$SERVICE_NAME"
  if [[ -n "$FILTER" ]]; then
    filter="$filter AND $FILTER"
  fi
  
  local traces
  traces=$(gcloud trace traces list \
    --project="$PROJECT_ID" \
    --filter="$filter" \
    --limit=100 \
    --format="json")
  
  local trace_count
  trace_count=$(echo "$traces" | jq length)
  format-echo "INFO" "Recent traces found: $trace_count"
  
  if [[ "$trace_count" -gt 0 ]]; then
    echo "Recent trace IDs:"
    echo "$traces" | jq -r '.[].name' | head -10
  fi
  
  print_with_separator "End of Service Statistics"
}

search_traces() {
  format-echo "INFO" "Searching traces with filters..."
  
  local cmd="gcloud trace traces list --project='$PROJECT_ID'"
  
  # Build filter
  local search_filter=""
  
  if [[ -n "$SERVICE_NAME" ]]; then
    search_filter="span_name:$SERVICE_NAME"
  fi
  
  if [[ -n "$VERSION" ]]; then
    if [[ -n "$search_filter" ]]; then
      search_filter="$search_filter AND version:$VERSION"
    else
      search_filter="version:$VERSION"
    fi
  fi
  
  if [[ -n "$FILTER" ]]; then
    if [[ -n "$search_filter" ]]; then
      search_filter="$search_filter AND $FILTER"
    else
      search_filter="$FILTER"
    fi
  fi
  
  if [[ -n "$search_filter" ]]; then
    cmd="$cmd --filter='$search_filter'"
  fi
  
  if [[ -n "$START_TIME" ]]; then
    cmd="$cmd --start-time='$START_TIME'"
  fi
  
  if [[ -n "$END_TIME" ]]; then
    cmd="$cmd --end-time='$END_TIME'"
  fi
  
  if [[ -n "$LIMIT" ]]; then
    cmd="$cmd --limit='$LIMIT'"
  else
    cmd="$cmd --limit=50"
  fi
  
  print_with_separator "Search Results"
  eval "$cmd"
  print_with_separator "End of Search Results"
}

get_latency_stats() {
  format-echo "INFO" "Getting latency statistics..."
  
  print_with_separator "Latency Statistics"
  
  local cmd="gcloud trace traces list --project='$PROJECT_ID' --limit=100"
  
  if [[ -n "$SERVICE_NAME" ]]; then
    cmd="$cmd --filter='span_name:$SERVICE_NAME'"
  fi
  
  if [[ -n "$START_TIME" ]]; then
    cmd="$cmd --start-time='$START_TIME'"
  fi
  
  if [[ -n "$END_TIME" ]]; then
    cmd="$cmd --end-time='$END_TIME'"
  fi
  
  format-echo "INFO" "Analyzing recent traces for latency patterns..."
  
  # Get traces and analyze
  local traces
  traces=$(eval "$cmd --format='json'")
  
  local trace_count
  trace_count=$(echo "$traces" | jq length)
  
  format-echo "INFO" "Traces analyzed: $trace_count"
  
  if [[ "$trace_count" -gt 0 ]]; then
    echo "Use the Cloud Console for detailed latency analysis:"
    echo "https://console.cloud.google.com/traces/list?project=$PROJECT_ID"
  fi
  
  print_with_separator "End of Latency Statistics"
}

check_status() {
  format-echo "INFO" "Checking Cloud Trace status..."
  
  print_with_separator "Cloud Trace Status"
  
  # Check if API is enabled
  if gcloud services list --enabled --filter="name:cloudtrace.googleapis.com" --format="value(name)" | grep -q "cloudtrace"; then
    format-echo "SUCCESS" "Cloud Trace API is enabled"
  else
    format-echo "WARNING" "Cloud Trace API is not enabled"
  fi
  
  # Count recent traces
  local trace_count
  trace_count=$(gcloud trace traces list --project="$PROJECT_ID" --limit=1000 --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Recent traces: $trace_count"
  
  # Check for traces in last 24 hours
  local yesterday
  yesterday=$(date -u -d '1 day ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-1d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "")
  
  if [[ -n "$yesterday" ]]; then
    local recent_count
    recent_count=$(gcloud trace traces list --project="$PROJECT_ID" --start-time="$yesterday" --format="value(name)" 2>/dev/null | wc -l || echo "0")
    format-echo "INFO" "Traces in last 24 hours: $recent_count"
  fi
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling Cloud Trace API..."
  enable_apis
  format-echo "SUCCESS" "Cloud Trace API enabled"
}

get_config() {
  format-echo "INFO" "Getting trace configuration..."
  
  print_with_separator "Trace Configuration"
  
  # Display project info
  format-echo "INFO" "Project: $PROJECT_ID"
  
  # Check API status
  if gcloud services list --enabled --filter="name:cloudtrace.googleapis.com" --format="value(name)" | grep -q "cloudtrace"; then
    format-echo "SUCCESS" "API Status: Enabled"
  else
    format-echo "WARNING" "API Status: Disabled"
  fi
  
  # Display configuration info
  echo
  echo "Default Configuration:"
  echo "- Trace Retention: 30 days"
  echo "- Max Spans per Trace: 128"
  echo "- Sampling Rate: Automatic (adaptive)"
  echo "- Max Trace Size: 32 MB"
  
  echo
  echo "Trace Console URL:"
  echo "https://console.cloud.google.com/traces/list?project=$PROJECT_ID"
  
  print_with_separator "End of Configuration"
}

setup_agent() {
  format-echo "INFO" "Showing trace agent setup instructions..."
  
  print_with_separator "Trace Agent Setup"
  
  echo "Language-specific setup:"
  echo
  echo "Java:"
  echo "  1. Add dependency: com.google.cloud:google-cloud-trace"
  echo "  2. Set environment: GOOGLE_CLOUD_PROJECT=$PROJECT_ID"
  echo "  3. Use OpenTelemetry or Cloud Trace library"
  echo
  echo "Python:"
  echo "  1. Install: pip install google-cloud-trace"
  echo "  2. Import: from google.cloud import trace_v1"
  echo "  3. Use OpenCensus or OpenTelemetry"
  echo
  echo "Node.js:"
  echo "  1. Install: npm install @google-cloud/trace-agent"
  echo "  2. Require at top: require('@google-cloud/trace-agent').start()"
  echo
  echo "Go:"
  echo "  1. Import: cloud.google.com/go/trace"
  echo "  2. Use OpenTelemetry with Cloud Trace exporter"
  echo
  echo "OpenTelemetry (Recommended):"
  echo "  1. Install OpenTelemetry SDK for your language"
  echo "  2. Configure Cloud Trace exporter"
  echo "  3. Set GOOGLE_CLOUD_PROJECT=$PROJECT_ID"
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
    list-traces)
      list_traces
      ;;
    get-trace)
      get_trace
      ;;
    list-spans)
      list_spans
      ;;
    get-span)
      get_span
      ;;
    analyze-trace)
      analyze_trace
      ;;
    list-services)
      list_services
      ;;
    get-service-stats)
      get_service_stats
      ;;
    search-traces)
      search_traces
      ;;
    get-latency-stats)
      get_latency_stats
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
    setup-agent)
      setup_agent
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
  
  print_with_separator "GCP Cloud Trace Manager"
  format-echo "INFO" "Starting Cloud Trace management operations..."
  
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
  format-echo "SUCCESS" "Cloud Trace management operation completed successfully."
  print_with_separator "End of GCP Cloud Trace Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
