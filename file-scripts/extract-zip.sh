#!/bin/bash
# extract-zip.sh
# Script to extract a zip archive

# Function to display usage instructions
usage() {
    echo "Usage: $0 <zip_file> <destination_directory> [log_file]"
    echo "Example: $0 /path/to/archive.zip /path/to/destination custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the zip file, destination directory, and log file from the arguments
ZIP_FILE="$1"
DEST_DIR="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
fi

# Check if the zip file exists
if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: Zip file $ZIP_FILE does not exist."
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

# Extract zip archive
log_message "Extracting zip archive $ZIP_FILE to $DEST_DIR..."
if unzip "$ZIP_FILE" -d "$DEST_DIR"; then
    log_message "Zip archive extracted to $DEST_DIR."
else
    log_message "Error: Failed to extract zip archive."
    exit 1
fi