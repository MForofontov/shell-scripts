#!/bin/bash
# clean-old-files.sh
# Script to delete files older than a specified number of days

# Function to display usage instructions
usage() {
    echo "Usage: $0 DIRECTORY DAYS [log_file]"
    echo "Example: $0 /path/to/directory 30 custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Configuration
DIRECTORY="$1"  # Directory to clean
DAYS="$2"       # Age threshold for files to be deleted (e.g., 30 days)
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

# Remove files older than the specified number of days
log_message "Removing files older than $DAYS days from $DIRECTORY..."
find "$DIRECTORY" -type f -mtime +$DAYS -exec rm {} \;
log_message "Removed files older than $DAYS days from $DIRECTORY."