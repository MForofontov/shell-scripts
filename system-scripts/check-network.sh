#!/bin/bash
# check-network.sh
# Script to check network connectivity to a specific host

# Configuration
HOST="localhost"   # Host to ping

# Check network connectivity
ping -c 4 "$HOST" > /dev/null

if [ $? -eq 0 ]; then
    echo "Network connectivity to $HOST is working."
else
    echo "Network connectivity to $HOST failed."
fi
