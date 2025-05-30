#!/bin/bash
# extract-zip.sh
# Script to extract a zip archive

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

ZIP_FILE=""
DEST_DIR=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Extract Zip Archive Script"
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
  print_with_separator
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log)
        if [[ -n "${2:-}" ]]; then
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
          shift
        elif [ -z "$DEST_DIR" ]; then
          DEST_DIR="$1"
          shift
        else
          log_message "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Extract Zip Archive Script"
  log_message "INFO" "Starting Extract Zip Archive Script..."

  # Validate arguments
  if [ -z "$ZIP_FILE" ] || [ -z "$DEST_DIR" ]; then
    log_message "ERROR" "<zip_file> and <destination_directory> are required."
    print_with_separator "End of Extract Zip Archive Script"
    exit 1
  fi

  if [ ! -f "$ZIP_FILE" ]; then
    log_message "ERROR" "Zip file $ZIP_FILE does not exist."
    print_with_separator "End of Extract Zip Archive Script"
    exit 1
  fi

  if [ ! -d "$DEST_DIR" ]; then
    log_message "ERROR" "Destination directory $DEST_DIR does not exist."
    print_with_separator "End of Extract Zip Archive Script"
    exit 1
  fi

  log_message "INFO" "Extracting zip archive $ZIP_FILE to $DEST_DIR..."

  if unzip "$ZIP_FILE" -d "$DEST_DIR"; then
    log_message "SUCCESS" "Zip archive extracted to $DEST_DIR."
  else
    log_message "ERROR" "Failed to extract zip archive."
    print_with_separator "End of Extract Zip Archive Script"
    exit 1
  fi

  print_with_separator "End of Extract Zip Archive Script"
}

main "$@"