#!/bin/bash
# backup-postgresql-compressed.sh
# Script to back up a PostgreSQL database and compress the backup.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
BACKUP_DIR=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

usage() {
  print_with_separator "PostgreSQL Backup Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a compressed backup of a PostgreSQL database."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <db_name> <db_user> <db_password> <backup_dir> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<db_name>\033[0m        (Required) Name of the PostgreSQL database."
  echo -e "  \033[1;33m<db_user>\033[0m        (Required) PostgreSQL user."
  echo -e "  \033[1;33m<db_password>\033[0m    (Required) Password for the PostgreSQL user."
  echo -e "  \033[1;33m<backup_dir>\033[0m     (Required) Directory to save the backup."
  echo -e "  \033[1;33m--log <log_file>\033[0m (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m           (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 my_database my_user my_password /path/to/backup --log backup.log"
  echo "  $0 my_database my_user my_password /path/to/backup"
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
        elif [ -z "$BACKUP_DIR" ]; then
          BACKUP_DIR="$1"
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

  print_with_separator "PostgreSQL Backup Script"
  format-echo "INFO" "Starting PostgreSQL Backup Script..."

  # Validate required arguments
  if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$BACKUP_DIR" ]; then
    format-echo "ERROR" "All required arguments <db_name>, <db_user>, <db_password>, and <backup_dir> must be provided."
    print_with_separator "End of PostgreSQL Backup Script"
    usage
  fi

  # Validate backup directory
  if [ ! -d "$BACKUP_DIR" ]; then
    format-echo "ERROR" "Backup directory $BACKUP_DIR does not exist."
    print_with_separator "End of PostgreSQL Backup Script"
    exit 1
  fi

  # Generate backup file name
  DATE=$(date +%Y%m%d%H%M%S)
  BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_${DATE}.sql.gz"

  # Export the database password to avoid prompt
  export PGPASSWORD="$DB_PASSWORD"

  # Create a compressed backup
  format-echo "INFO" "Creating compressed backup at $BACKUP_FILE..."
  if pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"; then
    format-echo "SUCCESS" "Database backup created and compressed at $BACKUP_FILE."
  else
    print_with_separator "End of PostgreSQL Backup Script"
    format-echo "ERROR" "Failed to create database backup."
    unset PGPASSWORD
    exit 1
  fi

  # Unset the database password
  unset PGPASSWORD

  print_with_separator "End of PostgreSQL Backup Script"
  format-echo "SUCCESS" "PostgreSQL backup process completed successfully."
}

main "$@"
