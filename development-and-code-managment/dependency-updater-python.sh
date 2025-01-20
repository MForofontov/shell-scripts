#!/bin/bash
# dependency-updater.sh
# Script to update Python dependencies

# Default requirements file and log file
REQUIREMENTS_FILE=${1:-"requirements.txt"}
LOG_FILE="dependency_update.log"

# Check if the requirements file exists
if [ ! -f "$REQUIREMENTS_FILE" ]; then
  echo "Error: Requirements file $REQUIREMENTS_FILE does not exist."
  exit 1
fi

echo "Updating Python dependencies from $REQUIREMENTS_FILE..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP: Updating Python dependencies from $REQUIREMENTS_FILE..." | tee -a "$LOG_FILE"

# Update Python dependencies
if pip install --upgrade -r "$REQUIREMENTS_FILE" >> "$LOG_FILE" 2>&1; then
  echo "Dependencies updated successfully!" | tee -a "$LOG_FILE"
else
  echo "Failed to update dependencies!" | tee -a "$LOG_FILE"
  exit 1
fi