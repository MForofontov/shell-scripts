#!/bin/bash
# monitor-network.sh
# Script to monitor network traffic on a specified interface.

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

INTERFACE=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Network Monitor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script monitors network traffic on a specified interface."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <interface> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<interface>\033[0m       (Required) Network interface to monitor (e.g., eth0)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 eth0 --log network_traffic.log"
  echo "  $0 wlan0"
  print_with_separator "End of Network Monitor Script"
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          log_message "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        if [ -z "$INTERFACE" ]; then
          INTERFACE="$1"
          shift
        else
          log_message "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

monitor_network() {
  log_message "INFO" "Starting network traffic monitoring on interface $INTERFACE..."
  log_message "INFO" "Press Ctrl+C to stop monitoring."
  tcpdump -i "$INTERFACE"
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

  print_with_separator "Network Monitor Script"
  log_message "INFO" "Starting Network Monitor Script..."

  # Validate required arguments
  if [ -z "$INTERFACE" ]; then
    log_message "ERROR" "Network interface is required."
    print_with_separator "End of Network Monitor Script"
    usage
  fi

  if ! command -v tcpdump &> /dev/null; then
    log_message "ERROR" "tcpdump is not installed. Please install it and try again."
    print_with_separator "End of Network Monitor Script"
    exit 1
  fi

  if ! ip link show "$INTERFACE" &> /dev/null; then
    log_message "ERROR" "Network interface $INTERFACE does not exist."
    print_with_separator "End of Network Monitor Script"
    exit 1
  fi

  monitor_network

  print_with_separator "End of Network Monitor Script"
  log_message "INFO" "Network traffic monitoring completed."
}

main "$@"