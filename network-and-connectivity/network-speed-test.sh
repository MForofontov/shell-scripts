#!/bin/bash
# network-speed-test.sh
# Script to run a network speed test using speedtest-cli

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
usage() {
  print_with_separator "Network Speed Test Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script runs a network speed test using speedtest-cli."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the speed test results."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 custom_log.log"
  echo "  $0"
  print_with_separator
  exit 1
}

# Check if speedtest-cli is installed
if ! command -v speedtest-cli &> /dev/null; then
  log_message "INFO" "speedtest-cli is not installed. Installing..."
  if [[ "$(uname)" == "Linux" ]]; then
    if ! sudo apt-get install -y speedtest-cli; then
      log_message "ERROR" "Failed to install speedtest-cli."
      exit 1
    fi
  elif [[ "$(uname)" == "Darwin" ]]; then
    if ! brew install speedtest-cli; then
      log_message "ERROR" "Failed to install speedtest-cli."
      exit 1
    fi
  else
    log_message "ERROR" "Unsupported operating system: $(uname)"
    exit 1
  fi
fi

# Initialize variables
LOG_FILE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --log)
      if [ -z "$2" ]; then
        log_message "ERROR" "Log file name is required after --log."
        usage
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    --help)
      usage
      ;;
    *)
      if [ -z "$LOG_FILE" ]; then
        LOG_FILE="$1"
      else
        log_message "ERROR" "Too many arguments provided."
        usage
      fi
      shift
      ;;
  esac
done

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

log_message "INFO" "Running network speed test..."
print_with_separator "Network Speed Test Output"

# Function to run the speed test and log the results
run_speed_test() {
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  log_message "INFO" "$TIMESTAMP: Running network speed test..."
  if ! speedtest-cli | tee -a "$LOG_FILE"; then
    log_message "ERROR" "Failed to run network speed test."
    exit 1
  fi
  log_message "INFO" "$TIMESTAMP: Network speed test completed."
}

# Run the speed test and handle errors
if ! run_speed_test; then
  log_message "ERROR" "Failed to run network speed test."
  print_with_separator "End of Network Speed Test Output"
  exit 1
fi

print_with_separator "End of Network Speed Test Output"
log_message "SUCCESS" "Network speed test complete."