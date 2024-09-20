#!/bin/bash
# docker-cleanup.sh
# Cleans up unused Docker containers, images, volumes, and networks

echo "Cleaning up unused Docker containers..."
docker container prune -f

echo "Cleaning up unused Docker images..."
docker image prune -a -f

echo "Cleaning up unused Docker volumes..."
docker volume prune -f

echo "Cleaning up unused Docker networks..."
docker network prune -f

echo "Docker cleanup completed."
