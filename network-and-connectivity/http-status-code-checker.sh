#!/bin/bash
# http-status-code-checker.sh
# Script to check HTTP status codes for a list of URLs

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

URLS=()
LOG_FILE="/dev/null"

usage() {
  print_with_separator "HTTP Status Code Checker Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks HTTP status codes for a list of URLs."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <url1> <url2> ... [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<url1> <url2> ...\033[0m  (Required) List of URLs to check."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 https://google.com https://github.com --log custom_log.log"
  echo "  $0 https://example.com"
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
        URLS+=("$1")
        shift
        ;;
    esac
  done
}

check_status_codes() {
  for URL in "${URLS[@]}"; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")
    if [[ "$STATUS_CODE" -ge 200 && "$STATUS_CODE" -lt 400 ]]; then
      log_message "INFO" "$TIMESTAMP: $URL: $STATUS_CODE (Success)"
    else
      log_message "ERROR" "$TIMESTAMP: $URL: $STATUS_CODE (Error)"
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

  print_with_separator "HTTP Status Code Checker Script"
  log_message "INFO" "Starting HTTP Status Code Checker Script..."

  # Validate URLs
  if [ "${#URLS[@]}" -eq 0 ]; then
    log_message "ERROR" "At least one URL is required."
    print_with_separator "End of HTTP Status Code Checker Script"
    exit 1
  fi

  if check_status_codes; then
    log_message "SUCCESS" "HTTP status code check complete."
  else
    log_message "ERROR" "Failed to check HTTP status codes."
    print_with_separator "End of HTTP Status Code Checker Script"
    exit 1
  fi

  print_with_separator "End of HTTP Status Code Checker Script"
}

main "$@"