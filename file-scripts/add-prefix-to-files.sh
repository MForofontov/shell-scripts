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

# Check if the directory exists
if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory $DIRECTORY does not exist."
    exit 1
fi

# Rename files by adding the prefix
for FILE in "$DIRECTORY"/*; do
    if [ -f "$FILE" ]; then
        BASENAME=$(basename "$FILE")
        NEW_NAME="$DIRECTORY/${PREFIX}${BASENAME}"
        if mv "$FILE" "$NEW_NAME"; then
            echo "Renamed $FILE to $NEW_NAME"
        else
            echo "Error: Failed to rename $FILE"
        fi
    fi
done

# Notify user
echo "Files renamed successfully."