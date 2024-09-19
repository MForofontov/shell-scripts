#!/bin/bash
# find-large-files.sh
# Script to find and list files larger than a specified size

# Configuration
DIRECTORY="/path/to/directory"  # Directory to search in
SIZE="+100M"                    # Minimum size of files to find (e.g., 100MB)

# Find files larger than the specified size
find "$DIRECTORY" -type f -size "$SIZE" -exec ls -lh {} \;

# Notify user
echo "Large files in $DIRECTORY:"
