#!/bin/bash
# npm-list-global.sh
# Script to list all globally installed NPM packages.

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

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
  print_with_separator "NPM List Global Packages Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script lists all globally installed NPM packages."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log npm_global_packages.log"
  echo "  $0"
  print_with_separator
  exit 1
}

# Default values
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

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Starting to list globally installed NPM packages..."
print_with_separator "NPM Global Packages"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
  log_message "ERROR" "npm is not installed. Please install Node.js and npm first."
  exit 1
fi

# List globally installed NPM packages
if npm list -g --depth=0; then
  log_message "SUCCESS" "Successfully listed globally installed NPM packages."
else
  print_with_separator "End of NPM Global Packages"
  log_message "ERROR" "Failed to list globally installed NPM packages."
  exit 1
fi

# Notify user
print_with_separator "End of NPM Global Packages"
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  log_message "SUCCESS" "List of globally installed NPM packages has been written to $LOG_FILE."
else
  log_message "INFO" "List of globally installed NPM packages displayed on the console."
fi