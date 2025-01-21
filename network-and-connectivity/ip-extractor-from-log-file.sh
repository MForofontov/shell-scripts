#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/network-and-connectivity/ip-extractor-from-log-file.sh
# ip-extractor-from-log-file.sh
# Script to extract unique IP addresses from a log file

# Function to display usage instructions
usage() {
    echo "Usage: $0 <log_file> [output_file]"
    echo "Example: $0 /path/to/logfile.log extracted_ips.txt"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the log file and output file from the arguments
LOG_FILE=$1
OUTPUT_FILE=${2:-}

# Check if the log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file $LOG_FILE does not exist."
    exit 1
fi

# Validate output file if provided
if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
        echo "Error: Cannot write to output file $OUTPUT_FILE"
        exit 1
    fi
fi

echo "Extracting IP addresses from $LOG_FILE..."

# Extract unique IP addresses and save to the output file or display on the console
if [ -n "$OUTPUT_FILE" ]; then
    if ! grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$LOG_FILE" | sort -u > "$OUTPUT_FILE"; then
        echo "Error: Failed to extract IP addresses."
        exit 1
    fi
    echo "Extracted IPs saved to $OUTPUT_FILE"
else
    if ! grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$LOG_FILE" | sort -u; then
        echo "Error: Failed to extract IP addresses."
        exit 1
    fi
fi