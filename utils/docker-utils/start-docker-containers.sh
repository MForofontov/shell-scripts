#!/bin/bash
# start-docker-containers.sh
# Starts multiple Docker containers in detached mode

# Check if at least one container name is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <container1> [<container2> ... <containerN>]"
    exit 1
fi

# Get the container names from the arguments
CONTAINERS=("$@")

for container in "${CONTAINERS[@]}"; do
    echo "Starting $container..."
    docker start "$container"
done

echo "All containers started."