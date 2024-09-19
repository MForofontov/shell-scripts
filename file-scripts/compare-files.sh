#!/bin/bash
# compare-files.sh
# Script to compare two files and print differences

# Configuration
FILE1="/path/to/file1.txt"   # First file
FILE2="/path/to/file2.txt"   # Second file

# Compare files using diff
if diff "$FILE1" "$FILE2" > /dev/null; then
    echo "Files are identical."
else
    echo "Files differ."
fi
