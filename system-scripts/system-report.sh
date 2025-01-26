#!/bin/bash
# system-report.sh
# Script to generate a system report

# Function to display usage instructions
usage() {
    echo "Usage: $0 <report_file> [log_file]"
    echo "Example: $0 /path/to/report.txt custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

# Get the report file path and log file from the arguments
REPORT_FILE="$1"
LOG_FILE=""

# Check if a log file is provided as a second argument
if [ "$#" -eq 2 ]; then
    LOG_FILE="$2"
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

# Generate system report
log_message "Generating system report at $REPORT_FILE..."
{
    echo "System Report - $(date)"
    echo "----------------------------------"
    echo "Uptime:"
    uptime
    echo ""
    echo "Disk Usage:"
    df -h
    echo ""
    echo "Memory Usage:"
    free -h
    echo ""
    echo "CPU Usage:"
    top -bn1 | grep "Cpu(s)"
} > "$REPORT_FILE"

# Notify user
log_message "System report generated at $REPORT_FILE."