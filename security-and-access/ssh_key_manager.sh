#!/bin/bash
# Script: ssh_key_manager.sh
# Description: Generate and distribute SSH keys.

# Function to display usage instructions
usage() {
    echo "Usage: $0 <username> <remote_server>"
    echo "Example: $0 user user@hostname"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    usage
fi

# Get the username and remote server from the arguments
USERNAME="$1"
REMOTE_SERVER="$2"

# Validate the username
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME exists."
else
    echo "Error: User $USERNAME does not exist."
    exit 1
fi

# Create the .ssh directory if it does not exist
if [ ! -d "/home/$USERNAME/.ssh" ]; then
    mkdir -p /home/$USERNAME/.ssh
    chown $USERNAME:$USERNAME /home/$USERNAME/.ssh
fi

# Generate the SSH key
ssh-keygen -t rsa -b 4096 -f /home/$USERNAME/.ssh/id_rsa -N ""
echo "SSH key generated for $USERNAME."

# Distribute the SSH key to the remote server
ssh-copy-id -i /home/$USERNAME/.ssh/id_rsa.pub $REMOTE_SERVER

echo "SSH key distribution completed."