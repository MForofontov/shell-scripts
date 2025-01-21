#!/bin/bash

# Git Commit Validator

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
if git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
  log_message "Commit successful!"
else
  log_message "Error: Failed to commit changes."
  exit 1
fi