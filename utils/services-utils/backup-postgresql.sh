#!/bin/bash
# backup-postgresql.sh
# Script to back up a PostgreSQL database

# Check if the correct number of arguments is provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <db_name> <db_user> <db_password> <backup_dir>"
    exit 1
fi

# Get the database name, user, password, and backup directory from the arguments
DB_NAME="$1"
DB_USER="$2"
DB_PASSWORD="$3"
BACKUP_DIR="$4"
DATE=$(date +%Y%m%d%H%M%S)         # Current date and time for backup file name
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_${DATE}.sql"  # Backup file name

# Export the database password to avoid prompt
export PGPASSWORD="$DB_PASSWORD"

# Create a backup
pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "Database backup created at $BACKUP_FILE."
else
    echo "Error: Backup failed."
fi

# Unset the database password
unset PGPASSWORD