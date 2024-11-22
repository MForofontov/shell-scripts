#!/bin/bash
# start-docker-compose-tmux.sh
# Script to start Docker Compose in a new tmux session

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <docker_compose_dir> <tmux_session_name>"
    exit 1
fi

# Get the Docker Compose directory and tmux session name from the arguments
DOCKER_COMPOSE_DIR="$1"
SESSION_NAME="$2"

# Check if the directory exists
if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
    echo "Error: Directory $DOCKER_COMPOSE_DIR does not exist."
    exit 1
fi

# Create a new tmux session and start Docker Compose
tmux new-session -d -s "$SESSION_NAME" -c "$DOCKER_COMPOSE_DIR" "docker-compose up"

# Notify user
echo "Docker Compose started in tmux session '$SESSION_NAME'."

# Optionally, attach to the tmux session
read -p "Do you want to attach to the tmux session? (y/n) " ATTACH
if [ "$ATTACH" = "y" ]; then
    tmux attach-session -t "$SESSION_NAME"
fi
