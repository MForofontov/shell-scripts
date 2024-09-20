#!/bin/bash
# restore-postgresql.sh
# Script to restore a PostgreSQL database from a backup file

# Check if the correct number of arguments is provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <db_name> <db_user> <db_password> <backup_file>"
    exit 1
fi

# Get the database name, user, password, and backup file from the arguments
DB_NAME="$1"
DB_USER="$2"
DB_PASSWORD="$3"
BACKUP_FILE="$4"

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