#!/bin/bash
# dependency-updater-python.sh
# Script to update Python dependencies listed in a requirements file

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-with-separator.sh"

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
  echo -e "\033[1;34mPython Dependency Updater\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script updates Python dependencies listed in a requirements file."
  echo "  It must be run in an environment where 'pip' is installed and accessible."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <requirements_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<requirements_file>\033[0m       (Required) Path to the requirements file."
  echo -e "  \033[1;33m--log <log_file>\033[0m          (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 requirements.txt               # Update dependencies without logging."
  echo "  $0 requirements.txt --log log.txt # Update dependencies and log output to 'log.txt'."
  echo "$SEPARATOR"
  echo
  exit 1
}

# Initialize variables
REQUIREMENTS_FILE=""
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
      if [ -z "$REQUIREMENTS_FILE" ]; then
        REQUIREMENTS_FILE="$1"
        shift
      else
        echo "Error: Unknown option or multiple requirements files provided: $1"
        usage
      fi
      ;;
  esac
done

# Validate requirements file
if [ -z "$REQUIREMENTS_FILE" ]; then
  log_message "ERROR" "Requirements file is required."
  usage
fi

if [ ! -f "$REQUIREMENTS_FILE" ]; then
  log_message "ERROR" "Requirements file '$REQUIREMENTS_FILE' does not exist."
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file '$LOG_FILE'."
    exit 1
  fi
fi

# Validate if pip is installed
if ! command -v pip &> /dev/null; then
  log_message "ERROR" "pip is not installed or not available in the PATH. Please install pip and try again."
  exit 1
fi

# Log the start of the update process
log_message "INFO" "Updating Python dependencies from '$REQUIREMENTS_FILE'..."
log_message "INFO" "Starting dependency update process..."

# Update Python dependencies with separators in the log file and stdout
print_with_separator "pip install output"
if pip install --upgrade -r "$REQUIREMENTS_FILE" 2>&1 | tee -a "$LOG_FILE"; then
  log_message "SUCCESS" "Dependencies updated successfully!"
else
  log_message "ERROR" "Failed to update dependencies! Check the log file for details: $LOG_FILE"
  exit 1
fi
print_with_separator "End of pip install"

log_message "INFO" "Dependency update process completed."