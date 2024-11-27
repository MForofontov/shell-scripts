#!/bin/bash
# stop_all_containers.sh
# Script to stop all running Docker containers

# Stop all running containers
echo "Stopping all running containers..."
docker stop $(docker ps -q)