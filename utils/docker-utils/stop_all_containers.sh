#!/bin/bash
# stop_all_containers.sh
# Script to stop all running Docker containers.

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

log_message "INFO" "Starting to stop all running Docker containers..."
print_with_separator "Stop All Docker Containers"

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

# Get the list of running containers
RUNNING_CONTAINERS=$(docker ps -q)

if [ -z "$RUNNING_CONTAINERS" ]; then
  log_message "INFO" "No running containers found."
  print_with_separator "End of Stop All Docker Containers"
  exit 0
fi

# Display confirmation prompt
log_message "INFO" "The following containers will be stopped:"
docker ps --format "table {{.ID}}\t{{.Names}}" | tee -a "$LOG_FILE"
read -p "Are you sure you want to stop all running containers? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  print_with_separator "End of Stop All Docker Containers"
  log_message "INFO" "Operation canceled."
  exit 0
fi

# Stop all running containers
log_message "INFO" "Stopping all running containers..."
STOPPED_CONTAINERS=$(docker stop $RUNNING_CONTAINERS)
if [ $? -eq 0 ]; then
  log_message "SUCCESS" "Stopped containers: $STOPPED_CONTAINERS"
else
  log_message "ERROR" "Failed to stop some containers."
  print_with_separator "End of Stop All Docker Containers"
  exit 1
fi

# Notify user
print_with_separator "End of Stop All Docker Containers"
log_message "SUCCESS" "All running containers have been stopped."