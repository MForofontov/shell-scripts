#!/bin/bash
# port-scanner.sh
# Script to scan open ports on a specified server

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <server> [start_port] [end_port] [output_file]"
    exit 1
fi

# Get the server, start port, end port, and output file from the arguments
SERVER=$1
START_PORT=${2:-1}
END_PORT=${3:-65535}
OUTPUT_FILE=${4:-}

# Check if an output file is provided
if [ -n "$OUTPUT_FILE" ]; then
    exec > "$OUTPUT_FILE" 2>&1
    echo "Writing port scan results to $OUTPUT_FILE"
fi

echo "Scanning ports on $SERVER from $START_PORT to $END_PORT..."

# Function to scan ports
scan_ports() {
    for PORT in $(seq $START_PORT $END_PORT); do
        timeout 1 bash -c "echo > /dev/tcp/$SERVER/$PORT" &> /dev/null && echo "Port $PORT is open."
    done
}

# Scan ports and handle errors
if ! scan_ports; then
    echo "Error: Failed to scan ports on $SERVER."
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    echo "Port scan results have been written to $OUTPUT_FILE"
else
    echo "Port scan results displayed on the console"
fi