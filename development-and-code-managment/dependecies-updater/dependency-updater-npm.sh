#!/bin/bash
# dependency-updater-npm.sh
# Script to update npm dependencies and generate a summary of updated packages

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
  TERMINAL_WIDTH=$(tput cols)
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mNPM Dependency Updater\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script updates npm dependencies and generates a summary of updated packages."
  echo "  It must be run in a directory containing a 'package.json' file."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_log.log   # Run the script and log output to 'custom_log.log'"
  echo "  $0                        # Run the script without logging to a file"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Initialize variables
LOG_FILE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --log)
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
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Validate if npm is installed
if ! command -v npm &> /dev/null; then
  log_message "ERROR" "npm is not installed or not available in the PATH. Please install npm and try again."
  exit 1
fi

# Validate if the script is run in a directory with a package.json file
if [ ! -f "package.json" ]; then
  log_message "ERROR" "No package.json file found in the current directory. Please run this script in a Node.js project directory."
  exit 1
fi

# Log the start of the update process
log_message "INFO" "Starting npm dependency update..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
log_message "INFO" "$TIMESTAMP: Updating npm dependencies..."

# Update npm dependencies
print_with_separator "npm update output"
if npm update 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of npm update"
  log_message "SUCCESS" "Dependencies updated successfully!"
else
  print_with_separator "End of npm update"
  log_message "ERROR" "Failed to update dependencies! Check the log file for details: $LOG_FILE"
  exit 1
fi

# Generate a summary of updated packages
log_message "INFO" "Generating summary of updated packages..."
print_with_separator "npm outdated output"
UPDATED_PACKAGES=$(npm outdated --json 2>/dev/null)

if [ -n "$UPDATED_PACKAGES" ]; then
  log_message "INFO" "Summary of updated packages:"
  echo "$UPDATED_PACKAGES" | jq -r 'to_entries[] | "\(.key) updated from \(.value.current) to \(.value.latest)"' | tee -a "$LOG_FILE"
  print_with_separator "End of npm outdated"
else
  print_with_separator "End of npm outdated"
  log_message "INFO" "No packages were updated."
fi

log_message "INFO" "$TIMESTAMP: npm dependency update process completed."