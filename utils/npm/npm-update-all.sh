#!/bin/bash
# npm-update-all.sh
# Script to update all NPM packages to the latest version

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 npm_update.log"
    exit 1
}

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -gt 1 ]; then
    usage
elif [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    if [ -n "$LOG_FILE" ]; then
        echo "$MESSAGE" | tee -a "$LOG_FILE"
    else
        echo "$MESSAGE"
    fi
}

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    log_message "Error: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

log_message "Starting NPM package update process..."

# Check outdated packages
log_message "Checking for outdated packages..."
if ! npm outdated; then
    log_message "Error: Failed to check outdated packages."
    exit 1
fi

# Update all packages
log_message "Updating all NPM packages..."
if ! npm update; then
    log_message "Error: Failed to update packages."
    exit 1
fi

# Install updated packages
log_message "Installing updated packages..."
if ! npm install; then
    log_message "Error: Failed to install updated packages."
    exit 1
fi

# Run npm audit fix
log_message "Running npm audit fix..."
if ! npm audit fix; then
    log_message "Error: Failed to run npm audit fix."
    exit 1
fi

log_message "All NPM packages have been updated to the latest version."
