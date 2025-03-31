#!/bin/bash
# npm-clean-cache.sh
# Script to clean the NPM cache

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 npm_clean_cache.log"
    exit 1
}

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -gt 1 ]; then
    usage
elif [ "$#" -eq 1 ]; then
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
    if [ -n "$LOG_FILE" ]; then
        echo "$MESSAGE" | tee -a "$LOG_FILE"
    else
        echo "$MESSAGE"
    fi
}

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    log_message "Error: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Clean the NPM cache
log_message "Cleaning NPM cache..."
if npm cache clean --force; then
    log_message "NPM cache has been cleaned successfully."
else
    log_message "Error: Failed to clean NPM cache."
    exit 1
fi
