#!/bin/bash
# download-file.sh
# Script to download a file using curl

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
URL=""
DEST_FILE=""
# shellcheck disable=SC2034
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
          format-echo "ERROR" "Missing argument for --log"
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
          format-echo "ERROR" "Unknown option or too many arguments: $1"
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

  setup_log_file

  print_with_separator "Download File Script"
  format-echo "INFO" "Starting Download File Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$URL" ] || [ -z "$DEST_FILE" ]; then
    format-echo "ERROR" "<url> and <destination_file> are required."
    print_with_separator "End of Download File Script"
    exit 1
  fi

  if ! [[ "$URL" =~ ^https?:// ]]; then
    format-echo "ERROR" "Invalid URL: $URL"
    print_with_separator "End of Download File Script"
    exit 1
  fi

  # Create destination directory if it doesn't exist
  DEST_DIR=$(dirname "$DEST_FILE")
  if [ ! -d "$DEST_DIR" ]; then
    format-echo "INFO" "Creating destination directory: $DEST_DIR"
    if ! mkdir -p "$DEST_DIR"; then
      format-echo "ERROR" "Failed to create destination directory: $DEST_DIR"
      print_with_separator "End of Download File Script"
      exit 1
    fi
  fi

  #---------------------------------------------------------------------
  # DOWNLOAD OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Downloading file from $URL to $DEST_FILE..."

  # Check if curl is available
  if ! command -v curl &> /dev/null; then
    format-echo "ERROR" "curl is not installed or not available in the PATH."
    print_with_separator "End of Download File Script"
    exit 1
  fi

  # Download the file with progress
  if curl -#fLo "$DEST_FILE" "$URL"; then
    # Get file size
    FILE_SIZE=$(du -h "$DEST_FILE" | cut -f1)
    format-echo "SUCCESS" "File downloaded to $DEST_FILE (Size: $FILE_SIZE)."
  else
    format-echo "ERROR" "Failed to download file from $URL."
    print_with_separator "End of Download File Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Download operation completed."
  print_with_separator "End of Download File Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
