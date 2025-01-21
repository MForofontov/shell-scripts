#!/bin/bash
# compare-files.sh
# Script to compare two files and print differences

# Function to display usage instructions
usage() {
    echo "Usage: $0 <file1> <file2> [log_file]"
    echo "Example: $0 /path/to/file1 /path/to/file2 custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the file paths from the arguments
FILE1="$1"
FILE2="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
fi

# Check if the files exist
if [ ! -f "$FILE1" ]; then
    echo "Error: File $FILE1 does not exist."
    exit 1
fi

if [ ! -f "$FILE2" ]; then
    echo "Error: File $FILE2 does not exist."
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

# Compare files using diff
if diff "$FILE1" "$FILE2" > /dev/null; then
    log_message "Files are identical."
else
    log_message "Files differ."
fi