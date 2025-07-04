#!/bin/bash
# git-add-commit-push.sh
# Script to automate Git operations: add, commit, and push

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
COMMIT_MESSAGE=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Git Add, Commit, and Push Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script automates the process of adding, committing, and pushing changes to a Git repository."
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
  echo "  $0 'Initial commit' --log git_operations.log"
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
        if [ -z "$COMMIT_MESSAGE" ]; then
          COMMIT_MESSAGE="$1"
          shift
        else
          format-echo "ERROR" "Unknown option: $1"
          usage
        fi
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

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Git Add, Commit, and Push Script"
  format-echo "INFO" "Starting Git Add, Commit, and Push Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate required arguments
  if [ -z "$COMMIT_MESSAGE" ]; then
    format-echo "ERROR" "<commit_message> is required."
    print_with_separator "End of Git Add, Commit, and Push Script"
    usage
  fi

  # Validate git is available
  if ! command -v git &> /dev/null; then
    format-echo "ERROR" "git is not installed or not available in the PATH."
    print_with_separator "End of Git Add, Commit, and Push Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # GIT OPERATIONS
  #---------------------------------------------------------------------
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  format-echo "INFO" "$TIMESTAMP: Starting Git operations..."

  # Add all changes
  if git add .; then
    format-echo "INFO" "Changes added successfully."
  else
    format-echo "ERROR" "Failed to add changes."
    print_with_separator "End of Git Add, Commit, and Push Script"
    exit 1
  fi

  # Commit changes
  if git commit -m "$COMMIT_MESSAGE"; then
    format-echo "INFO" "Changes committed successfully."
  else
    format-echo "ERROR" "Failed to commit changes."
    print_with_separator "End of Git Add, Commit, and Push Script"
    exit 1
  fi

  # Push changes
  if git push; then
    format-echo "INFO" "Changes pushed successfully."
  else
    format-echo "ERROR" "Failed to push changes."
    print_with_separator "End of Git Add, Commit, and Push Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "$TIMESTAMP: Git operations completed successfully."
  print_with_separator "End of Git Add, Commit, and Push Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
