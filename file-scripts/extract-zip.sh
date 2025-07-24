#!/bin/bash
# extract-zip.sh
# Script to extract a zip archive

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
ZIP_FILE=""
DEST_DIR=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
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
        if [ -z "$ZIP_FILE" ]; then
          ZIP_FILE="$1"
          shift
        elif [ -z "$DEST_DIR" ]; then
          DEST_DIR="$1"
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

  print_with_separator "Extract Zip Archive Script"
  format-echo "INFO" "Starting Extract Zip Archive Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$ZIP_FILE" ] || [ -z "$DEST_DIR" ]; then
    format-echo "ERROR" "<zip_file> and <destination_directory> are required."
    print_with_separator "End of Extract Zip Archive Script"
    exit 1
  fi

  if [ ! -f "$ZIP_FILE" ]; then
    format-echo "ERROR" "Zip file $ZIP_FILE does not exist."
    print_with_separator "End of Extract Zip Archive Script"
    exit 1
  fi

  # Check if destination directory exists, create if it doesn't
  if [ ! -d "$DEST_DIR" ]; then
    format-echo "INFO" "Destination directory $DEST_DIR does not exist. Creating it..."
    if ! mkdir -p "$DEST_DIR"; then
      format-echo "ERROR" "Failed to create destination directory $DEST_DIR."
      print_with_separator "End of Extract Zip Archive Script"
      exit 1
    fi
    format-echo "SUCCESS" "Created destination directory $DEST_DIR."
  fi

  #---------------------------------------------------------------------
  # EXTRACTION OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Extracting zip archive $ZIP_FILE to $DEST_DIR..."
  
  # Check if unzip is available
  if ! command -v unzip &> /dev/null; then
    format-echo "ERROR" "unzip is not installed or not available in the PATH."
    print_with_separator "End of Extract Zip Archive Script"
    exit 1
  fi
  
  # Get archive size
  ARCHIVE_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
  format-echo "INFO" "Archive size: $ARCHIVE_SIZE"
  
  # List content of the archive
  format-echo "INFO" "Archive contents (first 10 entries):"
  unzip -l "$ZIP_FILE" | head -n 12
  
  # Extract the archive with verbose output
  if unzip -o "$ZIP_FILE" -d "$DEST_DIR"; then
    # Count extracted files
    FILE_COUNT=$(find "$DEST_DIR" -type f | wc -l | tr -d ' ')
    format-echo "SUCCESS" "Zip archive extracted to $DEST_DIR (Files: $FILE_COUNT)."
  else
    format-echo "ERROR" "Failed to extract zip archive."
    print_with_separator "End of Extract Zip Archive Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Extraction operation completed."
  print_with_separator "End of Extract Zip Archive Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
