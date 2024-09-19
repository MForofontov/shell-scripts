#!/bin/bash
# extract-tar.sh
# Script to extract a tar archive

# Configuration
TAR_FILE="/path/to/archive.tar.gz"  # Tar file to extract
DEST_DIR="/path/to/destination"     # Destination directory

# Extract tar archive
tar -xzf "$TAR_FILE" -C "$DEST_DIR"

# Notify user
echo "Tar archive extracted to $DEST_DIR."
