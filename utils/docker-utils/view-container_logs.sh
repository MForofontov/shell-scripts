#!/bin/bash
# view_container_logs.sh
# Script to view logs of a specified Docker container with additional options.

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

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

CONTAINER_NAME=""
FOLLOW=""
SINCE=""
UNTIL=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "View Docker Container Logs Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script views logs of a specified Docker container with additional options."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <container_name> [--follow] [--since <time>] [--until <time>] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<container_name>\033[0m   (Required) Name of the Docker container."
  echo -e "  \033[1;33m--follow\033[0m           (Optional) Follow logs in real-time."
  echo -e "  \033[1;33m--since <time>\033[0m     (Optional) Show logs since a specific time (e.g., '10m' for 10 minutes ago)."
  echo -e "  \033[1;33m--until <time>\033[0m     (Optional) Show logs until a specific time."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 my_container --follow"
  echo "  $0 my_container --since 1h --until 10m --log logs.txt"
  print_with_separator
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --follow)
        FOLLOW="-f"
        shift
        ;;
      --since)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No time provided after --since."
          usage
        fi
        SINCE="--since $2"
        shift 2
        ;;
      --until)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No time provided after --until."
          usage
        fi
        UNTIL="--until $2"
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
        if [ -z "$CONTAINER_NAME" ]; then
          CONTAINER_NAME="$1"
          shift
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
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

  print_with_separator "View Docker Container Logs Script"
  format-echo "INFO" "Starting View Docker Container Logs Script..."

  # Validate required arguments
  if [ -z "$CONTAINER_NAME" ]; then
    format-echo "ERROR" "The <container_name> argument is required."
    print_with_separator "End of View Docker Container Logs Script"
    usage
  fi

  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    format-echo "ERROR" "Docker is not installed. Please install Docker first."
    print_with_separator "End of View Docker Container Logs Script"
    exit 1
  fi

  # Check if the container exists
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    format-echo "ERROR" "Container '$CONTAINER_NAME' does not exist."
    print_with_separator "End of View Docker Container Logs Script"
    exit 1
  fi

  format-echo "INFO" "Viewing logs for container: $CONTAINER_NAME"
  format-echo "INFO" "Executing: docker logs $FOLLOW $SINCE $UNTIL $CONTAINER_NAME"
  docker logs $FOLLOW $SINCE $UNTIL "$CONTAINER_NAME"

  print_with_separator "End of View Docker Container Logs Script"
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    format-echo "SUCCESS" "Logs for container '$CONTAINER_NAME' have been written to $LOG_FILE."
  else
    format-echo "INFO" "Logs for container '$CONTAINER_NAME' displayed on the console."
  fi
}

main "$@"
