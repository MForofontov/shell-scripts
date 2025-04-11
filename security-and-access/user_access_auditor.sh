#!/bin/bash
# user_access_auditor.sh
# Script to audit user access and log the results.

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
  print_with_separator "User Access Auditor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script audits user access and logs the results."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages (default: user_access.log)."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_user_access.log"
  echo "  $0"
  print_with_separator
  exit 1
}

# Default log file
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
      log_message "ERROR" "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate log file
if ! touch "$LOG_FILE" 2>/dev/null; then
  log_message "ERROR" "Cannot write to log file $LOG_FILE."
  exit 1
fi

log_message "INFO" "Starting user access audit..."
print_with_separator "User Access Audit Results"

# Audit user access
log_message "INFO" "Listing system users and their details..."
log_message "Username:Home Directory:Shell"
cat /etc/passwd | awk -F: '{ print $1 ":" $6 ":" $7 }' | tee -a "$LOG_FILE"

print_with_separator "End of User Access Audit"
log_message "SUCCESS" "User access audit completed. Log saved to $LOG_FILE."