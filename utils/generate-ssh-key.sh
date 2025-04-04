#!/bin/bash
# generate-ssh-key.sh
# Script to generate an SSH key pair

# Function to display usage instructions
usage() {
    echo "Usage: $0 <key_name> <key_dir> [log_file]"
    echo "Example: $0 my_key /path/to/keys custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

# Get the key name, key directory, and optional log file
KEY_NAME="$1"
KEY_DIR="$2"
LOG_FILE=""

if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
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

# Check if ssh-keygen is installed
if ! command -v ssh-keygen &> /dev/null; then
    log_message "Error: ssh-keygen is not installed. Please install OpenSSH tools."
    exit 1
fi

# Ensure the key directory exists
log_message "Ensuring the key directory exists: $KEY_DIR"
mkdir -p "$KEY_DIR"

# Generate SSH key pair
log_message "Generating SSH key pair..."
if ssh-keygen -t rsa -b 4096 -f "$KEY_DIR/$KEY_NAME" -N ""; then
    log_message "SSH key pair generated successfully at:"
    log_message "Private key: $KEY_DIR/$KEY_NAME"
    log_message "Public key: $KEY_DIR/${KEY_NAME}.pub"
else
    log_message "Error: Failed to generate SSH key pair."
    exit 1
fi
