#!/bin/bash
# monitor-resources.sh
# Script to monitor system resources (CPU, memory, disk) and log the usage

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -gt 1 ]; then
    usage
fi

# Get the log file from the arguments
LOG_FILE=""

# Check if a log file is provided as an argument
if [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    if [ -n "$MESSAGE" ]; then
        if [ -n "$LOG_FILE" ]; then
            echo "$MESSAGE" | tee -a "$LOG_FILE"
        else
            echo "$MESSAGE"
        fi
    fi
}

# Monitor CPU usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
log_message "CPU Usage: $CPU_USAGE%"

# Monitor memory usage
MEMORY_USAGE=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2 }')
log_message "Memory Usage: $MEMORY_USAGE%"

# Monitor disk usage
DISK_USAGE=$(df -h | awk '$NF=="/"{printf "%s", $5}')
log_message "Disk Usage: $DISK_USAGE"

# Notify user
log_message "Resource monitoring completed."