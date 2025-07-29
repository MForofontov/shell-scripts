#!/bin/bash
# real_time_container_logs.sh
# Script to follow logs of a specified Docker container in real-time.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
CONTAINER_NAME=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Real-Time Docker Logs Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script follows logs of a specified Docker container in real-time."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <container_name> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<container_name>\033[0m  (Required) Name of the Docker container."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 my_container --log logs.txt"
  echo "  $0 my_container"
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

  setup_log_file

  print_with_separator "Real-Time Docker Logs Script"
  format-echo "INFO" "Starting Real-Time Docker Logs Script..."

  # Validate required arguments
  if [ -z "$CONTAINER_NAME" ]; then
    format-echo "ERROR" "The <container_name> argument is required."
    print_with_separator "End of Real-Time Docker Logs Script"
    usage
  fi

  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    format-echo "ERROR" "Docker is not installed. Please install Docker first."
    print_with_separator "End of Real-Time Docker Logs Script"
    exit 1
  fi

  # Check if the container exists
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    format-echo "ERROR" "Container '$CONTAINER_NAME' does not exist."
    print_with_separator "End of Real-Time Docker Logs Script"
    exit 1
  fi

  # Check if the container is running
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    format-echo "ERROR" "Container '$CONTAINER_NAME' is not running."
    print_with_separator "End of Real-Time Docker Logs Script"
    exit 1
  fi

  format-echo "INFO" "Following logs of container: $CONTAINER_NAME"
  docker logs -f "$CONTAINER_NAME"

  print_with_separator "End of Real-Time Docker Logs Script"
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    format-echo "SUCCESS" "Real-time logs have been written to $LOG_FILE."
  else
    format-echo "INFO" "Real-time logs displayed on the console."
  fi
}

main "$@"
exit $?
