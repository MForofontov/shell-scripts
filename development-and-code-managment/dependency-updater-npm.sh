#!/bin/bash
# Script to update npm dependencies

# Function to display usage instructions
usage() {
  echo "Usage: $0 [log_file]"
  echo "Example: $0 custom_log.log"
  exit 1
}

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -gt 1 ]; then
  usage
elif [ "$#" -eq 1 ]; then
  LOG_FILE="$1"
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

log_message "Starting npm dependency update..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
log_message "$TIMESTAMP: Updating npm dependencies..."

# Update npm dependencies
if [ -n "$LOG_FILE" ]; then
  if npm update >> "$LOG_FILE" 2>&1; then
    log_message "Dependencies updated successfully!"
  else
    log_message "Failed to update dependencies!"
    exit 1
  fi
else
  if npm update; then
    log_message "Dependencies updated successfully!"
  else
    log_message "Failed to update dependencies!"
    exit 1
  fi
fi

# Generate a summary of updated packages
log_message "Generating summary of updated packages..."
UPDATED_PACKAGES=$(npm outdated --json)
if [ -n "$UPDATED_PACKAGES" ]; then
  log_message "Summary of updated packages:"
  if [ -n "$LOG_FILE" ]; then
    echo "$UPDATED_PACKAGES" | jq -r 'to_entries[] | "\(.key) updated from \(.value.current) to \(.value.latest)"' | tee -a "$LOG_FILE"
  else
    echo "$UPDATED_PACKAGES" | jq -r 'to_entries[] | "\(.key) updated from \(.value.current) to \(.value.latest)"'
  fi
else
  log_message "No packages were updated."
fi

log_message "$TIMESTAMP: npm dependency update process completed."