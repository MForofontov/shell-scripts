#!/bin/bash
# port-scanner.sh
# Script to scan open ports on a specified server

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

SERVER=""
START_PORT=1
END_PORT=65535
OUTPUT_FILE=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Port Scanner Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scans open ports on a specified server."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <server> [--start <start_port>] [--end <end_port>] [--output <output_file>] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<server>\033[0m                  (Required) The server to scan."
  echo -e "  \033[1;33m--start <start_port>\033[0m      (Optional) Start port (default: 1)."
  echo -e "  \033[1;33m--end <end_port>\033[0m          (Optional) End port (default: 65535)."
  echo -e "  \033[1;33m--output <output_file>\033[0m    (Optional) File to save the scan results."
  echo -e "  \033[1;33m--log <log_file>\033[0m          (Optional) File to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 example.com --start 1 --end 1000 --output scan_results.txt --log scan_log.txt"
  echo "  $0 example.com"
  print_with_separator
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log)
        if [ -z "${2:-}" ]; then
          log_message "ERROR" "Log file name is required after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --help)
        usage
        ;;
      --start)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
          log_message "ERROR" "Invalid start port: $2"
          usage
        fi
        START_PORT="$2"
        shift 2
        ;;
      --end)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ] || [ "$2" -gt 65535 ]; then
          log_message "ERROR" "Invalid end port: $2"
          usage
        fi
        END_PORT="$2"
        shift 2
        ;;
      --output)
        if [ -z "${2:-}" ]; then
          log_message "ERROR" "Output file name is required after --output."
          usage
        fi
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
}

scan_ports() {
  for PORT in $(seq "$START_PORT" "$END_PORT"); do
    if timeout 1 bash -c "echo > /dev/tcp/$SERVER/$PORT" &> /dev/null; then
      RESULT="Port $PORT is open."
      log_message "SUCCESS" "$RESULT"
      if [ -n "$OUTPUT_FILE" ]; then
        echo "$RESULT" >> "$OUTPUT_FILE"
      fi
    fi
  done
}

main() {
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Port Scanner Script"
  log_message "INFO" "Starting Port Scanner Script..."

  # Validate server
  if [ -z "$SERVER" ]; then
    log_message "ERROR" "Server is required."
    print_with_separator "End of Port Scanner Script"
    usage
  fi

  if ! ping -c 1 -W 1 "$SERVER" &> /dev/null; then
    log_message "ERROR" "Cannot reach server $SERVER."
    print_with_separator "End of Port Scanner Script"
    exit 1
  fi

  # Validate port range
  if [ "$START_PORT" -gt "$END_PORT" ]; then
    log_message "ERROR" "Start port ($START_PORT) is greater than end port ($END_PORT)."
    print_with_separator "End of Port Scanner Script"
    usage
  fi

  # Validate output file if provided
  if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
      log_message "ERROR" "Cannot write to output file $OUTPUT_FILE."
      print_with_separator "End of Port Scanner Script"
      exit 1
    fi
  fi

  log_message "INFO" "Scanning ports on $SERVER from $START_PORT to $END_PORT..."

  if scan_ports; then
    if [ -n "$OUTPUT_FILE" ]; then
      log_message "SUCCESS" "Port scan results have been written to $OUTPUT_FILE."
    else
      log_message "SUCCESS" "Port scan results displayed on the console."
    fi
  else
    log_message "ERROR" "Failed to scan ports on $SERVER."
    print_with_separator "End of Port Scanner Script"
    exit 1
  fi

  print_with_separator "End of Port Scanner Script"
}

main "$@"