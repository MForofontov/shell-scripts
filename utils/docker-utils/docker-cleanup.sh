#!/bin/bash
# docker-cleanup.sh
# Script to clean up all Docker containers, images, volumes, and networks.

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
  print_with_separator "Docker Cleanup Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script cleans up all Docker containers, images, volumes, and networks."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log cleanup.log"
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

docker_cleanup() {
  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    format-echo "ERROR" "Docker is not installed. Please install Docker first."
    print_with_separator "End of Docker Cleanup Script"
    exit 1
  fi

  # Check if Docker is running
  if ! docker info &> /dev/null; then
    format-echo "ERROR" "Docker is not running. Please start Docker first."
    print_with_separator "End of Docker Cleanup Script"
    exit 1
  fi

  # Confirm before proceeding
  read -p "This will delete ALL Docker containers, images, volumes, and networks. Are you sure? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    format-echo "INFO" "Cleanup canceled."
    print_with_separator "End of Docker Cleanup Script"
    exit 0
  fi

  # Stop all running containers
  RUNNING_CONTAINERS=$(docker ps -q)
  if [ -n "$RUNNING_CONTAINERS" ]; then
    format-echo "INFO" "Stopping all running containers..."
    docker stop $RUNNING_CONTAINERS
  else
    format-echo "INFO" "No running containers to stop."
  fi

  # Remove all containers
  ALL_CONTAINERS=$(docker ps -aq)
  if [ -n "$ALL_CONTAINERS" ]; then
    format-echo "INFO" "Removing all containers..."
    docker rm $ALL_CONTAINERS
  else
    format-echo "INFO" "No containers to remove."
  fi

  # Remove all images
  ALL_IMAGES=$(docker images -q)
  if [ -n "$ALL_IMAGES" ]; then
    format-echo "INFO" "Removing all images..."
    docker rmi $ALL_IMAGES -f
  else
    format-echo "INFO" "No images to remove."
  fi

  # Remove all volumes
  ALL_VOLUMES=$(docker volume ls -q)
  if [ -n "$ALL_VOLUMES" ]; then
    format-echo "INFO" "Removing all volumes..."
    docker volume rm $ALL_VOLUMES
  else
    format-echo "INFO" "No volumes to remove."
  fi

  # Remove all networks
  ALL_NETWORKS=$(docker network ls -q)
  if [ -n "$ALL_NETWORKS" ]; then
    format-echo "INFO" "Removing all networks..."
    docker network rm $ALL_NETWORKS
  else
    format-echo "INFO" "No networks to remove."
  fi

  # Prune all unused resources
  format-echo "INFO" "Pruning all unused resources..."
  docker system prune -a --volumes -f

  format-echo "SUCCESS" "Docker cleanup complete."
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

  print_with_separator "Docker Cleanup Script"
  format-echo "INFO" "Starting Docker Cleanup Script..."

  docker_cleanup

  print_with_separator "End of Docker Cleanup Script"
  format-echo "SUCCESS" "Docker cleanup complete."
}

main "$@"
