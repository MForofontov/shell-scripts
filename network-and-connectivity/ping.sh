#!/bin/bash
# ping.sh
# Script to ping a list of servers/websites and check their reachability

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
DEFAULT_WEBSITES=("google.com" "github.com" "stackoverflow.com")
PING_COUNT=3
TIMEOUT=5
WEBSITES=()
LOG_FILE="/dev/null"
SHOW_DETAILS=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Ping Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script pings a list of servers/websites and checks their reachability."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--websites <site1,site2,...>] [--count <number>] [--timeout <seconds>] [--log <file>] [--details] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m--websites <site1,site2,...>\033[0m   (Optional) Comma-separated list of websites to ping (default: ${DEFAULT_WEBSITES[*]})"
  echo -e "  \033[1;36m--count <number>\033[0m               (Optional) Number of ping attempts (default: $PING_COUNT)"
  echo -e "  \033[1;36m--timeout <seconds>\033[0m            (Optional) Timeout for each ping attempt (default: $TIMEOUT)"
  echo -e "  \033[1;33m--details\033[0m                      (Optional) Show detailed ping statistics"
  echo -e "  \033[1;33m--log <file>\033[0m                   (Optional) Log output to the specified file"
  echo -e "  \033[1;33m--help\033[0m                         (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --websites google.com,example.com --count 5 --timeout 3 --log ping_results.txt"
  echo "  $0 --websites github.com --details"
  echo "  $0"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  WEBSITES=("${DEFAULT_WEBSITES[@]}")
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --websites)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No websites provided after --websites."
          usage
        fi
        IFS=',' read -r -a WEBSITES <<< "$2"
        shift 2
        ;;
      --count)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid count value: $2"
          usage
        fi
        PING_COUNT="$2"
        shift 2
        ;;
      --timeout)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid timeout value: $2"
          usage
        fi
        TIMEOUT="$2"
        shift 2
        ;;
      --details)
        SHOW_DETAILS=true
        shift
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

#=====================================================================
# PING FUNCTIONS
#=====================================================================
# Function to get ping command with correct options for the OS
get_ping_command() {
  local count="$1"
  local timeout="$2"
  local target="$3"
  
  # Check if we're on macOS or Linux
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS ping format
    echo "ping -c $count -t $timeout $target"
  else
    # Linux ping format
    echo "ping -c $count -W $timeout $target"
  fi
}

# Extract average time from ping output in a cross-platform way
extract_avg_time() {
  local ping_output="$1"
  
  # For macOS ping output format
  if [[ "$ping_output" =~ min/avg/max/stddev[[:space:]]*=[[:space:]]*([0-9.]+)/([0-9.]+)/([0-9.]+)/([0-9.]+)[[:space:]]*ms ]]; then
    echo "${BASH_REMATCH[2]}"
    return
  fi
  
  # For Linux ping output format
  if [[ "$ping_output" =~ rtt[[:space:]]*min/avg/max/mdev[[:space:]]*=[[:space:]]*([0-9.]+)/([0-9.]+)/([0-9.]+)/([0-9.]+)[[:space:]]*ms ]]; then
    echo "${BASH_REMATCH[2]}"
    return
  fi
  
  # Fallback to grep method - make sure to strip any "ms" suffix
  local avg_time
  avg_time=$(echo "$ping_output" | grep -o "avg=[0-9.]*" | cut -d= -f2 | sed 's/ms//g' | tr -d ' ')
  
  if [[ -n "$avg_time" ]]; then
    echo "$avg_time"
  else
    echo "N/A"
  fi
}

ping_websites() {
  local success_count=0
  local failure_count=0
  local total_sites=${#WEBSITES[@]}
  
  # Arrays to store results for summary table
  declare -a site_column
  declare -a status_column
  declare -a time_column
  
  for SITE in "${WEBSITES[@]}"; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    format-echo "INFO" "Pinging $SITE..."
    
    # Get the appropriate ping command for this OS
    local ping_cmd
    ping_cmd=$(get_ping_command "$PING_COUNT" "$TIMEOUT" "$SITE")
    
    # Run ping and capture output for detailed stats
    local ping_output
    if ping_output=$(eval "$ping_cmd" 2>&1); then
      # Extract average round trip time if details requested
      local avg_time="N/A"
      if [[ "$SHOW_DETAILS" == true ]]; then
        avg_time=$(extract_avg_time "$ping_output")
      fi
      
      format-echo "SUCCESS" "$TIMESTAMP: $SITE is reachable."
      
      # Store for summary table - don't add "ms" here
      site_column+=("$SITE")
      status_column+=("\033[1;32mUP\033[0m")
      time_column+=("$avg_time")
      
      success_count=$((success_count + 1))
    else
      format-echo "ERROR" "$TIMESTAMP: $SITE is unreachable."
      
      # Store for summary table
      site_column+=("$SITE")
      status_column+=("\033[1;31mDOWN\033[0m")
      time_column+=("N/A")
      
      failure_count=$((failure_count + 1))
    fi
    
    # Show detailed output if requested
    if [[ "$SHOW_DETAILS" == true && -n "$ping_output" ]]; then
      echo "----------------------------------------------------------------------------------------"
      echo "$ping_output" | grep -v "PING"
      echo "----------------------------------------------------------------------------------------"
    fi
  done
  
  # Display summary table
  print_with_separator "Ping Results Summary"
  if [[ "$SHOW_DETAILS" == true ]]; then
    printf "%-40s %-15s %-20s\n" "WEBSITE" "STATUS" "AVG RESPONSE"
  else
    printf "%-40s %-15s\n" "WEBSITE" "STATUS"
  fi
  echo "----------------------------------------------------------------------------------------"
  
  for i in "${!site_column[@]}"; do
    if [[ "$SHOW_DETAILS" == true ]]; then
      # Add "ms" during display if time is not N/A
      local time_display="${time_column[$i]}"
      if [[ "$time_display" != "N/A" ]]; then
        time_display="${time_display} ms"
      fi
      printf "%-40s %-15b %-20s\n" "${site_column[$i]}" "${status_column[$i]}" "           $time_display"
    else
      printf "%-40s %-15b\n" "${site_column[$i]}" "${status_column[$i]}"
    fi
  done
  
  echo "----------------------------------------------------------------------------------------"
  echo "Summary: $success_count up, $failure_count down out of $total_sites websites."
  
  # Return success if all websites were reachable
  return $((failure_count > 0))
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

  print_with_separator "Ping Script"
  format-echo "INFO" "Starting Ping Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate websites
  if [ "${#WEBSITES[@]}" -eq 0 ]; then
    format-echo "ERROR" "At least one website is required."
    print_with_separator "End of Ping Script"
    exit 1
  fi
  
  # Check if ping command is available
  if ! command -v ping &> /dev/null; then
    format-echo "ERROR" "The 'ping' command is not available."
    print_with_separator "End of Ping Script"
    exit 1
  fi
  
  format-echo "INFO" "Will ping ${#WEBSITES[@]} website(s) with count=$PING_COUNT and timeout=$TIMEOUT seconds."

  #---------------------------------------------------------------------
  # PING OPERATION
  #---------------------------------------------------------------------
  if ping_websites; then
    format-echo "SUCCESS" "All ping tests completed successfully."
  else
    format-echo "WARNING" "Some websites could not be reached. Check the results for details."
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Ping operation completed."
  print_with_separator "End of Ping Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
