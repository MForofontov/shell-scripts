#!/bin/bash
# docker-info.sh
# Script to show detailed information about Docker containers, images, volumes, and networks.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
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

#=====================================================================
# DEFAULT VALUES
#=====================================================================
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Docker Info Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script shows detailed information about Docker containers, images, volumes, and networks."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log docker_info.log"
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

show_docker_info() {
  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    format-echo "ERROR" "Docker is not installed. Please install Docker first."
    print_with_separator "End of Docker Info Script"
    exit 1
  fi

  # Check if Docker is running
  if ! docker info &> /dev/null; then
    format-echo "ERROR" "Docker is not running. Please start Docker first."
    print_with_separator "End of Docker Info Script"
    exit 1
  fi

  format-echo "INFO" "Docker Containers:"
  docker ps -a
  echo

  format-echo "INFO" "Docker Images:"
  docker images
  echo

  format-echo "INFO" "Docker Volumes:"
  docker volume ls
  echo

  format-echo "INFO" "Docker Networks:"
  docker network ls
  echo

  format-echo "INFO" "Docker System Information:"
  docker system df
  echo

  format-echo "INFO" "Docker Version:"
  docker --version
  echo

  format-echo "INFO" "Docker Info:"
  docker info
  echo
}

main() {
  parse_args "$@"

  setup_log_file

  print_with_separator "Docker Info Script"
  format-echo "INFO" "Starting Docker Info Script..."

  show_docker_info

  print_with_separator "End of Docker Info Script"
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    format-echo "SUCCESS" "Docker information has been written to $LOG_FILE."
  else
    format-echo "INFO" "Docker information displayed on the console."
  fi
}

main "$@"
