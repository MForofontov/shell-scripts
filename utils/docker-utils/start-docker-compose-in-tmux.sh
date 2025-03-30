#!/bin/bash
# start-docker-compose-tmux.sh
# Script to start Docker Compose in a new tmux session

# Function to display usage instructions
usage() {
    echo "Usage: $0 <docker_compose_dir> <tmux_session_name> [log_file]"
    echo "Example: $0 /path/to/docker-compose my_session docker_compose.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

# Get the Docker Compose directory, tmux session name, and optional log file
DOCKER_COMPOSE_DIR="$1"
SESSION_NAME="$2"
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

# Check if required commands are available
if ! command -v tmux &> /dev/null; then
    log_message "Error: tmux is not installed. Please install tmux first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    log_message "Error: docker-compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check if the directory exists
if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
    log_message "Error: Directory $DOCKER_COMPOSE_DIR does not exist."
    exit 1
fi

# Check if the tmux session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log_message "Tmux session '$SESSION_NAME' already exists."
    read -p "Do you want to attach to the existing session? (y/n) " ATTACH_EXISTING
    if [ "$ATTACH_EXISTING" = "y" ]; then
        tmux attach-session -t "$SESSION_NAME"
        exit 0
    else
        log_message "Exiting without attaching to the existing session."
        exit 0
    fi
fi

# Create a new tmux session and start Docker Compose
log_message "Starting Docker Compose in tmux session '$SESSION_NAME'..."
tmux new-session -d -s "$SESSION_NAME" -c "$DOCKER_COMPOSE_DIR" "docker-compose up"

if [ $? -eq 0 ]; then
    log_message "Docker Compose started in tmux session '$SESSION_NAME'."
else
    log_message "Error: Failed to start Docker Compose in tmux session."
    exit 1
fi

# Optionally, attach to the tmux session
read -p "Do you want to attach to the tmux session? (y/n) " ATTACH
if [ "$ATTACH" = "y" ]; then
    tmux attach-session -t "$SESSION_NAME"
fi