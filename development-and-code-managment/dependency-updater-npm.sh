#!/bin/bash
# dependency-updater-npm.sh
# Script to update npm dependencies

# Default log file
LOG_FILE="npm_dependency_update.log"

# Check if a log file is provided as an argument
if [ "$#" -eq 1 ]; then
  LOG_FILE="$1"
fi

echo "Updating npm dependencies..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP: Updating npm dependencies..." | tee -a "$LOG_FILE"

# Update npm dependencies
if npm update >> "$LOG_FILE" 2>&1; then
  echo "Dependencies updated successfully!" | tee -a "$LOG_FILE"
else
  echo "Failed to update dependencies!" | tee -a "$LOG_FILE"
  exit 1
fi

# Generate a summary of updated packages
echo "Generating summary of updated packages..."
UPDATED_PACKAGES=$(npm outdated --json)
if [ -n "$UPDATED_PACKAGES" ]; then
  echo "Summary of updated packages:" | tee -a "$LOG_FILE"
  echo "$UPDATED_PACKAGES" | jq -r 'to_entries[] | "\(.key) updated from \(.value.current) to \(.value.latest)"' | tee -a "$LOG_FILE"
else
  echo "No packages were updated." | tee -a "$LOG_FILE"
fi

echo "$TIMESTAMP: npm dependency update process completed." | tee -a "$LOG_FILE"