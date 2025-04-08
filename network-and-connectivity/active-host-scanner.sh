#!/bin/bash
# active-host-scanner.sh
# Script to scan a network for active hosts

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
  echo -e "\033[1;34mActive Host Scanner Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scans a network for active hosts using ping."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <network_prefix> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<network_prefix>\033[0m  (Required) Network prefix to scan (e.g., 192.168.1)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 192.168.1 --log custom_log.log"
  echo "  $0 192.168.1"
  echo "$SEPARATOR"
  echo
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Initialize variables
NETWORK="$1"      # Network prefix to scan
LOG_FILE=""

# Parse optional arguments
if [[ "$#" -ge 2 && "$2" == "--log" ]]; then
  LOG_FILE="$3"
fi
LOG_FILE="${LOG_FILE:-/dev/null}"

# Validate network prefix
if ! [[ "$NETWORK" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
  log_message "ERROR" "Invalid network prefix format: $NETWORK. Expected format: X.X.X (e.g., 192.168.1)"
  usage
fi

# Extract octets and validate their range
IFS='.' read -r A B C <<< "$NETWORK"
if (( A < 0 || A > 255 || B < 0 || B > 255 || C < 0 || C > 255 )); then
  log_message "ERROR" "Network prefix out of range: $NETWORK. Each octet must be between 0 and 255."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Log start of the scan
log_message "INFO" "Scanning network $NETWORK.0/24 for active hosts..."
print_with_separator "Active Host Scan Output"

# Function to scan for active hosts
scan_network() {
  for IP in $(seq 1 254); do
    TARGET="$NETWORK.$IP"
    if ping -c 1 -W 1 "$TARGET" &> /dev/null; then
      TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
      log_message "INFO" "$TIMESTAMP: $TARGET is active"
    fi
  done
}

# Perform the network scan
if ! scan_network; then
  print_with_separator "End of Active Host Scan Output"
  log_message "ERROR" "Failed to scan network $NETWORK.0/24."
  exit 1
else
  print_with_separator "End of Active Host Scan Output"
  log_message "SUCCESS" "Network scan complete."
fi