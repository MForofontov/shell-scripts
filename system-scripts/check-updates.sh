#!/bin/bash
# check-updates.sh
# Script to check for and install system updates

# Check for updates
if [ -x "$(command -v apt-get)" ]; then
    sudo apt-get update
    sudo apt-get upgrade -y
elif [ -x "$(command -v yum)" ]; then
    sudo yum check-update
    sudo yum update -y
else
    echo "Unsupported package manager."
    exit 1
fi

# Notify user
echo "System updates completed."
