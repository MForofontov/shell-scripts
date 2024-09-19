#!/bin/bash
# create-symlink.sh
# Script to create a symbolic link

# Configuration
TARGET_FILE="/path/to/target_file"  # File to link to
LINK_NAME="/path/to/symlink"        # Symbolic link name

# Create symbolic link
ln -s "$TARGET_FILE" "$LINK_NAME"

# Notify user
echo "Symbolic link created: $LINK_NAME -> $TARGET_FILE."
