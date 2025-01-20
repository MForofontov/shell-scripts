#!/bin/bash
# delete-old-files.sh
# Script to delete files older than a specified number of days from a directory

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <directory> <days>"
    exit 1
fi

# Get the directory and number of days from the arguments
DIRECTORY="$1"
DAYS="$2"

# Check if the directory exists
if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory $DIRECTORY does not exist."
    exit 1
fi

# Find and delete files older than the specified number of days
echo "Deleting files older than $DAYS days from $DIRECTORY..."
find "$DIRECTORY" -type f -mtime +"$DAYS" -exec rm -f {} \;

# Notify user
echo "Files older than $DAYS days have been deleted from $DIRECTORY."