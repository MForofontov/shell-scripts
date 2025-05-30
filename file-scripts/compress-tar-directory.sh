#!/bin/bash
# compress-tar-directory.sh
# Script to compress a directory into a tar.gz file

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

SOURCE_DIR=""
OUTPUT_FILE=""
LOG_FILE="/dev/null"

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
        if [ -z "$SOURCE_DIR" ]; then
          SOURCE_DIR="$1"
          shift
        elif [ -z "$OUTPUT_FILE" ]; then
          OUTPUT_FILE="$1"
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

  print_with_separator "Compress Directory Script"
  log_message "INFO" "Starting Compress Directory Script..."

  # Validate arguments
  if [ -z "$SOURCE_DIR" ] || [ -z "$OUTPUT_FILE" ]; then
    log_message "ERROR" "<source_directory> and <output_file> are required."
    print_with_separator "End of Compress Directory Script"
    exit 1
  fi

  if [ ! -d "$SOURCE_DIR" ]; then
    log_message "ERROR" "Source directory $SOURCE_DIR does not exist."
    print_with_separator "End of Compress Directory Script"
    exit 1
  fi

  log_message "INFO" "Compressing directory $SOURCE_DIR into $OUTPUT_FILE..."

  if tar -czf "$OUTPUT_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"; then
    log_message "SUCCESS" "Directory compressed into $OUTPUT_FILE."
  else
    log_message "ERROR" "Failed to compress directory."
    print_with_separator "End of Compress Directory Script"
    exit 1
  fi

  print_with_separator "End of Compress Directory Script"
}

main "$@"