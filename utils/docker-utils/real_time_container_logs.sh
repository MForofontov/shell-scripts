#!/bin/bash
# real_time_container_logs.sh
# Script to follow logs of a specified Docker container in real-time

# Function to display usage instructions
usage() {
    echo "Usage: $0 <container_name> [log_file]"
    echo "Example: $0 my_container logs.txt"
    exit 1
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the container name and optional log file
CONTAINER_NAME="$1"
LOG_FILE=""

if [ "$#" -eq 2 ]; then
    LOG_FILE="$2"
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

# Check if the container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_message "Error: Container '$CONTAINER_NAME' does not exist."
    exit 1
fi

# Check if the container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_message "Error: Container '$CONTAINER_NAME' is not running."
    exit 1
fi

# Follow logs of the specified container
log_message "Following logs of container: $CONTAINER_NAME"
if [ -n "$LOG_FILE" ]; then
    docker logs -f "$CONTAINER_NAME" | tee -a "$LOG_FILE"
else
    docker logs -f "$CONTAINER_NAME"
fi