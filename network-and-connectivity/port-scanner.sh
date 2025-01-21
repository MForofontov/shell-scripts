#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/network-and-connectivity/port-scanner.sh
# port-scanner.sh
# Script to scan open ports on a specified server

# Function to display usage instructions
usage() {
    echo "Usage: $0 <server> [start_port] [end_port] [output_file]"
    echo "Example: $0 example.com 1 65535 scan_results.txt"
    exit 1
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the server, start port, end port, and output file from the arguments
SERVER=$1
START_PORT=${2:-1}
END_PORT=${3:-65535}
OUTPUT_FILE=${4:-}

# Validate server
if ! ping -c 1 -W 1 "$SERVER" &> /dev/null; then
    echo "Error: Cannot reach server $SERVER"
    exit 1
fi

# Validate start port
if ! [[ "$START_PORT" =~ ^[0-9]+$ ]] || [ "$START_PORT" -lt 1 ] || [ "$START_PORT" -gt 65535 ]; then
    echo "Error: Invalid start port $START_PORT"
    usage
fi

# Validate end port
if ! [[ "$END_PORT" =~ ^[0-9]+$ ]] || [ "$END_PORT" -lt 1 ] || [ "$END_PORT" -gt 65535 ]; then
    echo "Error: Invalid end port $END_PORT"
    usage
fi

# Validate port range
if [ "$START_PORT" -gt "$END_PORT" ]; then
    echo "Error: Start port $START_PORT is greater than end port $END_PORT"
    usage
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

log_message "Scanning ports on $SERVER from $START_PORT to $END_PORT..."

# Function to scan ports
scan_ports() {
    for PORT in $(seq $START_PORT $END_PORT); do
        timeout 1 bash -c "echo > /dev/tcp/$SERVER/$PORT" &> /dev/null && log_message "Port $PORT is open."
    done
}

# Scan ports and handle errors
if ! scan_ports; then
    log_message "Error: Failed to scan ports on $SERVER."
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    log_message "Port scan results have been written to $OUTPUT_FILE"
else
    log_message "Port scan results displayed on the console"
fi