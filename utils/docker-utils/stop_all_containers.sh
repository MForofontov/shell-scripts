#!/bin/bash
# stop_all_containers.sh
# Script to stop all running Docker containers

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 stop_containers.log"
    exit 1
}

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -gt 1 ]; then
    usage
elif [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
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

# Check if Docker is running
if ! docker info &> /dev/null; then
    log_message "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Get the list of running containers
RUNNING_CONTAINERS=$(docker ps -q)

if [ -z "$RUNNING_CONTAINERS" ]; then
    log_message "No running containers found."
    exit 0
fi

# Display confirmation prompt
log_message "The following containers will be stopped:"
docker ps --format "table {{.ID}}\t{{.Names}}" | tee -a "$LOG_FILE"
read -p "Are you sure you want to stop all running containers? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    log_message "Operation canceled."
    exit 0
fi

# Stop all running containers
log_message "Stopping all running containers..."
STOPPED_CONTAINERS=$(docker stop $RUNNING_CONTAINERS)
if [ $? -eq 0 ]; then
    log_message "Stopped containers: $STOPPED_CONTAINERS"
else
    log_message "Error: Failed to stop some containers."
    exit 1
fi

log_message "All running containers have been stopped."