#!/bin/bash
# schedule-task.sh
# Script to schedule a task using cron.

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
usage() {
  print_with_separator "Schedule Task Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script schedules a task using cron."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <script_path> <cron_schedule> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<script_path>\033[0m      (Required) Path to the script to schedule."
  echo -e "  \033[1;33m<cron_schedule>\033[0m    (Required) Cron schedule (e.g., '0 5 * * *')."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/script.sh '0 5 * * *' --log schedule_task.log"
  echo "  $0 /path/to/script.sh '0 5 * * *'"
  print_with_separator
  exit 1
}

# Default values
SCRIPT_PATH=""
CRON_SCHEDULE=""
LOG_FILE="/dev/null"

# Parse input arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --log)
      if [ -z "$2" ]; then
        log_message "ERROR" "No log file provided after --log."
        usage
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      if [ -z "$SCRIPT_PATH" ]; then
        SCRIPT_PATH="$1"
      elif [ -z "$CRON_SCHEDULE" ]; then
        CRON_SCHEDULE="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$SCRIPT_PATH" ] || [ -z "$CRON_SCHEDULE" ]; then
  log_message "ERROR" "Both <script_path> and <cron_schedule> are required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Starting task scheduling..."
print_with_separator "Task Scheduling Results"

# Check if the script is already scheduled
log_message "INFO" "Checking if the script is already scheduled..."
if crontab -l | grep -q "$SCRIPT_PATH"; then
  log_message "INFO" "The script is already scheduled."
else
  # Schedule the script using cron
  (crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $SCRIPT_PATH") | crontab -
  log_message "SUCCESS" "The script has been scheduled to run at '$CRON_SCHEDULE'."
fi

print_with_separator "End of Task Scheduling Results"
log_message "SUCCESS" "Task scheduling completed."