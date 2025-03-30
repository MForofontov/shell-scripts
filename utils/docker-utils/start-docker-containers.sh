#!/bin/bash
# start-docker-containers.sh
# Starts multiple Docker containers in detached mode

# Function to display usage instructions
usage() {
    echo "Usage: $0 <container1> [<container2> ... <containerN>] [log_file]"
    echo "Example: $0 container1 container2 start_containers.log"
    exit 1
}

# Check if at least one container name is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the log file if provided
LOG_FILE=""
if [[ "${!#}" == *.log ]]; then
    LOG_FILE="${!#}"
    CONTAINERS=("${@:1:$#-1}")
else
    CONTAINERS=("$@")
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

# Start containers
STARTED_CONTAINERS=()
for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        log_message "Starting $container..."
        if docker start "$container" &> /dev/null; then
            log_message "$container started successfully."
            STARTED_CONTAINERS+=("$container")
        else
            log_message "Error: Failed to start $container."
        fi
    else
        log_message "Error: Container '$container' does not exist."
    fi
done

# Display summary
if [ "${#STARTED_CONTAINERS[@]}" -gt 0 ]; then
    log_message "Successfully started containers: ${STARTED_CONTAINERS[*]}"
else
    log_message "No containers were started."
fi