#!/bin/bash
# compare-files.sh
# Script to compare two files and print differences

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
  print_with_separator "Compare Files Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script compares two files and prints their differences."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <source_file> <target_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<source_file>\033[0m     (Required) Path to the first file (source file)."
  echo -e "  \033[1;36m<target_file>\033[0m     (Required) Path to the second file (target file)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/source_file /path/to/target_file --log custom_log.log"
  echo "  $0 /path/to/source_file /path/to/target_file"
  print_with_separator
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  log_message "ERROR" "<source_file> and <target_file> are required."
  usage
fi

# Initialize variables
SOURCE_FILE=""
TARGET_FILE=""
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
      fi
      ;;
    --help)
      usage
      ;;
    *)
      if [ -z "$SOURCE_FILE" ]; then
        SOURCE_FILE="$1"
      elif [ -z "$TARGET_FILE" ]; then
        TARGET_FILE="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate files
if [ ! -f "$SOURCE_FILE" ]; then
  log_message "ERROR" "Source file $SOURCE_FILE does not exist."
  exit 1
fi

if [ ! -f "$TARGET_FILE" ]; then
  log_message "ERROR" "Target file $TARGET_FILE does not exist."
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Compare files using diff
log_message "INFO" "Comparing $SOURCE_FILE and $TARGET_FILE..."
print_with_separator "File Comparison Output"

if diff "$SOURCE_FILE" "$TARGET_FILE" 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of File Comparison"
  log_message "SUCCESS" "Files are identical."
else
  print_with_separator "End of File Comparison"
  log_message "INFO" "Files differ. See the output above for details."
fi