#!/bin/bash
# ping.sh
# Script to ping a list of servers/websites and check their reachability

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

DEFAULT_WEBSITES=("google.com" "github.com" "stackoverflow.com")
PING_COUNT=3
TIMEOUT=5
WEBSITES=()
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Ping Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script pings a list of servers/websites and checks their reachability."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--websites <site1,site2,...>] [--count <number>] [--timeout <seconds>] [--log <file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m--websites <site1,site2,...>\033[0m   (Optional) Comma-separated list of websites to ping (default: ${DEFAULT_WEBSITES[*]})"
  echo -e "  \033[1;36m--count <number>\033[0m               (Optional) Number of ping attempts (default: $PING_COUNT)"
  echo -e "  \033[1;36m--timeout <seconds>\033[0m            (Optional) Timeout for each ping attempt (default: $TIMEOUT)"
  echo -e "  \033[1;33m--log <file>\033[0m                   (Optional) Log output to the specified file"
  echo -e "  \033[1;33m--help\033[0m                         (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --websites google.com,example.com --count 5 --timeout 3 --log ping_results.txt"
  echo "  $0"
  print_with_separator
  exit 1
}

parse_args() {
  WEBSITES=("${DEFAULT_WEBSITES[@]}")
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --websites)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No websites provided after --websites."
          usage
        fi
        IFS=',' read -r -a WEBSITES <<< "$2"
        shift 2
        ;;
      --count)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid count value: $2"
          usage
        fi
        PING_COUNT="$2"
        shift 2
        ;;
      --timeout)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid timeout value: $2"
          usage
        fi
        TIMEOUT="$2"
        shift 2
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

ping_websites() {
  for SITE in "${WEBSITES[@]}"; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    format-echo "INFO" "Pinging $SITE..."
    if ping -c "$PING_COUNT" -W "$TIMEOUT" "$SITE" &> /dev/null; then
      format-echo "SUCCESS" "$TIMESTAMP: $SITE is reachable."
    else
      format-echo "ERROR" "$TIMESTAMP: $SITE is unreachable."
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

  print_with_separator "Ping Script"
  format-echo "INFO" "Starting Ping Script..."

  # Validate websites
  if [ "${#WEBSITES[@]}" -eq 0 ]; then
    format-echo "ERROR" "At least one website is required."
    print_with_separator "End of Ping Script"
    exit 1
  fi

  if ping_websites; then
    format-echo "SUCCESS" "Ping test completed."
  else
    format-echo "ERROR" "Failed to ping websites."
    print_with_separator "End of Ping Script"
    exit 1
  fi

  print_with_separator "End of Ping Script"
}

main "$@"