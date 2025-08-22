#!/usr/bin/env bash
# gcp-debugger-manager.sh
# Script to manage Google Cloud Debugger

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
DEBUGGEE_ID=""
BREAKPOINT_ID=""
LOCATION=""
CONDITION=""
EXPRESSION=""
LOG_LEVEL=""
SOURCE_VERSION=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Debugger Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Debugger for application debugging."
  echo "  Provides capabilities for setting breakpoints, viewing snapshots, and debugging applications."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-d, --debuggee DEBUGGEE_ID\033[0m   Set debuggee ID"
  echo -e "  \033[1;33m-b, --breakpoint ID\033[0m         Set breakpoint ID"
  echo -e "  \033[1;33m-l, --location LOCATION\033[0m     Set breakpoint location (file:line)"
  echo -e "  \033[1;33m-c, --condition CONDITION\033[0m   Set breakpoint condition"
  echo -e "  \033[1;33m-e, --expression EXPRESSION\033[0m Set log expression"
  echo -e "  \033[1;33m--log-level LEVEL\033[0m           Set log level (INFO, WARNING, ERROR)"
  echo -e "  \033[1;33m-v, --version VERSION\033[0m       Set source version"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mlist-debuggees\033[0m              List available debuggees"
  echo -e "  \033[1;36mget-debuggee\033[0m                Get debuggee details"
  echo -e "  \033[1;36mlist-breakpoints\033[0m            List breakpoints"
  echo -e "  \033[1;36mset-breakpoint\033[0m              Set a new breakpoint"
  echo -e "  \033[1;36mget-breakpoint\033[0m              Get breakpoint details"
  echo -e "  \033[1;36mdelete-breakpoint\033[0m           Delete a breakpoint"
  echo -e "  \033[1;36mset-logpoint\033[0m                Set a logpoint"
  echo -e "  \033[1;36mlist-snapshots\033[0m              List snapshots"
  echo -e "  \033[1;36mget-snapshot\033[0m                Get snapshot details"
  echo -e "  \033[1;36mstatus\033[0m                      Check debugger status"
  echo -e "  \033[1;36menable-api\033[0m                  Enable Cloud Debugger API"
  echo -e "  \033[1;36mget-config\033[0m                  Get debugger configuration"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project list-debuggees"
  echo "  $0 -p my-project -d debuggee-123 list-breakpoints"
  echo "  $0 -p my-project -d debuggee-123 -l main.py:25 set-breakpoint"
  echo "  $0 -p my-project -d debuggee-123 -b bp-123 get-breakpoint"
  echo "  $0 -p my-project -d debuggee-123 -l main.py:30 -e 'user_id' set-logpoint"
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
      -d|--debuggee)
        if [[ -n "${2:-}" ]]; then
          DEBUGGEE_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --debuggee"
          usage
        fi
        ;;
      -b|--breakpoint)
        if [[ -n "${2:-}" ]]; then
          BREAKPOINT_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --breakpoint"
          usage
        fi
        ;;
      -l|--location)
        if [[ -n "${2:-}" ]]; then
          LOCATION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --location"
          usage
        fi
        ;;
      -c|--condition)
        if [[ -n "${2:-}" ]]; then
          CONDITION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --condition"
          usage
        fi
        ;;
      -e|--expression)
        if [[ -n "${2:-}" ]]; then
          EXPRESSION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --expression"
          usage
        fi
        ;;
      --log-level)
        if [[ -n "${2:-}" ]]; then
          LOG_LEVEL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --log-level"
          usage
        fi
        ;;
      -v|--version)
        if [[ -n "${2:-}" ]]; then
          SOURCE_VERSION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --version"
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
    "clouddebugger.googleapis.com"
    "logging.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# CLOUD DEBUGGER OPERATIONS
#=====================================================================
list_debuggees() {
  format-echo "INFO" "Listing debuggees..."
  
  print_with_separator "Available Debuggees"
  gcloud debug targets list --project="$PROJECT_ID"
  print_with_separator "End of Debuggees"
}

get_debuggee() {
  format-echo "INFO" "Getting debuggee details..."
  
  if [[ -z "$DEBUGGEE_ID" ]]; then
    format-echo "ERROR" "Debuggee ID is required"
    exit 1
  fi
  
  print_with_separator "Debuggee: $DEBUGGEE_ID"
  gcloud debug targets describe "$DEBUGGEE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Debuggee Details"
}

list_breakpoints() {
  format-echo "INFO" "Listing breakpoints..."
  
  if [[ -z "$DEBUGGEE_ID" ]]; then
    format-echo "ERROR" "Debuggee ID is required"
    exit 1
  fi
  
  print_with_separator "Breakpoints for $DEBUGGEE_ID"
  gcloud debug breakpoints list --target="$DEBUGGEE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Breakpoints"
}

set_breakpoint() {
  format-echo "INFO" "Setting breakpoint..."
  
  if [[ -z "$DEBUGGEE_ID" ]] || [[ -z "$LOCATION" ]]; then
    format-echo "ERROR" "Debuggee ID and location are required"
    exit 1
  fi
  
  local cmd="gcloud debug breakpoints create '$LOCATION' --target='$DEBUGGEE_ID' --project='$PROJECT_ID'"
  
  if [[ -n "$CONDITION" ]]; then
    cmd="$cmd --condition='$CONDITION'"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "Breakpoint set at $LOCATION"
}

get_breakpoint() {
  format-echo "INFO" "Getting breakpoint details..."
  
  if [[ -z "$DEBUGGEE_ID" ]] || [[ -z "$BREAKPOINT_ID" ]]; then
    format-echo "ERROR" "Debuggee ID and breakpoint ID are required"
    exit 1
  fi
  
  print_with_separator "Breakpoint: $BREAKPOINT_ID"
  gcloud debug breakpoints describe "$BREAKPOINT_ID" --target="$DEBUGGEE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Breakpoint Details"
}

delete_breakpoint() {
  format-echo "INFO" "Deleting breakpoint..."
  
  if [[ -z "$DEBUGGEE_ID" ]] || [[ -z "$BREAKPOINT_ID" ]]; then
    format-echo "ERROR" "Debuggee ID and breakpoint ID are required"
    exit 1
  fi
  
  gcloud debug breakpoints delete "$BREAKPOINT_ID" --target="$DEBUGGEE_ID" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Breakpoint $BREAKPOINT_ID deleted"
}

set_logpoint() {
  format-echo "INFO" "Setting logpoint..."
  
  if [[ -z "$DEBUGGEE_ID" ]] || [[ -z "$LOCATION" ]]; then
    format-echo "ERROR" "Debuggee ID and location are required"
    exit 1
  fi
  
  local cmd="gcloud debug logpoints create '$LOCATION' --target='$DEBUGGEE_ID' --project='$PROJECT_ID'"
  
  if [[ -n "$EXPRESSION" ]]; then
    cmd="$cmd --format='$EXPRESSION'"
  fi
  
  if [[ -n "$LOG_LEVEL" ]]; then
    cmd="$cmd --log-level='$LOG_LEVEL'"
  fi
  
  if [[ -n "$CONDITION" ]]; then
    cmd="$cmd --condition='$CONDITION'"
  fi
  
  eval "$cmd"
  format-echo "SUCCESS" "Logpoint set at $LOCATION"
}

list_snapshots() {
  format-echo "INFO" "Listing snapshots..."
  
  if [[ -z "$DEBUGGEE_ID" ]]; then
    format-echo "ERROR" "Debuggee ID is required"
    exit 1
  fi
  
  print_with_separator "Snapshots for $DEBUGGEE_ID"
  gcloud debug snapshots list --target="$DEBUGGEE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Snapshots"
}

get_snapshot() {
  format-echo "INFO" "Getting snapshot details..."
  
  if [[ -z "$DEBUGGEE_ID" ]] || [[ -z "$BREAKPOINT_ID" ]]; then
    format-echo "ERROR" "Debuggee ID and snapshot ID are required"
    exit 1
  fi
  
  print_with_separator "Snapshot: $BREAKPOINT_ID"
  gcloud debug snapshots describe "$BREAKPOINT_ID" --target="$DEBUGGEE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Snapshot Details"
}

check_status() {
  format-echo "INFO" "Checking Cloud Debugger status..."
  
  print_with_separator "Cloud Debugger Status"
  
  # Check if API is enabled
  if gcloud services list --enabled --filter="name:clouddebugger.googleapis.com" --format="value(name)" | grep -q "clouddebugger"; then
    format-echo "SUCCESS" "Cloud Debugger API is enabled"
  else
    format-echo "WARNING" "Cloud Debugger API is not enabled"
  fi
  
  # List debuggees count
  local debuggee_count
  debuggee_count=$(gcloud debug targets list --project="$PROJECT_ID" --format="value(id)" 2>/dev/null | wc -l || echo "0")
  format-echo "INFO" "Available debuggees: $debuggee_count"
  
  # List breakpoints count if debuggee is specified
  if [[ -n "$DEBUGGEE_ID" ]]; then
    local breakpoint_count
    breakpoint_count=$(gcloud debug breakpoints list --target="$DEBUGGEE_ID" --project="$PROJECT_ID" --format="value(id)" 2>/dev/null | wc -l || echo "0")
    format-echo "INFO" "Active breakpoints: $breakpoint_count"
  fi
  
  print_with_separator "End of Status"
}

enable_api() {
  format-echo "INFO" "Enabling Cloud Debugger API..."
  enable_apis
  format-echo "SUCCESS" "Cloud Debugger API enabled"
}

get_config() {
  format-echo "INFO" "Getting debugger configuration..."
  
  print_with_separator "Debugger Configuration"
  
  # Display project info
  format-echo "INFO" "Project: $PROJECT_ID"
  
  # Check API status
  if gcloud services list --enabled --filter="name:clouddebugger.googleapis.com" --format="value(name)" | grep -q "clouddebugger"; then
    format-echo "SUCCESS" "API Status: Enabled"
  else
    format-echo "WARNING" "API Status: Disabled"
  fi
  
  # Display setup instructions
  echo
  echo "Setup Instructions:"
  echo "1. Enable Cloud Debugger API:"
  echo "   gcloud services enable clouddebugger.googleapis.com"
  echo
  echo "2. Install debugger agent in your application:"
  echo "   - Java: Add Cloud Debugger Java agent"
  echo "   - Python: Install google-python-cloud-debugger"
  echo "   - Node.js: Install @google-cloud/debug-agent"
  echo "   - Go: Import cloud.google.com/go/debugger"
  echo
  echo "3. Set environment variables:"
  echo "   GOOGLE_CLOUD_PROJECT=$PROJECT_ID"
  echo "   GAE_SERVICE=your-service-name"
  echo "   GAE_VERSION=your-version"
  echo
  echo "4. Deploy your application with source context"
  
  print_with_separator "End of Configuration"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    list-debuggees)
      list_debuggees
      ;;
    get-debuggee)
      get_debuggee
      ;;
    list-breakpoints)
      list_breakpoints
      ;;
    set-breakpoint)
      set_breakpoint
      ;;
    get-breakpoint)
      get_breakpoint
      ;;
    delete-breakpoint)
      delete_breakpoint
      ;;
    set-logpoint)
      set_logpoint
      ;;
    list-snapshots)
      list_snapshots
      ;;
    get-snapshot)
      get_snapshot
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
  
  print_with_separator "GCP Cloud Debugger Manager"
  format-echo "INFO" "Starting Cloud Debugger management operations..."
  
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
  format-echo "SUCCESS" "Cloud Debugger management operation completed successfully."
  print_with_separator "End of GCP Cloud Debugger Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
