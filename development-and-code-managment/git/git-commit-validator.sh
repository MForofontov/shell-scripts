#!/bin/bash
# git-commit-validator.sh
# Script to validate and commit changes with a proper commit message

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

COMMIT_MESSAGE=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Git Commit Validator Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script validates a commit message and ensures that changes are staged before committing."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <commit_message> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<commit_message>\033[0m    (Required) The commit message for the changes."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExample:\033[0m"
  echo "  $0 'Initial commit' --log commit_validation.log"
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
        if [ -z "$COMMIT_MESSAGE" ]; then
          COMMIT_MESSAGE="$1"
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

  print_with_separator "Git Commit Validator Script"
  log_message "INFO" "Starting Git Commit Validator Script..."

  # Validate required arguments
  if [ -z "$COMMIT_MESSAGE" ]; then
    log_message "ERROR" "<commit_message> is required."
    print_with_separator "End of Git Commit Validator Script"
    usage
  fi

  # Validate git is available
  if ! command -v git &> /dev/null; then
    log_message "ERROR" "git is not installed or not available in the PATH."
    print_with_separator "End of Git Commit Validator Script"
    exit 1
  fi

  # Validate commit message format (example: must start with a capital letter and be at least 10 characters long)
  if [[ ! "$COMMIT_MESSAGE" =~ ^[A-Z] ]] || [ ${#COMMIT_MESSAGE} -lt 10 ]; then
    log_message "ERROR" "Invalid commit message format! Must start with a capital letter and be at least 10 characters long."
    print_with_separator "End of Git Commit Validator Script"
    exit 1
  fi

  # Check if there are changes staged for commit
  log_message "INFO" "Validating staged changes..."
  if git diff --cached --quiet; then
    log_message "ERROR" "No changes staged for commit!"
    print_with_separator "End of Git Commit Validator Script"
    exit 1
  fi

  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

  # Commit the changes
  if git commit -m "$COMMIT_MESSAGE"; then
    log_message "SUCCESS" "Commit successful!"
  else
    log_message "ERROR" "Failed to commit changes."
    print_with_separator "End of Git Commit Validator Script"
    exit 1
  fi

  log_message "INFO" "$TIMESTAMP: Commit process completed."
  print_with_separator "End of Git Commit Validator Script"
}

main "$@"