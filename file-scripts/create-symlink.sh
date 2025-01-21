#!/bin/bash
# create-symlink.sh
# Script to create a symbolic link

# Function to display usage instructions
usage() {
    echo "Usage: $0 <target_file> <link_name> [log_file]"
    echo "Example: $0 /path/to/target /path/to/link custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the target file, link name, and log file from the arguments
TARGET_FILE="$1"
LINK_NAME="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
fi

# Check if the target file exists
if [ ! -e "$TARGET_FILE" ]; then
    echo "Error: Target file $TARGET_FILE does not exist."
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

# Create symbolic link
log_message "Creating symbolic link: $LINK_NAME -> $TARGET_FILE"
if ln -s "$TARGET_FILE" "$LINK_NAME"; then
    log_message "Symbolic link created: $LINK_NAME -> $TARGET_FILE"
else
    log_message "Error: Failed to create symbolic link."
    exit 1
fi