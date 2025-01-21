#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/development-and-code-managment/git/git-conflict-finder.sh
# Git Conflict Finder

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
  if [ -n "$LOG_FILE" ]; then
    echo "$MESSAGE" | tee -a "$LOG_FILE"
  else
    echo "$MESSAGE"
  fi
}

log_message "Checking for unresolved conflicts..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
log_message "$TIMESTAMP: Checking for unresolved conflicts..."

# Find merge conflicts
CONFLICTS=$(git diff --name-only --diff-filter=U)

if [ $? -eq 0 ]; then
  if [ -n "$CONFLICTS" ]; then
    log_message "Conflicted files:"
    log_message "$CONFLICTS"
  else
    log_message "No conflicts found!"
  fi
else
  log_message "Error: Failed to check for conflicts."
  exit 1
fi