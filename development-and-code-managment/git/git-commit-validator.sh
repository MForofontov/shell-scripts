#!/bin/bash
# Git Commit Validator
# Script to validate and commit changes with a proper commit message

# Function to display usage instructions
usage() {
  echo "Usage: $0 [--log <log_file>] [--help]"
  echo
  echo "Options:"
  echo "  --log <log_file>    (Optional) Log output to the specified file."
  echo "  --help              (Optional) Display this help message."
  echo
  echo "Example:"
  echo "  $0 --log commit_validation.log"
  exit 0
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
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

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

# Prompt user for commit message
log_message "Enter commit message:"
read -r COMMIT_MESSAGE

# Check if commit message is empty
if [ -z "$COMMIT_MESSAGE" ]; then
  log_message "Error: Commit message cannot be empty!"
  exit 1
fi

# Validate commit message format (example: must start with a capital letter and be at least 10 characters long)
if [[ ! "$COMMIT_MESSAGE" =~ ^[A-Z] ]] || [ ${#COMMIT_MESSAGE} -lt 10 ]; then
  log_message "Error: Invalid commit message format! Must start with a capital letter and be at least 10 characters long."
  exit 1
fi

# Check if there are changes staged for commit
log_message "Validating staged changes..."
if git diff --cached --quiet; then
  log_message "Error: No changes staged for commit!"
  exit 1
fi

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Commit the changes
log_message "$TIMESTAMP: Committing changes..."
if [ -n "$LOG_FILE" ]; then
  if git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
    log_message "Commit successful!"
  else
    log_message "Error: Failed to commit changes."
    exit 1
  fi
else
  if git commit -m "$COMMIT_MESSAGE"; then
    log_message "Commit successful!"
  else
    log_message "Error: Failed to commit changes."
    exit 1
  fi
fi