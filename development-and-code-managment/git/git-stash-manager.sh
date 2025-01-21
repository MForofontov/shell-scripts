#!/bin/bash
# Git Stash Manager

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

# Display available stashes
log_message "Available stashes:"
git stash list | tee -a "$LOG_FILE"

# Prompt user for stash index
log_message "Enter stash index to apply or drop (e.g., stash@{0}):"
read -r STASH_INDEX

# Validate stash index
if ! git stash list | grep -q "$STASH_INDEX"; then
  log_message "Error: Invalid stash index $STASH_INDEX"
  exit 1
fi

# Prompt user for action
log_message "Choose an action: [apply/drop]"
read -r ACTION

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Perform the chosen action
if [ "$ACTION" == "apply" ]; then
  log_message "$TIMESTAMP: Applying stash $STASH_INDEX..."
  if [ -n "$LOG_FILE" ]; then
    if git stash apply "$STASH_INDEX" >> "$LOG_FILE" 2>&1; then
      log_message "Stash $STASH_INDEX applied successfully."
    else
      log_message "Error: Failed to apply stash $STASH_INDEX."
      exit 1
    fi
  else
    if git stash apply "$STASH_INDEX"; then
      log_message "Stash $STASH_INDEX applied successfully."
    else
      log_message "Error: Failed to apply stash $STASH_INDEX."
      exit 1
    fi
  fi
elif [ "$ACTION" == "drop" ]; then
  log_message "$TIMESTAMP: Dropping stash $STASH_INDEX..."
  if [ -n "$LOG_FILE" ]; then
    if git stash drop "$STASH_INDEX" >> "$LOG_FILE" 2>&1; then
      log_message "Stash $STASH_INDEX dropped successfully."
    else
      log_message "Error: Failed to drop stash $STASH_INDEX."
      exit 1
    fi
  else
    if git stash drop "$STASH_INDEX"; then
      log_message "Stash $STASH_INDEX dropped successfully."
    else
      log_message "Error: Failed to drop stash $STASH_INDEX."
      exit 1
    fi
  fi
else
  log_message "Invalid action!"
  exit 1
fi
