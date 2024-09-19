#!/bin/bash
# schedule-task.sh
# Script to schedule a task using cron

# Configuration
SCRIPT_PATH="/path/to/your_script.sh"  # Path to the script to be scheduled
CRON_SCHEDULE="0 2 * * *"              # Schedule (daily at 2 AM)

# Check if the script is already scheduled
if crontab -l | grep -q "$SCRIPT_PATH"; then
    echo "Script is already scheduled."
else
    # Schedule the script using cron
    (crontab -l; echo "$CRON_SCHEDULE $SCRIPT_PATH") | crontab -
    echo "Script scheduled to run at $CRON_SCHEDULE."
fi
