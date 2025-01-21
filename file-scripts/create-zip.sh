#!/bin/bash
# create-zip.sh
# Script to create a zip archive of a directory

# Function to display usage instructions
usage() {
    echo "Usage: $0 <source_directory> <zip_file> [log_file]"
    echo "Example: $0 /path/to/source /path/to/archive.zip custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the source directory, zip file name, and log file from the arguments
SOURCE_DIR="$1"
ZIP_FILE="$2"
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

# Create zip archive
log_message "Creating zip archive of $SOURCE_DIR at $ZIP_FILE..."
if zip -r "$ZIP_FILE" "$SOURCE_DIR"; then
    log_message "Zip archive created at $ZIP_FILE."
else
    log_message "Error: Failed to create zip archive."
    exit 1
fi