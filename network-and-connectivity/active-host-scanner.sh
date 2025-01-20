#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/network-and-connectivity/active-host-scanner.sh
# active-host-scanner.sh
# Script to scan a network for active hosts

# Get the network prefix and log file from the arguments
NETWORK=$1
LOG_FILE=${2:-active_hosts.log}

# Check if the network prefix is provided
if [ -z "$NETWORK" ]; then
  echo "Usage: $0 <network_prefix> [log_file]"
  echo "Example: $0 192.168.1"
  exit 1
fi

echo "Scanning network $NETWORK.0/24 for active hosts..."
echo "Results logged in $LOG_FILE"

# Function to scan for active hosts
scan_network() {
  for IP in $(seq 1 254); do
    TARGET="$NETWORK.$IP"
    if ping -c 1 -W 1 $TARGET &> /dev/null; then
      TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
      echo "$TIMESTAMP: $TARGET is active" | tee -a $LOG_FILE
    fi
  done
}

# Scan network and handle errors
if ! scan_network; then
  echo "Error: Failed to scan network $NETWORK.0/24."
  exit 1
fi

echo "Network scan complete. Results logged in $LOG_FILE"