#!/bin/bash
# download-file.sh
# Script to download a file using curl

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <url> <destination_file>"
    exit 1
fi

# Get the URL and destination file from the arguments
URL="$1"
DEST_FILE="$2"

# Download file using curl
curl -o "$DEST_FILE" "$URL"

# Notify user
echo "File downloaded to $DEST_FILE."