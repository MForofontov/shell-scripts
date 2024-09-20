#!/bin/bash
# check-network.sh
# Script to check network connectivity to a specific host

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <host>"
    exit 1
fi

# Get the host from the argument
HOST="$1"

# Check network connectivity
ping -c 4 "$HOST" > /dev/null

if [ $? -eq 0 ]; then
    echo "Network connectivity to $HOST is working."
else
    echo "Network connectivity to $HOST failed."
fi