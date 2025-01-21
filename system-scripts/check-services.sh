#!/bin/bash
# check-services.sh
# Script to check if a list of services are running

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -gt 1 ]; then
    usage
fi

# Configuration
SERVICES=("nginx" "apache2" "postgresql" "django" "react" "celery-worker")  # List of services to check
LOG_FILE=""

# Check if a log file is provided as an argument
if [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
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

# Function to check if a service is running
is_running() {
    local service_name=$1
    local pid
    pid=$(pgrep -f "$service_name")
    if [ -n "$pid" ]; then
        log_message "$service_name is running with PID(s): $pid"
        return 0
    else
        log_message "$service_name is not running"
        return 1
    fi
}

# Check each service
for service in "${SERVICES[@]}"; do
    is_running "$service"
done

# Check for any Celery worker
log_message "Checking for any Celery worker..."
if pgrep -f "celery" > /dev/null; then
    log_message "Celery worker is running."
else
    log_message "No Celery worker is running."
fi