#!/bin/bash
# schedule-task.sh
# Script to schedule a task using cron

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <script_path> <cron_schedule>"
    exit 1
fi

# Get the script path and cron schedule from the arguments
SCRIPT_PATH="$1"
CRON_SCHEDULE="$2"

# Check if the script is already scheduled
if crontab -l | grep -q "$SCRIPT_PATH"; then
    echo "Script is already scheduled."
else
    # Schedule the script using cron
    (crontab -l; echo "$CRON_SCHEDULE $SCRIPT_PATH") | crontab -
    echo "Script scheduled to run at $CRON_SCHEDULE."
fi