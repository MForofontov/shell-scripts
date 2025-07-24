#!/bin/bash
# inspect-resource-docker.sh
# Script to inspect Docker resources (containers, networks, volumes).

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
RESOURCE_TYPE=""
RESOURCE_NAME=""
LOG_FILE="/dev/null"

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
        if [ -z "$RESOURCE_TYPE" ]; then
          RESOURCE_TYPE="$1"
        elif [ -z "$RESOURCE_NAME" ]; then
          RESOURCE_NAME="$1"
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        shift
        ;;
    esac
  done
}

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

inspect_resource() {
  format-echo "INFO" "Inspecting $RESOURCE_TYPE: $RESOURCE_NAME"
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
      format-echo "ERROR" "Invalid resource type. Use 'container', 'network', or 'volume'."
      exit 1
      ;;
  esac
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

  print_with_separator "Docker Resource Inspection Script"
  format-echo "INFO" "Starting Docker Resource Inspection Script..."

  # Validate required arguments
  if [ -z "$RESOURCE_TYPE" ] || [ -z "$RESOURCE_NAME" ]; then
    format-echo "ERROR" "Both <resource_type> and <resource_name> are required."
    print_with_separator "End of Docker Resource Inspection Script"
    usage
  fi

  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    format-echo "ERROR" "Docker is not installed. Please install Docker first."
    print_with_separator "End of Docker Resource Inspection Script"
    exit 1
  fi

  # Check if the resource exists
  if ! check_resource_exists "$RESOURCE_TYPE" "$RESOURCE_NAME"; then
    format-echo "ERROR" "$RESOURCE_TYPE '$RESOURCE_NAME' does not exist."
    print_with_separator "End of Docker Resource Inspection Script"
    exit 1
  fi

  inspect_resource

  print_with_separator "End of Docker Resource Inspection Script"
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    format-echo "SUCCESS" "Docker resource inspection results have been written to $LOG_FILE."
  else
    format-echo "INFO" "Docker resource inspection results displayed on the console."
  fi
}

main "$@"
