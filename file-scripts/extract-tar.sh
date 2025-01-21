#!/bin/bash
# extract-tar.sh
# Script to extract a tar archive

# Function to display usage instructions
usage() {
    echo "Usage: $0 <tar_file> <destination_directory> [log_file]"
    echo "Example: $0 /path/to/archive.tar.gz /path/to/destination custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the tar file, destination directory, and log file from the arguments
TAR_FILE="$1"
DEST_DIR="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
fi

# Check if the tar file exists
if [ ! -f "$TAR_FILE" ]; then
    echo "Error: Tar file $TAR_FILE does not exist."
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

# Extract tar archive
log_message "Extracting tar archive $TAR_FILE to $DEST_DIR..."
if tar -xzf "$TAR_FILE" -C "$DEST_DIR"; then
    log_message "Tar archive extracted to $DEST_DIR."
else
    log_message "Error: Failed to extract tar archive."
    exit 1
fi