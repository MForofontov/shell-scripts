#!/bin/bash
# bandwidth-monitor.sh
# Script to monitor bandwidth usage on a specified network interface

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
  print_with_separator "Bandwidth Monitor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script monitors bandwidth usage on a specified network interface."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <interface> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<interface>\033[0m       (Required) Network interface to monitor (e.g., eth0 or en0)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 eth0 --log custom_log.log"
  echo "  $0 en0"
  print_with_separator
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

monitor_bandwidth() {
  local RX_PREV=0
  local TX_PREV=0

  while true; do
    if [[ "$(uname)" == "Linux" ]]; then
      RX_CURRENT=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null)
      TX_CURRENT=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null)
    elif [[ "$(uname)" == "Darwin" ]]; then
      RX_CURRENT=$(netstat -ib | awk -v iface="$INTERFACE" '$1 == iface {print $7}' | head -n 1)
      TX_CURRENT=$(netstat -ib | awk -v iface="$INTERFACE" '$1 == iface {print $10}' | head -n 1)
    else
      log_message "ERROR" "Unsupported operating system: $(uname)"
      exit 1
    fi

    if ! [[ "$RX_CURRENT" =~ ^[0-9]+$ ]] || ! [[ "$TX_CURRENT" =~ ^[0-9]+$ ]]; then
      log_message "ERROR" "Failed to retrieve network statistics for interface $INTERFACE."
      exit 1
    fi

    RX_RATE=$((RX_CURRENT - RX_PREV))
    TX_RATE=$((TX_CURRENT - TX_PREV))

    RX_PREV=$RX_CURRENT
    TX_PREV=$TX_CURRENT

    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    log_message "INFO" "$TIMESTAMP: Download: $((RX_RATE / 1024)) KB/s, Upload: $((TX_RATE / 1024)) KB/s"

    sleep 1
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

  print_with_separator "Bandwidth Monitor Script"
  log_message "INFO" "Starting Bandwidth Monitor Script..."

  if [ -z "$INTERFACE" ]; then
    log_message "ERROR" "<interface> is required."
    print_with_separator "End of Bandwidth Monitor Script"
    exit 1
  fi

  log_message "INFO" "Monitoring bandwidth usage on interface $INTERFACE..."
  log_message "INFO" "Press Ctrl+C to stop."

  monitor_bandwidth

  print_with_separator "End of Bandwidth Monitor Script"
}

main "$@"