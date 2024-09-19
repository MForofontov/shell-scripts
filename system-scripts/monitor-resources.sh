#!/bin/bash
# monitor-resources.sh
# Script to monitor and log CPU and memory usage

# Configuration
LOG_FILE="/path/to/resource_log.txt"  # File to log resource usage

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
