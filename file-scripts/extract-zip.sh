#!/bin/bash
# extract-zip.sh
# Script to extract a zip archive

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
  echo -e "\033[1;34mExtract Zip Archive Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script extracts a zip archive to a specified destination directory."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <zip_file> <destination_directory> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<zip_file>\033[0m              (Required) Path to the zip archive to extract."
  echo -e "  \033[1;36m<destination_directory>\033[0m (Required) Directory to extract the archive into."
  echo -e "  \033[1;33m--log <log_file>\033[0m        (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m                  (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/archive.zip /path/to/destination --log custom_log.log"
  echo "  $0 /path/to/archive.zip /path/to/destination"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  log_message "ERROR" "<zip_file> and <destination_directory> are required."
  usage
fi

# Initialize variables
ZIP_FILE=""
DEST_DIR=""
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
      if [ -z "$ZIP_FILE" ]; then
        ZIP_FILE="$1"
      elif [ -z "$DEST_DIR" ]; then
        DEST_DIR="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate zip file
if [ ! -f "$ZIP_FILE" ]; then
  log_message "ERROR" "Zip file $ZIP_FILE does not exist."
  exit 1
fi

# Validate destination directory
if [ ! -d "$DEST_DIR" ]; then
  log_message "ERROR" "Destination directory $DEST_DIR does not exist."
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Extract zip archive
log_message "INFO" "Extracting zip archive $ZIP_FILE to $DEST_DIR..."
print_with_separator "Extraction Output"

if unzip "$ZIP_FILE" -d "$DEST_DIR" 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of Extraction Output"
  log_message "SUCCESS" "Zip archive extracted to $DEST_DIR."
else
  print_with_separator "End of Extraction Output"
  log_message "ERROR" "Failed to extract zip archive."
  exit 1
fi