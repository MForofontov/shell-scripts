#!/bin/bash
# restore-postgresql.sh
# Script to restore a PostgreSQL database from a backup file.

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
BACKUP_FILE=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

usage() {
  print_with_separator "PostgreSQL Restore Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script restores a PostgreSQL database from a backup file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <db_name> <db_user> <db_password> <backup_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<db_name>\033[0m        (Required) Name of the PostgreSQL database."
  echo -e "  \033[1;33m<db_user>\033[0m        (Required) PostgreSQL user."
  echo -e "  \033[1;33m<db_password>\033[0m    (Required) Password for the PostgreSQL user."
  echo -e "  \033[1;33m<backup_file>\033[0m    (Required) Path to the backup file."
  echo -e "  \033[1;33m--log <log_file>\033[0m (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m           (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 my_database my_user my_password /path/to/backup.sql --log restore.log"
  echo "  $0 my_database my_user my_password /path/to/backup.dump"
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
        elif [ -z "$BACKUP_FILE" ]; then
          BACKUP_FILE="$1"
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
  if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$BACKUP_FILE" ]; then
    format-echo "ERROR" "All required arguments <db_name>, <db_user>, <db_password>, and <backup_file> must be provided."
    print_with_separator "End of PostgreSQL Restore Script"
    usage
  fi

  export PGPASSWORD="$DB_PASSWORD"

  # Check the backup file format and restore
  if [[ "$BACKUP_FILE" == *.sql ]]; then
    format-echo "INFO" "Restoring database from SQL dump file..."
    if psql -U "$DB_USER" -d "$DB_NAME" -f "$BACKUP_FILE"; then
      format-echo "SUCCESS" "Database restored successfully from $BACKUP_FILE."
    else
      print_with_separator "End of PostgreSQL Restore Script"
      format-echo "ERROR" "Failed to restore database from SQL dump file."
      unset PGPASSWORD
      exit 1
    fi
  elif [[ "$BACKUP_FILE" == *.dump ]]; then
    format-echo "INFO" "Restoring database from custom format dump file..."
    if pg_restore -U "$DB_USER" -d "$DB_NAME" "$BACKUP_FILE"; then
      format-echo "SUCCESS" "Database restored successfully from $BACKUP_FILE."
    else
      print_with_separator "End of PostgreSQL Restore Script"
      format-echo "ERROR" "Failed to restore database from custom format dump file."
      unset PGPASSWORD
      exit 1
    fi
  else
    print_with_separator "End of PostgreSQL Restore Script"
    format-echo "ERROR" "Unsupported backup file format: $BACKUP_FILE"
    unset PGPASSWORD
    exit 1
  fi

  unset PGPASSWORD

  print_with_separator "End of PostgreSQL Restore Script"
  format-echo "SUCCESS" "PostgreSQL restore process completed successfully."
}

main "$@"
exit $?
