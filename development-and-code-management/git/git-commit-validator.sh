#!/bin/bash
# git-commit-validator.sh
# Script to validate and commit changes with a proper commit message

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
COMMIT_MESSAGE=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
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

  setup_log_file

  print_with_separator "Git Commit Validator Script"
  format-echo "INFO" "Starting Git Commit Validator Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate required arguments
  if [ -z "$COMMIT_MESSAGE" ]; then
    format-echo "ERROR" "<commit_message> is required."
    print_with_separator "End of Git Commit Validator Script"
    usage
  fi

  # Validate git is available
  if ! command -v git &> /dev/null; then
    format-echo "ERROR" "git is not installed or not available in the PATH."
    print_with_separator "End of Git Commit Validator Script"
    exit 1
  fi

  # Validate commit message format (example: must start with a capital letter and be at least 10 characters long)
  if [[ ! "$COMMIT_MESSAGE" =~ ^[A-Z] ]] || [ ${#COMMIT_MESSAGE} -lt 10 ]; then
    format-echo "ERROR" "Invalid commit message format! Must start with a capital letter and be at least 10 characters long."
    print_with_separator "End of Git Commit Validator Script"
    exit 1
  fi

  # Check if there are changes staged for commit
  format-echo "INFO" "Validating staged changes..."
  if git diff --cached --quiet; then
    format-echo "ERROR" "No changes staged for commit!"
    print_with_separator "End of Git Commit Validator Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMMIT OPERATION
  #---------------------------------------------------------------------
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  format-echo "INFO" "Committing changes with message: $COMMIT_MESSAGE"

  # Commit the changes
  if git commit -m "$COMMIT_MESSAGE"; then
    format-echo "SUCCESS" "Commit successful!"
  else
    format-echo "ERROR" "Failed to commit changes."
    print_with_separator "End of Git Commit Validator Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "$TIMESTAMP: Commit process completed."
  print_with_separator "End of Git Commit Validator Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
