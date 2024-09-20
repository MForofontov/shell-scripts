#!/bin/bash
# backup.sh
# Script to back up a directory

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 SOURCE_DIR BACKUP_DIR"
    exit 1
fi

# Configuration
SOURCE_DIR="$1"   # Directory to back up
BACKUP_DIR="$2"   # Directory where backup will be stored
DATE=$(date +%Y%m%d%H%M%S)     # Current date and time for backup file name
BACKUP_FILE="${BACKUP_DIR}/backup_${DATE}.tar.gz"  # Backup file name

# Create a compressed backup of the source directory
tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" .

# Notify user
echo "Backup created at $BACKUP_FILE"