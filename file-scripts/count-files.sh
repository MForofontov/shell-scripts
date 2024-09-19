#!/bin/bash
# count-files.sh
# Script to count the number of files and directories in a given path

# Configuration
DIRECTORY="/path/to/directory"  # Directory to count files and directories

# Count files and directories
FILE_COUNT=$(find "$DIRECTORY" -type f | wc -l)
DIR_COUNT=$(find "$DIRECTORY" -type d | wc -l)

# Print counts
echo "Number of files in $DIRECTORY: $FILE_COUNT"
echo "Number of directories in $DIRECTORY: $DIR_COUNT"
