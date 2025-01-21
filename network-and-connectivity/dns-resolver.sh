#!/bin/bash
# dns-resolver.sh
# Script to test DNS resolution for a list of domains

# Function to display usage instructions
usage() {
    echo "Usage: $0 <domain1> <domain2> ... [log_file]"
    echo "Example: $0 google.com github.com custom_log.log"
    exit 1
}

# Default domains
DOMAINS=("google.com" "github.com" "example.com")

# Check if domains are provided as arguments
LOG_FILE=""
if [ "$#" -ge 1 ]; then
    if [[ "${!#}" != *"."* ]]; then
        LOG_FILE="${!#}"
        DOMAINS=("${@:1:$#-1}")
    else
        DOMAINS=("$@")
    fi
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "Error: Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

# Function to log messages
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

log_message "Testing DNS resolution..."

# Function to resolve domains
resolve_domains() {
    for DOMAIN in "${DOMAINS[@]}"; do
        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        IP=$(dig +short "$DOMAIN" | head -n 1)
        if [ -z "$IP" ]; then
            log_message "$TIMESTAMP: $DOMAIN: DNS resolution failed"
        else
            log_message "$TIMESTAMP: $DOMAIN: Resolved to $IP"
        fi
    done
}

# Resolve domains and handle errors
if ! resolve_domains; then
    log_message "Error: Failed to resolve domains."
    exit 1
fi

log_message "DNS resolution complete."