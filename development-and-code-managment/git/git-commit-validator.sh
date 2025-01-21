#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/development-and-code-managment/git/git-commit-validator.sh
# Git Commit Validator

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

# Prompt user for commit message
log_message "Enter commit message:"
read -r COMMIT_MESSAGE

# Check if commit message is empty
if [ -z "$COMMIT_MESSAGE" ]; then
  log_message "Commit message cannot be empty!"
  exit 1
fi

# Validate commit message format (example: must start with a capital letter and be at least 10 characters long)
if [[ ! "$COMMIT_MESSAGE" =~ ^[A-Z] ]] || [ ${#COMMIT_MESSAGE} -lt 10 ]; then
  log_message "Invalid commit message format! Must start with a capital letter and be at least 10 characters long."
  exit 1
fi

# Check if there are changes staged for commit
log_message "Validating files..."
if git diff --cached --quiet; then
  log_message "No changes staged for commit!"
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