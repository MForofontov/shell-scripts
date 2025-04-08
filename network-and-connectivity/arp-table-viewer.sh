#!/bin/bash
# arp-table-viewer.sh
# Script to view and log the ARP table

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

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
  echo -e "\033[1;34mARP Table Viewer Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script fetches and logs the ARP table."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [log_file] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m[log_file]\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m      (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 custom_log.log"
  echo "  $0"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Check if help is requested
if [[ "$1" == "--help" ]]; then
  usage
fi

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -gt 1 ]; then
  usage
elif [ "$#" -eq 1 ]; then
  LOG_FILE="$1"
fi
LOG_FILE="${LOG_FILE:-/dev/null}"
# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Log start of the ARP table fetch
log_message "INFO" "Fetching ARP table..."
print_with_separator "ARP Table Output"

# Fetch and log the ARP table
if ! arp -a | tee -a "$LOG_FILE"; then
  log_message "ERROR" "Failed to fetch ARP table."
  print_with_separator "End of ARP Table Output"
  exit 1
fi

# Log success
print_with_separator "End of ARP Table Output"
if [ -n "$LOG_FILE" ]; then
  log_message "SUCCESS" "ARP table saved to $LOG_FILE"
else
  log_message "SUCCESS" "ARP table fetched successfully."
fi