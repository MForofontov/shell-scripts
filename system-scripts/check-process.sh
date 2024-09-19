#!/bin/bash
# check-process.sh
# Script to check if a specific process is running

# Configuration
PROCESS_NAME="process_name"  # Name of the process to check

# Check if the process is running
if pgrep "$PROCESS_NAME" > /dev/null
then
    echo "$PROCESS_NAME is running."
else
    echo "$PROCESS_NAME is not running."
fi
