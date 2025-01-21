#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/network-and-connectivity/active-host-scanner.sh
# active-host-scanner.sh
# Script to scan a network for active hosts

# Function to display usage instructions
usage() {
    echo "Usage: $0 <network_prefix> [log_file]"
    echo "Example: $0 192.168.1 custom_log.log"
    exit 1
}

# Check if the network prefix is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the network prefix and log file from the arguments
NETWORK=$1
LOG_FILE=""
if [ "$#" -ge 2 ]; then
    LOG_FILE="$2"
fi

# Validate network prefix
if ! [[ "$NETWORK" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid network prefix $NETWORK"
    usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

echo "Scanning network $NETWORK.0/24 for active hosts..."
if [ -n "$LOG_FILE" ]; then
    echo "Results logged in $LOG_FILE"
else
    echo "Results displayed on the console"
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

# Function to scan for active hosts
scan_network() {
    for IP in $(seq 1 254); do
        TARGET="$NETWORK.$IP"
        if ping -c 1 -W 1 $TARGET &> /dev/null; then
            TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
            log_message "$TIMESTAMP: $TARGET is active"
        fi
    done
}

# Scan network and handle errors
if ! scan_network; then
    log_message "Error: Failed to scan network $NETWORK.0/24."
    exit 1
fi

log_message "Network scan complete."