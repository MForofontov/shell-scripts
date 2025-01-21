#!/bin/bash
# count-files.sh
# Script to count the number of files and directories in a given path

# Function to display usage instructions
usage() {
    echo "Usage: $0 <directory> [log_file]"
    echo "Example: $0 /path/to/directory custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the directory path and log file from the arguments
DIRECTORY="$1"
LOG_FILE=""

# Check if a log file is provided as a second argument
if [ "$#" -eq 2 ]; then
    LOG_FILE="$2"
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

# Count files and directories
FILE_COUNT=$(find "$DIRECTORY" -type f | wc -l)
DIR_COUNT=$(find "$DIRECTORY" -type d | wc -l)

# Log and print counts
log_message "Number of files in $DIRECTORY: $FILE_COUNT"
log_message "Number of directories in $DIRECTORY: $DIR_COUNT"