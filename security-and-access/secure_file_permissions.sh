#!/bin/bash
# Script: secure_file_permissions.sh
# Description: Set secure permissions for sensitive files.

FILES=(
  "/etc/passwd"
  "/etc/shadow"
  "/etc/ssh/sshd_config"
)

for file in "${FILES[@]}"; do
  if [ -f $file ]; then
    echo "Securing permissions for $file..."
    chmod 600 $file
    chown root:root $file
  fi
done

echo "Secure file permissions enforced."
