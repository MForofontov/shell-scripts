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
  # Get the terminal width
  TERMINAL_WIDTH=$(tput cols)
  # Generate a separator line based on the terminal width
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mGit Stash Manager\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script helps you manage Git stashes. It allows you to:"
  echo "    - List all available stashes"
  echo "    - Apply a specific stash"
  echo "    - Drop a specific stash"
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_log.log   # Run the script and log output to 'custom_log.log'"
  echo "  $0                        # Run the script without logging to a file"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Initialize variables
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
      log_message "ERROR" "Unknown option: $1"
      usage
      ;;
  esac
done

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