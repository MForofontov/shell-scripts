#!/bin/bash
# backup-postgresql.sh
# Script to back up a PostgreSQL database.

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

DB_NAME=""
DB_USER=""
DB_PASSWORD=""
BACKUP_DIR=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "PostgreSQL Backup Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a backup of a PostgreSQL database."
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
          log_message "ERROR" "No log file provided after --log."
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
          log_message "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        shift
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "PostgreSQL Backup Script"
  log_message "INFO" "Starting PostgreSQL Backup Script..."

  # Validate required arguments
  if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$BACKUP_DIR" ]; then
    log_message "ERROR" "All required arguments <db_name>, <db_user>, <db_password>, and <backup_dir> must be provided."
    print_with_separator "End of PostgreSQL Backup Script"
    usage
  fi

  # Validate backup directory
  if [ ! -d "$BACKUP_DIR" ]; then
    log_message "ERROR" "Backup directory $BACKUP_DIR does not exist."
    print_with_separator "End of PostgreSQL Backup Script"
    exit 1
  fi

  # Generate backup file name
  DATE=$(date +%Y%m%d%H%M%S)
  BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_backup_${DATE}.sql"

  # Export the database password to avoid prompt
  export PGPASSWORD="$DB_PASSWORD"

  # Create a backup
  log_message "INFO" "Creating backup at $BACKUP_FILE..."
  if pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_FILE"; then
    log_message "SUCCESS" "Database backup created at $BACKUP_FILE."
  else
    print_with_separator "End of PostgreSQL Backup Script"
    log_message "ERROR" "Failed to create database backup."
    unset PGPASSWORD
    exit 1
  fi

  # Unset the database password
  unset PGPASSWORD

  print_with_separator "End of PostgreSQL Backup Script"
  log_message "SUCCESS" "PostgreSQL backup process completed successfully."
}

main "$@"