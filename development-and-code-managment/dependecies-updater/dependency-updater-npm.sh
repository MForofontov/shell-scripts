#!/bin/bash
# dependency-updater-npm.sh
# Script to update npm dependencies and generate a summary of updated packages

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
  print_with_separator "NPM Dependency Updater Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script updates npm dependencies and generates a summary of updated packages."
  echo "  It must be run in a directory containing a 'package.json' file."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_log.log   # Run the script and log output to 'custom_log.log'"
  echo "  $0                        # Run the script without logging to a file"
  print_with_separator "End of NPM Dependency Updater Script"
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

  print_with_separator "NPM Dependency Updater Script"
  log_message "INFO" "Starting NPM Dependency Updater Script..."

  # Validate if npm is installed
  if ! command -v npm &> /dev/null; then
    log_message "ERROR" "npm is not installed or not available in the PATH. Please install npm and try again."
    print_with_separator "End of NPM Dependency Updater Script"
    exit 1
  fi

  # Validate if the script is run in a directory with a package.json file
  if [ ! -f "package.json" ]; then
    log_message "ERROR" "No package.json file found in the current directory. Please run this script in a Node.js project directory."
    print_with_separator "End of NPM Dependency Updater Script"
    exit 1
  fi

  log_message "INFO" "Updating npm dependencies..."

  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  log_message "INFO" "$TIMESTAMP: Running npm update..."

  # Update npm dependencies
  if npm update; then
    log_message "SUCCESS" "Dependencies updated successfully!"
  else
    log_message "ERROR" "Failed to update dependencies!"
    print_with_separator "End of NPM Dependency Updater Script"
    exit 1
  fi

  # Generate a summary of updated packages
  log_message "INFO" "Generating summary of updated packages..."
  UPDATED_PACKAGES=$(npm outdated --json 2>/dev/null)

  if [ -n "$UPDATED_PACKAGES" ] && [ "$UPDATED_PACKAGES" != "null" ]; then
    log_message "INFO" "Summary of updated packages:"
    echo "$UPDATED_PACKAGES" | jq -r 'to_entries[] | "\(.key) updated from \(.value.current) to \(.value.latest)"'
  else
    log_message "INFO" "No packages were updated."
  fi

  log_message "INFO" "$TIMESTAMP: npm dependency update process completed."
  print_with_separator "End of NPM Dependency Updater Script"
}

main "$@"