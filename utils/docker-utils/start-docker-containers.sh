#!/bin/bash
# start-docker-containers.sh
# Script to start multiple Docker containers in detached mode.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
LOG_FILE="/dev/null"
CONTAINERS=()

usage() {
  print_with_separator "Start Docker Containers Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script starts multiple Docker containers in detached mode."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <container1> [<container2> ... <containerN>] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<container1> ... <containerN>\033[0m   (Required) Names of the Docker containers to start."
  echo -e "  \033[1;33m--log <log_file>\033[0m                (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                          (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 container1 container2 --log start_containers.log"
  echo "  $0 container1 container2"
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
        CONTAINERS+=("$1")
        shift
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

  print_with_separator "Start Docker Containers Script"
  format-echo "INFO" "Starting Start Docker Containers Script..."

  # Validate required arguments
  if [ "${#CONTAINERS[@]}" -eq 0 ]; then
    format-echo "ERROR" "At least one container name is required."
    print_with_separator "End of Start Docker Containers Script"
    usage
  fi

  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    format-echo "ERROR" "Docker is not installed. Please install Docker first."
    print_with_separator "End of Start Docker Containers Script"
    exit 1
  fi

  # Check if Docker is running
  if ! docker info &> /dev/null; then
    format-echo "ERROR" "Docker is not running. Please start Docker first."
    print_with_separator "End of Start Docker Containers Script"
    exit 1
  fi

  # Start containers
  STARTED_CONTAINERS=()
  for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
      format-echo "INFO" "Starting container: $container..."
      if docker start "$container" &> /dev/null; then
        format-echo "SUCCESS" "Container '$container' started successfully."
        STARTED_CONTAINERS+=("$container")
      else
        format-echo "ERROR" "Failed to start container '$container'."
      fi
    else
      format-echo "ERROR" "Container '$container' does not exist."
    fi
  done

  # Display summary
  if [ "${#STARTED_CONTAINERS[@]}" -gt 0 ]; then
    format-echo "SUCCESS" "Successfully started containers: ${STARTED_CONTAINERS[*]}"
  else
    format-echo "INFO" "No containers were started."
  fi

  print_with_separator "End of Start Docker Containers Script"
  format-echo "SUCCESS" "Docker container startup process completed."
}

main "$@"
