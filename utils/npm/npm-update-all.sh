#!/bin/bash
# npm-update-all.sh
# Script to update all NPM packages to the latest version.

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
  print_with_separator "NPM Update All Packages Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script updates all NPM packages to their latest versions."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log npm_update.log"
  echo "  $0"
  print_with_separator "End of NPM Update All Packages Script"
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

  print_with_separator "NPM Update All Packages Script"
  log_message "INFO" "Starting NPM Update All Packages Script..."

  # Check if npm is installed
  if ! command -v npm &> /dev/null; then
    log_message "ERROR" "npm is not installed. Please install Node.js and npm first."
    print_with_separator "End of NPM Update All Packages Script"
    exit 1
  fi

  # Check for outdated packages
  log_message "INFO" "Checking for outdated packages..."
  if ! npm outdated; then
    print_with_separator "End of NPM Update All Packages Script"
    log_message "ERROR" "Failed to check outdated packages."
    exit 1
  fi

  # Update all packages
  log_message "INFO" "Updating all NPM packages..."
  if ! npm update; then
    print_with_separator "End of NPM Update All Packages Script"
    log_message "ERROR" "Failed to update packages."
    exit 1
  fi

  # Install updated packages
  log_message "INFO" "Installing updated packages..."
  if ! npm install; then
    print_with_separator "End of NPM Update All Packages Script"
    log_message "ERROR" "Failed to install updated packages."
    exit 1
  fi

  # Run npm audit fix
  log_message "INFO" "Running npm audit fix..."
  if ! npm audit fix; then
    print_with_separator "End of NPM Update All Packages Script"
    log_message "ERROR" "Failed to run npm audit fix."
    exit 1
  fi

  print_with_separator "End of NPM Update All Packages Script"
  log_message "SUCCESS" "All NPM packages have been updated to the latest version."
}

main "$@"