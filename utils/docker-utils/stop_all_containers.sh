#!/bin/bash
# stop_all_containers.sh
# Script to stop all running Docker containers.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# LOG file path used by utility functions
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Stop All Docker Containers Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script stops all running Docker containers."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m           (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log stop_containers.log"
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

main() {
  parse_args "$@"

  setup_log_file

  print_with_separator "Stop All Docker Containers Script"
  format-echo "INFO" "Starting Stop All Docker Containers Script..."

  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    format-echo "ERROR" "Docker is not installed. Please install Docker first."
    print_with_separator "End of Stop All Docker Containers Script"
    exit 1
  fi

  # Check if Docker is running
  if ! docker info &> /dev/null; then
    format-echo "ERROR" "Docker is not running. Please start Docker first."
    print_with_separator "End of Stop All Docker Containers Script"
    exit 1
  fi

  # Get the list of running containers
  RUNNING_CONTAINERS=$(docker ps -q)

  if [ -z "$RUNNING_CONTAINERS" ]; then
    format-echo "INFO" "No running containers found."
    print_with_separator "End of Stop All Docker Containers Script"
    exit 0
  fi

  # Display confirmation prompt
  format-echo "INFO" "The following containers will be stopped:"
  docker ps --format "table {{.ID}}\t{{.Names}}"
  read -r -p "Are you sure you want to stop all running containers? (y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    format-echo "INFO" "Operation canceled."
    print_with_separator "End of Stop All Docker Containers Script"
    exit 0
  fi

  # Stop all running containers
  format-echo "INFO" "Stopping all running containers..."
  if STOPPED_CONTAINERS=$(docker stop "$RUNNING_CONTAINERS"); then
    format-echo "SUCCESS" "Stopped containers: $STOPPED_CONTAINERS"
  else
    format-echo "ERROR" "Failed to stop some containers."
    print_with_separator "End of Stop All Docker Containers Script"
    exit 1
  fi

  print_with_separator "End of Stop All Docker Containers Script"
  format-echo "SUCCESS" "All running containers have been stopped."
}

main "$@"
