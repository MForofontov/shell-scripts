#!/bin/bash
# find-large-files.sh
# Script to find and list files larger than a specified size

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <directory> <size>"
    exit 1
fi

# Get the directory and size from the arguments
DIRECTORY="$1"
SIZE="$2"

# Find files larger than the specified size
find "$DIRECTORY" -type f -size "$SIZE" -exec ls -lh {} \;

# Notify user
echo "Large files in $DIRECTORY:"