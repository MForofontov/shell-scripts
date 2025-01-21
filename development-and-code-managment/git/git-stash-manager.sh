#!/bin/bash

# Git Stash Manager

# Default log file
LOG_FILE="git_stash_manager.log"

# Display available stashes
echo "Available stashes:"
git stash list | tee -a "$LOG_FILE"

# Prompt user for stash index
echo "Enter stash index to apply or drop (e.g., stash@{0}):"
read -r STASH_INDEX

# Prompt user for action
echo "Choose an action: [apply/drop]"
read -r ACTION

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Perform the chosen action
if [ "$ACTION" == "apply" ]; then
  echo "$TIMESTAMP: Applying stash $STASH_INDEX..." | tee -a "$LOG_FILE"
  if git stash apply "$STASH_INDEX" >> "$LOG_FILE" 2>&1; then
    echo "Stash $STASH_INDEX applied successfully." | tee -a "$LOG_FILE"
  else
    echo "Error: Failed to apply stash $STASH_INDEX." | tee -a "$LOG_FILE"
    exit 1
  fi
elif [ "$ACTION" == "drop" ]; then
  echo "$TIMESTAMP: Dropping stash $STASH_INDEX..." | tee -a "$LOG_FILE"
  if git stash drop "$STASH_INDEX" >> "$LOG_FILE" 2>&1; then
    echo "Stash $STASH_INDEX dropped successfully." | tee -a "$LOG_FILE"
  else
    echo "Error: Failed to drop stash $STASH_INDEX." | tee -a "$LOG_FILE"
    exit 1
  fi
else
  echo "Invalid action!" | tee -a "$LOG_FILE"
  exit 1
fi