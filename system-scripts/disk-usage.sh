#!/bin/bash
# disk-usage.sh
# Script to check disk usage and alert if it exceeds a threshold

# Configuration
THRESHOLD=80                # Usage percentage threshold for alert
EMAIL="your-email@example.com"  # Email address for alert

# Get disk usage percentage for the root filesystem
USAGE=$(df / | grep / | awk '{ print $5 }' | sed 's/%//g')

# Check if disk usage exceeds the threshold
if [ "$USAGE" -ge "$THRESHOLD" ]; then
    # Send an email alert if usage exceeds the threshold
    echo "Disk usage is at ${USAGE}% - exceeds the threshold of ${THRESHOLD}%" | mail -s "Disk Usage Alert" "$EMAIL"
fi
