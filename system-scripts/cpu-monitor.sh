#!/bin/bash
# cpu-monitor.sh
# Script to monitor CPU usage and alert if it exceeds a threshold

# Function to display usage instructions
usage() {
    echo "Usage: $0 <threshold> <email> [log_file]"
    echo "Example: $0 80 user@example.com custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

# Get the threshold, email address, and log file from the arguments
THRESHOLD="$1"
EMAIL="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
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

# Get current CPU usage percentage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Check if CPU usage exceeds the threshold
if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l) )); then
    # Send an email alert
    ALERT_MESSAGE="CPU usage is at ${CPU_USAGE}% - exceeds the threshold of ${THRESHOLD}%"
    echo "$ALERT_MESSAGE" | mail -s "CPU Usage Alert" "$EMAIL"
    log_message "$ALERT_MESSAGE"
else
    log_message "CPU usage is at ${CPU_USAGE}%, below the threshold of ${THRESHOLD}%."
fi