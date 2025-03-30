#!/bin/bash
# view_container_logs.sh
# Script to view logs of a specified Docker container with additional options

# Function to display usage instructions
usage() {
  echo "Usage: ./view_container_logs.sh <container_name> [--follow] [--since <time>] [--until <time>]"
  echo "Options:"
  echo "  --follow          Follow logs in real-time"
  echo "  --since <time>    Show logs since a specific time (e.g., '10m' for 10 minutes ago)"
  echo "  --until <time>    Show logs until a specific time"
  echo "Examples:"
  echo "  ./view_container_logs.sh my_container --follow"
  echo "  ./view_container_logs.sh my_container --since 1h --until 10m"
  exit 1
}

# Check if a container name is provided
if [ -z "$1" ]; then
  usage
fi

CONTAINER_NAME=$1
shift

# Check if the container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Error: Container '$CONTAINER_NAME' does not exist."
  exit 1
fi

# Parse additional options
FOLLOW=""
SINCE=""
UNTIL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --follow)
      FOLLOW="-f"
      shift
      ;;
    --since)
      SINCE="--since $2"
      shift 2
      ;;
    --until)
      UNTIL="--until $2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option '$1'"
      usage
      ;;
  esac
done

# View logs of the specified container with options
echo "Viewing logs of container: $CONTAINER_NAME"
docker logs $FOLLOW $SINCE $UNTIL $CONTAINER_NAME