#!/bin/bash
# pgsql-backup.sh
# Script to backup PostgreSQL database

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <db_name> <backup_dir>"
    exit 1
fi

# Get the database name and backup directory from the arguments
DB_NAME="$1"
BACKUP_DIR="$2"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/$DB_NAME-backup-$DATE.sql"

echo "Backing up PostgreSQL database $DB_NAME..."
pg_dump "$DB_NAME" > "$BACKUP_FILE"
if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed!"
fi