#!/usr/bin/env bash
# compress-tar-directory.sh
# Script to compress a directory into a tar.gz file

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
SOURCE_DIR=""
OUTPUT_FILE=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Compress Directory Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script compresses a directory into a tar.gz file."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <source_directory> <output_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<source_directory>\033[0m  (Required) Directory to compress."
  echo -e "  \033[1;36m<output_file>\033[0m       (Required) Path to the output tar.gz file."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/source /path/to/output.tar.gz --log custom_log.log"
  echo "  $0 /path/to/source /path/to/output.tar.gz"
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
        if [ -z "$SOURCE_DIR" ]; then
          SOURCE_DIR="$1"
          shift
        elif [ -z "$OUTPUT_FILE" ]; then
          OUTPUT_FILE="$1"
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

  print_with_separator "Compress Directory Script"
  format-echo "INFO" "Starting Compress Directory Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$SOURCE_DIR" ] || [ -z "$OUTPUT_FILE" ]; then
    format-echo "ERROR" "<source_directory> and <output_file> are required."
    print_with_separator "End of Compress Directory Script"
    exit 1
  fi

  if [ ! -d "$SOURCE_DIR" ]; then
    format-echo "ERROR" "Source directory $SOURCE_DIR does not exist."
    print_with_separator "End of Compress Directory Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPRESSION
  #---------------------------------------------------------------------
  format-echo "INFO" "Compressing directory $SOURCE_DIR into $OUTPUT_FILE..."

  # Get directory size before compression
  DIR_SIZE=$(du -sh "$SOURCE_DIR" | cut -f1)
  format-echo "INFO" "Directory size before compression: $DIR_SIZE"

  # Perform the compression
  if tar -czf "$OUTPUT_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"; then
    ARCHIVE_SIZE=$(du -sh "$OUTPUT_FILE" | cut -f1)
    format-echo "SUCCESS" "Directory compressed successfully."
    format-echo "INFO" "Archive size: $ARCHIVE_SIZE"
  else
    format-echo "ERROR" "Failed to compress directory."
    print_with_separator "End of Compress Directory Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Compression operation completed."
  print_with_separator "End of Compress Directory Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
