#!/bin/bash
# network-speed-test.sh
# Script to run a network speed test using speedtest-cli

# Check if speedtest-cli is installed
if ! command -v speedtest-cli &> /dev/null; then
  echo "speedtest-cli is not installed. Installing..."
  if ! sudo apt-get install -y speedtest-cli; then
    echo "Error: Failed to install speedtest-cli."
    exit 1
  fi
fi

# Default log file
LOG_FILE="network_speed.log"

# Check if a log file is provided as an argument
if [ "$#" -eq 1 ]; then
  LOG_FILE="$1"
fi

echo "Running network speed test..."
echo "Results will be logged in $LOG_FILE"

# Function to run the speed test and log the results
run_speed_test() {
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$TIMESTAMP: Running network speed test..." | tee -a "$LOG_FILE"
  if ! speedtest-cli | tee -a "$LOG_FILE"; then
    echo "Error: Failed to run network speed test." | tee -a "$LOG_FILE"
    exit 1
  fi
  echo "$TIMESTAMP: Network speed test completed." | tee -a "$LOG_FILE"
}

# Run the speed test and handle errors
if ! run_speed_test; then
  echo "Error: Failed to run network speed test."
  exit 1
fi

echo "Network speed test complete. Results logged in $LOG_FILE"