#!/bin/bash
# docker-cleanup.sh
# Script to clean up all Docker containers, images, volumes, and networks.

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
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

# Default values
LOG_FILE="/dev/null"

# Parse input arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --log)
      if [ -z "$2" ]; then
        log_message "ERROR" "No log file provided after --log."
        usage
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      log_message "ERROR" "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Starting Docker cleanup..."
print_with_separator "Docker Cleanup"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log_message "ERROR" "Docker is not installed. Please install Docker first."
  exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
  log_message "ERROR" "Docker is not running. Please start Docker first."
  exit 1
fi

# Confirm before proceeding
read -p "This will delete ALL Docker containers, images, volumes, and networks. Are you sure? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  log_message "INFO" "Cleanup canceled."
  exit 0
fi

# Stop all running containers
RUNNING_CONTAINERS=$(docker ps -q)
if [ -n "$RUNNING_CONTAINERS" ]; then
  log_message "INFO" "Stopping all running containers..."
  docker stop $RUNNING_CONTAINERS
else
  log_message "INFO" "No running containers to stop."
fi

# Remove all containers
ALL_CONTAINERS=$(docker ps -aq)
if [ -n "$ALL_CONTAINERS" ]; then
  log_message "INFO" "Removing all containers..."
  docker rm $ALL_CONTAINERS
else
  log_message "INFO" "No containers to remove."
fi

# Remove all images
ALL_IMAGES=$(docker images -q)
if [ -n "$ALL_IMAGES" ]; then
  log_message "INFO" "Removing all images..."
  docker rmi $ALL_IMAGES -f
else
  log_message "INFO" "No images to remove."
fi

# Remove all volumes
ALL_VOLUMES=$(docker volume ls -q)
if [ -n "$ALL_VOLUMES" ]; then
  log_message "INFO" "Removing all volumes..."
  docker volume rm $ALL_VOLUMES
else
  log_message "INFO" "No volumes to remove."
fi

# Remove all networks
ALL_NETWORKS=$(docker network ls -q)
if [ -n "$ALL_NETWORKS" ]; then
  log_message "INFO" "Removing all networks..."
  docker network rm $ALL_NETWORKS
else
  log_message "INFO" "No networks to remove."
fi

# Prune all unused resources
log_message "INFO" "Pruning all unused resources..."
docker system prune -a --volumes -f

# Notify user that cleanup is complete
print_with_separator "End of Docker Cleanup"
log_message "SUCCESS" "Docker cleanup complete."