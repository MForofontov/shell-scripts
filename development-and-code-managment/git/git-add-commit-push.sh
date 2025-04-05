#!/bin/bash
# Script to automate Git operations: add, commit, and push

# Function to display usage instructions
usage() {
  echo "Usage: $0 <commit_message> [--log <log_file>] [--help]"
  echo
  echo "Options:"
  echo "  <commit_message>    (Required) The commit message for the changes."
  echo "  --log <log_file>    (Optional) Log output to the specified file."
  echo "  --help              (Optional) Display this help message."
  echo
  echo "Example:"
  echo "  $0 'Initial commit' --log git_operations.log"
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
        echo "Unknown option: $1"
        usage
      fi
      ;;
  esac
done

# Validate required arguments
if [ -z "$COMMIT_MESSAGE" ]; then
  echo "Error: <commit_message> is required."
  usage
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
if ! git add . >> "$LOG_FILE" 2>&1; then
  log_message "Error: Failed to add changes."
  exit 1
fi

# Commit changes
log_message "Committing changes..."
if ! git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
  log_message "Error: Failed to commit changes."
  exit 1
fi

# Push changes
log_message "Pushing changes..."
if ! git push >> "$LOG_FILE" 2>&1; then
  log_message "Error: Failed to push changes."
  exit 1
fi

log_message "$TIMESTAMP: Git operations completed successfully."