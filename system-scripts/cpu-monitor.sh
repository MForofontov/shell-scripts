#!/bin/bash
# cpu-monitor.sh
# Script to monitor CPU usage and alert if it exceeds a threshold.

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
  print_with_separator "CPU Monitor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script monitors CPU usage and sends an alert if it exceeds a threshold."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <threshold> <email> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<threshold>\033[0m       (Required) CPU usage threshold percentage."
  echo -e "  \033[1;33m<email>\033[0m           (Required) Email address to send alerts."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 80 user@example.com --log cpu_monitor.log"
  echo "  $0 90 admin@example.com"
  print_with_separator
  exit 1
}

# Default values
THRESHOLD=""
EMAIL=""
LOG_FILE="/dev/null"

# Parse input arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --log)
      if [ -z "$2" ]; then
        log_message "ERROR" "No log file provided after --log."
        usage
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      if [ -z "$THRESHOLD" ]; then
        THRESHOLD="$1"
      elif [ -z "$EMAIL" ]; then
        EMAIL="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$THRESHOLD" ] || [ -z "$EMAIL" ]; then
  log_message "ERROR" "Both <threshold> and <email> are required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Starting CPU usage monitoring..."
print_with_separator "CPU Monitor Results"

# Get current CPU usage percentage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Check if CPU usage exceeds the threshold
if (( $(echo "$CPU_USAGE > $THRESHOLD" | bc -l) )); then
  ALERT_MESSAGE="CPU usage is at ${CPU_USAGE}% - exceeds the threshold of ${THRESHOLD}%"
  echo "$ALERT_MESSAGE" | mail -s "CPU Usage Alert" "$EMAIL"
  log_message "ERROR" "$ALERT_MESSAGE"
else
  log_message "SUCCESS" "CPU usage is at ${CPU_USAGE}%, below the threshold of ${THRESHOLD}%."
fi

print_with_separator "End of CPU Monitor Results"
log_message "INFO" "CPU monitoring completed."