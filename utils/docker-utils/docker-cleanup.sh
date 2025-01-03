#!/bin/bash
# docker-cleanup.sh
# Script to clean up all Docker containers, images, volumes, and networks

# Confirm before proceeding
read -p "This will delete ALL Docker containers, images, volumes, and networks. Are you sure? (Y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cleanup canceled."
    exit 1
fi

# Stop all running containers
echo "Stopping all running containers..."
docker stop $(docker ps -q) 2>/dev/null

# Remove all containers
echo "Removing all containers..."
docker rm $(docker ps -aq) 2>/dev/null

# Remove all images
echo "Removing all images..."
docker rmi $(docker images -q) -f 2>/dev/null

# Remove all volumes
echo "Removing all volumes..."
docker volume rm $(docker volume ls -q) 2>/dev/null

# Remove all networks
echo "Removing all networks..."
docker network rm $(docker network ls -q) 2>/dev/null

# Prune all unused resources (containers, images, volumes, networks)
echo "Pruning all unused resources..."
docker system prune -a --volumes -f

# Notify user that cleanup is complete
echo "Docker cleanup complete."