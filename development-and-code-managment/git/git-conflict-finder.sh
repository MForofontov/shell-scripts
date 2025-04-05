#!/bin/bash
# Git Conflict Finder
# Script to identify unresolved merge conflicts in a Git repository

# Function to display usage instructions
usage() {
  # Get the terminal width
  TERMINAL_WIDTH=$(tput cols)
  # Generate a separator line based on the terminal width
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mGit Conflict Finder\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks for unresolved merge conflicts in the current Git repository."
  echo "  It optionally logs the output to a specified file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [log_file]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33mlog_file\033[0m    (Optional) Log output to the specified file."
  echo
  echo -e "\033[1;34mExample:\033[0m"
  echo "  $0 custom_log.log"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -gt 1 ]; then
  usage
elif [ "$#" -eq 1 ]; then
  LOG_FILE="$1"
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
  if [ -n "$LOG_FILE" ]; then
    echo "$PLAIN_MESSAGE" | tee -a "$LOG_FILE"
  else
    echo -e "$MESSAGE"
  fi
}

log_message "\033[1;34mChecking for unresolved conflicts...\033[0m"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
log_message "\033[1;34m$TIMESTAMP: Checking for unresolved conflicts...\033[0m"

# Find merge conflicts
CONFLICTS=$(git diff --name-only --diff-filter=U)

if [ $? -eq 0 ]; then
  if [ -n "$CONFLICTS" ]; then
    log_message "\033[1;33mConflicted files:\033[0m"
    log_message "$CONFLICTS"
  else
    log_message "\033[1;32mNo conflicts found!\033[0m"
  fi
else
  log_message "\033[1;31mError:\033[0m Failed to check for conflicts."
  exit 1
fi