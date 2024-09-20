#!/bin/bash
# create-zip.sh
# Script to create a zip archive of a directory

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <zip_file>"
    exit 1
fi

# Get the source directory and zip file name from the arguments
SOURCE_DIR="$1"
ZIP_FILE="$2"

# Create zip archive
zip -r "$ZIP_FILE" "$SOURCE_DIR"

# Notify user
echo "Zip archive created at $ZIP_FILE."