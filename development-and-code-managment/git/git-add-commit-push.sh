#!/bin/bash
# Script to automate Git operations: add, commit, and push

# Function to display usage instructions
usage() {
  echo "Usage: $0 <commit_message> [log_file]"
  echo "Example: $0 'Initial commit' custom_log.log"
  exit 1
}

# Check if a commit message is provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Get the commit message from the first argument
COMMIT_MESSAGE=$1

# Check if a log file is provided as a second argument
LOG_FILE=""
if [ "$#" -eq 2 ]; then
  LOG_FILE="$2"
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

log_message "Starting Git operations..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
log_message "$TIMESTAMP: Starting Git operations..."

# Add all changes
log_message "Adding all changes..."
if [ -n "$LOG_FILE" ]; then
  if ! git add . >> "$LOG_FILE" 2>&1; then
    log_message "Error: Failed to add changes."
    exit 1
  fi
else
  if ! git add .; then
    log_message "Error: Failed to add changes."
    exit 1
  fi
fi

# Commit changes
log_message "Committing changes..."
if [ -n "$LOG_FILE" ]; then
  if ! git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
    log_message "Error: Failed to commit changes."
    exit 1
  fi
else
  if ! git commit -m "$COMMIT_MESSAGE"; then
    log_message "Error: Failed to commit changes."
    exit 1
  fi
fi

# Push changes
log_message "Pushing changes..."
if [ -n "$LOG_FILE" ]; then
  if ! git push >> "$LOG_FILE" 2>&1; then
    log_message "Error: Failed to push changes."
    exit 1
  fi
else
  if ! git push; then
    log_message "Error: Failed to push changes."
    exit 1
  fi
fi

log_message "$TIMESTAMP: Git operations completed successfully."