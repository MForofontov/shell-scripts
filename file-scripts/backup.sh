#!/bin/bash
# backup.sh
# Script to back up a directory

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../utils/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../utils/helpers/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
usage() {
  TERMINAL_WIDTH=$(tput cols)
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mBackup Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a compressed backup of a source directory."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <source_dir> <backup_dir> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<source_dir>\033[0m       (Required) Directory to back up."
  echo -e "  \033[1;36m<backup_dir>\033[0m       (Required) Directory where the backup will be stored."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/source /path/to/backup --log custom_log.log"
  echo "  $0 /path/to/source /path/to/backup"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  usage
fi

# Initialize variables
SOURCE_DIR="$1"   # Directory to back up
BACKUP_DIR="$2"   # Directory where backup will be stored
LOG_FILE=""

# Parse optional arguments
if [[ "$#" -ge 3 && "$3" == "--log" ]]; then
  LOG_FILE="$4"
fi

# Validate source directory
if [ ! -d "$SOURCE_DIR" ]; then
  log_message "ERROR" "Source directory $SOURCE_DIR does not exist."
  exit 1
fi

# Validate backup directory
if [ ! -d "$BACKUP_DIR" ]; then
  log_message "ERROR" "Backup directory $BACKUP_DIR does not exist."
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Create a compressed backup of the source directory
DATE=$(date +%Y%m%d%H%M%S)     # Current date and time for backup file name
BACKUP_FILE="${BACKUP_DIR}/backup_${DATE}.tar.gz"  # Backup file name

log_message "INFO" "Creating backup of $SOURCE_DIR at $BACKUP_FILE..."
print_with_separator "tar output"

if tar -czf "$BACKUP_FILE" -C "$SOURCE_DIR" . 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of tar output"
  log_message "SUCCESS" "Backup created at $BACKUP_FILE"
else
  print_with_separator "End of tar output"
  log_message "ERROR" "Failed to create backup."
  exit 1
fi