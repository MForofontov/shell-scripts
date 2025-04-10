#!/bin/bash
# port-scanner.sh
# Script to scan open ports on a specified server

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
  print_with_separator "Port Scanner Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scans open ports on a specified server."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <server> [--start <start_port>] [--end <end_port>] [--output <output_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<server>\033[0m                  (Required) The server to scan."
  echo -e "  \033[1;33m--start <start_port>\033[0m      (Optional) Start port (default: 1)."
  echo -e "  \033[1;33m--end <end_port>\033[0m          (Optional) End port (default: 65535)."
  echo -e "  \033[1;33m--output <output_file>\033[0m    (Optional) File to save the scan results."
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 example.com --start 1 --end 1000 --output scan_results.txt"
  echo "  $0 example.com"
  print_with_separator
  exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 1 ]; then
  log_message "ERROR" "Server is required."
  usage
fi

# Initialize variables
SERVER=""
START_PORT=1
END_PORT=65535
OUTPUT_FILE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --start)
      if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
        log_message "ERROR" "Invalid start port: $2"
        usage
      fi
      START_PORT="$2"
      shift 2
      ;;
    --end)
      if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
        log_message "ERROR" "Invalid end port: $2"
        usage
      fi
      END_PORT="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      if [ -z "$SERVER" ]; then
        SERVER="$1"
        shift
      else
        log_message "ERROR" "Unknown option: $1"
        usage
      fi
      ;;
  esac
done

# Validate server
if [ -z "$SERVER" ]; then
  log_message "ERROR" "Server is required."
  usage
fi

if ! ping -c 1 -W 1 "$SERVER" &> /dev/null; then
  log_message "ERROR" "Cannot reach server $SERVER."
  exit 1
fi

# Validate port range
if [ "$START_PORT" -gt "$END_PORT" ]; then
  log_message "ERROR" "Start port ($START_PORT) is greater than end port ($END_PORT)."
  usage
fi

# Validate output file if provided
if [ -n "$OUTPUT_FILE" ]; then
  if ! touch "$OUTPUT_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to output file $OUTPUT_FILE."
    exit 1
  fi
fi

log_message "INFO" "Scanning ports on $SERVER from $START_PORT to $END_PORT..."
print_with_separator "Port Scan Results"

# Function to scan ports
scan_ports() {
  for PORT in $(seq "$START_PORT" "$END_PORT"); do
    timeout 1 bash -c "echo > /dev/tcp/$SERVER/$PORT" &> /dev/null && log_message "SUCCESS" "Port $PORT is open."
  done
}

# Perform port scan
if ! scan_ports; then
  log_message "ERROR" "Failed to scan ports on $SERVER."
  print_with_separator "End of Port Scan Results"
  exit 1
fi

print_with_separator "End of Port Scan Results"
if [ -n "$OUTPUT_FILE" ]; then
  log_message "SUCCESS" "Port scan results have been written to $OUTPUT_FILE."
else
  log_message "SUCCESS" "Port scan results displayed on the console."
fi