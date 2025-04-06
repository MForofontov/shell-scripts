#!/bin/bash
# Script to update Python dependencies

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
  echo "Error: Requirements file is required."
  usage
fi

if [ ! -f "$REQUIREMENTS_FILE" ]; then
  echo "Error: Requirements file '$REQUIREMENTS_FILE' does not exist."
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Error: Cannot write to log file '$LOG_FILE'."
    exit 1
  fi
fi

# Validate if pip is installed
if ! command -v pip &> /dev/null; then
  echo "Error: pip is not installed or not available in the PATH. Please install pip and try again."
  exit 1
fi

# Function to log messages with levels
log_message() {
  local LEVEL=$1
  local MESSAGE=$2
  local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  local FORMATTED_MESSAGE="[$TIMESTAMP] [$LEVEL] $MESSAGE"

  if [ -n "$LOG_FILE" ]; then
    echo "$FORMATTED_MESSAGE" | tee -a "$LOG_FILE"
  else
    echo "$FORMATTED_MESSAGE"
  fi
}

# Log the start of the update process
log_message "INFO" "Updating Python dependencies from '$REQUIREMENTS_FILE'..."
log_message "INFO" "Starting dependency update process..."

# Update Python dependencies with separators in the log file
if [ -n "$LOG_FILE" ]; then
  echo "========== pip install output ==========" >> "$LOG_FILE"
  if pip install --upgrade -r "$REQUIREMENTS_FILE" >> "$LOG_FILE" 2>&1; then
    echo "========== End of pip install ==========" >> "$LOG_FILE"
    log_message "SUCCESS" "Dependencies updated successfully!"
  else
    echo "========== End of pip install ==========" >> "$LOG_FILE"
    log_message "ERROR" "Failed to update dependencies! Check the log file for details: $LOG_FILE"
    exit 1
  fi
else
  if pip install --upgrade -r "$REQUIREMENTS_FILE"; then
    log_message "SUCCESS" "Dependencies updated successfully!"
  else
    log_message "ERROR" "Failed to update dependencies!"
    exit 1
  fi
fi

log_message "INFO" "Dependency update process completed."