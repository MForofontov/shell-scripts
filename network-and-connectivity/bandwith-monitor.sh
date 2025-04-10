#!/bin/bash
# bandwidth-monitor.sh
# Script to monitor bandwidth usage on a specified network interface

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
    TERMINAL_WIDTH=$(tput cols)
    SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

    echo
    echo "$SEPARATOR"
    echo -e "\033[1;34mBandwidth Monitor Script\033[0m"
    echo
    echo -e "\033[1;34mDescription:\033[0m"
    echo "  This script monitors bandwidth usage on a specified network interface."
    echo "  It also supports optional logging to a file."
    echo
    echo -e "\033[1;34mUsage:\033[0m"
    echo "  $0 <interface> [--log <log_file>] [--help]"
    echo
    echo -e "\033[1;34mOptions:\033[0m"
    echo -e "  \033[1;36m<interface>\033[0m       (Required) Network interface to monitor (e.g., eth0)."
    echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
    echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
    echo
    echo -e "\033[1;34mExamples:\033[0m"
    echo "  $0 eth0 --log custom_log.log"
    echo "  $0 eth0"
    echo "$SEPARATOR"
    echo
    exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 1 ]; then
    log_message "ERROR" "<interface> is required."
    usage
fi

# Initialize variables
INTERFACE=""
LOG_FILE="/dev/null"

# Parse arguments using while and case
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --log)
            if [[ -n "$2" ]]; then
                LOG_FILE="$2"
                shift 2
            else
                log_message "ERROR" "Missing argument for --log"
                usage
            fi
            ;;
        --help)
            usage
            ;;
        *)
            if [ -z "$INTERFACE" ]; then
                INTERFACE="$1"
                shift
            else
                log_message "ERROR" "Unknown option or too many arguments: $1"
                usage
            fi
            ;;
    esac
done

# Validate interface
if [ -z "$INTERFACE" ]; then
    log_message "ERROR" "Network interface is required."
    usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        log_message "ERROR" "Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

log_message "INFO" "Monitoring bandwidth usage on interface $INTERFACE..."
log_message "INFO" "Press Ctrl+C to stop."

# Function to monitor bandwidth usage
monitor_bandwidth() {
    while true; do
        RX1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        TX1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
        sleep 1
        RX2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        TX2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

        RX_RATE=$((RX2 - RX1))
        TX_RATE=$((TX2 - TX1))

        TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
        log_message "INFO" "$TIMESTAMP: Download: $((RX_RATE / 1024)) KB/s, Upload: $((TX_RATE / 1024)) KB/s"
    done
}

# Monitor bandwidth usage and handle errors
if ! monitor_bandwidth; then
    print_with_separator "End of Bandwidth Monitor Output"
    log_message "ERROR" "Failed to monitor bandwidth usage on interface $INTERFACE."
    exit 1
fi