#!/bin/bash
# create-zip.sh
# Script to create a zip archive of a directory

# Configuration
SOURCE_DIR="/path/to/directory"  # Directory to zip
ZIP_FILE="/path/to/archive.zip"  # Zip file name

# Create zip archive
zip -r "$ZIP_FILE" "$SOURCE_DIR"

# Notify user
echo "Zip archive created at $ZIP_FILE."
