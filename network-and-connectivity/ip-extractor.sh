#!/bin/bash
# ip-extractor.sh
# Script to extract unique IP addresses from a log file

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <log_file> [output_file]"
    exit 1
fi

# Get the log file and output file from the arguments
LOG_FILE=$1
OUTPUT_FILE=${2:-extracted_ips.txt}

# Check if the log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file $LOG_FILE does not exist."
    exit 1
fi

echo "Extracting IP addresses from $LOG_FILE..."

# Extract unique IP addresses and save to the output file
if ! grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$LOG_FILE" | sort -u > "$OUTPUT_FILE"; then
    echo "Error: Failed to extract IP addresses."
    exit 1
fi

echo "Extracted IPs saved to $OUTPUT_FILE"