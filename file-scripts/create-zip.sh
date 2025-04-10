#!/bin/bash
# create-zip.sh
# Script to create a zip archive of a directory or file

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
  print_with_separator "Create Zip Archive Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a zip archive of a directory or file."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <source> <output_zip> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<source>\033[0m          (Required) Path to the file or directory to zip."
  echo -e "  \033[1;36m<output_zip>\033[0m     (Required) Path to the output zip file."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/source /path/to/output.zip --log custom_log.log"
  echo "  $0 /path/to/source /path/to/output.zip"
  print_with_separator
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  log_message "ERROR" "<source> and <output_zip> are required."
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
      if [ -z "$SOURCE" ]; then
        SOURCE="$1"
      elif [ -z "$OUTPUT_ZIP" ]; then
        OUTPUT_ZIP="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate source file or directory
if [ ! -e "$SOURCE" ]; then
  log_message "ERROR" "Source $SOURCE does not exist."
  exit 1
fi

# Validate output zip file
if [ -z "$OUTPUT_ZIP" ]; then
  log_message "ERROR" "Output zip file path is required."
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Create zip archive
log_message "INFO" "Creating zip archive: $OUTPUT_ZIP from $SOURCE"
print_with_separator "Zip Creation Output"

if zip -r "$OUTPUT_ZIP" "$SOURCE" 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of Zip Creation"
  log_message "SUCCESS" "Zip archive created: $OUTPUT_ZIP"
else
  print_with_separator "End of Zip Creation"
  log_message "ERROR" "Failed to create zip archive."
  exit 1
fi