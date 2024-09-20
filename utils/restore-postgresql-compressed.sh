#!/bin/bash
# restore-postgresql-compressed.sh
# Script to restore a PostgreSQL database from a compressed backup

# Check if the correct number of arguments is provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <db_name> <db_user> <db_password> <compressed_backup_file>"
    exit 1
fi

# Get the database name, user, password, and compressed backup file from the arguments
DB_NAME="$1"
DB_USER="$2"
DB_PASSWORD="$3"
COMPRESSED_BACKUP_FILE="$4"
TEMP_BACKUP_FILE="/tmp/$(basename "$COMPRESSED_BACKUP_FILE" .gz)"

# Export the database password to avoid prompt
export PGPASSWORD="$DB_PASSWORD"

# Decompress the backup file
echo "Decompressing backup file..."
gunzip -c "$COMPRESSED_BACKUP_FILE" > "$TEMP_BACKUP_FILE"

# Check if decompression was successful
if [ $? -eq 0 ]; then
    echo "Decompression successful. Restoring database..."
else
    echo "Error: Decompression failed."
    exit 1
fi

# Check if the decompressed backup file is in SQL format or custom format
if [[ "$COMPRESSED_BACKUP_FILE" == *.sql.gz ]]; then
    # Restore from SQL dump file
    psql -U "$DB_USER" -d "$DB_NAME" -f "$TEMP_BACKUP_FILE"
elif [[ "$COMPRESSED_BACKUP_FILE" == *.dump.gz ]]; then
    # Restore from custom format dump file
    pg_restore -U "$DB_USER" -d "$DB_NAME" "$TEMP_BACKUP_FILE"
else
    echo "Unsupported backup file format."
    exit 1
fi

# Check if restore was successful
if [ $? -eq 0 ]; then
    echo "Database restored successfully from $COMPRESSED_BACKUP_FILE."
else
    echo "Error: Restore failed."
fi

# Clean up temporary file
rm "$TEMP_BACKUP_FILE"

# Unset the database password
unset PGPASSWORD