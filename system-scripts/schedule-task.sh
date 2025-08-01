#!/usr/bin/env bash
# schedule-task.sh
# Script to schedule a task using cron or launchd (on macOS).

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
SCRIPT_PATH=""
CRON_SCHEDULE=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
TASK_NAME=""
USE_LAUNCHD=false
TASK_DESCRIPTION=""
USER_EMAIL=""
OVERWRITE=false
EXIT_CODE=0

# Detect if running on macOS
IS_MACOS=false
[[ "$OSTYPE" == "darwin"* ]] && IS_MACOS=true

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Schedule Task Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script schedules a task using cron (Linux/Unix) or launchd (macOS)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <script_path> <cron_schedule> [--name <task_name>] [--description <description>]"
  echo "     [--email <email>] [--use-launchd] [--overwrite] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<script_path>\033[0m              (Required) Path to the script to schedule."
  echo -e "  \033[1;36m<cron_schedule>\033[0m            (Required) Cron schedule expression (e.g., '0 5 * * *')."
  echo -e "  \033[1;33m--name <task_name>\033[0m         (Optional) Name for the scheduled task (required for launchd)."
  echo -e "  \033[1;33m--description <description>\033[0m (Optional) Description of the task."
  echo -e "  \033[1;33m--email <email>\033[0m            (Optional) Email address for task notifications."
  echo -e "  \033[1;33m--use-launchd\033[0m              (Optional) Use launchd instead of cron on macOS."
  echo -e "  \033[1;33m--overwrite\033[0m                (Optional) Overwrite existing task if it exists."
  echo -e "  \033[1;33m--log <log_file>\033[0m           (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/script.sh '0 5 * * *' --log schedule_task.log"
  echo "  $0 /path/to/script.sh '0 5 * * *' --name 'daily-backup' --description 'Daily backup job'"
  echo "  $0 /path/to/script.sh '0 5 * * *' --email admin@example.com --overwrite"
  echo "  $0 /path/to/script.sh '0 5 * * *' --use-launchd --name 'com.mycompany.backup'"
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
      --name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No task name provided after --name."
          usage
        fi
        TASK_NAME="$2"
        shift 2
        ;;
      --description)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No description provided after --description."
          usage
        fi
        TASK_DESCRIPTION="$2"
        shift 2
        ;;
      --email)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No email provided after --email."
          usage
        fi
        USER_EMAIL="$2"
        shift 2
        ;;
      --use-launchd)
        USE_LAUNCHD=true
        shift
        ;;
      --overwrite)
        OVERWRITE=true
        shift
        ;;
      *)
        if [ -z "$SCRIPT_PATH" ]; then
          SCRIPT_PATH="$1"
        elif [ -z "$CRON_SCHEDULE" ]; then
          CRON_SCHEDULE="$1"
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        shift
        ;;
    esac
  done
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Function to validate cron schedule expression
validate_cron_schedule() {
  local schedule="$1"
  
  # Basic pattern matching for cron schedule (5 fields)
  if ! [[ "$schedule" =~ ^[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+$ ]]; then
    format-echo "ERROR" "Invalid cron schedule format: $schedule"
    format-echo "INFO" "Format should be: minute hour day month weekday (e.g., '0 5 * * *')"
    return 1
  fi
  
  return 0
}

# Function to convert cron schedule to launchd format
cron_to_launchd() {
  local cron="$1"
  
  # Extract components
  local minute=$(echo "$cron" | awk '{print $1}')
  local hour=$(echo "$cron" | awk '{print $2}')
  local day=$(echo "$cron" | awk '{print $3}')
  local month=$(echo "$cron" | awk '{print $4}')
  local weekday=$(echo "$cron" | awk '{print $5}')
  
  local launchd_xml=""
  
  # Handle minutes
  if [[ "$minute" != "*" ]]; then
    launchd_xml+="  <key>Minute</key>\n  <integer>$minute</integer>\n"
  fi
  
  # Handle hours
  if [[ "$hour" != "*" ]]; then
    launchd_xml+="  <key>Hour</key>\n  <integer>$hour</integer>\n"
  fi
  
  # Handle days
  if [[ "$day" != "*" ]]; then
    launchd_xml+="  <key>Day</key>\n  <integer>$day</integer>\n"
  fi
  
  # Handle months
  if [[ "$month" != "*" ]]; then
    launchd_xml+="  <key>Month</key>\n  <integer>$month</integer>\n"
  fi
  
  # Handle weekdays
  if [[ "$weekday" != "*" ]]; then
    launchd_xml+="  <key>Weekday</key>\n  <integer>$weekday</integer>\n"
  fi
  
  echo -e "$launchd_xml"
}

# Function to check if a task already exists
task_exists() {
  local script_path="$1"
  
  if [[ "$USE_LAUNCHD" == "true" && "$IS_MACOS" == "true" ]]; then
    if [[ -z "$TASK_NAME" ]]; then
      format-echo "ERROR" "Task name is required for launchd. Use --name option."
      return 2
    fi
    
    # Check if plist file exists
    if [[ -f "$HOME/Library/LaunchAgents/$TASK_NAME.plist" ]]; then
      return 0  # Task exists
    else
      return 1  # Task does not exist
    fi
  else
    # Check in crontab
    if crontab -l 2>/dev/null | grep -q -F "$script_path"; then
      return 0  # Task exists
    else
      return 1  # Task does not exist
    fi
  fi
}

# Function to generate launchd plist file
create_launchd_plist() {
  local script_path="$1"
  local cron_schedule="$2"
  local task_name="${TASK_NAME:-com.script.task}"
  local description="${TASK_DESCRIPTION:-Scheduled task}"
  local plist_file="$HOME/Library/LaunchAgents/$task_name.plist"
  
  # Create LaunchAgents directory if it doesn't exist
  mkdir -p "$HOME/Library/LaunchAgents"
  
  # Generate plist content
  cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$task_name</string>
  <key>ProgramArguments</key>
  <array>
    <string>$script_path</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
$(cron_to_launchd "$cron_schedule")
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/$task_name.err</string>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/$task_name.log</string>
EOF

  # Add description if provided
  if [[ -n "$TASK_DESCRIPTION" ]]; then
    cat >> "$plist_file" << EOF
  <key>ProcessType</key>
  <string>Background</string>
  <key>ServiceDescription</key>
  <string>$TASK_DESCRIPTION</string>
EOF
  fi

  # Close the plist
  cat >> "$plist_file" << EOF
</dict>
</plist>
EOF

  # Set proper permissions
  chmod 644 "$plist_file"
  
  format-echo "SUCCESS" "Created launchd plist file: $plist_file"
  return 0
}

# Function to schedule a task using launchd
schedule_with_launchd() {
  local script_path="$1"
  local cron_schedule="$2"
  local task_name="${TASK_NAME:-com.script.task}"
  
  # Generate plist file
  if ! create_launchd_plist "$script_path" "$cron_schedule"; then
    format-echo "ERROR" "Failed to create launchd plist file."
    return 1
  fi
  
  # Load the task
  if launchctl load -w "$HOME/Library/LaunchAgents/$task_name.plist"; then
    format-echo "SUCCESS" "Task scheduled with launchd as '$task_name'."
    return 0
  else
    format-echo "ERROR" "Failed to load launchd task."
    return 1
  fi
}

# Function to schedule a task using cron
schedule_with_cron() {
  local script_path="$1"
  local cron_schedule="$2"
  
  # Prepare cron entry with optional email notification
  local cron_entry="$cron_schedule $script_path"
  if [[ -n "$USER_EMAIL" ]]; then
    cron_entry="$cron_schedule MAILTO=\"$USER_EMAIL\" $script_path"
  fi
  
  # Add to crontab
  local temp_crontab=$(mktemp)
  crontab -l 2>/dev/null > "$temp_crontab" || true
  echo "$cron_entry" >> "$temp_crontab"
  
  if crontab "$temp_crontab"; then
    rm -f "$temp_crontab"
    format-echo "SUCCESS" "Task scheduled with cron to run at '$cron_schedule'."
    return 0
  else
    rm -f "$temp_crontab"
    format-echo "ERROR" "Failed to update crontab."
    return 1
  fi
}

# Function to remove an existing task
remove_task() {
  local script_path="$1"
  
  if [[ "$USE_LAUNCHD" == "true" && "$IS_MACOS" == "true" ]]; then
    if [[ -z "$TASK_NAME" ]]; then
      format-echo "ERROR" "Task name is required for launchd. Use --name option."
      return 1
    fi
    
    # Unload and remove plist
    launchctl unload -w "$HOME/Library/LaunchAgents/$TASK_NAME.plist" 2>/dev/null || true
    if rm -f "$HOME/Library/LaunchAgents/$TASK_NAME.plist"; then
      format-echo "SUCCESS" "Removed existing launchd task: $TASK_NAME"
      return 0
    else
      format-echo "ERROR" "Failed to remove existing launchd task."
      return 1
    fi
  else
    # Remove from crontab
    local temp_crontab=$(mktemp)
    crontab -l 2>/dev/null | grep -v -F "$script_path" > "$temp_crontab" || true
    
    if crontab "$temp_crontab"; then
      rm -f "$temp_crontab"
      format-echo "SUCCESS" "Removed existing cron task for: $script_path"
      return 0
    else
      rm -f "$temp_crontab"
      format-echo "ERROR" "Failed to update crontab."
      return 1
    fi
  fi
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

  print_with_separator "Schedule Task Script"
  format-echo "INFO" "Starting Schedule Task Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate required arguments
  if [ -z "$SCRIPT_PATH" ] || [ -z "$CRON_SCHEDULE" ]; then
    format-echo "ERROR" "Both <script_path> and <cron_schedule> are required."
    print_with_separator "End of Schedule Task Script"
    usage
  fi
  
  # Check if the script exists and is executable
  if [ ! -f "$SCRIPT_PATH" ]; then
    format-echo "ERROR" "Script file '$SCRIPT_PATH' does not exist."
    print_with_separator "End of Schedule Task Script"
    exit 1
  fi

  # Ensure script is executable
  if [ ! -x "$SCRIPT_PATH" ]; then
    format-echo "WARNING" "Script '$SCRIPT_PATH' is not executable. Attempting to set executable permission."
    if chmod +x "$SCRIPT_PATH"; then
      format-echo "SUCCESS" "Set executable permission for '$SCRIPT_PATH'."
    else
      format-echo "ERROR" "Failed to set executable permission for '$SCRIPT_PATH'."
      print_with_separator "End of Schedule Task Script"
      exit 1
    fi
  fi
  
  # Validate cron schedule format
  if ! validate_cron_schedule "$CRON_SCHEDULE"; then
    print_with_separator "End of Schedule Task Script"
    exit 1
  fi
  
  # For launchd, ensure we have a task name
  if [[ "$USE_LAUNCHD" == "true" && "$IS_MACOS" == "true" && -z "$TASK_NAME" ]]; then
    format-echo "ERROR" "Task name (--name) is required when using launchd."
    print_with_separator "End of Schedule Task Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # TASK SCHEDULING
  #---------------------------------------------------------------------
  # Check if task already exists
  task_exists "$SCRIPT_PATH"
  task_status=$?
  
  if [[ $task_status -eq 0 ]]; then
    format-echo "INFO" "Task for '$SCRIPT_PATH' already exists."
    if [[ "$OVERWRITE" == "true" ]]; then
      format-echo "INFO" "Removing existing task (--overwrite specified)..."
      if ! remove_task "$SCRIPT_PATH"; then
        EXIT_CODE=1
        print_with_separator "End of Schedule Task Script"
        exit 1
      fi
    else
      format-echo "WARNING" "Task not scheduled. Use --overwrite to replace existing task."
      print_with_separator "End of Schedule Task Script"
      exit 0
    fi
  elif [[ $task_status -eq 2 ]]; then
    # Error was already displayed in task_exists function
    EXIT_CODE=1
    print_with_separator "End of Schedule Task Script"
    exit 1
  fi
  
  # Schedule the task
  if [[ "$USE_LAUNCHD" == "true" && "$IS_MACOS" == "true" ]]; then
    format-echo "INFO" "Using launchd to schedule the task..."
    if ! schedule_with_launchd "$SCRIPT_PATH" "$CRON_SCHEDULE"; then
      EXIT_CODE=1
    fi
  else
    format-echo "INFO" "Using cron to schedule the task..."
    if ! schedule_with_cron "$SCRIPT_PATH" "$CRON_SCHEDULE"; then
      EXIT_CODE=1
    fi
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Schedule Task Script"
  
  if [[ $EXIT_CODE -eq 0 ]]; then
    format-echo "SUCCESS" "Task scheduling completed successfully."
  else
    format-echo "ERROR" "Task scheduling failed."
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
