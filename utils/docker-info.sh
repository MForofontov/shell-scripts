#!/bin/bash
# docker-info.sh
# Script to show detailed information about Docker containers, images, volumes, and networks

echo "Docker Containers:"
docker ps -a
echo

echo "Docker Images:"
docker images
echo

echo "Docker Volumes:"
docker volume ls
echo

echo "Docker Networks:"
docker network ls
echo

echo "Docker System Information:"
docker system df
echo

echo "Docker Version:"
docker --version
echo

echo "Docker Info:"
docker info
echo