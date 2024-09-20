#!/bin/bash
# count-files.sh
# Script to count the number of files and directories in a given path

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Get the directory path from the argument
DIRECTORY="$1"

# Count files and directories
FILE_COUNT=$(find "$DIRECTORY" -type f | wc -l)
DIR_COUNT=$(find "$DIRECTORY" -type d | wc -l)

# Print counts
echo "Number of files in $DIRECTORY: $FILE_COUNT"
echo "Number of directories in $DIRECTORY: $DIR_COUNT"