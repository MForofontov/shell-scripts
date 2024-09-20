#!/bin/bash
# compress-tar-directory.sh
# Script to compress a directory into a tar.gz file

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_directory> <output_file>"
    exit 1
fi

# Get the source directory and output file from the arguments
SOURCE_DIR="$1"
OUTPUT_FILE="$2"

# Compress the directory
tar -czf "$OUTPUT_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

# Notify user
echo "Directory compressed into $OUTPUT_FILE."