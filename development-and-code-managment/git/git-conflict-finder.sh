#!/bin/bash

# Git Conflict Finder

# Default log file
LOG_FILE="git_conflict_finder.log"

# Check if a log file is provided as an argument
if [ "$#" -eq 1 ]; then
  LOG_FILE="$1"
fi

echo "Checking for unresolved conflicts..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP: Checking for unresolved conflicts..." | tee -a "$LOG_FILE"

# Find merge conflicts
CONFLICTS=$(git diff --name-only --diff-filter=U)

if [ $? -eq 0 ]; then
  if [ -n "$CONFLICTS" ]; then
    echo "Conflicted files:" | tee -a "$LOG_FILE"
    echo "$CONFLICTS" | tee -a "$LOG_FILE"
  else
    echo "No conflicts found!" | tee -a "$LOG_FILE"
  fi
else
  echo "Error: Failed to check for conflicts." | tee -a "$LOG_FILE"
  exit 1
fi