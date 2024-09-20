#!/bin/bash
# clean-old-files.sh
# Script to delete files older than a specified number of days

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 DIRECTORY DAYS"
    exit 1
fi

# Configuration
DIRECTORY="$1"  # Directory to clean
DAYS="$2"       # Age threshold for files to be deleted (e.g., 30 days)

# Remove files older than the specified number of days
find "$DIRECTORY" -type f -mtime +$DAYS -exec rm {} \;

# Notify user
echo "Removed files older than $DAYS days from $DIRECTORY."