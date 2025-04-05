#!/bin/bash
# Git Stash Manager
# Script to manage Git stashes (list, apply, drop)

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
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Display available stashes
log_message "INFO" "Available stashes:"
git stash list | tee -a "$LOG_FILE"

# Prompt user for stash index
log_message "INFO" "Enter stash index to apply or drop (e.g., stash@{0}):"
read -r STASH_INDEX

# Validate stash index
if ! git stash list | grep -q "$STASH_INDEX"; then
  log_message "ERROR" "Invalid stash index $STASH_INDEX"
  exit 1
fi

# Prompt user for action
log_message "INFO" "Choose an action: [apply/drop]"
read -r ACTION

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Perform the chosen action
if [ "$ACTION" == "apply" ]; then
  log_message "INFO" "$TIMESTAMP: Applying stash $STASH_INDEX..."
  if git stash apply "$STASH_INDEX" >> "$LOG_FILE" 2>&1; then
    log_message "SUCCESS" "Stash $STASH_INDEX applied successfully."
  else
    log_message "ERROR" "Failed to apply stash $STASH_INDEX."
    exit 1
  fi
elif [ "$ACTION" == "drop" ]; then
  log_message "INFO" "$TIMESTAMP: Dropping stash $STASH_INDEX..."
  if git stash drop "$STASH_INDEX" >> "$LOG_FILE" 2>&1; then
    log_message "SUCCESS" "Stash $STASH_INDEX dropped successfully."
  else
    log_message "ERROR" "Failed to drop stash $STASH_INDEX."
    exit 1
  fi
else
  log_message "ERROR" "Invalid action!"
  exit 1
fi