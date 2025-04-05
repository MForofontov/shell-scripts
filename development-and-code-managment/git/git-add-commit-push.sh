#!/bin/bash
# Script to automate Git operations: add, commit, and push

# Import the log_message function from log_with_levels.sh
LOGGER_FILE="/Users/mykfor1/Documents/git/github/shell-scripts/utils/log/log_with_levels.sh"

if [ -f "$LOGGER_FILE" ]; then
  source "$LOGGER_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOGGER_FILE"
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
  echo -e "\033[1;34mGit Add, Commit, and Push Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script automates the process of adding, committing, and pushing changes to a Git repository."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <commit_message> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<commit_message>\033[0m    (Required) The commit message for the changes."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExample:\033[0m"
  echo "  $0 'Initial commit' --log git_operations.log"
  echo "$SEPARATOR"
  echo
  exit 0
}

# Check if no arguments are provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Initialize variables
COMMIT_MESSAGE=""
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
      if [ -z "$COMMIT_MESSAGE" ]; then
        COMMIT_MESSAGE="$1"
        shift
      else
        log_message "ERROR" "Unknown option: $1"
        usage
      fi
      ;;
  esac
done

# Validate required arguments
if [ -z "$COMMIT_MESSAGE" ]; then
  log_message "ERROR" "<commit_message> is required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

log_message "INFO" "Starting Git operations..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
log_message "INFO" "$TIMESTAMP: Starting Git operations..."

# Add all changes
log_message "INFO" "Adding all changes..."
if ! git add . >> "$LOG_FILE" 2>&1; then
  log_message "ERROR" "Failed to add changes."
  exit 1
fi

# Commit changes
log_message "INFO" "Committing changes..."
if ! git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
  log_message "ERROR" "Failed to commit changes."
  exit 1
fi

# Push changes
log_message "INFO" "Pushing changes..."
if ! git push >> "$LOG_FILE" 2>&1; then
  log_message "ERROR" "Failed to push changes."
  exit 1
fi

log_message "SUCCESS" "$TIMESTAMP: Git operations completed successfully."