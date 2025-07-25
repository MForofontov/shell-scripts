#!/bin/bash
# restore-postgresql-compressed.sh
# Script to restore a PostgreSQL database from a compressed backup.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
COMPRESSED_BACKUP_FILE=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

usage() {
  print_with_separator "PostgreSQL Restore Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script restores a PostgreSQL database from a compressed backup."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <db_name> <db_user> <db_password> <compressed_backup_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<db_name>\033[0m                 (Required) Name of the PostgreSQL database."
  echo -e "  \033[1;33m<db_user>\033[0m                 (Required) PostgreSQL user."
  echo -e "  \033[1;33m<db_password>\033[0m             (Required) Password for the PostgreSQL user."
  echo -e "  \033[1;33m<compressed_backup_file>\033[0m  (Required) Path to the compressed backup file."
  echo -e "  \033[1;33m--log <log_file>\033[0m          (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 my_database my_user my_password /path/to/backup.sql.gz --log restore.log"
  echo "  $0 my_database my_user my_password /path/to/backup.dump.gz"
  print_with_separator
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        if [ -z "$DB_NAME" ]; then
          DB_NAME="$1"
        elif [ -z "$DB_USER" ]; then
          DB_USER="$1"
        elif [ -z "$DB_PASSWORD" ]; then
          DB_PASSWORD="$1"
        elif [ -z "$COMPRESSED_BACKUP_FILE" ]; then
          COMPRESSED_BACKUP_FILE="$1"
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        shift
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  setup_log_file

  print_with_separator "PostgreSQL Restore Script"
  format-echo "INFO" "Starting PostgreSQL Restore Script..."

  # Validate required arguments
  if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$COMPRESSED_BACKUP_FILE" ]; then
    format-echo "ERROR" "All required arguments <db_name>, <db_user>, <db_password>, and <compressed_backup_file> must be provided."
    print_with_separator "End of PostgreSQL Restore Script"
    usage
  fi

  # Export the database password to avoid prompt
  export PGPASSWORD="$DB_PASSWORD"

  # Decompress the backup file
  TEMP_BACKUP_FILE="/tmp/$(basename "$COMPRESSED_BACKUP_FILE" .gz)"
  format-echo "INFO" "Decompressing backup file $COMPRESSED_BACKUP_FILE..."
  if gunzip -c "$COMPRESSED_BACKUP_FILE" > "$TEMP_BACKUP_FILE"; then
    format-echo "SUCCESS" "Decompression successful. Temporary file: $TEMP_BACKUP_FILE"
  else
    print_with_separator "End of PostgreSQL Restore Script"
    format-echo "ERROR" "Decompression failed."
    unset PGPASSWORD
    exit 1
  fi

  # Check the backup file format and restore
  if [[ "$COMPRESSED_BACKUP_FILE" == *.sql.gz ]]; then
    format-echo "INFO" "Restoring database from SQL dump file..."
    if psql -U "$DB_USER" -d "$DB_NAME" -f "$TEMP_BACKUP_FILE"; then
      format-echo "SUCCESS" "Database restored successfully from $COMPRESSED_BACKUP_FILE."
    else
      print_with_separator "End of PostgreSQL Restore Script"
      format-echo "ERROR" "Failed to restore database from SQL dump file."
      rm -f "$TEMP_BACKUP_FILE"
      unset PGPASSWORD
      exit 1
    fi
  elif [[ "$COMPRESSED_BACKUP_FILE" == *.dump.gz ]]; then
    format-echo "INFO" "Restoring database from custom format dump file..."
    if pg_restore -U "$DB_USER" -d "$DB_NAME" "$TEMP_BACKUP_FILE"; then
      format-echo "SUCCESS" "Database restored successfully from $COMPRESSED_BACKUP_FILE."
    else
      print_with_separator "End of PostgreSQL Restore Script"
      format-echo "ERROR" "Failed to restore database from custom format dump file."
      rm -f "$TEMP_BACKUP_FILE"
      unset PGPASSWORD
      exit 1
    fi
  else
    print_with_separator "End of PostgreSQL Restore Script"
    format-echo "ERROR" "Unsupported backup file format: $COMPRESSED_BACKUP_FILE"
    rm -f "$TEMP_BACKUP_FILE"
    unset PGPASSWORD
    exit 1
  fi

  # Clean up temporary file
  rm -f "$TEMP_BACKUP_FILE"
  format-echo "INFO" "Temporary file $TEMP_BACKUP_FILE removed."

  # Unset the database password
  unset PGPASSWORD

  print_with_separator "End of PostgreSQL Restore Script"
  format-echo "SUCCESS" "PostgreSQL restore process completed successfully."
}

main "$@"
