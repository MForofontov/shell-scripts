#!/bin/bash
# backup.sh
# Script to back up a directory

# Configuration
SOURCE_DIR="/path/to/source"   # Directory to back up
BACKUP_DIR="/path/to/backup"   # Directory where backup will be stored
DATE=$(date +%Y%m%d%H%M%S)     # Current date and time for backup file name
BACKUP_FILE="${BACKUP_DIR}/backup_${DATE}.tar.gz"  # Backup file name

# Create a compressed backup of the source directory
tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" .

# Notify user
echo "Backup created at $BACKUP_FILE"
