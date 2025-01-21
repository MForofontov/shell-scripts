#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/network-and-connectivity/arp-table-viewer.sh
# arp-table-viewer.sh
# Script to view and log the ARP table

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 custom_log.log"
    exit 1
}

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -gt 1 ]; then
    usage
elif [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

echo "Fetching ARP table..."
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
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

log_message "$TIMESTAMP: Fetching ARP table..."

# Fetch and log the ARP table
if ! arp -a | tee -a "$LOG_FILE"; then
    log_message "Error: Failed to fetch ARP table."
    exit 1
fi

log_message "$TIMESTAMP: ARP table saved to $LOG_FILE"