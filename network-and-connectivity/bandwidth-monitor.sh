#!/bin/bash
# bandwidth-monitor.sh
# Script to monitor bandwidth usage on a specified network interface

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
INTERFACE=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Bandwidth Monitor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script monitors bandwidth usage on a specified network interface."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <interface> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<interface>\033[0m       (Required) Network interface to monitor (e.g., eth0 or en0)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 eth0 --log custom_log.log"
  echo "  $0 en0"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log)
        if [[ -n "${2:-}" ]]; then
          LOG_FILE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --log"
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
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

#=====================================================================
# BANDWIDTH MONITORING FUNCTIONS
#=====================================================================
monitor_bandwidth() {
  local RX_PREV=0
  local TX_PREV=0
  local DISPLAY_COUNTER=0
  local DISPLAY_INTERVAL=5
  
  format-echo "INFO" "Beginning bandwidth monitoring on $INTERFACE..."
  print_with_separator "Bandwidth Statistics"
  
  echo -e "\033[1;34mTimestamp\033[0m               \033[1;32mDownload\033[0m     \033[1;33mUpload\033[0m"
  echo "------------------------------------------------------"

  while true; do
    # Get current statistics based on OS
    if [[ "$(uname)" == "Linux" ]]; then
      RX_CURRENT=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null)
      TX_CURRENT=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null)
    elif [[ "$(uname)" == "Darwin" ]]; then
      RX_CURRENT=$(netstat -ib | awk -v iface="$INTERFACE" '$1 == iface {print $7}' | head -n 1)
      TX_CURRENT=$(netstat -ib | awk -v iface="$INTERFACE" '$1 == iface {print $10}' | head -n 1)
    else
      format-echo "ERROR" "Unsupported operating system: $(uname)"
      exit 1
    fi

    # Validate retrieved statistics
    if ! [[ "$RX_CURRENT" =~ ^[0-9]+$ ]] || ! [[ "$TX_CURRENT" =~ ^[0-9]+$ ]]; then
      format-echo "ERROR" "Failed to retrieve network statistics for interface $INTERFACE."
      exit 1
    fi

    # Calculate bandwidth rates
    RX_RATE=$((RX_CURRENT - RX_PREV))
    TX_RATE=$((TX_CURRENT - TX_PREV))

    # Update previous values for next iteration
    RX_PREV=$RX_CURRENT
    TX_PREV=$TX_CURRENT

    # Format the output with units
    RX_KB=$(( RX_RATE / 1024 ))
    TX_KB=$(( TX_RATE / 1024 ))
    
    # Format output with color and units
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "$TIMESTAMP  \033[1;32m${RX_KB} KB/s\033[0m    \033[1;33m${TX_KB} KB/s\033[0m"
    
    # Every DISPLAY_INTERVAL seconds, show summary statistics
    DISPLAY_COUNTER=$((DISPLAY_COUNTER + 1))
    if [ $DISPLAY_COUNTER -ge $DISPLAY_INTERVAL ]; then
      print_with_separator "Current Statistics"
      format-echo "INFO" "Download rate: $RX_KB KB/s"
      format-echo "INFO" "Upload rate: $TX_KB KB/s"
      format-echo "INFO" "Total received since start: $((RX_CURRENT / 1048576)) MB"
      format-echo "INFO" "Total transmitted since start: $((TX_CURRENT / 1048576)) MB"
      print_with_separator "Continuing Monitoring"
      
      echo -e "\033[1;34mTimestamp\033[0m               \033[1;32mDownload\033[0m     \033[1;33mUpload\033[0m"
      echo "------------------------------------------------------"
      DISPLAY_COUNTER=0
    fi

    sleep 1
  done
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Bandwidth Monitor Script"
  format-echo "INFO" "Starting Bandwidth Monitor Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if interface is provided
  if [ -z "$INTERFACE" ]; then
    format-echo "ERROR" "<interface> is required."
    print_with_separator "End of Bandwidth Monitor Script"
    exit 1
  fi

  # Verify that the interface exists
  if [[ "$(uname)" == "Linux" ]]; then
    if [ ! -d "/sys/class/net/$INTERFACE" ]; then
      format-echo "ERROR" "Interface $INTERFACE does not exist."
      print_with_separator "End of Bandwidth Monitor Script"
      exit 1
    fi
  elif [[ "$(uname)" == "Darwin" ]]; then
    if ! ifconfig "$INTERFACE" &> /dev/null; then
      format-echo "ERROR" "Interface $INTERFACE does not exist."
      print_with_separator "End of Bandwidth Monitor Script"
      exit 1
    fi
  fi

  #---------------------------------------------------------------------
  # MONITORING OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Monitoring bandwidth usage on interface $INTERFACE..."
  format-echo "INFO" "Press Ctrl+C to stop."

  # Start the monitoring
  trap 'echo -e "\n"; format-echo "INFO" "Bandwidth monitoring stopped."; print_with_separator "End of Bandwidth Monitor Script"; exit 0' INT
  monitor_bandwidth

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  # This section will only be reached if monitor_bandwidth exits normally
  format-echo "INFO" "Bandwidth monitoring completed."
  print_with_separator "End of Bandwidth Monitor Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
