#!/bin/bash
# find-large-files.sh
# Script to find and list files larger than a specified size

# Function to display usage instructions
usage() {
    echo "Usage: $0 <directory> <size> [log_file]"
    echo "Example: $0 /path/to/directory +100M custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the directory, size, and log file from the arguments
DIRECTORY="$1"
SIZE="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
fi

# Check if the directory exists
if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory $DIRECTORY does not exist."
    exit 1
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

# Find files larger than the specified size
log_message "Finding files larger than $SIZE in $DIRECTORY..."
find "$DIRECTORY" -type f -size "$SIZE" -exec ls -lh {} \; | awk '{ print $9 ": " $5 }' | while read -r line; do
    log_message "$line"
done

# Notify user
log_message "Large files in $DIRECTORY have been listed."