#!/bin/bash
# download-file.sh
# Script to download a file using curl

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
  echo -e "\033[1;34mDownload File Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script downloads a file from a given URL to a specified destination."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <url> <destination_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<url>\033[0m               (Required) URL of the file to download."
  echo -e "  \033[1;36m<destination_file>\033[0m  (Required) Path to save the downloaded file."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 https://example.com/file.txt /path/to/destination/file.txt --log custom_log.log"
  echo "  $0 https://example.com/file.txt /path/to/destination/file.txt"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 2 ]; then
  usage
fi

# Initialize variables
URL="$1"          # URL of the file to download
DEST_FILE="$2"    # Path to save the downloaded file
LOG_FILE=""

# Parse optional arguments
if [[ "$#" -ge 3 && "$3" == "--log" ]]; then
  LOG_FILE="$4"
fi

# Validate URL
if ! [[ "$URL" =~ ^https?:// ]]; then
  log_message "ERROR" "Invalid URL: $URL"
  usage
fi

# Validate destination file path
if [ -z "$DEST_FILE" ]; then
  log_message "ERROR" "Destination file path is required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Download file using curl
log_message "INFO" "Downloading file from $URL to $DEST_FILE..."
print_with_separator "Download Output"

if curl -o "$DEST_FILE" "$URL" 2>&1 | tee -a "$LOG_FILE"; then
  print_with_separator "End of Download Output"
  log_message "SUCCESS" "File downloaded to $DEST_FILE."
else
  print_with_separator "End of Download Output"
  log_message "ERROR" "Failed to download file from $URL."
  exit 1
fi