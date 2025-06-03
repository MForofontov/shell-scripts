#!/bin/bash
# arp-table-viewer.sh
# Script to view and log the ARP table

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "ARP Table Viewer Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script fetches and logs the ARP table."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_log.log"
  echo "  $0"
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
          log_message "ERROR" "Missing argument for --log"
          usage
        fi
        ;;
      --help)
        usage
        ;;
      *)
        log_message "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

#=====================================================================
# ARP TABLE FUNCTIONS
#=====================================================================
format_arp_table() {
  # Create a header for the table
  printf "\n%-20s %-20s %-20s\n" "IP ADDRESS" "MAC ADDRESS" "INTERFACE"
  echo "------------------------------------------------------"
  
  # Process the ARP table based on OS type
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS format
    arp -a | while read -r line; do
      IP=$(echo "$line" | awk '{print $2}' | tr -d '()')
      MAC=$(echo "$line" | awk '{print $4}')
      IFACE=$(echo "$line" | awk '{print $6}')
      
      # Skip incomplete entries
      if [[ "$MAC" == "(incomplete)" ]]; then
        MAC="N/A"
      fi
      
      printf "%-20s %-20s %-20s\n" "$IP" "$MAC" "$IFACE"
    done
  else
    # Linux format
    arp -n | grep -v "Address" | while read -r line; do
      IP=$(echo "$line" | awk '{print $1}')
      MAC=$(echo "$line" | awk '{print $3}')
      IFACE=$(echo "$line" | awk '{print $5}')
      
      if [[ "$MAC" == "(incomplete)" ]]; then
        MAC="N/A"
      fi
      
      printf "%-20s %-20s %-20s\n" "$IP" "$MAC" "$IFACE"
    done
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

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "ARP Table Viewer Script"
  log_message "INFO" "Starting ARP Table Viewer Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if arp command is available
  if ! command -v arp &> /dev/null; then
    log_message "ERROR" "The 'arp' command is not available on this system."
    print_with_separator "End of ARP Table Viewer Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # ARP TABLE RETRIEVAL
  #---------------------------------------------------------------------
  log_message "INFO" "Fetching ARP table..."
  print_with_separator "ARP Table Output"

  # Fetch and format the ARP table
  if format_arp_table; then
    print_with_separator "End of ARP Table Output"
    log_message "SUCCESS" "ARP table fetched and displayed successfully."
  else
    print_with_separator "End of ARP Table Output"
    log_message "ERROR" "Failed to fetch ARP table."
    print_with_separator "End of ARP Table Viewer Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  log_message "INFO" "ARP table operation completed."
  print_with_separator "End of ARP Table Viewer Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"