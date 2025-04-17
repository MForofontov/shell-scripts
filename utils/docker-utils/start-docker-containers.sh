#!/bin/bash
# start-docker-containers.sh
# Starts multiple Docker containers in detached mode.

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

# Default values
LOG_FILE="/dev/null"
CONTAINERS=()

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
      CONTAINERS+=("$1")
      shift
      ;;
  esac
done

# Validate required arguments
if [ "${#CONTAINERS[@]}" -eq 0 ]; then
  log_message "ERROR" "At least one container name is required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Starting Docker containers: ${CONTAINERS[*]}"
print_with_separator "Start Docker Containers"

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

# Start containers
STARTED_CONTAINERS=()
for container in "${CONTAINERS[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
    log_message "INFO" "Starting container: $container..."
    if docker start "$container" &> /dev/null; then
      log_message "SUCCESS" "Container '$container' started successfully."
      STARTED_CONTAINERS+=("$container")
    else
      log_message "ERROR" "Failed to start container '$container'."
    fi
  else
    log_message "ERROR" "Container '$container' does not exist."
  fi
done

# Display summary
if [ "${#STARTED_CONTAINERS[@]}" -gt 0 ]; then
  log_message "SUCCESS" "Successfully started containers: ${STARTED_CONTAINERS[*]}"
else
  log_message "INFO" "No containers were started."
fi

# Notify user
print_with_separator "End of Start Docker Containers"
log_message "SUCCESS" "Docker container startup process completed."