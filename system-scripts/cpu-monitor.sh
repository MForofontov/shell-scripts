#!/bin/bash
# cpu-monitor.sh
# Script to monitor CPU usage and alert if it exceeds a threshold.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
THRESHOLD=""
EMAIL=""
LOG_FILE="/dev/null"
INTERVAL=5   # Check interval in seconds
DURATION=60  # Total monitoring duration in seconds
CONTINUOUS=false
EXIT_CODE=0

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "CPU Monitor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script monitors CPU usage and sends an alert if it exceeds a threshold."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <threshold> <email> [--interval <seconds>] [--duration <seconds>] [--continuous] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<threshold>\033[0m              (Required) CPU usage threshold percentage."
  echo -e "  \033[1;36m<email>\033[0m                  (Required) Email address to send alerts."
  echo -e "  \033[1;33m--interval <seconds>\033[0m     (Optional) Check interval in seconds (default: 5)."
  echo -e "  \033[1;33m--duration <seconds>\033[0m     (Optional) Total monitoring duration in seconds (default: 60)."
  echo -e "  \033[1;33m--continuous\033[0m             (Optional) Monitor continuously until stopped."
  echo -e "  \033[1;33m--log <log_file>\033[0m         (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 80 user@example.com --log cpu_monitor.log"
  echo "  $0 90 admin@example.com --interval 10 --duration 300"
  echo "  $0 75 sysadmin@company.com --continuous"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --interval)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid interval: $2. Must be a positive integer."
          usage
        fi
        INTERVAL="$2"
        shift 2
        ;;
      --duration)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid duration: $2. Must be a positive integer."
          usage
        fi
        DURATION="$2"
        shift 2
        ;;
      --continuous)
        CONTINUOUS=true
        shift
        ;;
      *)
        if [ -z "$THRESHOLD" ]; then
          if ! [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            format-echo "ERROR" "Invalid threshold: $1. Must be a number."
            usage
          fi
          THRESHOLD="$1"
        elif [ -z "$EMAIL" ]; then
          # Simple email validation
          if ! [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            format-echo "ERROR" "Invalid email address: $1"
            usage
          fi
          EMAIL="$1"
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        shift
        ;;
    esac
  done
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Function to get current CPU usage
get_cpu_usage() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS approach
    top -l 1 -n 0 | grep "CPU usage" | awk '{print $3+$5}' | tr -d '%'
  else
    # Linux approach
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'
  fi
}

# Function to send email alert
send_alert() {
  local usage=$1
  local subject="CPU Usage Alert - ${usage}% on $(hostname)"
  local message="CPU usage is at ${usage}% - exceeds the threshold of ${THRESHOLD}%\n\nTimestamp: $(date)\nHostname: $(hostname)\nSystem load: $(uptime)"
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "$message" | mail -s "$subject" "$EMAIL"
  else
    echo -e "$message" | mail -s "$subject" -r "cpu-monitor@$(hostname)" "$EMAIL"
  fi
  
  format-echo "WARNING" "Alert sent to $EMAIL - CPU usage is at ${usage}%"
}

# Function to monitor CPU once
check_cpu_once() {
  local cpu_usage=$(get_cpu_usage)
  
  # Check if CPU usage exceeds the threshold
  if (( $(echo "$cpu_usage > $THRESHOLD" | bc -l) )); then
    send_alert "$cpu_usage"
    EXIT_CODE=1
    return 1
  else
    format-echo "SUCCESS" "CPU usage is at ${cpu_usage}%, below the threshold of ${THRESHOLD}%."
    return 0
  fi
}

# Function to monitor CPU for a specified duration
monitor_cpu() {
  format-echo "INFO" "Starting CPU monitoring (threshold: ${THRESHOLD}%)..."
  
  if [[ "$CONTINUOUS" == "true" ]]; then
    format-echo "INFO" "Monitoring continuously until stopped (Ctrl+C to stop)"
    format-echo "INFO" "Checking every $INTERVAL seconds"
    
    # Trap Ctrl+C to exit gracefully
    trap 'echo; format-echo "INFO" "Monitoring stopped by user"; return' INT
    
    while true; do
      check_cpu_once
      sleep "$INTERVAL"
    done
  else
    local end_time=$(($(date +%s) + DURATION))
    local current_time=$(date +%s)
    local iteration=1
    
    format-echo "INFO" "Monitoring for $DURATION seconds (interval: $INTERVAL seconds)"
    
    while [[ $current_time -lt $end_time ]]; do
      format-echo "INFO" "Check $iteration - $(date)"
      check_cpu_once
      
      # Only sleep if we're not at the last iteration
      if [[ $((current_time + INTERVAL)) -lt $end_time ]]; then
        sleep "$INTERVAL"
      fi
      
      current_time=$(date +%s)
      iteration=$((iteration + 1))
    done
    
    format-echo "INFO" "Monitoring completed after $DURATION seconds"
  fi
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  setup_log_file

  print_with_separator "CPU Monitor Script"
  format-echo "INFO" "Starting CPU Monitor Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate required arguments
  if [ -z "$THRESHOLD" ] || [ -z "$EMAIL" ]; then
    format-echo "ERROR" "Both <threshold> and <email> are required."
    print_with_separator "End of CPU Monitor Script"
    usage
  fi

  # Check if mail command is available
  if ! command -v mail &> /dev/null; then
    format-echo "WARNING" "mail command not found. Email alerts will not be sent."
  fi

  # Check if bc command is available
  if ! command -v bc &> /dev/null; then
    format-echo "ERROR" "bc command not found. Required for floating-point comparison."
    print_with_separator "End of CPU Monitor Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # CPU MONITORING
  #---------------------------------------------------------------------
  monitor_cpu

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of CPU Monitor Script"
  if [[ $EXIT_CODE -eq 0 ]]; then
    format-echo "SUCCESS" "CPU monitoring completed successfully."
  else
    format-echo "WARNING" "CPU monitoring completed. Threshold was exceeded."
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
