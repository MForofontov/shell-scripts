#!/bin/bash
# download-file.sh
# Script to download a file using curl

# Function to display usage instructions
usage() {
    echo "Usage: $0 <url> <destination_file> [log_file]"
    echo "Example: $0 https://example.com/file.txt /path/to/destination/file.txt custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the URL, destination file, and log file from the arguments
URL="$1"
DEST_FILE="$2"
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

# Download file using curl
log_message "Downloading file from $URL to $DEST_FILE..."
if curl -o "$DEST_FILE" "$URL"; then
    log_message "File downloaded to $DEST_FILE."
else
    log_message "Error: Failed to download file."
    exit 1
fi