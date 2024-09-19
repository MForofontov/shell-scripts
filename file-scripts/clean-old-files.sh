#!/bin/bash
# clean-old-files.sh
# Script to delete files older than a specified number of days

# Configuration
DIRECTORY="/path/to/directory"  # Directory to clean
DAYS=30                        # Age threshold for files to be deleted (e.g., 30 days)

# Remove files older than the specified number of days
find "$DIRECTORY" -type f -mtime +$DAYS -exec rm {} \;

# Notify user
echo "Removed files older than $DAYS days from $DIRECTORY."
