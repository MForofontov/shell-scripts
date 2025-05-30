#!/bin/bash
# generate-changelog.sh
# Script to generate a changelog from the Git log

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

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

OUTPUT_FILE=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Generate Changelog Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates a changelog file from the Git log of the current repository."
  echo "  It includes commit hashes, messages, authors, and relative commit times."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <output_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<output_file>\033[0m       (Required) The file where the changelog will be saved."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExample:\033[0m"
  echo "  $0 CHANGELOG.md --log changelog.log"
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
        if [ -z "$OUTPUT_FILE" ]; then
          OUTPUT_FILE="$1"
          shift
        else
          log_message "ERROR" "Unknown option: $1"
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

  print_with_separator "Generate Changelog Script"
  log_message "INFO" "Starting Generate Changelog Script..."

  # Validate required arguments
  if [ -z "$OUTPUT_FILE" ]; then
    log_message "ERROR" "<output_file> is required."
    print_with_separator "End of Generate Changelog Script"
    usage
  fi

  # Validate output file
  if ! touch "$OUTPUT_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to output file $OUTPUT_FILE"
    print_with_separator "End of Generate Changelog Script"
    exit 1
  fi

  # Validate git is available
  if ! command -v git &> /dev/null; then
    log_message "ERROR" "git is not installed or not available in the PATH."
    print_with_separator "End of Generate Changelog Script"
    exit 1
  fi

  # Get the project name from the current directory
  PROJECT_NAME=$(basename "$(pwd)")
  CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

  log_message "INFO" "Generating changelog for $PROJECT_NAME..."

  # Add a header to the changelog
  {
    echo "# Changelog for $PROJECT_NAME"
    echo "Generated on $CURRENT_DATE"
    echo
  } > "$OUTPUT_FILE"

  # Append the git log to the changelog
  if git log --pretty=format:"- %h %s (%an, %ar)" 2>&1 | tee -a "$OUTPUT_FILE"; then
    log_message "SUCCESS" "Changelog saved to $OUTPUT_FILE"
  else
    log_message "ERROR" "Failed to generate changelog."
    print_with_separator "End of Generate Changelog Script"
    exit 1
  fi

  print_with_separator "End of Generate Changelog Script"
}

main "$@"