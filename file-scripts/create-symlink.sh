#!/bin/bash
# create-symlink.sh
# Script to create a symbolic link

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <target_file> <link_name>"
    exit 1
fi

# Get the target file and link name from the arguments
TARGET_FILE="$1"
LINK_NAME="$2"

# Create symbolic link
ln -s "$TARGET_FILE" "$LINK_NAME"

# Notify user
echo "Symbolic link created: $LINK_NAME -> $TARGET_FILE."