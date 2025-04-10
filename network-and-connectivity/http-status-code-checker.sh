#!/bin/bash
# http-status-code-checker.sh
# Script to check HTTP status codes for a list of URLs

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
  print_with_separator "HTTP Status Code Checker Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks HTTP status codes for a list of URLs."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <url1> <url2> ... [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<url1> <url2> ...\033[0m  (Required) List of URLs to check."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 https://google.com https://github.com --log custom_log.log"
  echo "  $0 https://example.com"
  print_with_separator
  exit 1
}

# Check if no arguments are provided
if [ "$#" -eq 0 ]; then
  log_message "ERROR" "<url1> <url2> ... are required."
  usage
fi

# Initialize variables
URLS=()
LOG_FILE="/dev/null"

# Parse arguments using while and case
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --log)
      if [[ -n "$2" ]]; then
        LOG_FILE="$2"
        shift 2
      else
        log_message "ERROR" "Missing argument for --log"
        usage
      fi
      ;;
    --help)
      usage
      ;;
    *)
      URLS+=("$1")
      shift
      ;;
  esac
done

# Validate URLs
if [ "${#URLS[@]}" -eq 0 ]; then
  log_message "ERROR" "At least one URL is required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

log_message "INFO" "Checking HTTP status codes for the following URLs: ${URLS[*]}"
print_with_separator "HTTP Status Code Output"

# Function to check HTTP status codes
check_status_codes() {
  for URL in "${URLS[@]}"; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")
    if [[ "$STATUS_CODE" -ge 200 && "$STATUS_CODE" -lt 400 ]]; then
      log_message "INFO" "$TIMESTAMP: $URL: $STATUS_CODE (Success)"
    else
      log_message "ERROR" "$TIMESTAMP: $URL: $STATUS_CODE (Error)"
    fi
  done
}

# Check status codes and handle errors
if ! check_status_codes; then
  log_message "ERROR" "Failed to check HTTP status codes."
  print_with_separator "End of HTTP Status Code Output"
  exit 1
fi

print_with_separator "End of HTTP Status Code Output"
log_message "SUCCESS" "HTTP status code check complete."