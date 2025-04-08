#!/bin/bash
# Git Commit Validator
# Script to validate and commit changes with a proper commit message

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
usage() {
  TERMINAL_WIDTH=$(tput cols)
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mGit Commit Validator\033[0m"
  echo
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
  echo "$SEPARATOR"
  echo
  exit 0
}

# Initialize variables
COMMIT_MESSAGE=""
LOG_FILE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --log)
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      if [ -z "$COMMIT_MESSAGE" ]; then
        COMMIT_MESSAGE="$1"
        shift
      else
        log_message "ERROR" "Unknown option: $1"
        usage
      fi
      ;;
  esac
done
LOG_FILE="${LOG_FILE:-/dev/null}"

# Validate required arguments
if [ -z "$COMMIT_MESSAGE" ]; then
  log_message "ERROR" "<commit_message> is required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Validate commit message format (example: must start with a capital letter and be at least 10 characters long)
if [[ ! "$COMMIT_MESSAGE" =~ ^[A-Z] ]] || [ ${#COMMIT_MESSAGE} -lt 10 ]; then
  log_message "ERROR" "Invalid commit message format! Must start with a capital letter and be at least 10 characters long."
  exit 1
fi

# Check if there are changes staged for commit
log_message "INFO" "Validating staged changes..."
if git diff --cached --quiet; then
  log_message "ERROR" "No changes staged for commit!"
  exit 1
fi

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Commit the changes with separators
print_with_separator "git commit output"
if git commit -m "$COMMIT_MESSAGE" 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of git commit"
  log_message "SUCCESS" "Commit successful!"
else
  print_with_separator "End of git commit"
  log_message "ERROR" "Failed to commit changes."
  exit 1
fi