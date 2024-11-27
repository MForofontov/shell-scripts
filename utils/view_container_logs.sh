#!/bin/bash
# view_container_logs.sh
# Script to view logs of a specified Docker container

# Check if a container name is provided
if [ -z "$1" ]; then
  echo "Usage: ./view_container_logs.sh <container_name>"
  exit 1
fi

# View logs of the specified container
echo "Viewing logs of container: $1"
docker logs $1
