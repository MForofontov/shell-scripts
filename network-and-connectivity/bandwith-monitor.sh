#!/bin/bash
# bandwidth-monitor.sh
# Script to monitor bandwidth usage on a specified network interface

# Function to display usage instructions
usage() {
    echo "Usage: $0 <interface> [log_file]"
    echo "Example: $0 eth0 custom_log.log"
    exit 1
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the network interface and log file from the arguments
INTERFACE=$1
LOG_FILE=""
if [ "$#" -ge 2 ]; then
    LOG_FILE="$2"
fi

# Check if the network interface exists
if [ ! -d "/sys/class/net/$INTERFACE" ]; then
    echo "Error: Network interface $INTERFACE does not exist."
    exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

echo "Monitoring bandwidth usage on interface $INTERFACE..."
echo "Press Ctrl+C to stop."

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

# Function to monitor bandwidth usage
monitor_bandwidth() {
    while true; do
        RX1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        TX1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        sleep 1
        RX2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        TX2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

        RX_RATE=$((RX2 - RX1))
        TX_RATE=$((TX2 - TX1))

        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        log_message "$TIMESTAMP: Download: $((RX_RATE / 1024)) KB/s, Upload: $((TX_RATE / 1024)) KB/s"
    done
}

# Monitor bandwidth usage and handle errors
if ! monitor_bandwidth; then
    log_message "Error: Failed to monitor bandwidth usage on interface $INTERFACE."
    exit 1
fi