#!/bin/bash
# active-host-scanner.sh
# Script to scan a network for active hosts

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

NETWORK=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Active Host Scanner Script"
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
  print_with_separator "End of Active Host Scanner Script"
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log)
        if [[ -n "${2:-}" ]]; then
          LOG_FILE="$2"
          shift 2
        else
          log_message "ERROR" "Missing argument for --log"
          usage
        fi
        ;;
      --help)
        usage
        ;;
      *)
        if [ -z "$NETWORK" ]; then
          NETWORK="$1"
          shift
        else
          log_message "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

scan_network() {
  for IP in $(seq 1 254); do
    TARGET="$NETWORK.$IP"
    if ping -c 1 -W 1 "$TARGET" &> /dev/null; then
      TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
      log_message "INFO" "$TIMESTAMP: $TARGET is active"
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

  print_with_separator "Active Host Scanner Script"
  log_message "INFO" "Starting Active Host Scanner Script..."

  # Validate arguments
  if [ -z "$NETWORK" ]; then
    log_message "ERROR" "<network_prefix> is required."
    print_with_separator "End of Active Host Scanner Script"
    exit 1
  fi

  if ! [[ "$NETWORK" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    log_message "ERROR" "Invalid network prefix format: $NETWORK. Expected format: X.X.X (e.g., 192.168.1)"
    print_with_separator "End of Active Host Scanner Script"
    exit 1
  fi

  IFS='.' read -r A B C <<< "$NETWORK"
  if (( A < 0 || A > 255 || B < 0 || B > 255 || C < 0 || C > 255 )); then
    log_message "ERROR" "Network prefix out of range: $NETWORK. Each octet must be between 0 and 255."
    print_with_separator "End of Active Host Scanner Script"
    exit 1
  fi

  log_message "INFO" "Scanning network $NETWORK.0/24 for active hosts..."

  scan_network

  print_with_separator "End of Active Host Scanner Script"
}

main "$@"