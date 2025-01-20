#!/bin/bash
# filepath: /home/ummi/Documents/github/shell-scripts/network-and-connectivity/http-status-code-checker.sh
# http-status-code-checker.sh
# Script to check HTTP status codes for a list of URLs

# Default URLs and log file
URLS=("https://google.com" "https://github.com" "https://example.com")
LOG_FILE="http_status.log"

# Check if URLs are provided as arguments
if [ "$#" -ge 1 ]; then
    URLS=("${@:1:$#-1}")
    LOG_FILE="${!#}"
fi

echo "Checking HTTP status codes..."
echo "Results logged in $LOG_FILE"

# Function to check HTTP status codes
check_status_codes() {
    for URL in "${URLS[@]}"; do
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" "$URL")
        echo "$TIMESTAMP: $URL: $STATUS_CODE" | tee -a "$LOG_FILE"
    done
}

# Check status codes and handle errors
if ! check_status_codes; then
    echo "Error: Failed to check HTTP status codes."
    exit 1
fi

echo "HTTP status code check complete. Results logged in $LOG_FILE"