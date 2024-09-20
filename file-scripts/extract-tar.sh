#!/bin/bash
# extract-tar.sh
# Script to extract a tar archive

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <tar_file> <destination_directory>"
    exit 1
fi

# Get the tar file and destination directory from the arguments
TAR_FILE="$1"
DEST_DIR="$2"

# Extract tar archive
tar -xzf "$TAR_FILE" -C "$DEST_DIR"

# Notify user
echo "Tar archive extracted to $DEST_DIR."