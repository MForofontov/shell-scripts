#!/bin/bash
# dns-resolver.sh
# Script to test DNS resolution for a list of domains

# Default domains and log file
DOMAINS=("google.com" "github.com" "example.com")
LOG_FILE="dns_resolution.log"

# Check if domains are provided as arguments
if [ "$#" -ge 1 ]; then
    DOMAINS=("$@")
fi

# Check if a log file is provided as the last argument
if [ -n "${!#}" ]; then
    LOG_FILE="${!#}"
fi

echo "Testing DNS resolution..."
echo "Results logged in $LOG_FILE"

# Function to resolve domains
resolve_domains() {
    for DOMAIN in "${DOMAINS[@]}"; do
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        IP=$(dig +short "$DOMAIN" | head -n 1)
        if [ -z "$IP" ]; then
            echo "$TIMESTAMP: $DOMAIN: DNS resolution failed" | tee -a "$LOG_FILE"
        else
            echo "$TIMESTAMP: $DOMAIN: Resolved to $IP" | tee -a "$LOG_FILE"
        fi
    done
}

# Resolve domains and handle errors
if ! resolve_domains; then
    echo "Error: Failed to resolve domains."
    exit 1
fi

echo "DNS resolution complete. Results logged in $LOG_FILE"