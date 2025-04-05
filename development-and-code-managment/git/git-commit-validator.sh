#!/bin/bash
# Git Commit Validator
# Script to validate and commit changes with a proper commit message

# Function to display usage instructions
usage() {
  # Get the terminal width
  TERMINAL_WIDTH=$(tput cols)
  # Generate a separator line based on the terminal width
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
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExample:\033[0m"
  echo "  $0 --log commit_validation.log"
  echo "$SEPARATOR"
  echo
  exit 0
}

# Initialize variables
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
      echo -e "\033[1;31mError:\033[0m Unknown option: $1"
      usage
      ;;
  esac
done

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Function to log messages
log_message() {
  local MESSAGE=$1
  # Remove color codes for the log file
  local PLAIN_MESSAGE=$(echo -e "$MESSAGE" | sed 's/\x1b\[[0-9;]*m//g')
  if [ -n "$LOG_FILE" ]; then
    echo "$PLAIN_MESSAGE" | tee -a "$LOG_FILE"
  else
    echo -e "$MESSAGE"
  fi
}

# Prompt user for commit message
log_message "\033[1;34mEnter commit message:\033[0m"
read -r COMMIT_MESSAGE

# Check if commit message is empty
if [ -z "$COMMIT_MESSAGE" ]; then
  log_message "\033[1;31mError:\033[0m Commit message cannot be empty!"
  exit 1
fi

# Validate commit message format (example: must start with a capital letter and be at least 10 characters long)
if [[ ! "$COMMIT_MESSAGE" =~ ^[A-Z] ]] || [ ${#COMMIT_MESSAGE} -lt 10 ]; then
  log_message "\033[1;31mError:\033[0m Invalid commit message format! Must start with a capital letter and be at least 10 characters long."
  exit 1
fi

# Check if there are changes staged for commit
log_message "\033[1;34mValidating staged changes...\033[0m"
if git diff --cached --quiet; then
  log_message "\033[1;31mError:\033[0m No changes staged for commit!"
  exit 1
fi

# Get the current timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Commit the changes
log_message "\033[1;34m$TIMESTAMP: Committing changes...\033[0m"
if git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
  log_message "\033[1;32mCommit successful!\033[0m"
else
  log_message "\033[1;31mError:\033[0m Failed to commit changes."
  exit 1
fi