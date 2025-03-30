#!/bin/bash
# docker-info.sh
# Script to show detailed information about Docker containers, images, volumes, and networks

# Function to display usage instructions
usage() {
    echo "Usage: $0 [output_file]"
    echo "Example: $0 docker_info.log"
    exit 1
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "Error: Docker is not running. Please start Docker first."
    exit 1
fi

# Check if an output file is provided
OUTPUT_FILE=""
if [ "$#" -eq 1 ]; then
    OUTPUT_FILE="$1"
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
        echo "Error: Cannot write to output file $OUTPUT_FILE"
        exit 1
    fi
    exec > "$OUTPUT_FILE" 2>&1
    echo "Writing Docker information to $OUTPUT_FILE"
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    echo "$MESSAGE"
}

# Display Docker information
log_message "Docker Containers:"
docker ps -a
echo

log_message "Docker Images:"
docker images
echo

log_message "Docker Volumes:"
docker volume ls
echo

log_message "Docker Networks:"
docker network ls
echo

log_message "Docker System Information:"
docker system df
echo

log_message "Docker Version:"
docker --version
echo

log_message "Docker Info:"
docker info
echo

if [ -n "$OUTPUT_FILE" ]; then
    log_message "Docker information has been written to $OUTPUT_FILE"
else
    log_message "Docker information displayed on the console"
fi