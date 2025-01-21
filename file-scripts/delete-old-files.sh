#!/bin/bash
# delete-old-files.sh
# Script to delete files older than a specified number of days from a directory

# Function to display usage instructions
usage() {
    echo "Usage: $0 <directory> <days> [log_file]"
    echo "Example: $0 /path/to/directory 30 custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the directory, number of days, and log file from the arguments
DIRECTORY="$1"
DAYS="$2"
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

# Check if DAYS is a valid number
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    echo "Error: DAYS must be a valid number."
    usage
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

# Find and delete files older than the specified number of days
log_message "Deleting files older than $DAYS days from $DIRECTORY..."
find "$DIRECTORY" -type f -mtime +"$DAYS" -exec rm -f {} \;
log_message "Files older than $DAYS days have been deleted from $DIRECTORY."