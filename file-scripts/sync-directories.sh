#!/bin/bash
# sync-directories.sh
# Script to synchronize two directories using rsync

# Configuration
SOURCE_DIR="/path/to/source"   # Source directory
DEST_DIR="/path/to/destination"  # Destination directory

# Synchronize directories
rsync -av --delete "$SOURCE_DIR/" "$DEST_DIR/"

# Notify user
echo "Synchronization complete from $SOURCE_DIR to $DEST_DIR."
