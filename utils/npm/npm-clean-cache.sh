#!/bin/bash
# npm-clean-cache.sh
# Script to clean the NPM cache.

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

LOG_FILE="/dev/null"

usage() {
  print_with_separator "NPM Clean Cache Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script cleans the NPM cache."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log npm_clean_cache.log"
  echo "  $0"
  print_with_separator "End of NPM Clean Cache Script"
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          log_message "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        log_message "ERROR" "Unknown option: $1"
        usage
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

  print_with_separator "NPM Clean Cache Script"
  log_message "INFO" "Starting NPM Clean Cache Script..."

  # Check if npm is installed
  if ! command -v npm &> /dev/null; then
    log_message "ERROR" "npm is not installed. Please install Node.js and npm first."
    print_with_separator "End of NPM Clean Cache Script"
    exit 1
  fi

  # Clean the NPM cache
  if npm cache clean --force; then
    log_message "SUCCESS" "NPM cache has been cleaned successfully."
  else
    log_message "ERROR" "Failed to clean NPM cache."
    print_with_separator "End of NPM Clean Cache Script"
    exit 1
  fi

  print_with_separator "End of NPM Clean Cache Script"
  log_message "SUCCESS" "NPM cache cleaning process completed."
}

main "$@"