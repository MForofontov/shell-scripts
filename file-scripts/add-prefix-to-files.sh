#!/bin/bash
# add-prefix-to-files.sh
# Script to add a prefix to all files in a specified directory

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
  print_with_separator "Add Prefix to Files Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script adds a specified prefix to all files in a given directory."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <directory> <prefix> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<directory>\033[0m       (Required) Directory containing the files to rename."
  echo -e "  \033[1;36m<prefix>\033[0m          (Required) Prefix to add to the files."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/directory my_prefix --log custom_log.log"
  echo "  $0 /path/to/directory my_prefix"
  print_with_separator
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  log_message "ERROR" "<directory> and <prefix> are required."
  usage
fi

# Initialize variables
DIRECTORY=""
PREFIX=""
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
      elif [ -z "$PREFIX" ]; then
        PREFIX="$1"
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

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Add prefix to files
log_message "INFO" "Adding prefix '$PREFIX' to files in $DIRECTORY..."
print_with_separator "File Renaming Output"

for FILE in "$DIRECTORY"/*; do
  if [ -f "$FILE" ]; then
    BASENAME=$(basename "$FILE")
    NEW_NAME="${DIRECTORY}/${PREFIX}${BASENAME}"
    if mv "$FILE" "$NEW_NAME"; then
      log_message "SUCCESS" "Renamed $BASENAME to ${PREFIX}${BASENAME}"
    else
      log_message "ERROR" "Failed to rename $BASENAME"
    fi
  fi
done

print_with_separator "End of File Renaming"
log_message "INFO" "Prefix addition completed."