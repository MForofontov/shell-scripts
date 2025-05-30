#!/bin/bash
# add-prefix-to-files.sh
# Script to add a prefix to all files in a specified directory

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

DIRECTORY=""
PREFIX=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Add Prefix to Files Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script adds a specified prefix to all files in a given directory."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <directory> <prefix> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<directory>\033[0m       (Required) Directory containing the files to rename."
  echo -e "  \033[1;36m<prefix>\033[0m          (Required) Prefix to add to the files."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/directory my_prefix --log custom_log.log"
  echo "  $0 /path/to/directory my_prefix"
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
        if [ -z "$DIRECTORY" ]; then
          DIRECTORY="$1"
          shift
        elif [ -z "$PREFIX" ]; then
          PREFIX="$1"
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

  print_with_separator "Add Prefix to Files Script"
  log_message "INFO" "Starting Add Prefix to Files Script..."

  if [ -z "$DIRECTORY" ] || [ -z "$PREFIX" ]; then
    log_message "ERROR" "<directory> and <prefix> are required."
    print_with_separator "End of Add Prefix to Files Script"
    exit 1
  fi

  if [ ! -d "$DIRECTORY" ]; then
    log_message "ERROR" "Directory $DIRECTORY does not exist."
    print_with_separator "End of Add Prefix to Files Script"
    exit 1
  fi

  log_message "INFO" "Adding prefix '$PREFIX' to files in $DIRECTORY..."

  for FILE in "$DIRECTORY"/*; do
    if [ -f "$FILE" ]; then
      BASENAME=$(basename "$FILE")
      NEW_NAME="${DIRECTORY}/${PREFIX}${BASENAME}"
      if mv "$FILE" "$NEW_NAME"; then
        log_message "SUCCESS" "Renamed $BASENAME to ${PREFIX}${BASENAME}"
      else
        log_message "ERROR" "Failed to rename $BASENAME"
      fi
    fi
  done

  log_message "INFO" "Prefix addition completed."
  print_with_separator "End of Add Prefix to Files Script"
}

main "$@"