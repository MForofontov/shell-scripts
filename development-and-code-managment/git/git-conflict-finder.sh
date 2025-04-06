#!/bin/bash
# Git Conflict Finder
# Script to find merge conflicts in a Git repository

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-with-separator.sh"

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
  echo -e "\033[1;34mGit Conflict Finder\033[0m"
  echo
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
      log_message "ERROR" "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Log the start of the conflict search
log_message "INFO" "Starting conflict search in the repository..."

# Search for merge conflict markers
print_with_separator "Searching for merge conflicts"
if git grep -n '<<<<<<< HEAD' 2>/dev/null | tee -a "$LOG_FILE"; then
  print_with_separator "End of conflict search"
  log_message "INFO" "Conflict search completed successfully."
else
  print_with_separator "End of conflict search"
  log_message "ERROR" "No conflicts found or an error occurred during the search."
  exit 1
fi

log_message "SUCCESS" "Conflict search process completed."