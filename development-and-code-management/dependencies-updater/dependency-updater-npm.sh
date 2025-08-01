#!/usr/bin/env bash
# dependency-updater-npm.sh
# Script to update npm dependencies and generate a summary of updated packages

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
DRY_RUN=false
LIST_ONLY=false
UPDATE_PACKAGE_JSON=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "NPM Dependency Updater Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script updates npm dependencies and generates a summary of updated packages."
  echo "  It must be run in a directory containing a 'package.json' file."
  echo "  It also supports optional logging to a file."
  echo "  The 'jq' utility must be installed to parse npm output."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--dry-run] [--list-outdated] [--update-package-json] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m          (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--dry-run\033[0m                (Optional) Show what would be updated without installing."
  echo -e "  \033[1;33m--list-outdated\033[0m          (Optional) Only list outdated packages and exit."
  echo -e "  \033[1;33m--update-package-json\033[0m    (Optional) Update package.json with latest versions."
  echo -e "  \033[1;33m--help\033[0m                  (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_log.log   # Run the script and log output to 'custom_log.log'"
  echo "  $0 --dry-run             # Show packages that would be updated"
  echo "  $0 --list-outdated       # Only list outdated packages"
  echo "  $0 --update-package-json # Update package.json and install"
  echo "  $0                        # Run the script without logging to a file"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log)
        if [[ -n "${2:-}" ]]; then
          LOG_FILE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --log"
          usage
        fi
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --list-outdated)
        LIST_ONLY=true
        shift
        ;;
      --update-package-json)
        UPDATE_PACKAGE_JSON=true
        shift
        ;;
      --help)
        usage
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  setup_log_file

  print_with_separator "NPM Dependency Updater Script"
  format-echo "INFO" "Starting NPM Dependency Updater Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate if npm is installed
  if ! command -v npm &> /dev/null; then
    format-echo "ERROR" "npm is not installed or not available in the PATH. Please install npm and try again."
    print_with_separator "End of NPM Dependency Updater Script"
    exit 1
  fi

  # Validate if the script is run in a directory with a package.json file
  if [ ! -f "package.json" ]; then
    format-echo "ERROR" "No package.json file found in the current directory. Please run this script in a Node.js project directory."
    print_with_separator "End of NPM Dependency Updater Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # LIST OUTDATED PACKAGES
  #---------------------------------------------------------------------
  if [ "$LIST_ONLY" = true ]; then
    format-echo "INFO" "Listing outdated packages..."
    npm outdated
    print_with_separator "End of NPM Dependency Updater Script"
    exit 0
  fi

  #---------------------------------------------------------------------
  # DEPENDENCY UPDATES
  #---------------------------------------------------------------------
  format-echo "INFO" "Updating npm dependencies..."

  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  format-echo "INFO" "$TIMESTAMP: Running npm update..."

  UPDATE_CMD=(npm update)
  if [ "$DRY_RUN" = true ]; then
    UPDATE_CMD+=(--dry-run)
  fi

  if "${UPDATE_CMD[@]}"; then
    if [ "$DRY_RUN" = true ]; then
      format-echo "INFO" "Dry run complete. No packages were installed."
    else
      format-echo "SUCCESS" "Dependencies updated successfully!"
    fi
  else
    format-echo "ERROR" "Failed to update dependencies!"
    print_with_separator "End of NPM Dependency Updater Script"
    exit 1
  fi

  # Update package.json with latest versions if requested
  if [ "$UPDATE_PACKAGE_JSON" = true ] && [ "$DRY_RUN" = false ]; then
    format-echo "INFO" "Updating package.json with latest versions using npm-check-updates..."
    if npx npm-check-updates -u; then
      npm install
    else
      format-echo "ERROR" "npm-check-updates failed."
    fi
  fi

  #---------------------------------------------------------------------
  # SUMMARY GENERATION
  #---------------------------------------------------------------------
  # Generate a summary of updated packages
  format-echo "INFO" "Generating summary of updated packages..."

  # Ensure jq is available for parsing npm output
  if ! command -v jq >/dev/null; then
    format-echo "ERROR" "jq is required to parse npm output. Please install jq."
    exit 1
  fi
  UPDATED_PACKAGES=$(npm outdated --json 2>/dev/null)

  if [ -n "$UPDATED_PACKAGES" ] && [ "$UPDATED_PACKAGES" != "null" ]; then
    format-echo "INFO" "Summary of updated packages:"
    echo "$UPDATED_PACKAGES" | jq -r 'to_entries[] | "\(.key) updated from \(.value.current) to \(.value.latest)"'
  else
    format-echo "INFO" "No packages were updated."
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "$TIMESTAMP: npm dependency update process completed."
  print_with_separator "End of NPM Dependency Updater Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
