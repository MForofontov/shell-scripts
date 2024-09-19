#!/bin/bash
# restore-postgresql.sh
# Script to restore a PostgreSQL database from a backup file

# Configuration
DB_NAME="your_database"            # Database name to restore
DB_USER="your_username"            # Database user
DB_PASSWORD="your_password"        # Database password
BACKUP_FILE="/path/to/backup.sql"  # Path to the SQL dump file
# BACKUP_FILE="/path/to/backup.dump"  # Uncomment this line and comment out the above line if using custom format

# Export the database password to avoid prompt
export PGPASSWORD="$DB_PASSWORD"

# Check if the backup file is in SQL format or custom format
if [[ "$BACKUP_FILE" == *.sql ]]; then
    # Restore from SQL dump file
    echo "Restoring database from SQL dump file..."
    psql -U "$DB_USER" -d "$DB_NAME" -f "$BACKUP_FILE"
elif [[ "$BACKUP_FILE" == *.dump ]]; then
    # Restore from custom format dump file
    echo "Restoring database from custom format dump file..."
    pg_restore -U "$DB_USER" -d "$DB_NAME" "$BACKUP_FILE"
else
    echo "Unsupported backup file format."
    exit 1
fi

# Check if restore was successful
if [ $? -eq 0 ]; then
    echo "Database restored successfully from $BACKUP_FILE."
else
    echo "Error: Restore failed."
fi

# Unset the database password
unset PGPASSWORD
