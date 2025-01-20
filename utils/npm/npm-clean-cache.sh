#!/bin/bash
# npm-clean-cache.sh
# Script to clean the NPM cache

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Clean the NPM cache
echo "Cleaning NPM cache..."
if ! npm cache clean --force; then
    echo "Error: Failed to clean NPM cache."
    exit 1
fi

echo "NPM cache has been cleaned successfully."