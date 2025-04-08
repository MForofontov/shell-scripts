#!/bin/bash
# count-files.sh
# Script to count the number of files and directories in a given path

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
  TERMINAL_WIDTH=$(tput cols)
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mCount Files Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script counts the number of files and directories in a given path."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <directory> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<directory>\033[0m       (Required) Directory to count files and directories."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/directory --log custom_log.log"
  echo "  $0 /path/to/directory"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Initialize variables
DIRECTORY=""
LOG_FILE="/dev/null"

# Parse arguments using while and case
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --log)
      if [[ -n "$2" ]]; then
        LOG_FILE="$2"
        shift 2
      else
        echo -e "\033[1;31mError:\033[0m Missing argument for --log"
        usage
      fi
      ;;
    --help)
      usage
      ;;
    *)
      if [ -z "$DIRECTORY" ]; then
        DIRECTORY="$1"
        shift
      else
        echo -e "\033[1;31mError:\033[0m Unknown option or too many arguments: $1"
        usage
      fi
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

# Count files and directories
log_message "INFO" "Counting files and directories in $DIRECTORY..."
print_with_separator "Counting Output"

FILE_COUNT=$(find "$DIRECTORY" -type f | wc -l)
DIR_COUNT=$(find "$DIRECTORY" -type d | wc -l)

# Log and print counts
log_message "INFO" "Number of files in $DIRECTORY: $FILE_COUNT"
log_message "INFO" "Number of directories in $DIRECTORY: $DIR_COUNT"

print_with_separator "End of Counting"