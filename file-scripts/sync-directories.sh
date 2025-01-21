#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/file-scripts/sync-directories.sh
# sync-directories.sh
# Script to synchronize two directories using rsync

# Function to display usage instructions
usage() {
    echo "Usage: $0 <source_directory> <destination_directory> [log_file]"
    echo "Example: $0 /path/to/source /path/to/destination custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the source and destination directories from the arguments
SOURCE_DIR="$1"
DEST_DIR="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
fi

# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR does not exist."
    exit 1
fi

# Check if the destination directory exists
if [ ! -d "$DEST_DIR" ]; then
    echo "Error: Destination directory $DEST_DIR does not exist."
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

# Synchronize directories
log_message "Synchronizing directories from $SOURCE_DIR to $DEST_DIR..."
if rsync -av --delete "$SOURCE_DIR/" "$DEST_DIR/"; then
    log_message "Synchronization complete from $SOURCE_DIR to $DEST_DIR."
else
    log_message "Error: Failed to synchronize directories."
    exit 1
fi