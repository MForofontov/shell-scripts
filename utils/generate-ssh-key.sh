#!/bin/bash
# generate-ssh-key.sh
# Script to generate an SSH key pair

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <key_name> <key_dir>"
    exit 1
fi

# Get the key name and key directory from the arguments
KEY_NAME="$1"
KEY_DIR="$2"

# Ensure the key directory exists
mkdir -p "$KEY_DIR"

# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f "$KEY_DIR/$KEY_NAME" -N ""

# Notify user
echo "SSH key pair generated at $KEY_DIR/$KEY_NAME and $KEY_DIR/${KEY_NAME}.pub."