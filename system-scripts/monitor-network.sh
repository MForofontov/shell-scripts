#!/bin/bash
# monitor-network.sh
# Script to monitor network traffic on a specified interface

# Configuration
INTERFACE="eth0"    # Network interface to monitor
LOG_FILE="/path/to/network_traffic.log"  # Log file to record traffic

# Monitor network traffic
tcpdump -i "$INTERFACE" -w "$LOG_FILE"

# Notify user
echo "Network traffic is being monitored on interface $INTERFACE. Logs saved to $LOG_FILE."
