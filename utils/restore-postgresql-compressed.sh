#!/bin/bash
# restore-postgresql-compressed.sh
# Script to restore a PostgreSQL database from a compressed backup file

# Configuration
DB_NAME="your_database"            # Database name to restore
DB_USER="your_username"            # Database user
DB_PASSWORD="your_password"        # Database password
COMPRESSED_BACKUP_FILE="/path/to/backup.sql.gz"  # Compressed backup file (e.g., gzip compressed)
# COMPRESSED_BACKUP_FILE="/path/to/backup.dump.gz"  # Uncomment this line and comment out the above line if using custom format

# Temporary file for decompressed backup
TEMP_BACKUP_FILE="/tmp/backup.sql"  # Temporary file to store decompressed SQL dump

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
