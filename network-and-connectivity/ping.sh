#!/bin/bash
# ping.sh
# Script to ping a list of servers/websites and check their reachability

# Default list of servers/websites to ping
DEFAULT_WEBSITES=("google.com" "github.com" "stackoverflow.com")

# Default number of ping attempts and timeout
PING_COUNT=3
TIMEOUT=5
OUTPUT_FILE=""

# Function to display usage instructions
usage() {
    echo "Usage: $0 [--websites <site1,site2,...>] [--count <number>] [--timeout <seconds>] [--log <file>] [--help]"
    echo
    echo "Options:"
    echo "  --websites <site1,site2,...>   (Optional) Comma-separated list of websites to ping (default: ${DEFAULT_WEBSITES[*]})"
    echo "  --count <number>               (Optional) Number of ping attempts (default: $PING_COUNT)"
    echo "  --timeout <seconds>            (Optional) Timeout for each ping attempt (default: $TIMEOUT)"
    echo "  --log <file>                   (Optional) Log output to the specified file"
    echo "  --help                         (Optional) Display this help message"
    echo
    echo "Example:"
    echo "  $0 --websites google.com,example.com --count 5 --timeout 3 --log ping_results.txt"
    exit 0
}

# Parse input arguments
WEBSITES=("${DEFAULT_WEBSITES[@]}")
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            ;;
        --websites)
            IFS=',' read -r -a WEBSITES <<< "$2"
            shift 2
            ;;
        --count)
            PING_COUNT="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --log)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate log file if provided
if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $OUTPUT_FILE"
        exit 1
    fi
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$MESSAGE" | tee -a "$OUTPUT_FILE"
    else
        echo "$MESSAGE"
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