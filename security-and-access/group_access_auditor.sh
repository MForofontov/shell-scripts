#!/bin/bash
# Script: group_access_auditor.sh
# Description: List all groups and their members.

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 custom_group_access.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -gt 1 ]; then
    usage
fi

# Get the log file from the arguments or use the default
LOG_FILE="group_access.log"
if [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
fi

# Validate log file
if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Error: Cannot write to log file $LOG_FILE"
    exit 1
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    echo "$MESSAGE" | tee -a "$LOG_FILE"
}

# List all groups and their members
log_message "Listing groups and members..."
cat /etc/group | awk -F: '{ print $1 ": " $4 }' | tee -a "$LOG_FILE"

log_message "Group access audit completed. Log saved to $LOG_FILE."
