#!/bin/bash
# git-conflict-finder.sh
# Script to find merge conflicts in a Git repository

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
  print_with_separator "Git Conflict Finder Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scans the repository for merge conflicts."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExample:\033[0m"
  echo "  $0 --log conflict_finder.log"
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

  print_with_separator "Git Conflict Finder Script"
  log_message "INFO" "Starting Git Conflict Finder Script..."

  # Validate git is available
  if ! command -v git &> /dev/null; then
    log_message "ERROR" "git is not installed or not available in the PATH."
    print_with_separator "End of Git Conflict Finder Script"
    exit 1
  fi

  # Search for merge conflict markers
  log_message "INFO" "Searching for merge conflicts in the repository..."
  if git grep -n '<<<<<<< HEAD' 2>/dev/null; then
    log_message "INFO" "Conflict(s) found in the repository."
  else
    log_message "SUCCESS" "No merge conflicts found."
  fi

  log_message "INFO" "Conflict search process completed."
  print_with_separator "End of Git Conflict Finder Script"
}

main "$@"