#!/bin/bash
# compare-files.sh
# Script to compare two files and print differences

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <file1> <file2>"
    exit 1
fi

# Get the file paths from the arguments
FILE1="$1"
FILE2="$2"

# Compare files using diff
if diff "$FILE1" "$FILE2" > /dev/null; then
    echo "Files are identical."
else
    echo "Files differ."
fi