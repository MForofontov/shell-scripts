#!/bin/bash
# extract-tar.sh
# Script to extract a tar archive

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
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
TAR_FILE=""
DEST_DIR=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
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
        if [ -z "$TAR_FILE" ]; then
          TAR_FILE="$1"
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

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Extract Tar Archive Script"
  format-echo "INFO" "Starting Extract Tar Archive Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$TAR_FILE" ] || [ -z "$DEST_DIR" ]; then
    format-echo "ERROR" "<tar_file> and <destination_directory> are required."
    print_with_separator "End of Extract Tar Archive Script"
    exit 1
  fi

  if [ ! -f "$TAR_FILE" ]; then
    format-echo "ERROR" "Tar file $TAR_FILE does not exist."
    print_with_separator "End of Extract Tar Archive Script"
    exit 1
  fi

  if [ ! -d "$DEST_DIR" ]; then
    format-echo "INFO" "Destination directory $DEST_DIR does not exist. Creating it..."
    if ! mkdir -p "$DEST_DIR"; then
      format-echo "ERROR" "Failed to create destination directory $DEST_DIR."
      print_with_separator "End of Extract Tar Archive Script"
      exit 1
    fi
    format-echo "SUCCESS" "Created destination directory $DEST_DIR."
  fi

  #---------------------------------------------------------------------
  # EXTRACTION OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Extracting tar archive $TAR_FILE to $DEST_DIR..."
  
  # Detect archive type
  ARCHIVE_TYPE=$(file -b "$TAR_FILE" | tr '[:upper:]' '[:lower:]')
  format-echo "INFO" "Archive type: $ARCHIVE_TYPE"
  
  # Extract based on file type
  if [[ "$ARCHIVE_TYPE" == *"gzip"* ]]; then
    format-echo "INFO" "Extracting gzip compressed tar archive..."
    if tar -xzf "$TAR_FILE" -C "$DEST_DIR"; then
      format-echo "SUCCESS" "Tar archive extracted successfully."
    else
      format-echo "ERROR" "Failed to extract tar archive."
      print_with_separator "End of Extract Tar Archive Script"
      exit 1
    fi
  elif [[ "$ARCHIVE_TYPE" == *"bzip2"* ]]; then
    format-echo "INFO" "Extracting bzip2 compressed tar archive..."
    if tar -xjf "$TAR_FILE" -C "$DEST_DIR"; then
      format-echo "SUCCESS" "Tar archive extracted successfully."
    else
      format-echo "ERROR" "Failed to extract tar archive."
      print_with_separator "End of Extract Tar Archive Script"
      exit 1
    fi
  elif [[ "$ARCHIVE_TYPE" == *"xz"* ]]; then
    format-echo "INFO" "Extracting xz compressed tar archive..."
    if tar -xJf "$TAR_FILE" -C "$DEST_DIR"; then
      format-echo "SUCCESS" "Tar archive extracted successfully."
    else
      format-echo "ERROR" "Failed to extract tar archive."
      print_with_separator "End of Extract Tar Archive Script"
      exit 1
    fi
  elif [[ "$ARCHIVE_TYPE" == *"tar"* ]]; then
    format-echo "INFO" "Extracting uncompressed tar archive..."
    if tar -xf "$TAR_FILE" -C "$DEST_DIR"; then
      format-echo "SUCCESS" "Tar archive extracted successfully."
    else
      format-echo "ERROR" "Failed to extract tar archive."
      print_with_separator "End of Extract Tar Archive Script"
      exit 1
    fi
  else
    format-echo "ERROR" "Unsupported archive type: $ARCHIVE_TYPE"
    print_with_separator "End of Extract Tar Archive Script"
    exit 1
  fi
  
  # List extracted files (top level only)
  format-echo "INFO" "Files extracted:"
  ls -la "$DEST_DIR" | head -n 20
  
  # Show more details if there are many files
  FILE_COUNT=$(find "$DEST_DIR" -type f | wc -l | tr -d ' ')
  if [ "$FILE_COUNT" -gt 20 ]; then
    format-echo "INFO" "Total files extracted: $FILE_COUNT (showing first 20 only)"
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Extraction operation completed."
  print_with_separator "End of Extract Tar Archive Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
