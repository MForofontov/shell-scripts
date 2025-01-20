#!/bin/bash
# arp-table-viewer.sh
# Script to view and log the ARP table

# Default log file
LOG_FILE="arp_table.log"

# Check if a log file is provided as an argument
if [ "$#" -eq 1 ]; then
  LOG_FILE="$1"
fi

echo "Fetching ARP table..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP: Fetching ARP table..." | tee -a "$LOG_FILE"

# Fetch and log the ARP table
if ! arp -a | tee -a "$LOG_FILE"; then
  echo "Error: Failed to fetch ARP table." | tee -a "$LOG_FILE"
  exit 1
fi

echo "$TIMESTAMP: ARP table saved to $LOG_FILE" | tee -a "$LOG_FILE"