#!/bin/bash
# http-status-code-checker.sh
# Script to check HTTP status codes for a list of URLs

# Function to display usage instructions
usage() {
    echo "Usage: $0 <url1> <url2> ... [log_file]"
    echo "Example: $0 https://google.com https://github.com custom_log.log"
    exit 1
}

# Default URLs
URLS=("https://google.com" "https://github.com" "https://example.com")

# Check if URLs are provided as arguments
LOG_FILE=""
if [ "$#" -ge 1 ]; then
    URLS=("${@:1:$#-1}")
    LOG_FILE="${!#}"
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "${LOG_FILE:0:4}" != "http" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $LOG_FILE"
        exit 1
    fi
else
    LOG_FILE=""
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

log_message "Checking HTTP status codes..."

# Function to check HTTP status codes
check_status_codes() {
    for URL in "${URLS[@]}"; do
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")
        log_message "$TIMESTAMP: $URL: $STATUS_CODE"
    done
}

# Check status codes and handle errors
if ! check_status_codes; then
    log_message "Error: Failed to check HTTP status codes."
    exit 1
fi

log_message "HTTP status code check complete."