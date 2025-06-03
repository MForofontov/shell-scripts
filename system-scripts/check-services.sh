#!/bin/bash
# check-services.sh
# Script to check if a list of services are running.

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
SERVICES=("nginx" "apache2" "postgresql" "django" "react" "celery-worker") # Default services to check

usage() {
  print_with_separator "Check Services Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks if a list of services are running."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log services_check.log"
  echo "  $0"
  print_with_separator
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

is_running() {
  local service_name=$1
  local pid
  pid=$(pgrep -f "$service_name")
  if [ -n "$pid" ]; then
    format-echo "SUCCESS" "$service_name is running with PID(s): $pid"
    return 0
  else
    format-echo "ERROR" "$service_name is not running"
    return 1
  fi
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

  print_with_separator "Check Services Script"
  format-echo "INFO" "Starting Check Services Script..."

  for service in "${SERVICES[@]}"; do
    is_running "$service"
  done

  # Enhanced Celery worker check
  format-echo "INFO" "Checking for Celery workers using the Celery CLI..."
  if command -v celery > /dev/null; then
    if celery -A <app_name> status > /dev/null 2>&1; then
      format-echo "SUCCESS" "Celery workers are running."
    else
      format-echo "ERROR" "No Celery workers are running or unable to connect to the Celery application."
    fi
  else
    format-echo "WARNING" "Celery CLI is not installed. Falling back to process name check."
    if pgrep -f "celery" > /dev/null; then
      format-echo "SUCCESS" "Celery worker is running (detected by process name)."
    else
      format-echo "ERROR" "No Celery worker is running."
    fi
  fi

  print_with_separator "End of Check Services Script"
  format-echo "INFO" "Service checks completed."
}

main "$@"