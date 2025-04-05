#!/bin/bash
# Script to automate Git operations: add, commit, and push

# Function to display usage instructions
usage() {
  # Get the terminal width
  TERMINAL_WIDTH=$(tput cols)
  # Generate a separator line based on the terminal width
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mGit Add, Commit, and Push Script\033[0m"
  echo
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
  echo "$SEPARATOR"
  echo
  exit 0
}

# Check if no arguments are provided
if [ "$#" -lt 1 ]; then
  usage
fi

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
        echo -e "\033[1;31mError:\033[0m Unknown option: $1"
        usage
      fi
      ;;
  esac
done

# Validate required arguments
if [ -z "$COMMIT_MESSAGE" ]; then
  echo -e "\033[1;31mError:\033[0m <commit_message> is required."
  usage
fi

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
  
  if [ -n "$MESSAGE" ]; then
    if [ -n "$LOG_FILE" ]; then
      # Write plain text to the log file
      echo "$PLAIN_MESSAGE" | tee -a "$LOG_FILE"
    else
      # Print colored message to the console
      echo -e "$MESSAGE"
    fi
  fi
}

log_message "Starting Git operations..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
log_message "$TIMESTAMP: Starting Git operations..."

# Add all changes
log_message "Adding all changes..."
if ! git add . >> "$LOG_FILE" 2>&1; then
  log_message "\033[1;31mError:\033[0m Failed to add changes."
  exit 1
fi

# Commit changes
log_message "Committing changes..."
if ! git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1; then
  log_message "\033[1;31mError:\033[0m Failed to commit changes."
  exit 1
fi

# Push changes
log_message "Pushing changes..."
if ! git push >> "$LOG_FILE" 2>&1; then
  log_message "\033[1;31mError:\033[0m Failed to push changes."
  exit 1
fi

log_message "\033[1;32m$TIMESTAMP: Git operations completed successfully.\033[0m"