#!/bin/bash
# bandwidth-monitor.sh
# Script to monitor bandwidth usage on a specified network interface

# Function to display usage instructions
usage() {
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
    exit 1
}

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
                echo -e "\033[1;31mError:\033[0m Missing argument for --log"
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
                echo -e "\033[1;31mError:\033[0m Unknown option or too many arguments: $1"
                usage
            fi
            ;;
    esac
done

# Validate interface
if [ -z "$INTERFACE" ]; then
    echo -e "\033[1;31mError:\033[0m Network interface is required."
    usage
fi

if [ ! -d "/sys/class/net/$INTERFACE" ]; then
    echo -e "\033[1;31mError:\033[0m Network interface $INTERFACE does not exist."
    exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE"
        exit 1
    fi
fi

echo "Monitoring bandwidth usage on interface $INTERFACE..."
echo "Press Ctrl+C to stop."

# Function to log messages
log_message() {
    local MESSAGE=$1
    if [ -n "$MESSAGE" ]; then
        if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
            echo "$MESSAGE" | tee -a "$LOG_FILE"
        else
            echo "$MESSAGE"
        fi
    fi
}

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
        log_message "$TIMESTAMP: Download: $((RX_RATE / 1024)) KB/s, Upload: $((TX_RATE / 1024)) KB/s"
    done
}

# Monitor bandwidth usage and handle errors
if ! monitor_bandwidth; then
    log_message "Error: Failed to monitor bandwidth usage on interface $INTERFACE."
    exit 1
fi