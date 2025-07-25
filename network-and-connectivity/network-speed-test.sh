#!/bin/bash
# network-speed-test.sh
# Script to run a network speed test using speedtest-cli

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
SERVER_ID=""
SIMPLE_OUTPUT=false
JSON_OUTPUT=false
SHOW_SERVERS=false
LIST_COUNT=0

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Network Speed Test Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script runs a network speed test using speedtest-cli."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m        (Optional) Path to save the speed test results."
  echo -e "  \033[1;33m--server <server_id>\033[0m    (Optional) Test against a specific server."
  echo -e "  \033[1;33m--simple\033[0m                (Optional) Simplified output format."
  echo -e "  \033[1;33m--json\033[0m                  (Optional) Output results as JSON."
  echo -e "  \033[1;33m--list\033[0m                  (Optional) List nearby servers instead of testing."
  echo -e "  \033[1;33m--list-count <count>\033[0m    (Optional) Number of servers to list (default: 10)."
  echo -e "  \033[1;33m--help\033[0m                  (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log speed_results.log"
  echo "  $0 --server 1234 --simple"
  echo "  $0 --list --list-count 5"
  echo "  $0 --json"
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
      --server)
        if [[ -n "${2:-}" ]]; then
          SERVER_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --server"
          usage
        fi
        ;;
      --simple)
        SIMPLE_OUTPUT=true
        shift
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --list)
        SHOW_SERVERS=true
        shift
        ;;
      --list-count)
        if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
          LIST_COUNT="$2"
          shift 2
        else
          format-echo "ERROR" "Invalid or missing argument for --list-count"
          usage
        fi
        ;;
      --help)
        usage
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

#=====================================================================
# NETWORK SPEED TEST FUNCTIONS
#=====================================================================
check_speedtest_cli() {
  format-echo "INFO" "Checking for speedtest-cli..."
  
  if ! command -v speedtest-cli &> /dev/null; then
    format-echo "INFO" "speedtest-cli is not installed. Installing..."
    
    if [[ "$(uname)" == "Linux" ]]; then
      if ! sudo apt-get install -y speedtest-cli; then
        format-echo "ERROR" "Failed to install speedtest-cli. Please install it manually."
        return 1
      fi
    elif [[ "$(uname)" == "Darwin" ]]; then
      if ! brew install speedtest-cli; then
        format-echo "ERROR" "Failed to install speedtest-cli. Please install it manually."
        return 1
      fi
    else
      format-echo "ERROR" "Unsupported operating system: $(uname)"
      format-echo "INFO" "Please install speedtest-cli manually for your system."
      return 1
    fi
    
    format-echo "SUCCESS" "speedtest-cli installed successfully."
  else
    format-echo "INFO" "speedtest-cli is already installed."
  fi
  
  return 0
}

list_servers() {
  local count="${1:-10}"
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  
  format-echo "INFO" "$TIMESTAMP: Listing $count closest speedtest servers..."
  
  if ! speedtest-cli --list | head -n "$((count + 1))"; then
    format-echo "ERROR" "Failed to list speedtest servers."
    return 1
  fi
  
  return 0
}

run_speed_test() {
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  format-echo "INFO" "$TIMESTAMP: Running network speed test..."
  
  local cmd_args=()
  
  # Add options based on user input
  if [[ -n "$SERVER_ID" ]]; then
    cmd_args+=("--server" "$SERVER_ID")
    format-echo "INFO" "Using server ID: $SERVER_ID"
  fi
  
  if [[ "$SIMPLE_OUTPUT" == true ]]; then
    cmd_args+=("--simple")
  fi
  
  if [[ "$JSON_OUTPUT" == true ]]; then
    cmd_args+=("--json")
  fi
  
  # Run the speedtest command with any specified arguments
  if ! speedtest-cli "${cmd_args[@]}"; then
    format-echo "ERROR" "Failed to run network speed test."
    return 1
  fi
  
  format-echo "INFO" "$TIMESTAMP: Network speed test completed."
  return 0
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

  print_with_separator "Network Speed Test Script"
  format-echo "INFO" "Starting Network Speed Test Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if speedtest-cli is installed
  if ! check_speedtest_cli; then
    format-echo "ERROR" "speedtest-cli is required to run this script."
    print_with_separator "End of Network Speed Test Script"
    exit 1
  fi
  
  # Check for conflicting options
  if [[ "$SIMPLE_OUTPUT" == true && "$JSON_OUTPUT" == true ]]; then
    format-echo "WARNING" "Both --simple and --json options specified. Using --simple."
    JSON_OUTPUT=false
  fi

  #---------------------------------------------------------------------
  # SPEED TEST OPERATION
  #---------------------------------------------------------------------
  # Either list servers or run a speed test
  if [[ "$SHOW_SERVERS" == true ]]; then
    format-echo "INFO" "Listing nearby speedtest servers..."
    
    if [[ "$LIST_COUNT" -eq 0 ]]; then
      LIST_COUNT=10  # Default count if not specified
    fi
    
    if list_servers "$LIST_COUNT"; then
      format-echo "SUCCESS" "Server listing completed."
    else
      format-echo "ERROR" "Failed to list servers."
      print_with_separator "End of Network Speed Test Script"
      exit 1
    fi
  else
    format-echo "INFO" "Starting network speed test..."
    
    if run_speed_test; then
      format-echo "SUCCESS" "Network speed test completed successfully."
    else
      format-echo "ERROR" "Network speed test failed."
      print_with_separator "End of Network Speed Test Script"
      exit 1
    fi
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Network speed test operation completed."
  print_with_separator "End of Network Speed Test Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
