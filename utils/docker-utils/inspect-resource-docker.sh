#!/bin/bash
# inspect-resource-docker.sh
# Script to inspect Docker resources (containers, networks, volumes).

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
  print_with_separator "Docker Resource Inspection Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script inspects Docker resources (containers, networks, volumes)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <resource_type> <resource_name> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<resource_type>\033[0m   (Required) Type of resource: container, network, or volume."
  echo -e "  \033[1;33m<resource_name>\033[0m   (Required) Name of the resource to inspect."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 container my_container --log inspect.log"
  echo "  $0 network my_network"
  print_with_separator
  exit 1
}

# Default values
RESOURCE_TYPE=""
RESOURCE_NAME=""
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
      if [ -z "$RESOURCE_TYPE" ]; then
        RESOURCE_TYPE="$1"
      elif [ -z "$RESOURCE_NAME" ]; then
        RESOURCE_NAME="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$RESOURCE_TYPE" ] || [ -z "$RESOURCE_NAME" ]; then
  log_message "ERROR" "Both <resource_type> and <resource_name> are required."
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

log_message "INFO" "Starting Docker resource inspection..."
print_with_separator "Docker Resource Inspection"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log_message "ERROR" "Docker is not installed. Please install Docker first."
  exit 1
fi

# Check if the resource exists
check_resource_exists() {
  local type=$1
  local name=$2
  case "$type" in
    container)
      docker ps -a --format '{{.Names}}' | grep -q "^${name}$"
      ;;
    network)
      docker network ls --format '{{.Name}}' | grep -q "^${name}$"
      ;;
    volume)
      docker volume ls --format '{{.Name}}' | grep -q "^${name}$"
      ;;
    *)
      return 1
      ;;
  esac
}

if ! check_resource_exists "$RESOURCE_TYPE" "$RESOURCE_NAME"; then
  log_message "ERROR" "$RESOURCE_TYPE '$RESOURCE_NAME' does not exist."
  exit 1
fi

# Inspect the resource
log_message "INFO" "Inspecting $RESOURCE_TYPE: $RESOURCE_NAME"
case "$RESOURCE_TYPE" in
  container)
    docker inspect "$RESOURCE_NAME"
    ;;
  network)
    docker network inspect "$RESOURCE_NAME"
    ;;
  volume)
    docker volume inspect "$RESOURCE_NAME"
    ;;
  *)
    log_message "ERROR" "Invalid resource type. Use 'container', 'network', or 'volume'."
    exit 1
    ;;
esac

# Notify user
print_with_separator "End of Docker Resource Inspection"
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  log_message "SUCCESS" "Docker resource inspection results have been written to $LOG_FILE."
else
  log_message "INFO" "Docker resource inspection results displayed on the console."
fi