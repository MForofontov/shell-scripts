#!/bin/bash
# disk-usage.sh
# Script to check disk usage and alert if it exceeds a threshold

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <threshold> <email>"
    exit 1
fi

# Get the threshold and email address from the arguments
THRESHOLD="$1"
EMAIL="$2"

# Get disk usage percentage for the root filesystem
USAGE=$(df / | grep / | awk '{ print $5 }' | sed 's/%//g')

# Check if disk usage exceeds the threshold
if [ "$USAGE" -ge "$THRESHOLD" ]; then
    # Send an email alert if usage exceeds the threshold
    echo "Disk usage is at ${USAGE}% - exceeds the threshold of ${THRESHOLD}%" | mail -s "Disk Usage Alert" "$EMAIL"
fi