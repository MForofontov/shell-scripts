#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/network-and-connectivity/ping.sh
# ping.sh
# Script to ping a list of servers/websites and check their reachability

# List of servers/websites to ping
WEBSITES=("google.com" "github.com" "stackoverflow.com")

# Default number of ping attempts and timeout
PING_COUNT=3
TIMEOUT=5

# Function to display usage instructions
usage() {
    echo "Usage: $0 [output_file]"
    echo "Example: $0 ping_results.txt"
    exit 1
}

# Check if an output file is provided as an argument
OUTPUT_FILE=""
if [ "$#" -gt 1 ]; then
    usage
elif [ "$#" -eq 1 ]; then
    OUTPUT_FILE="$1"
fi

# Validate output file if provided
if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
        echo "Error: Cannot write to output file $OUTPUT_FILE"
        exit 1
    fi
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    if [ -n "$MESSAGE" ]; then
        if [ -n "$OUTPUT_FILE" ]; then
            echo "$MESSAGE" | tee -a "$OUTPUT_FILE"
        else
            echo "$MESSAGE"
        fi
    fi
}

# Function to ping websites
ping_websites() {
    for SITE in "${WEBSITES[@]}"; do
        log_message "Pinging $SITE..."
        if ping -c "$PING_COUNT" -W "$TIMEOUT" "$SITE" &> /dev/null; then
            log_message "$SITE is reachable."
        else
            log_message "$SITE is unreachable."
        fi
    done
}

# Ping websites and handle errors
if ! ping_websites; then
    log_message "Error: Failed to ping websites."
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    log_message "Ping results have been written to $OUTPUT_FILE"
else
    log_message "Ping results displayed on the console"
fi