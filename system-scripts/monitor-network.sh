#!/bin/bash
# monitor-network.sh
# Script to monitor network traffic on a specified interface

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <interface> <log_file>"
    exit 1
fi

# Get the network interface and log file from the arguments
INTERFACE="$1"
LOG_FILE="$2"

# Monitor network traffic
tcpdump -i "$INTERFACE" -w "$LOG_FILE"

# Notify user
echo "Network traffic is being monitored on interface $INTERFACE. Logs saved to $LOG_FILE."