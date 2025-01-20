#!/bin/bash
# npm-list-global.sh
# Script to list all globally installed NPM packages

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Check if an output file is provided
if [ "$#" -eq 1 ]; then
    OUTPUT_FILE="$1"
    exec > "$OUTPUT_FILE" 2>&1
    echo "Writing list of globally installed NPM packages to $OUTPUT_FILE"
else
    OUTPUT_FILE=""
fi

# List globally installed NPM packages
echo "Listing all globally installed NPM packages..."
if ! npm list -g --depth=0; then
    echo "Error: Failed to list globally installed NPM packages."
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    echo "List of globally installed NPM packages has been written to $OUTPUT_FILE"
else
    echo "List of globally installed NPM packages displayed on the console"
fi