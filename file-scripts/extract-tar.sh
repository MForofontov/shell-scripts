#!/bin/bash
# extract-tar.sh
# Script to extract a tar archive

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
  print_with_separator "Extract Tar Archive Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script extracts a tar archive to a specified destination directory."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <tar_file> <destination_directory> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<tar_file>\033[0m              (Required) Path to the tar archive to extract."
  echo -e "  \033[1;36m<destination_directory>\033[0m (Required) Directory to extract the archive into."
  echo -e "  \033[1;33m--log <log_file>\033[0m        (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m                  (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/archive.tar.gz /path/to/destination --log custom_log.log"
  echo "  $0 /path/to/archive.tar.gz /path/to/destination"
  print_with_separator
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  log_message "ERROR" "<tar_file> and <destination_directory> are required."
  usage
fi

# Initialize variables
TAR_FILE=""
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
      if [ -z "$TAR_FILE" ]; then
        TAR_FILE="$1"
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

# Validate tar file
if [ ! -f "$TAR_FILE" ]; then
  log_message "ERROR" "Tar file $TAR_FILE does not exist."
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

# Extract tar archive
log_message "INFO" "Extracting tar archive $TAR_FILE to $DEST_DIR..."
print_with_separator "Extraction Output"

if tar -xzf "$TAR_FILE" -C "$DEST_DIR" 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of Extraction Output"
  log_message "SUCCESS" "Tar archive extracted to $DEST_DIR."
else
  print_with_separator "End of Extraction Output"
  log_message "ERROR" "Failed to extract tar archive."
  exit 1
fi