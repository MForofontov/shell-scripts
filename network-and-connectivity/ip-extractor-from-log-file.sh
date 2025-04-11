#!/bin/bash
# ip-extractor-from-log-file.sh
# Script to extract unique IP addresses from a log file

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
  print_with_separator "IP Extractor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script extracts unique IP addresses from a log file."
  echo "  It also supports optional output to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <input_log> [--log_file <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<input_log>\033[0m                  (Required) Path to the input log file."
  echo -e "  \033[1;33m--log_file <log_file>\033[0m        (Optional) Path to save the extracted IPs."
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/inputlog.log --log_file extracted_ips.txt"
  echo "  $0 /path/to/inputlog.log"
  print_with_separator
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 1 ]; then
  log_message "ERROR" "Input log file is required."
  usage
fi

# Parse arguments
INPUT_LOG=""
LOG_FILE="/dev/null"
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --log_file)
      if [ -z "$2" ]; then
        log_message "ERROR" "Log file name is required after --log_file."
        usage
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      if [ -z "$INPUT_LOG" ]; then
        INPUT_LOG="$1"
      elif [ -z "$LOG_FILE" ]; then
        LOG_FILE="$1"
      else
        log_message "ERROR" "Too many arguments provided."
        usage
      fi
      shift
      ;;
  esac
done

# Validate input log file
if [ -z "$INPUT_LOG" ]; then
  log_message "ERROR" "Input log file is required."
  usage
fi

if [ ! -f "$INPUT_LOG" ]; then
  log_message "ERROR" "Input log file $INPUT_LOG does not exist."
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

log_message "INFO" "Extracting IP addresses from $INPUT_LOG..."
print_with_separator "IP Extraction Output"

# Extract unique IP addresses
extract_ips() {
  if [ -n "$LOG_FILE" ]; then
    if ! grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$INPUT_LOG" | sort -u > "$LOG_FILE"; then
      log_message "ERROR" "Failed to extract IP addresses."
      exit 1
    fi
    log_message "SUCCESS" "Extracted IPs saved to $LOG_FILE"
  else
    if ! grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$INPUT_LOG" | sort -u; then
      log_message "ERROR" "Failed to extract IP addresses."
      exit 1
    fi
  fi
}

# Perform IP extraction
if ! extract_ips; then
  print_with_separator "End of IP Extraction Output"
  log_message "ERROR" "IP extraction failed."
  exit 1
fi

print_with_separator "End of IP Extraction Output"
log_message "SUCCESS" "IP extraction completed successfully."