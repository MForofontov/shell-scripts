#!/bin/bash
# disk-usage.sh
# Script to check disk usage and alert if it exceeds a threshold

# Function to display usage instructions
usage() {
    echo "Usage: $0 <threshold> <email> [log_file]"
    echo "Example: $0 80 user@example.com custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

# Get the threshold, email address, and log file from the arguments
THRESHOLD="$1"
EMAIL="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
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
    if [ -n "$MESSAGE" ]; then
        if [ -n "$LOG_FILE" ]; then
            echo "$MESSAGE" | tee -a "$LOG_FILE"
        else
            echo "$MESSAGE"
        fi
    fi
}

# Get disk usage percentage for the root filesystem
USAGE=$(df / | grep / | awk '{ print $5 }' | sed 's/%//g')

# Check if disk usage exceeds the threshold
if [ "$USAGE" -ge "$THRESHOLD" ]; then
    # Send an email alert if usage exceeds the threshold
    ALERT_MESSAGE="Disk usage is at ${USAGE}% - exceeds the threshold of ${THRESHOLD}%"
    echo "$ALERT_MESSAGE" | mail -s "Disk Usage Alert" "$EMAIL"
    log_message "$ALERT_MESSAGE"
else
    log_message "Disk usage is at ${USAGE}%, below the threshold of ${THRESHOLD}%."
fi