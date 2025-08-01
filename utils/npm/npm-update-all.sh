#!/usr/bin/env bash
# npm-update-all.sh
# Script to update all NPM packages to the latest version.

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

  print_with_separator "NPM Update All Packages Script"
  format-echo "INFO" "Starting NPM Update All Packages Script..."

  # Check if npm is installed
  if ! command -v npm &> /dev/null; then
    format-echo "ERROR" "npm is not installed. Please install Node.js and npm first."
    print_with_separator "End of NPM Update All Packages Script"
    exit 1
  fi

  # Check for outdated packages
  format-echo "INFO" "Checking for outdated packages..."
  if ! npm outdated; then
    print_with_separator "End of NPM Update All Packages Script"
    format-echo "ERROR" "Failed to check outdated packages."
    exit 1
  fi

  # Update all packages
  format-echo "INFO" "Updating all NPM packages..."
  if ! npm update; then
    print_with_separator "End of NPM Update All Packages Script"
    format-echo "ERROR" "Failed to update packages."
    exit 1
  fi

  # Install updated packages
  format-echo "INFO" "Installing updated packages..."
  if ! npm install; then
    print_with_separator "End of NPM Update All Packages Script"
    format-echo "ERROR" "Failed to install updated packages."
    exit 1
  fi

  # Run npm audit fix
  format-echo "INFO" "Running npm audit fix..."
  if ! npm audit fix; then
    print_with_separator "End of NPM Update All Packages Script"
    format-echo "ERROR" "Failed to run npm audit fix."
    exit 1
  fi

  print_with_separator "End of NPM Update All Packages Script"
  format-echo "SUCCESS" "All NPM packages have been updated to the latest version."
}

main "$@"
exit $?
