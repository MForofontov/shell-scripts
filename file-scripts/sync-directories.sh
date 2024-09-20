#!/bin/bash
# sync-directories.sh
# Script to synchronize two directories using rsync

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <destination_directory>"
    exit 1
fi

# Get the source and destination directories from the arguments
SOURCE_DIR="$1"
DEST_DIR="$2"

# Synchronize directories
rsync -av --delete "$SOURCE_DIR/" "$DEST_DIR/"

# Notify user
echo "Synchronization complete from $SOURCE_DIR to $DEST_DIR."