#!/bin/bash
# docker-info.sh
# Script to show detailed information about Docker containers, images, volumes, and networks.

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

log_message "INFO" "Starting Docker information retrieval..."
print_with_separator "Docker Information"

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

# Display Docker information
log_message "INFO" "Docker Containers:"
docker ps -a
echo

log_message "INFO" "Docker Images:"
docker images
echo

log_message "INFO" "Docker Volumes:"
docker volume ls
echo

log_message "INFO" "Docker Networks:"
docker network ls
echo

log_message "INFO" "Docker System Information:"
docker system df
echo

log_message "INFO" "Docker Version:"
docker --version
echo

log_message "INFO" "Docker Info:"
docker info
echo

# Notify user
print_with_separator "End of Docker Information"
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  log_message "SUCCESS" "Docker information has been written to $LOG_FILE."
else
  log_message "INFO" "Docker information displayed on the console."
fi