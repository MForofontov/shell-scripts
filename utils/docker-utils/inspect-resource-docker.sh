#!/bin/bash
# inspect-resource.sh
# Script to inspect Docker resources (containers, networks, volumes)

# Check if a resource type and name are provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./inspect_resource.sh <resource_type> <resource_name>"
  echo "Resource types: container, network, volume"
  exit 1
fi

# Inspect the resource
case "$1" in
  container)
    echo "Inspecting container: $2"
    docker inspect $2
    ;;
  network)
    echo "Inspecting network: $2"
    docker network inspect $2
    ;;
  volume)
    echo "Inspecting volume: $2"
    docker volume inspect $2
    ;;
  *)
    echo "Invalid resource type. Use 'container', 'network', or 'volume'."
    exit 1
    ;;
esac