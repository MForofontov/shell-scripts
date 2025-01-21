#!/bin/bash
# schedule-task.sh
# Script to schedule a task using cron

# Function to display usage instructions
usage() {
    echo "Usage: $0 <script_path> <cron_schedule> [log_file]"
    echo "Example: $0 /path/to/script.sh '0 5 * * *' custom_log.log"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

# Get the script path, cron schedule, and log file from the arguments
SCRIPT_PATH="$1"
CRON_SCHEDULE="$2"
LOG_FILE=""

# Check if a log file is provided as a third argument
if [ "$#" -eq 3 ]; then
    LOG_FILE="$3"
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

# Check if the script is already scheduled
log_message "Checking if the script is already scheduled..."
if crontab -l | grep -q "$SCRIPT_PATH"; then
    log_message "Script is already scheduled."
else
    # Schedule the script using cron
    (crontab -l; echo "$CRON_SCHEDULE $SCRIPT_PATH") | crontab -
    log_message "Script scheduled to run at $CRON_SCHEDULE."
fi