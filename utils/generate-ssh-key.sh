#!/bin/bash
# generate-ssh-key.sh
# Script to generate an SSH key pair

# Configuration
KEY_NAME="id_rsa"  # Name for the key pair
KEY_DIR="$HOME/.ssh"  # Directory to store the key

# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f "$KEY_DIR/$KEY_NAME" -N ""

# Notify user
echo "SSH key pair generated at $KEY_DIR/$KEY_NAME and $KEY_DIR/${KEY_NAME}.pub."
