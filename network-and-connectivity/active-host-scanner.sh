#!/bin/bash
# active-host-scanner.sh
# Script to scan a network for active hosts

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
NETWORK=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Active Host Scanner Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scans a network for active hosts using ping."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <network_prefix> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<network_prefix>\033[0m  (Required) Network prefix to scan (e.g., 192.168.1)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 192.168.1 --log custom_log.log"
  echo "  $0 192.168.1"
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
        if [ -z "$NETWORK" ]; then
          NETWORK="$1"
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
# NETWORK SCANNING FUNCTIONS
#=====================================================================
scan_network() {
  local active_count=0
  local total_ips=254
  
  format-echo "INFO" "Beginning scan of $total_ips IP addresses in $NETWORK.0/24 network..."
  print_with_separator "Scanning Network"
  
  for IP in $(seq 1 254); do
    TARGET="$NETWORK.$IP"
    if ping -c 1 -W 1 "$TARGET" &> /dev/null; then
      TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
      format-echo "SUCCESS" "$TIMESTAMP: $TARGET is active"
      active_count=$((active_count + 1))
    fi
    
    # Show progress every 25 IPs
    if [ $((IP % 25)) -eq 0 ]; then
      format-echo "INFO" "Progress: $IP/$total_ips IPs scanned ($(( (IP * 100) / total_ips ))%)"
    fi
  done
  
  print_with_separator "End of Network Scan"
  format-echo "INFO" "Found $active_count active hosts out of $total_ips scanned IPs."
  
  return $active_count
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

  print_with_separator "Active Host Scanner Script"
  format-echo "INFO" "Starting Active Host Scanner Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate network argument
  if [ -z "$NETWORK" ]; then
    format-echo "ERROR" "<network_prefix> is required."
    print_with_separator "End of Active Host Scanner Script"
    exit 1
  fi

  # Validate network format
  if ! [[ "$NETWORK" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    format-echo "ERROR" "Invalid network prefix format: $NETWORK. Expected format: X.X.X (e.g., 192.168.1)"
    print_with_separator "End of Active Host Scanner Script"
    exit 1
  fi

  # Validate IP octets are in valid range
  IFS='.' read -r A B C <<< "$NETWORK"
  if (( A < 0 || A > 255 || B < 0 || B > 255 || C < 0 || C > 255 )); then
    format-echo "ERROR" "Network prefix out of range: $NETWORK. Each octet must be between 0 and 255."
    print_with_separator "End of Active Host Scanner Script"
    exit 1
  fi

  # Check if ping is available
  if ! command -v ping &> /dev/null; then
    format-echo "ERROR" "The 'ping' utility is not available. Please install it to use this script."
    print_with_separator "End of Active Host Scanner Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # SCANNING OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Scanning network $NETWORK.0/24 for active hosts..."
  
  # Perform network scan
  scan_network
  ACTIVE_HOSTS=$?
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "Network scan completed successfully."
  format-echo "INFO" "Total active hosts: $ACTIVE_HOSTS"
  print_with_separator "End of Active Host Scanner Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
