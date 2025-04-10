#!/bin/bash
# create-symlink.sh
# Script to create a symbolic link

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
    print_with_separator "Create Symbolic Link Script"
    echo -e "\033[1;34mDescription:\033[0m"
    echo "  This script creates a symbolic link to a target file."
    echo "  It also supports optional logging to a file."
    echo
    echo -e "\033[1;34mUsage:\033[0m"
    echo "  $0 <target_file> <link_name> [--log <log_file>] [--help]"
    echo
    echo -e "\033[1;34mOptions:\033[0m"
    echo -e "  \033[1;36m<target_file>\033[0m      (Required) Path to the target file."
    echo -e "  \033[1;36m<link_name>\033[0m        (Required) Path to the symbolic link to create."
    echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Log output to the specified file."
    echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
    echo
    echo -e "\033[1;34mExamples:\033[0m"
    echo "  $0 /path/to/target /path/to/link --log custom_log.log"
    echo "  $0 /path/to/target /path/to/link"
    print_with_separator
    exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  log_message "ERROR" "<target_file> and <link_name> are required."
  usage
fi

# Initialize variables
TARGET_FILE=""
LINK_NAME=""
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
      if [ -z "$TARGET_FILE" ]; then
        TARGET_FILE="$1"
      elif [ -z "$LINK_NAME" ]; then
        LINK_NAME="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate target file
if [ ! -e "$TARGET_FILE" ]; then
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

# Create symbolic link
log_message "INFO" "Creating symbolic link: $LINK_NAME -> $TARGET_FILE"
print_with_separator "Symbolic Link Creation Output"

if ln -s "$TARGET_FILE" "$LINK_NAME"; then
  print_with_separator "End of Symbolic Link Creation"
  log_message "SUCCESS" "Symbolic link created: $LINK_NAME -> $TARGET_FILE"
else
  print_with_separator "End of Symbolic Link Creation"
  log_message "ERROR" "Failed to create symbolic link."
  exit 1
fi