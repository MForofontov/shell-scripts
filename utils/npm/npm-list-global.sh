#!/bin/bash
# npm-list-global.sh
# Script to list all globally installed NPM packages

# Function to display usage instructions
usage() {
    echo "Usage: $0 [output_file]"
    echo "Example: $0 npm_global_packages.log"
    exit 1
}

# Check if a log file is provided as an argument
OUTPUT_FILE=""
if [ "$#" -gt 1 ]; then
    usage
elif [ "$#" -eq 1 ]; then
    OUTPUT_FILE="$1"
fi

# Validate output file if provided
if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
        echo "Error: Cannot write to output file $OUTPUT_FILE"
        exit 1
    fi
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$MESSAGE" | tee -a "$OUTPUT_FILE"
    else
        echo "$MESSAGE"
    fi
}

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    log_message "Error: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# List globally installed NPM packages
log_message "Listing all globally installed NPM packages..."
if ! npm list -g --depth=0; then
    log_message "Error: Failed to list globally installed NPM packages."
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    log_message "List of globally installed NPM packages has been written to $OUTPUT_FILE"
else
    log_message "List of globally installed NPM packages displayed on the console"
fi