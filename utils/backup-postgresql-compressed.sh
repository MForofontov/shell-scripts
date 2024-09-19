#!/bin/bash
# backup-postgresql-compressed.sh
# Script to back up a PostgreSQL database and compress the backup

# Configuration
DB_NAME="your_database"            # Database name to back up
DB_USER="your_username"            # Database user
DB_PASSWORD="your_password"        # Database password
BACKUP_DIR="/path/to/backup"       # Directory where backup will be stored
DATE=$(date +%Y%m%d%H%M%S)         # Current date and time for backup file name
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_${DATE}.sql.gz"  # Compressed backup file name

# Export the database password to avoid prompt
export PGPASSWORD="$DB_PASSWORD"

# Create a compressed backup
pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

# Check if backup was successful
if [ $? -eq 0 ]; then
    echo "Database backup created and compressed at $BACKUP_FILE."
else
    echo "Error: Backup failed."
fi

# Unset the database password
unset PGPASSWORD
