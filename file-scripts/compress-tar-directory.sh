#!/bin/bash
# compress-tar-directory.sh
# Script to compress a directory into a tar.gz file

# Configuration
SOURCE_DIR="/path/to/directory"  # Directory to compress
OUTPUT_FILE="/path/to/output.tar.gz"  # Output file name

# Compress the directory
tar -czf "$OUTPUT_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"

# Notify user
echo "Directory compressed into $OUTPUT_FILE."
