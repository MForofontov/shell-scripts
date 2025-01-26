#!/bin/bash
# Script: secure_file_permissions.sh
# Description: Set secure permissions for sensitive files.

# Function to display usage instructions
usage() {
    echo "Usage: $0 [additional_files...]"
    echo "Example: $0 /path/to/file1 /path/to/file2"
    exit 1
}

# Default list of sensitive files
FILES=(
  "/etc/passwd"
  "/etc/shadow"
  "/etc/ssh/sshd_config"
)

# Add additional files from arguments
if [ "$#" -gt 0 ]; then
    for file in "$@"; do
        FILES+=("$file")
    done
fi

# Function to secure file permissions
secure_file() {
    local file=$1
    if [ -f "$file" ]; then
        echo "Securing permissions for $file..."
        chmod 600 "$file"
        chown root:root "$file"
    else
        echo "Warning: $file does not exist."
    fi
}

# Secure permissions for each file
for file in "${FILES[@]}"; do
    secure_file "$file"
done

echo "Secure file permissions enforced."