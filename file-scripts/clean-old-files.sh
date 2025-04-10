#!/bin/bash
# clean-old-files.sh
# Script to delete files older than a specified number of days

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

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
    print_with_separator "Clean Old Files Script"
    echo -e "\033[1;34mDescription:\033[0m"
    echo "  This script deletes files older than a specified number of days from a given directory."
    echo "  It also supports optional logging to a file."
    echo
    echo -e "\033[1;34mUsage:\033[0m"
    echo "  $0 <directory> <days> [--log <log_file>] [--help]"
    echo
    echo -e "\033[1;34mOptions:\033[0m"
    echo -e "  \033[1;36m<directory>\033[0m       (Required) Directory to clean."
    echo -e "  \033[1;36m<days>\033[0m            (Required) Age threshold for files to be deleted (e.g., 30 days)."
    echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
    echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
    echo
    echo -e "\033[1;34mExamples:\033[0m"
    echo "  $0 /path/to/directory 30 --log custom_log.log"
    echo "  $0 /path/to/directory 30"
    print_with_separator
    exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  log_message "ERROR" "<directory> and <days> are required."
  usage
fi

# Initialize variables
DIRECTORY=""
DAYS=""
LOG_FILE="/dev/null"

# Parse arguments using while and case
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --log)
      if [[ -n "$2" ]]; then
        LOG_FILE="$2"
        shift 2
      else
        log_message "ERROR" "Missing argument for --log"
        usage
      ;;
    --help)
      usage
      ;;
    *)
      if [ -z "$DIRECTORY" ]; then
        DIRECTORY="$1"
      elif [ -z "$DAYS" ]; then
        DAYS="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate directory
if [ ! -d "$DIRECTORY" ]; then
  log_message "ERROR" "Directory $DIRECTORY does not exist."
  exit 1
fi

# Validate DAYS is a positive integer
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  log_message "ERROR" "DAYS must be a valid positive number."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Remove files older than the specified number of days
log_message "INFO" "Removing files older than $DAYS days from $DIRECTORY..."
print_with_separator "File Deletion Output"

if find "$DIRECTORY" -type f -mtime +"$DAYS" -exec rm -v {} \; 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of File Deletion"
  log_message "SUCCESS" "Successfully removed files older than $DAYS days from $DIRECTORY."
else
  print_with_separator "End of File Deletion"
  log_message "ERROR" "Failed to remove some files from $DIRECTORY."
  exit 1
fi