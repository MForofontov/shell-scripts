#!/bin/bash
# check-process.sh
# Script to check if a specific process is running

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <process_name>"
    exit 1
fi

# Get the process name from the argument
PROCESS_NAME="$1"

# Check if the process is running
if pgrep "$PROCESS_NAME" > /dev/null
then
    echo "$PROCESS_NAME is running."
else
    echo "$PROCESS_NAME is not running."
fi