#!/bin/bash
# Script: unused_ssh_key_detector.sh
# Description: Detect unused SSH keys.

# Function to display usage instructions
usage() {
    echo "Usage: $0 [ssh_directory] [log_file]"
    echo "Example: $0 /home unused_ssh_keys.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -gt 2 ]; then
    usage
fi

# Get the SSH directory and log file from the arguments or use defaults
SSH_DIR="/home"
LOG_FILE="unused_ssh_keys.log"
if [ "$#" -ge 1 ]; then
    SSH_DIR="$1"
fi
if [ "$#" -ge 2 ]; then
    LOG_FILE="$2"
fi

# Validate SSH directory
if [ ! -d "$SSH_DIR" ]; then
    echo "Error: Directory $SSH_DIR does not exist."
    exit 1
fi

# Validate log file
if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Error: Cannot write to log file $LOG_FILE"
    exit 1
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    echo "$MESSAGE" | tee -a "$LOG_FILE"
}

# Scan for unused SSH keys
log_message "Scanning for unused SSH keys in $SSH_DIR..."
for user in $(ls "$SSH_DIR"); do
    if [ -d "$SSH_DIR/$user/.ssh" ]; then
        find "$SSH_DIR/$user/.ssh" -type f -name "*.pub" -exec ls -l {} \; >> "$LOG_FILE"
    fi
done

log_message "Unused SSH key scan completed. Log saved to $LOG_FILE."
