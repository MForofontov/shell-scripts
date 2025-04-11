#!/bin/bash
# group_access_auditor.sh
# Script to list all groups and their members.

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
  print_with_separator "Group Access Auditor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script lists all groups and their members."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the audit log (default: prints to console)."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_group_access.log"
  echo "  $0"
  print_with_separator
  exit 1
}

# Parse input arguments
LOG_FILE="/dev/null"
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
      log_message "ERROR" "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE."
    exit 1
  fi
fi

log_message "INFO" "Starting group access audit..."
print_with_separator "Group Access Audit Results"

# List all groups and their members
list_groups() {
  if [ -n "$LOG_FILE" ]; then
    cat /etc/group | awk -F: '{ print $1 ": " $4 }' | tee -a "$LOG_FILE"
  else
    cat /etc/group | awk -F: '{ print $1 ": " $4 }'
  fi
}

# Perform the group access audit
if ! list_groups; then
  print_with_separator "End of Group Access Audit Results"
  log_message "ERROR" "Failed to list groups and their members."
  exit 1
fi

print_with_separator "End of Group Access Audit Results"
if [ -n "$LOG_FILE" ]; then
  log_message "SUCCESS" "Group access audit completed. Log saved to $LOG_FILE."
else
  log_message "SUCCESS" "Group access audit completed. Results displayed on the console."
fi