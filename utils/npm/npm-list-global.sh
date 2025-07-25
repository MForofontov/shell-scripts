#!/bin/bash
# npm-list-global.sh
# Script to list all globally installed NPM packages.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

usage() {
  print_with_separator "NPM List Global Packages Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script lists all globally installed NPM packages."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log npm_global_packages.log"
  echo "  $0"
  print_with_separator
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
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  setup_log_file

  print_with_separator "NPM List Global Packages Script"
  format-echo "INFO" "Starting NPM List Global Packages Script..."

  # Check if npm is installed
  if ! command -v npm &> /dev/null; then
    format-echo "ERROR" "npm is not installed. Please install Node.js and npm first."
    print_with_separator "End of NPM List Global Packages Script"
    exit 1
  fi

  # List globally installed NPM packages
  if npm list -g --depth=0; then
    format-echo "SUCCESS" "Successfully listed globally installed NPM packages."
  else
    format-echo "ERROR" "Failed to list globally installed NPM packages."
    print_with_separator "End of NPM List Global Packages Script"
    exit 1
  fi

  print_with_separator "End of NPM List Global Packages Script"
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    format-echo "SUCCESS" "List of globally installed NPM packages has been written to $LOG_FILE."
  else
    format-echo "INFO" "List of globally installed NPM packages displayed on the console."
  fi
}

main "$@"
