#!/bin/bash
# Script to update npm dependencies

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger file relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../utils/log/log_with_levels.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
usage() {
  # Get the terminal width
  TERMINAL_WIDTH=$(tput cols)
  # Generate a separator line based on the terminal width
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
if [ -n "$LOG_FILE" ]; then
  if npm update >> "$LOG_FILE" 2>&1; then
    log_message "SUCCESS" "Dependencies updated successfully!"
  else
    log_message "ERROR" "Failed to update dependencies!"
    exit 1
  fi
else
  if npm update; then
    log_message "SUCCESS" "Dependencies updated successfully!"
  else
    log_message "ERROR" "Failed to update dependencies!"
    exit 1
  fi
fi

# Generate a summary of updated packages
log_message "INFO" "Generating summary of updated packages..."
UPDATED_PACKAGES=$(npm outdated --json)
if [ -n "$UPDATED_PACKAGES" ]; then
  log_message "INFO" "Summary of updated packages:"
  if [ -n "$LOG_FILE" ]; then
    echo "$UPDATED_PACKAGES" | jq -r 'to_entries[] | "\(.key) updated from \(.value.current) to \(.value.latest)"' | tee -a "$LOG_FILE"
  else
    echo "$UPDATED_PACKAGES" | jq -r 'to_entries[] | "\(.key) updated from \(.value.current) to \(.value.latest)"'
  fi
else
  log_message "INFO" "No packages were updated."
fi

log_message "INFO" "$TIMESTAMP: npm dependency update process completed."