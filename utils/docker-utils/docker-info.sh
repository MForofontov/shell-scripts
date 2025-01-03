#!/bin/bash
# docker-info.sh
# Script to show detailed information about Docker containers, images, volumes, and networks

# Check if an output file is provided
if [ "$#" -eq 1 ]; then
    OUTPUT_FILE="$1"
    exec > "$OUTPUT_FILE" 2>&1
    echo "Writing Docker information to $OUTPUT_FILE"
else
    OUTPUT_FILE=""
fi

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

if [ -n "$OUTPUT_FILE" ]; then
    echo "Docker information has been written to $OUTPUT_FILE"
else
    echo "Docker information displayed on the console"
fi
