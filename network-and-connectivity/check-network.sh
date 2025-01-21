#!/bin/bash
# check-network.sh
# Script to check network connectivity to a specific host

# Function to display usage instructions
usage() {
    echo "Usage: $0 <host> [log_file]"
    echo "Example: $0 example.com custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the host and log file from the arguments
HOST="$1"
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

# Check network connectivity
log_message "Checking network connectivity to $HOST..."
if ping -c 4 "$HOST" > /dev/null; then
    log_message "Network connectivity to $HOST is working."
else
    log_message "Network connectivity to $HOST failed."
fi