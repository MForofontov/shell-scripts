#!/bin/bash
# cpu-monitor.sh
# Script to monitor CPU usage and alert if it exceeds a threshold

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <threshold> <email>"
    exit 1
fi

# Get the threshold and email address from the arguments
THRESHOLD="$1"
EMAIL="$2"

# Get current CPU usage percentage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Check if CPU usage exceeds the threshold
if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l) )); then
    # Send an email alert
    echo "CPU usage is at ${CPU_USAGE}% - exceeds the threshold of ${THRESHOLD}%" | mail -s "CPU Usage Alert" "$EMAIL"
fi