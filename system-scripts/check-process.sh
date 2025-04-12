#!/bin/bash
# check-process.sh
# Script to check if a specific process is running.

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
  print_with_separator "Check Process Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks if a specific process is running."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <process_name> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<process_name>\033[0m  (Required) Name of the process to check."
  echo -e "  \033[1;33m--log <log_file>\033[0m (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m          (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 nginx --log process_check.log"
  echo "  $0 apache2"
  print_with_separator
  exit 1
}

# Default values
PROCESS_NAME=""
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
      if [ -z "$PROCESS_NAME" ]; then
        PROCESS_NAME="$1"
        shift
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      ;;
  esac
done

# Validate process name
if [ -z "$PROCESS_NAME" ]; then
  log_message "ERROR" "Process name is required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Checking if process $PROCESS_NAME is running..."
print_with_separator "Process Check"

# Check if the process is running
if pgrep "$PROCESS_NAME" > /dev/null; then
  log_message "SUCCESS" "Process $PROCESS_NAME is running."
else
  log_message "ERROR" "Process $PROCESS_NAME is not running."
fi

print_with_separator "End of Process Check"
log_message "INFO" "Process check completed."