#!/bin/bash
# Script: sudo_command_logger.sh
# Description: Log all commands run with sudo.

# Function to display usage instructions
usage() {
    echo "Usage: $0 [log_file]"
    echo "Example: $0 /var/log/custom_sudo_command.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -gt 1 ]; then
    usage
fi

# Get the log file from the arguments or use the default
LOG_FILE="/var/log/sudo_command.log"
if [ "$#" -eq 1 ]; then
    LOG_FILE="$1"
fi

# Validate log file
if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Error: Cannot write to log file $LOG_FILE"
    exit 1
fi

# Function to log messages
log_message() {
    local MESSAGE=$1
    echo "$MESSAGE" | tee -a "$LOG_FILE"
}

# Monitor sudo commands
log_message "Monitoring sudo commands..."
tail -f /var/log/auth.log | grep --line-buffered "COMMAND" >> "$LOG_FILE" &
log_message "Logging sudo commands to $LOG_FILE"
