#!/bin/bash

# Git Commit Validator

# Default log file
LOG_FILE="git_commit_validator.log"

# Prompt user for commit message
echo "Enter commit message:"
read -r COMMIT_MESSAGE

# Check if commit message is empty
if [ -z "$COMMIT_MESSAGE" ]; then
  echo "Commit message cannot be empty!" | tee -a "$LOG_FILE"
  exit 1
fi

# Validate commit message format (example: must start with a capital letter and be at least 10 characters long)
if [[ ! "$COMMIT_MESSAGE" =~ ^[A-Z] ]] || [ ${#COMMIT_MESSAGE} -lt 10 ]; then
  echo "Invalid commit message format! Must start with a capital letter and be at least 10 characters long." | tee -a "$LOG_FILE"
  exit 1
fi

# Check if there are changes staged for commit
echo "Validating files..."
if git diff --cached --quiet; then
  echo "No changes staged for commit!" | tee -a "$LOG_FILE"
  exit 1
fi

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Commit the changes
echo "$TIMESTAMP: Committing changes..." | tee -a "$LOG_FILE"
if git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
  echo "Commit successful!" | tee -a "$LOG_FILE"
else
  echo "Error: Failed to commit changes." | tee -a "$LOG_FILE"
  exit 1
fi