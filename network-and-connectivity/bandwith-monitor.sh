#!/bin/bash
# bandwidth-monitor.sh
# Script to monitor bandwidth usage on a specified network interface

# Default network interface and log file
INTERFACE=${1:-eth0}
LOG_FILE=${2:-bandwidth_usage.log}

# Check if the network interface exists
if [ ! -d "/sys/class/net/$INTERFACE" ]; then
    echo "Error: Network interface $INTERFACE does not exist."
    exit 1
fi

echo "Monitoring bandwidth usage on interface $INTERFACE..."
echo "Press Ctrl+C to stop."

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
        echo "$TIMESTAMP: Download: $((RX_RATE / 1024)) KB/s, Upload: $((TX_RATE / 1024)) KB/s" | tee -a "$LOG_FILE"
    done
}

# Monitor bandwidth usage and handle errors
if ! monitor_bandwidth; then
    echo "Error: Failed to monitor bandwidth usage on interface $INTERFACE."
    exit 1
fi