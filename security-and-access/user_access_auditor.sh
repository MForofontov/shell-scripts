#!/bin/bash
# user_access_auditor.sh
# Script to audit user access and log the results

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 custom_user_access.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -gt 1 ]; then
    usage
fi

# Get the log file from the arguments
LOG_FILE="user_access.log"
if [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
fi

# Validate log file if provided
if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Error: Cannot write to log file $LOG_FILE"
    exit 1
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    echo "$MESSAGE" | tee -a "$LOG_FILE"
}

# Audit user access
log_message "Listing system users and their details..."
log_message "Username:Home Directory:Shell"
cat /etc/passwd | awk -F: '{ print $1 ":" $6 ":" $7 }' | tee -a "$LOG_FILE"

log_message "User access audit completed. Log saved to $LOG_FILE."