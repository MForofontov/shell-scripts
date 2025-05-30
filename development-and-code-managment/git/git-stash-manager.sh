#!/bin/bash
# git-stash-manager.sh
# Script to manage Git stashes (list, apply, drop)

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

  print_with_separator "Git Stash Manager Script"
  log_message "INFO" "Starting Git Stash Manager Script..."

  # Validate git is available
  if ! command -v git &> /dev/null; then
    log_message "ERROR" "git is not installed or not available in the PATH."
    print_with_separator "End of Git Stash Manager Script"
    exit 1
  fi

  # Display available stashes
  log_message "INFO" "Listing available stashes..."
  git stash list

  # Prompt user for stash index
  log_message "INFO" "Enter stash index to apply or drop (e.g., stash@{0}):"
  read -r STASH_INDEX

  # Validate stash index
  if ! git stash list | grep -q "$STASH_INDEX"; then
    log_message "ERROR" "Invalid stash index $STASH_INDEX"
    print_with_separator "End of Git Stash Manager Script"
    exit 1
  fi

  # Prompt user for action
  log_message "INFO" "Choose an action: [apply/drop]"
  read -r ACTION

  # Validate the action
  if [[ "$ACTION" != "apply" && "$ACTION" != "drop" ]]; then
    log_message "ERROR" "Invalid action: $ACTION. Allowed actions are 'apply' or 'drop'."
    print_with_separator "End of Git Stash Manager Script"
    exit 1
  fi

  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

  # Perform the chosen action
  if [ "$ACTION" == "apply" ]; then
    log_message "INFO" "$TIMESTAMP: Applying stash $STASH_INDEX..."
    if git stash apply "$STASH_INDEX"; then
      log_message "SUCCESS" "Stash $STASH_INDEX applied successfully."
    else
      log_message "ERROR" "Failed to apply stash $STASH_INDEX."
      print_with_separator "End of Git Stash Manager Script"
      exit 1
    fi
  elif [ "$ACTION" == "drop" ]; then
    log_message "INFO" "$TIMESTAMP: Dropping stash $STASH_INDEX..."
    if git stash drop "$STASH_INDEX"; then
      log_message "SUCCESS" "Stash $STASH_INDEX dropped successfully."
    else
      log_message "ERROR" "Failed to drop stash $STASH_INDEX."
      print_with_separator "End of Git Stash Manager Script"
      exit 1
    fi
  fi

  log_message "INFO" "Git Stash Manager Script completed."
  print_with_separator "End of Git Stash Manager Script"
}

main "$@"