#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/development-and-code-managment/git/git-add-commit-push.sh
# git-add-commit-push.sh
# Script to automate Git operations: add, commit, and push

# Check if a commit message is provided
COMMIT_MESSAGE=$1
if [ -z "$COMMIT_MESSAGE" ]; then
  echo "Usage: $0 <commit_message>"
  exit 1
fi

# Default log file
LOG_FILE="git_operations.log"

# Check if a log file is provided as an argument
if [ "$#" -eq 2 ]; then
  LOG_FILE="$2"
fi

echo "Starting Git operations..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP: Starting Git operations..." | tee -a "$LOG_FILE"

# Add all changes
echo "Adding all changes..."
if ! git add . >> "$LOG_FILE" 2>&1; then
  echo "Error: Failed to add changes." | tee -a "$LOG_FILE"
  exit 1
fi

# Commit changes
echo "Committing changes..."
if ! git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
  echo "Error: Failed to commit changes." | tee -a "$LOG_FILE"
  exit 1
fi

# Push changes
echo "Pushing changes..."
if ! git push >> "$LOG_FILE" 2>&1; then
  echo "Error: Failed to push changes." | tee -a "$LOG_FILE"
  exit 1
fi

echo "$TIMESTAMP: Git operations completed successfully." | tee -a "$LOG_FILE"