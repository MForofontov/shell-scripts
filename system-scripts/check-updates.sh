#!/bin/bash
# check-updates.sh
# Script to check for and install system updates

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -gt 1 ]; then
    usage
fi

# Get the log file from the arguments
LOG_FILE=""

# Check if a log file is provided as an argument
if [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
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

# Check for updates
log_message "Checking for system updates..."
if [ -x "$(command -v apt-get)" ]; then
    sudo apt-get update
    sudo apt-get upgrade -y
elif [ -x "$(command -v yum)" ]; then
    sudo yum check-update
    sudo yum update -y
else
    log_message "Unsupported package manager."
    exit 1
fi

# Notify user
log_message "System updates completed."