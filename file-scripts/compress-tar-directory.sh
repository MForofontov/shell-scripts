#!/bin/bash
# compress-tar-directory.sh
# Script to compress a directory into a tar.gz file

# Function to display usage instructions
usage() {
    echo "Usage: $0 <source_directory> <output_file> [log_file]"
    echo "Example: $0 /path/to/source /path/to/output.tar.gz custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the source directory, output file, and log file from the arguments
SOURCE_DIR="$1"
OUTPUT_FILE="$2"
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

# Compress the directory
log_message "Compressing directory $SOURCE_DIR into $OUTPUT_FILE..."
if tar -czf "$OUTPUT_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"; then
    log_message "Directory compressed into $OUTPUT_FILE."
else
    log_message "Error: Failed to compress directory."
    exit 1
fi