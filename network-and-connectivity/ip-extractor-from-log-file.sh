#!/bin/bash
# ip-extractor-from-log-file.sh
# Script to extract unique IP addresses from a log file

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

INPUT_LOG=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "IP Extractor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script extracts unique IP addresses from a log file."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <input_log> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<input_log>\033[0m         (Required) Path to the input log file."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/inputlog.log --log extracted_ips.txt"
  echo "  $0 /path/to/inputlog.log"
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
        if [ -z "$INPUT_LOG" ]; then
          INPUT_LOG="$1"
          shift
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

extract_ips() {
  if ! grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$INPUT_LOG" | sort -u; then
    format-echo "ERROR" "Failed to extract IP addresses."
    return 1
  fi
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

  print_with_separator "IP Extractor Script"
  format-echo "INFO" "Starting IP Extractor Script..."

  # Validate input log file
  if [ -z "$INPUT_LOG" ]; then
    format-echo "ERROR" "Input log file is required."
    print_with_separator "End of IP Extractor Script"
    usage
  fi

  if [ ! -f "$INPUT_LOG" ]; then
    format-echo "ERROR" "Input log file $INPUT_LOG does not exist."
    print_with_separator "End of IP Extractor Script"
    exit 1
  fi

  format-echo "INFO" "Extracting unique IP addresses from $INPUT_LOG..."

  if extract_ips; then
    format-echo "SUCCESS" "IP extraction completed successfully."
  else
    format-echo "ERROR" "IP extraction failed."
    print_with_separator "End of IP Extractor Script"
    exit 1
  fi

  print_with_separator "End of IP Extractor Script"
}

main "$@"