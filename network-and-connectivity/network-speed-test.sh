#!/bin/bash
# network-speed-test.sh
# Script to run a network speed test using speedtest-cli

# Function to display usage instructions
usage() {
  echo "Usage: $0 [log_file]"
  echo "Example: $0 custom_log.log"
  exit 1
}

# Check if speedtest-cli is installed
if ! command -v speedtest-cli &> /dev/null; then
  echo "speedtest-cli is not installed. Installing..."
  if ! sudo apt-get install -y speedtest-cli; then
    echo "Error: Failed to install speedtest-cli."
    exit 1
  fi
fi

# Check if a log file is provided as an argument
LOG_FILE=""
if [ "$#" -gt 1 ]; then
  usage
elif [ "$#" -eq 1 ]; then
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

log_message "Running network speed test..."

# Function to run the speed test and log the results
run_speed_test() {
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  log_message "$TIMESTAMP: Running network speed test..."
  if ! speedtest-cli | tee -a "$LOG_FILE"; then
    log_message "Error: Failed to run network speed test."
    exit 1
  fi
  log_message "$TIMESTAMP: Network speed test completed."
}

# Run the speed test and handle errors
if ! run_speed_test; then
  log_message "Error: Failed to run network speed test."
  exit 1
fi

log_message "Network speed test complete."