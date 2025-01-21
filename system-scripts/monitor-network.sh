#!/bin/bash
# monitor-network.sh
# Script to monitor network traffic on a specified interface

# Function to display usage instructions
usage() {
    echo "Usage: $0 <interface> [log_file]"
    echo "Example: $0 eth0 custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

# Get the network interface and log file from the arguments
INTERFACE="$1"
LOG_FILE=""

# Check if a log file is provided as a second argument
if [ "$#" -eq 2 ]; then
    LOG_FILE="$2"
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

# Monitor network traffic
log_message "Monitoring network traffic on interface $INTERFACE..."
if [ -n "$LOG_FILE" ]; then
    tcpdump -i "$INTERFACE" -w "$LOG_FILE"
    log_message "Network traffic is being monitored on interface $INTERFACE. Logs saved to $LOG_FILE."
else
    tcpdump -i "$INTERFACE"
    log_message "Network traffic is being monitored on interface $INTERFACE."
fi