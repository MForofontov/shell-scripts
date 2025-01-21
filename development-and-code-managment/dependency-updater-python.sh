#!/bin/bash
# Script to update Python dependencies

# Function to display usage instructions
usage() {
  echo "Usage: $0 <requirements_file> [log_file]"
  echo "Example: $0 requirements.txt custom_log.log"
  exit 1
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Get the requirements file from the first argument
REQUIREMENTS_FILE=$1

# Check if a log file is provided as a second argument
LOG_FILE=""
if [ "$#" -ge 2 ]; then
  LOG_FILE="$2"
fi

# Validate requirements file
if [ ! -f "$REQUIREMENTS_FILE" ]; then
  echo "Error: Requirements file $REQUIREMENTS_FILE does not exist."
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Error: Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Function to log messages
log_message() {
  local MESSAGE=$1
  if [ -n "$MESSAGE" ]; then
    if [ -n "$LOG_FILE" ]; then
      echo "$MESSAGE" | tee -a "$LOG_FILE"
    else
      echo "$MESSAGE"
    fi
  fi
}

log_message "Updating Python dependencies from $REQUIREMENTS_FILE..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
log_message "$TIMESTAMP: Updating Python dependencies from $REQUIREMENTS_FILE..."

# Update Python dependencies
if [ -n "$LOG_FILE" ]; then
  if pip install --upgrade -r "$REQUIREMENTS_FILE" >> "$LOG_FILE" 2>&1; then
    log_message "Dependencies updated successfully!"
  else
    log_message "Failed to update dependencies!"
    exit 1
  fi
else
  if pip install --upgrade -r "$REQUIREMENTS_FILE"; then
    log_message "Dependencies updated successfully!"
  else
    log_message "Failed to update dependencies!"
    exit 1
  fi
fi