#!/bin/bash
# create-directory-tree.sh
# Script to create a directory tree

# Configuration
BASE_DIR="/path/to/base"           # Base directory
DIR_STRUCTURE=(
    "dir1/subdir1"
    "dir1/subdir2"
    "dir2/subdir1"
    "dir2/subdir2"
)

# Create directories
for DIR in "${DIR_STRUCTURE[@]}"; do
    mkdir -p "$BASE_DIR/$DIR"
done

# Notify user
echo "Directory tree created under $BASE_DIR."
