#!/bin/bash
# extract-zip.sh
# Script to extract a zip archive

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <zip_file> <destination_directory>"
    exit 1
fi

# Get the zip file and destination directory from the arguments
ZIP_FILE="$1"
DEST_DIR="$2"

# Extract zip archive
unzip "$ZIP_FILE" -d "$DEST_DIR"

# Notify user
echo "Zip archive extracted to $DEST_DIR."