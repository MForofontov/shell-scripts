#!/usr/bin/env bash
# gcp-profiler-manager.sh
# Script to manage Google Cloud Profiler

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
PROFILE_TYPE=""
DURATION=""
START_TIME=""
END_TIME=""
TARGET=""
ZONE=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Profiler Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Profiler for application performance monitoring."
  echo "  Provides capabilities for collecting and analyzing performance profiles."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-s, --service SERVICE_NAME\033[0m   Set service name"
  echo -e "  \033[1;33m-t, --type PROFILE_TYPE\033[0m     Set profile type (CPU, HEAP, THREADS, CONTENTION)"
  echo -e "  \033[1;33m-d, --duration DURATION\033[0m     Set profiling duration (e.g., 60s, 5m)"
  echo -e "  \033[1;33m--start-time TIME\033[0m           Set start time (RFC3339 format)"
  echo -e "  \033[1;33m--end-time TIME\033[0m             Set end time (RFC3339 format)"
  echo -e "  \033[1;33m--target TARGET\033[0m             Set target label (version, zone, etc.)"
  echo -e "  \033[1;33m-z, --zone ZONE\033[0m             Set zone filter"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mlist-profiles\033[0m               List available profiles"
  echo -e "  \033[1;36mget-profile\033[0m                 Get profile details"
  echo -e "  \033[1;36mlist-profile-types\033[0m          List supported profile types"
  echo -e "  \033[1;36mcreate-profile\033[0m              Create a new profile"
  echo -e "  \033[1;36mdownload-profile\033[0m            Download profile data"
  echo -e "  \033[1;36manalyze-profile\033[0m             Analyze profile with pprof"
  echo -e "  \033[1;36mlist-services\033[0m               List services with profiles"
  echo -e "  \033[1;36mget-service-stats\033[0m           Get service profiling statistics"
  echo -e "  \033[1;36mstatus\033[0m                      Check profiler status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Cloud Profiler API"
  echo -e "  \033[1;36mget-config\033[0m                  Get profiler configuration"
  echo -e "  \033[1;36msetup-agent\033[0m                 Show agent setup instructions"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project list-services"
  echo "  $0 -p my-project -s my-service list-profiles"
  echo "  $0 -p my-project -s my-service -t CPU create-profile"
  echo "  $0 -p my-project -s my-service -t HEAP -d 120s create-profile"
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
      -t|--type)
        if [[ -n "${2:-}" ]]; then
          PROFILE_TYPE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --type"
          usage
        fi
        ;;
      -d|--duration)
        if [[ -n "${2:-}" ]]; then
          DURATION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --duration"
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
      --target)
        if [[ -n "${2:-}" ]]; then
          TARGET="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --target"
          usage
        fi
        ;;
      -z|--zone)
        if [[ -n "${2:-}" ]]; then
          ZONE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --zone"
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
    "cloudprofiler.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# CLOUD PROFILER OPERATIONS
#=====================================================================
list_profiles() {
  format-echo "INFO" "Listing profiles..."
  
  local cmd="gcloud profiler profiles list --project='$PROJECT_ID'"
  
  if [[ -n "$SERVICE_NAME" ]]; then
    cmd="$cmd --filter='target.labels.service=\"$SERVICE_NAME\"'"
  fi
  
  if [[ -n "$PROFILE_TYPE" ]]; then
    cmd="$cmd --filter='profileType=\"$PROFILE_TYPE\"'"
  fi
  
  if [[ -n "$START_TIME" ]]; then
    cmd="$cmd --filter='startTime>=\"$START_TIME\"'"
  fi
  
  if [[ -n "$END_TIME" ]]; then
    cmd="$cmd --filter='startTime<=\"$END_TIME\"'"
  fi
  
  print_with_separator "Available Profiles"
  eval "$cmd"
  print_with_separator "End of Profiles"
}

get_profile() {
  format-echo "INFO" "Getting profile details..."
  
  if [[ -z "$PROFILE_ID" ]]; then
    format-echo "ERROR" "Profile ID is required. Use list-profiles to find available profiles."
    exit 1
  fi
  
  print_with_separator "Profile Details"
  gcloud profiler profiles describe "$PROFILE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Profile Details"
}

list_profile_types() {
  format-echo "INFO" "Listing supported profile types..."
  
  print_with_separator "Supported Profile Types"
  echo "CPU       - CPU usage profiling"
  echo "HEAP      - Memory heap profiling"
  echo "THREADS   - Thread contention profiling"
  echo "CONTENTION - Lock contention profiling"
  echo "WALL      - Wall-clock time profiling"
  echo "ALLOCATIONS - Memory allocation profiling"
  print_with_separator "End of Profile Types"
}

create_profile() {
  format-echo "INFO" "Creating profile..."
  
  if [[ -z "$SERVICE_NAME" ]]; then
    format-echo "ERROR" "Service name is required"
    exit 1
  fi
  
  if [[ -z "$PROFILE_TYPE" ]]; then
    PROFILE_TYPE="CPU"
    format-echo "INFO" "Using default profile type: CPU"
  fi
  
  if [[ -z "$DURATION" ]]; then
    DURATION="60s"
    format-echo "INFO" "Using default duration: 60s"
  fi
  
  local cmd="gcloud profiler profiles create"
  cmd="$cmd --project='$PROJECT_ID'"
  cmd="$cmd --target-service='$SERVICE_NAME'"
  cmd="$cmd --profile-type='$PROFILE_TYPE'"
  cmd="$cmd --duration='$DURATION'"
  
  if [[ -n "$TARGET" ]]; then
    cmd="$cmd --target='$TARGET'"
  fi
  
  format-echo "INFO" "Creating $PROFILE_TYPE profile for service $SERVICE_NAME (duration: $DURATION)"
  eval "$cmd"
  format-echo "SUCCESS" "Profile creation initiated"
}

download_profile() {
  format-echo "INFO" "Downloading profile..."
  
  if [[ -z "$PROFILE_ID" ]]; then
    format-echo "ERROR" "Profile ID is required. Use list-profiles to find available profiles."
    exit 1
  fi
  
  local output_file="profile_${PROFILE_ID}.pb.gz"
  
  gcloud profiler profiles download "$PROFILE_ID" \
    --project="$PROJECT_ID" \
    --output-file="$output_file"
  
  format-echo "SUCCESS" "Profile downloaded to $output_file"
}

analyze_profile() {
  format-echo "INFO" "Analyzing profile with pprof..."
  
  if [[ -z "$PROFILE_ID" ]]; then
    format-echo "ERROR" "Profile ID is required. Use list-profiles to find available profiles."
    exit 1
  fi
  
  # Check if pprof is available
  if ! command -v pprof &> /dev/null; then
    format-echo "WARNING" "pprof tool not found. Installing go and pprof..."
    echo "To install pprof:"
    echo "  go install github.com/google/pprof@latest"
    echo
    echo "Or use the web interface:"
    echo "  gcloud profiler profiles view-web $PROFILE_ID --project=$PROJECT_ID"
    return 1
  fi
  
  local temp_file="temp_profile_${PROFILE_ID}.pb.gz"
  
  # Download profile
  gcloud profiler profiles download "$PROFILE_ID" \
    --project="$PROJECT_ID" \
    --output-file="$temp_file"
  
  # Analyze with pprof
  format-echo "INFO" "Opening pprof interactive analysis..."
  pprof "$temp_file"
  
  # Cleanup
  rm -f "$temp_file"
}

list_services() {
  format-echo "INFO" "Listing services with profiles..."
  
  print_with_separator "Services with Profiles"
  gcloud profiler profiles list \
    --project="$PROJECT_ID" \
    --format="table(target.labels.service:sort=1)" \
    --filter="target.labels.service!=''" | \
    sort -u
  print_with_separator "End of Services"
}

get_service_stats() {
  format-echo "INFO" "Getting service profiling statistics..."
  
  if [[ -z "$SERVICE_NAME" ]]; then
    format-echo "ERROR" "Service name is required"
    exit 1
  fi
  
  print_with_separator "Service Statistics: $SERVICE_NAME"
  
  # Get profile count by type
  echo "Profile counts by type:"
  gcloud profiler profiles list \
    --project="$PROJECT_ID" \
    --filter="target.labels.service=\"$SERVICE_NAME\"" \
    --format="table(profileType:sort=1)" | \
    sort | uniq -c
  
  echo
  echo "Recent profiles (last 10):"
  gcloud profiler profiles list \
    --project="$PROJECT_ID" \
    --filter="target.labels.service=\"$SERVICE_NAME\"" \
    --limit=10 \
    --sort-by="~startTime" \
    --format="table(profileType,startTime,duration)"
  
  print_with_separator "End of Service Statistics"
}

check_status() {
  format-echo "INFO" "Checking Cloud Profiler status..."
  
  print_with_separator "Cloud Profiler Status"
  
  # Check if API is enabled
  if gcloud services list --enabled --filter="name:cloudprofiler.googleapis.com" --format="value(name)" | grep -q "cloudprofiler"; then
    format-echo "SUCCESS" "Cloud Profiler API is enabled"
  else
    format-echo "WARNING" "Cloud Profiler API is not enabled"
  fi
  
  # Count total profiles
  local profile_count
  profile_count=$(gcloud profiler profiles list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Total profiles: $profile_count"
  
  # Count services
  local service_count
  service_count=$(gcloud profiler profiles list --project="$PROJECT_ID" --format="value(target.labels.service)" --filter="target.labels.service!=''" 2>/dev/null | sort -u | wc -l || echo "0")
  format-echo "INFO" "Services with profiles: $service_count"
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling Cloud Profiler API..."
  enable_apis
  format-echo "SUCCESS" "Cloud Profiler API enabled"
}

get_config() {
  format-echo "INFO" "Getting profiler configuration..."
  
  print_with_separator "Profiler Configuration"
  
  # Display project info
  format-echo "INFO" "Project: $PROJECT_ID"
  
  # Check API status
  if gcloud services list --enabled --filter="name:cloudprofiler.googleapis.com" --format="value(name)" | grep -q "cloudprofiler"; then
    format-echo "SUCCESS" "API Status: Enabled"
  else
    format-echo "WARNING" "API Status: Disabled"
  fi
  
  # Display configuration info
  echo
  echo "Default Configuration:"
  echo "- Profile Duration: 60 seconds"
  echo "- Profile Types: CPU, HEAP, THREADS, CONTENTION"
  echo "- Data Retention: 30 days"
  echo "- Max Profile Size: 32 MB"
  
  print_with_separator "End of Configuration"
}

setup_agent() {
  format-echo "INFO" "Showing profiler agent setup instructions..."
  
  print_with_separator "Profiler Agent Setup"
  
  echo "Language-specific setup:"
  echo
  echo "Java:"
  echo "  1. Download the profiler agent JAR"
  echo "  2. Add JVM flag: -javaagent:cloud-profiler-java-agent.jar"
  echo "  3. Set environment: GOOGLE_CLOUD_PROFILER_ENABLE=true"
  echo
  echo "Python:"
  echo "  1. Install: pip install google-cloud-profiler"
  echo "  2. Add to code: import googlecloudprofiler"
  echo "  3. Initialize: googlecloudprofiler.start()"
  echo
  echo "Node.js:"
  echo "  1. Install: npm install @google-cloud/profiler"
  echo "  2. Add to code: require('@google-cloud/profiler').start()"
  echo
  echo "Go:"
  echo "  1. Import: cloud.google.com/go/profiler"
  echo "  2. Initialize: profiler.Start(profiler.Config{Service: \"myservice\"})"
  echo
  echo "Environment Variables:"
  echo "  GOOGLE_CLOUD_PROJECT=$PROJECT_ID"
  echo "  GOOGLE_CLOUD_PROFILER_ENABLE=true"
  echo "  GAE_SERVICE=your-service-name"
  echo "  GAE_VERSION=your-version"
  
  print_with_separator "End of Setup Instructions"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    list-profiles)
      list_profiles
      ;;
    get-profile)
      get_profile
      ;;
    list-profile-types)
      list_profile_types
      ;;
    create-profile)
      create_profile
      ;;
    download-profile)
      download_profile
      ;;
    analyze-profile)
      analyze_profile
      ;;
    list-services)
      list_services
      ;;
    get-service-stats)
      get_service_stats
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
  
  print_with_separator "GCP Cloud Profiler Manager"
  format-echo "INFO" "Starting Cloud Profiler management operations..."
  
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
  format-echo "SUCCESS" "Cloud Profiler management operation completed successfully."
  print_with_separator "End of GCP Cloud Profiler Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
