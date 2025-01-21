#!/bin/bash

# Git Stash Manager

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -eq 1 ]; then
  LOG_FILE="$1"
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

# Display available stashes
log_message "Available stashes:"
git stash list | tee -a "$LOG_FILE"

# Prompt user for stash index
log_message "Enter stash index to apply or drop (e.g., stash@{0}):"
read -r STASH_INDEX

# Prompt user for action
log_message "Choose an action: [apply/drop]"
read -r ACTION

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Perform the chosen action
if [ "$ACTION" == "apply" ]; then
  log_message "$TIMESTAMP: Applying stash $STASH_INDEX..."
  if git stash apply "$STASH_INDEX" >> "$LOG_FILE" 2>&1; then
    log_message "Stash $STASH_INDEX applied successfully."
  else
    log_message "Error: Failed to apply stash $STASH_INDEX."
    exit 1
  fi
elif [ "$ACTION" == "drop" ]; then
  log_message "$TIMESTAMP: Dropping stash $STASH_INDEX..."
  if git stash drop "$STASH_INDEX" >> "$LOG_FILE" 2>&1; then
    log_message "Stash $STASH_INDEX dropped successfully."
  else
    log_message "Error: Failed to drop stash $STASH_INDEX."
    exit 1
  fi
else
  log_message "Invalid action!"
  exit 1
fi