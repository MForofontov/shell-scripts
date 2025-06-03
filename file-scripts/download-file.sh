#!/bin/bash
# download-file.sh
# Script to download a file using curl

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
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

#=====================================================================
# DEFAULT VALUES
#=====================================================================
URL=""
DEST_FILE=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Download File Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script downloads a file from a given URL to a specified destination."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <url> <destination_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<url>\033[0m               (Required) URL of the file to download."
  echo -e "  \033[1;36m<destination_file>\033[0m  (Required) Path to save the downloaded file."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 https://example.com/file.txt /path/to/destination/file.txt --log custom_log.log"
  echo "  $0 https://example.com/file.txt /path/to/destination/file.txt"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
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
        if [ -z "$URL" ]; then
          URL="$1"
          shift
        elif [ -z "$DEST_FILE" ]; then
          DEST_FILE="$1"
          shift
        else
          log_message "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Download File Script"
  log_message "INFO" "Starting Download File Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$URL" ] || [ -z "$DEST_FILE" ]; then
    log_message "ERROR" "<url> and <destination_file> are required."
    print_with_separator "End of Download File Script"
    exit 1
  fi

  if ! [[ "$URL" =~ ^https?:// ]]; then
    log_message "ERROR" "Invalid URL: $URL"
    print_with_separator "End of Download File Script"
    exit 1
  fi

  # Create destination directory if it doesn't exist
  DEST_DIR=$(dirname "$DEST_FILE")
  if [ ! -d "$DEST_DIR" ]; then
    log_message "INFO" "Creating destination directory: $DEST_DIR"
    if ! mkdir -p "$DEST_DIR"; then
      log_message "ERROR" "Failed to create destination directory: $DEST_DIR"
      print_with_separator "End of Download File Script"
      exit 1
    fi
  fi

  #---------------------------------------------------------------------
  # DOWNLOAD OPERATION
  #---------------------------------------------------------------------
  log_message "INFO" "Downloading file from $URL to $DEST_FILE..."

  # Check if curl is available
  if ! command -v curl &> /dev/null; then
    log_message "ERROR" "curl is not installed or not available in the PATH."
    print_with_separator "End of Download File Script"
    exit 1
  fi

  # Download the file with progress
  if curl -#fLo "$DEST_FILE" "$URL"; then
    # Get file size
    FILE_SIZE=$(du -h "$DEST_FILE" | cut -f1)
    log_message "SUCCESS" "File downloaded to $DEST_FILE (Size: $FILE_SIZE)."
  else
    log_message "ERROR" "Failed to download file from $URL."
    print_with_separator "End of Download File Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  log_message "INFO" "Download operation completed."
  print_with_separator "End of Download File Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"