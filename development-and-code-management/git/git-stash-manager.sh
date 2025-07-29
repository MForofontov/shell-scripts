#!/bin/bash
# git-stash-manager.sh
# Script to manage Git stashes (list, apply, drop)

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=../../functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Git Stash Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script helps you manage Git stashes. It allows you to:"
  echo "    - List all available stashes"
  echo "    - Apply a specific stash"
  echo "    - Drop a specific stash"
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
          # shellcheck disable=SC2034
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

  print_with_separator "Git Stash Manager Script"
  format-echo "INFO" "Starting Git Stash Manager Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate git is available
  if ! command -v git &> /dev/null; then
    format-echo "ERROR" "git is not installed or not available in the PATH."
    print_with_separator "End of Git Stash Manager Script"
    exit 1
  fi

  # Validate that we're in a git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    format-echo "ERROR" "Not in a git repository. Please run this script inside a git repository."
    print_with_separator "End of Git Stash Manager Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # STASH MANAGEMENT
  #---------------------------------------------------------------------
  # Display available stashes
  format-echo "INFO" "Listing available stashes..."
  git stash list

  # Check if there are any stashes
  if [[ -z "$(git stash list)" ]]; then
    format-echo "INFO" "No stashes found in this repository."
    print_with_separator "End of Git Stash Manager Script"
    exit 0
  fi

  # Prompt user for stash index
  format-echo "INFO" "Enter stash index to apply or drop (e.g., stash@{0}):"
  read -r STASH_INDEX

  # Validate stash index
  if ! git stash list | grep -q "$STASH_INDEX"; then
    format-echo "ERROR" "Invalid stash index $STASH_INDEX"
    print_with_separator "End of Git Stash Manager Script"
    exit 1
  fi

  # Prompt user for action
  format-echo "INFO" "Choose an action: [apply/drop]"
  read -r ACTION

  # Validate the action
  if [[ "$ACTION" != "apply" && "$ACTION" != "drop" ]]; then
    format-echo "ERROR" "Invalid action: $ACTION. Allowed actions are 'apply' or 'drop'."
    print_with_separator "End of Git Stash Manager Script"
    exit 1
  fi

  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

  # Perform the chosen action
  if [ "$ACTION" == "apply" ]; then
    format-echo "INFO" "$TIMESTAMP: Applying stash $STASH_INDEX..."
    if git stash apply "$STASH_INDEX"; then
      format-echo "SUCCESS" "Stash $STASH_INDEX applied successfully."
    else
      format-echo "ERROR" "Failed to apply stash $STASH_INDEX."
      print_with_separator "End of Git Stash Manager Script"
      exit 1
    fi
  elif [ "$ACTION" == "drop" ]; then
    format-echo "INFO" "$TIMESTAMP: Dropping stash $STASH_INDEX..."
    if git stash drop "$STASH_INDEX"; then
      format-echo "SUCCESS" "Stash $STASH_INDEX dropped successfully."
    else
      format-echo "ERROR" "Failed to drop stash $STASH_INDEX."
      print_with_separator "End of Git Stash Manager Script"
      exit 1
    fi
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Git Stash Manager Script completed."
  print_with_separator "End of Git Stash Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
