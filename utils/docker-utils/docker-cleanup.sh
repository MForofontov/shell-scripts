#!/bin/bash
# docker-cleanup.sh
# Script to clean up all Docker containers, images, volumes, and networks

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 cleanup.log"
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

# Confirm before proceeding
read -p "This will delete ALL Docker containers, images, volumes, and networks. Are you sure? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_message "Cleanup canceled."
    exit 0
fi

# Stop all running containers
RUNNING_CONTAINERS=$(docker ps -q)
if [ -n "$RUNNING_CONTAINERS" ]; then
    log_message "Stopping all running containers..."
    docker stop $RUNNING_CONTAINERS
else
    log_message "No running containers to stop."
fi

# Remove all containers
ALL_CONTAINERS=$(docker ps -aq)
if [ -n "$ALL_CONTAINERS" ]; then
    log_message "Removing all containers..."
    docker rm $ALL_CONTAINERS
else
    log_message "No containers to remove."
fi

# Remove all images
ALL_IMAGES=$(docker images -q)
if [ -n "$ALL_IMAGES" ]; then
    log_message "Removing all images..."
    docker rmi $ALL_IMAGES -f
else
    log_message "No images to remove."
fi

# Remove all volumes
ALL_VOLUMES=$(docker volume ls -q)
if [ -n "$ALL_VOLUMES" ]; then
    log_message "Removing all volumes..."
    docker volume rm $ALL_VOLUMES
else
    log_message "No volumes to remove."
fi

# Remove all networks
ALL_NETWORKS=$(docker network ls -q)
if [ -n "$ALL_NETWORKS" ]; then
    log_message "Removing all networks..."
    docker network rm $ALL_NETWORKS
else
    log_message "No networks to remove."
fi

# Prune all unused resources
log_message "Pruning all unused resources..."
docker system prune -a --volumes -f

# Notify user that cleanup is complete
log_message "Docker cleanup complete."