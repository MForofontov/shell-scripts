#!/bin/bash
# check-process.sh
# Script to check if a specific process is running

# Function to display usage instructions
usage() {
    echo "Usage: $0 <process_name> [log_file]"
    echo "Example: $0 process_name custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the process name and log file from the arguments
PROCESS_NAME="$1"
LOG_FILE=""

# Check if a log file is provided as a second argument
if [ "$#" -eq 2 ]; then
    LOG_FILE="$2"
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

# Check if the process is running
log_message "Checking if process $PROCESS_NAME is running..."
if pgrep "$PROCESS_NAME" > /dev/null; then
    log_message "$PROCESS_NAME is running."
else
    log_message "$PROCESS_NAME is not running."
fi