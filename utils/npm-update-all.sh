#!/bin/bash
# npm-update-all.sh
# Script to update all NPM packages to the latest version

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "Error: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Navigate to the project directory (optional, if needed)
# cd /path/to/your/project

# Update all NPM packages
echo "Updating all NPM packages..."
if ! npm outdated; then
    echo "Error: Failed to check outdated packages."
    exit 1
fi

if ! npm update; then
    echo "Error: Failed to update packages."
    exit 1
fi

# Install updated packages
echo "Installing updated packages..."
if ! npm install; then
    echo "Error: Failed to install updated packages."
    exit 1
fi

# Run npm audit fix
echo "Running npm audit fix..."
if ! npm audit fix; then
    echo "Error: Failed to run npm audit fix."
    exit 1
fi

echo "All NPM packages have been updated to the latest version."