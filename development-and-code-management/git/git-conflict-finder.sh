#!/bin/bash
# git-conflict-finder.sh
# Script to find merge conflicts in a Git repository

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
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

  print_with_separator "Git Conflict Finder Script"
  format-echo "INFO" "Starting Git Conflict Finder Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate git is available
  if ! command -v git &> /dev/null; then
    format-echo "ERROR" "git is not installed or not available in the PATH."
    print_with_separator "End of Git Conflict Finder Script"
    exit 1
  fi

  # Validate that we're in a git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    format-echo "ERROR" "Not in a git repository. Please run this script inside a git repository."
    print_with_separator "End of Git Conflict Finder Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # CONFLICT DETECTION
  #---------------------------------------------------------------------
  # Search for merge conflict markers
  format-echo "INFO" "Searching for merge conflicts in the repository..."
  
  # Look for common conflict markers
  CONFLICT_MARKERS=("<<<<<<< HEAD" "=======" ">>>>>>> ")
  CONFLICTS_FOUND=false
  
  for marker in "${CONFLICT_MARKERS[@]}"; do
    if git grep -l "$marker" &>/dev/null; then
      CONFLICTS_FOUND=true
      format-echo "WARNING" "Files with conflict marker '$marker':"
      git grep -n "$marker" | while read -r line; do
        format-echo "INFO" "$line"
      done
      echo
    fi
  done
  
  if [[ "$CONFLICTS_FOUND" == true ]]; then
    format-echo "WARNING" "Conflict(s) found in the repository."
  else
    format-echo "SUCCESS" "No merge conflicts found."
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Conflict search process completed."
  print_with_separator "End of Git Conflict Finder Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
