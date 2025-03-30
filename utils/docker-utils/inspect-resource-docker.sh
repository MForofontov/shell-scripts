#!/bin/bash
# inspect-resource.sh
# Script to inspect Docker resources (containers, networks, volumes)

# Function to display usage instructions
usage() {
    echo "Usage: $0 <resource_type> <resource_name> [log_file]"
    echo "Resource types: container, network, volume"
    echo "Example: $0 container my_container inspect.log"
    exit 1
}

# Check if at least two arguments are provided
if [ "$#" -lt 2 ]; then
    usage
fi

# Get the resource type, resource name, and optional log file
RESOURCE_TYPE="$1"
RESOURCE_NAME="$2"
LOG_FILE=""

if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    if [ -n "$LOG_FILE" ]; then
        echo "$MESSAGE" | tee -a "$LOG_FILE"
    else
        echo "$MESSAGE"
    fi
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_message "Error: Docker is not installed. Please install Docker first."
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
    log_message "Error: $RESOURCE_TYPE '$RESOURCE_NAME' does not exist."
    exit 1
fi

# Inspect the resource
log_message "Inspecting $RESOURCE_TYPE: $RESOURCE_NAME"
case "$RESOURCE_TYPE" in
    container)
        docker inspect "$RESOURCE_NAME" | tee -a "$LOG_FILE"
        ;;
    network)
        docker network inspect "$RESOURCE_NAME" | tee -a "$LOG_FILE"
        ;;
    volume)
        docker volume inspect "$RESOURCE_NAME" | tee -a "$LOG_FILE"
        ;;
    *)
        log_message "Invalid resource type. Use 'container', 'network', or 'volume'."
        exit 1
        ;;
esac