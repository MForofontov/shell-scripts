#!/bin/bash
# monitor-resources.sh
# Script to monitor and log CPU and memory usage

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <log_file>"
    exit 1
fi

# Get the log file from the argument
LOG_FILE="$1"

# Record current date and time
echo "Resource usage at $(date)" >> "$LOG_FILE"

# Log CPU usage
echo "CPU Usage:" >> "$LOG_FILE"
top -bn1 | grep "Cpu(s)" >> "$LOG_FILE"

# Log memory usage
echo "Memory Usage:" >> "$LOG_FILE"
free -h >> "$LOG_FILE"

# Add a separator for readability
echo "--------------------------------------" >> "$LOG_FILE"