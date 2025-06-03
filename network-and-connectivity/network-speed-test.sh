#!/bin/bash
# network-speed-test.sh
# Script to run a network speed test using speedtest-cli

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

LOG_FILE="/dev/null"

usage() {
  print_with_separator "Network Speed Test Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script runs a network speed test using speedtest-cli."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the speed test results."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_log.log"
  echo "  $0"
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
          format-echo "ERROR" "Missing argument for --log"
          usage
        fi
        ;;
      --help)
        usage
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

check_speedtest_cli() {
  if ! command -v speedtest-cli &> /dev/null; then
    format-echo "INFO" "speedtest-cli is not installed. Installing..."
    if [[ "$(uname)" == "Linux" ]]; then
      if ! sudo apt-get install -y speedtest-cli; then
        format-echo "ERROR" "Failed to install speedtest-cli."
        exit 1
      fi
    elif [[ "$(uname)" == "Darwin" ]]; then
      if ! brew install speedtest-cli; then
        format-echo "ERROR" "Failed to install speedtest-cli."
        exit 1
      fi
    else
      format-echo "ERROR" "Unsupported operating system: $(uname)"
      exit 1
    fi
  fi
}

run_speed_test() {
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  format-echo "INFO" "$TIMESTAMP: Running network speed test..."
  if ! speedtest-cli; then
    format-echo "ERROR" "Failed to run network speed test."
    return 1
  fi
  format-echo "INFO" "$TIMESTAMP: Network speed test completed."
  return 0
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

  print_with_separator "Network Speed Test Script"
  format-echo "INFO" "Starting Network Speed Test Script..."

  check_speedtest_cli

  if run_speed_test; then
    format-echo "SUCCESS" "Network speed test complete."
  else
    format-echo "ERROR" "Failed to run network speed test."
    print_with_separator "End of Network Speed Test Script"
    exit 1
  fi

  print_with_separator "End of Network Speed Test Script"
}

main "$@"