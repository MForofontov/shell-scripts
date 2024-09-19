#!/bin/bash
# download-file.sh
# Script to download a file using curl

# Configuration
URL="https://example.com/file.txt"  # URL of the file to download
DEST_FILE="/path/to/downloaded_file.txt"  # Destination file

# Download file using curl
curl -o "$DEST_FILE" "$URL"

# Notify user
echo "File downloaded to $DEST_FILE."
