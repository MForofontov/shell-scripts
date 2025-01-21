#!/bin/bash
# backup.sh
# Script to back up a directory

# Function to display usage instructions
usage() {
    echo "Usage: $0 SOURCE_DIR BACKUP_DIR [log_file]"
    echo "Example: $0 /path/to/source /path/to/backup custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Configuration
SOURCE_DIR="$1"   # Directory to back up
BACKUP_DIR="$2"   # Directory where backup will be stored
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

# Check if the backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory $BACKUP_DIR does not exist."
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

# Create a compressed backup of the source directory
DATE=$(date +%Y%m%d%H%M%S)     # Current date and time for backup file name
BACKUP_FILE="${BACKUP_DIR}/backup_${DATE}.tar.gz"  # Backup file name

log_message "Creating backup of $SOURCE_DIR at $BACKUP_FILE..."
if tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" .; then
    log_message "Backup created at $BACKUP_FILE"
else
    log_message "Error: Failed to create backup."
    exit 1
fi