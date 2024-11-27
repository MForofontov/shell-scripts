#!/bin/bash
# real_time_container_logs.sh
# Script to follow logs of a specified Docker container in real-time

# Check if a container name is provided
if [ -z "$1" ]; then
  echo "Usage: ./real_time_container_logs.sh <container_name>"
  exit 1
fi

# Follow logs of the specified container
echo "Following logs of container: $1"
docker logs -f $1
