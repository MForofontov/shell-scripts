#!/bin/bash
# extract-zip.sh
# Script to extract a zip archive

# Configuration
ZIP_FILE="/path/to/archive.zip"  # Zip file to extract
DEST_DIR="/path/to/destination"  # Destination directory

# Extract zip archive
unzip "$ZIP_FILE" -d "$DEST_DIR"

# Notify user
echo "Zip archive extracted to $DEST_DIR."
