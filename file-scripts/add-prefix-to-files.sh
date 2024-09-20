#!/bin/bash
# add-prefix-to-files.sh
# Script to rename all files in a directory by adding a prefix

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 DIRECTORY PREFIX"
    exit 1
fi

# Configuration
DIRECTORY="$1"  # Directory containing files to rename
PREFIX="$2"     # Prefix to add to filenames

# Rename files by adding the prefix
for FILE in "$DIRECTORY"/*; do
    if [ -f "$FILE" ]; then
        BASENAME=$(basename "$FILE")
        mv "$FILE" "$DIRECTORY/${PREFIX}${BASENAME}"
    fi
done

# Notify user
echo "Files renamed successfully."