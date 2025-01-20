#!/bin/bash
# ping.sh
# Script to ping a list of servers/websites and check their reachability

# List of servers/websites to ping
WEBSITES=("google.com" "github.com" "stackoverflow.com")

# Default number of ping attempts and timeout
PING_COUNT=3
TIMEOUT=5

# Check if an output file is provided
if [ "$#" -eq 1 ]; then
    OUTPUT_FILE="$1"
    exec > "$OUTPUT_FILE" 2>&1
    echo "Writing ping results to $OUTPUT_FILE"
else
    OUTPUT_FILE=""
fi

# Function to ping websites
ping_websites() {
    for SITE in "${WEBSITES[@]}"; do
        echo "Pinging $SITE..."
        if ping -c "$PING_COUNT" -W "$TIMEOUT" "$SITE" &> /dev/null; then
            echo "$SITE is reachable."
        else
            echo "$SITE is unreachable."
        fi
    done
}

# Ping websites and handle errors
if ! ping_websites; then
    echo "Error: Failed to ping websites."
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    echo "Ping results have been written to $OUTPUT_FILE"
else
    echo "Ping results displayed on the console"
fi