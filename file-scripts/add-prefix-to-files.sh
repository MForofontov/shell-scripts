#!/bin/bash
# add-prefix-to-files.sh
# Script to rename all files in a directory by adding a prefix

# Configuration
DIRECTORY="/path/to/directory"  # Directory containing files to rename
PREFIX="new_"                   # Prefix to add to filenames

# Rename files by adding the prefix
for FILE in "$DIRECTORY"/*; do
    if [ -f "$FILE" ]; then
        BASENAME=$(basename "$FILE")
        mv "$FILE" "$DIRECTORY/${PREFIX}${BASENAME}"
    fi
done

# Notify user
echo "Files renamed successfully."
