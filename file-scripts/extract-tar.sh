#!/bin/bash
# extract-tar.sh
# Script to extract a tar archive

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

TAR_FILE=""
DEST_DIR=""
LOG_FILE="/dev/null"

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
  print_with_separator "End of Extract Tar Archive Script"
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
        if [ -z "$TAR_FILE" ]; then
          TAR_FILE="$1"
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

  print_with_separator "Extract Tar Archive Script"
  log_message "INFO" "Starting Extract Tar Archive Script..."

  # Validate arguments
  if [ -z "$TAR_FILE" ] || [ -z "$DEST_DIR" ]; then
    log_message "ERROR" "<tar_file> and <destination_directory> are required."
    print_with_separator "End of Extract Tar Archive Script"
    exit 1
  fi

  if [ ! -f "$TAR_FILE" ]; then
    log_message "ERROR" "Tar file $TAR_FILE does not exist."
    print_with_separator "End of Extract Tar Archive Script"
    exit 1
  fi

  if [ ! -d "$DEST_DIR" ]; then
    log_message "ERROR" "Destination directory $DEST_DIR does not exist."
    print_with_separator "End of Extract Tar Archive Script"
    exit 1
  fi

  log_message "INFO" "Extracting tar archive $TAR_FILE to $DEST_DIR..."

  if tar -xzf "$TAR_FILE" -C "$DEST_DIR"; then
    log_message "SUCCESS" "Tar archive extracted to $DEST_DIR."
  else
    log_message "ERROR" "Failed to extract tar archive."
    print_with_separator "End of Extract Tar Archive Script"
    exit 1
  fi

  print_with_separator "End of Extract Tar Archive Script"
}

main "$@"