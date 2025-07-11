#!/usr/bin/env bash
# http-status-code-checker.sh
# Script to check HTTP status codes for a list of URLs

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
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
URLS=()
LOG_FILE="/dev/null"
TIMEOUT=10
RETRY_COUNT=2
SHOW_HEADERS=false
VERBOSE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "HTTP Status Code Checker Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks HTTP status codes for a list of URLs."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <url1> <url2> ... [--log <log_file>] [--timeout <seconds>] [--retry <count>] [--headers] [--verbose] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<url1> <url2> ...\033[0m  (Required) List of URLs to check."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--timeout <seconds>\033[0m (Optional) Connection timeout in seconds (default: $TIMEOUT)."
  echo -e "  \033[1;33m--retry <count>\033[0m    (Optional) Number of retry attempts (default: $RETRY_COUNT)."
  echo -e "  \033[1;33m--headers\033[0m          (Optional) Show response headers."
  echo -e "  \033[1;33m--verbose\033[0m          (Optional) Show more detailed information."
  echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 https://google.com https://github.com --log custom_log.log"
  echo "  $0 https://example.com --timeout 5 --retry 3 --verbose"
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
      --timeout)
        if [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
          TIMEOUT="$2"
          shift 2
        else
          format-echo "ERROR" "Invalid or missing argument for --timeout"
          usage
        fi
        ;;
      --retry)
        if [[ -n "${2:-}" ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
          RETRY_COUNT="$2"
          shift 2
        else
          format-echo "ERROR" "Invalid or missing argument for --retry"
          usage
        fi
        ;;
      --headers)
        SHOW_HEADERS=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --help)
        usage
        ;;
      *)
        URLS+=("$1")
        shift
        ;;
    esac
  done
}

#=====================================================================
# HTTP STATUS CHECK FUNCTIONS
#=====================================================================
check_status_codes() {
  local success_count=0
  local failure_count=0
  local total_urls=${#URLS[@]}
  
  # Arrays to store table rows and log messages
  declare -a table_rows
  declare -a verbose_messages
  declare -a header_messages
  
  # Process all URLs and store output
  for URL in "${URLS[@]}"; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Store verbose information if enabled
    if [[ "$VERBOSE" == true ]]; then
      verbose_messages+=("$(format-echo "INFO" "Checking URL: $URL (Timeout: ${TIMEOUT}s, Retries: $RETRY_COUNT)" 2>&1)")
    fi
    
    # Use curl with retries and timeout
    local curl_cmd="curl -o /dev/null -s -w \"%{http_code} %{time_total} %{size_download}\" "
    curl_cmd+="--connect-timeout $TIMEOUT --retry $RETRY_COUNT "
    
    # If headers requested, get them too
    local headers=""
    if [[ "$SHOW_HEADERS" == true ]]; then
      headers=$(curl -sI "$URL" | head -n 20)
    fi
    
    # Execute the curl command
    local result
    result=$(eval "$curl_cmd \"$URL\"")
    
    # Parse the results
    STATUS_CODE=$(echo "$result" | cut -d' ' -f1)
    RESPONSE_TIME=$(echo "$result" | cut -d' ' -f2)
    RESPONSE_SIZE=$(echo "$result" | cut -d' ' -f3)
    
    # Format the status code with appropriate color
    local color_code
    if [[ "$STATUS_CODE" -ge 200 && "$STATUS_CODE" -lt 300 ]]; then
      color_code="32"  # Green
      result_text="SUCCESS"
      success_count=$((success_count + 1))
    elif [[ "$STATUS_CODE" -ge 300 && "$STATUS_CODE" -lt 400 ]]; then
      color_code="33"  # Yellow
      result_text="REDIRECT"
      success_count=$((success_count + 1))
    elif [[ "$STATUS_CODE" -ge 400 && "$STATUS_CODE" -lt 500 ]]; then
      color_code="31"  # Red
      result_text="CLIENT ERROR"
      failure_count=$((failure_count + 1))
    elif [[ "$STATUS_CODE" -ge 500 ]]; then
      color_code="31"  # Red
      result_text="SERVER ERROR"
      failure_count=$((failure_count + 1))
    else
      color_code="36"  # Cyan
      result_text="UNKNOWN"
      failure_count=$((failure_count + 1))
    fi
    
    # Store the table row
    table_rows+=("$(printf "%-40s \033[1;${color_code}m%-7s\033[0m %s\n" "$(echo "$URL" | cut -c 1-40)" "$STATUS_CODE" "             $result_text")")
    
    # Store the log message
    verbose_messages+=("$(format-echo "INFO" "$TIMESTAMP: $URL: $STATUS_CODE (Response time: ${RESPONSE_TIME}s, Size: ${RESPONSE_SIZE} bytes)" 2>&1)")
    
    # Store headers if requested
    if [[ "$SHOW_HEADERS" == true && -n "$headers" ]]; then
      header_messages+=("$(format-echo "INFO" "Headers for $URL:" 2>&1)")
      header_messages+=("$(echo "$headers" | sed 's/^/    /')")
    fi
  done
  
  # First display the complete table
  print_with_separator "HTTP Status Check Results"
  printf "%-40s %-20s %-30s\n" "URL" "STATUS CODE" "RESULT"
  echo "----------------------------------------------------------------------------------------"
  for row in "${table_rows[@]}"; do
    echo -e "$row"
  done
  echo "----------------------------------------------------------------------------------------"
  echo "Summary: $success_count successful, $failure_count failed out of $total_urls URLs checked."
  print_with_separator "End of HTTP Status Check Results"
  
  # Then display all the log messages
  if [ ${#verbose_messages[@]} -gt 0 ]; then
    print_with_separator "Detailed Information"
    for msg in "${verbose_messages[@]}"; do
      echo -e "$msg"
    done
  fi
  
  # Display headers if any
  if [ ${#header_messages[@]} -gt 0 ]; then
    print_with_separator "Response Headers"
    for header in "${header_messages[@]}"; do
      echo -e "$header"
    done
  fi
  
  # Return success if all URLs were successful
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

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "HTTP Status Code Checker Script"
  format-echo "INFO" "Starting HTTP Status Code Checker Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if curl is available
  if ! command -v curl &> /dev/null; then
    format-echo "ERROR" "The 'curl' command is not available. Please install it to use this script."
    print_with_separator "End of HTTP Status Code Checker Script"
    exit 1
  fi
  
  # Validate URLs
  if [ "${#URLS[@]}" -eq 0 ]; then
    format-echo "ERROR" "At least one URL is required."
    print_with_separator "End of HTTP Status Code Checker Script"
    exit 1
  fi
  
  # Validate URLs format (basic check)
  for URL in "${URLS[@]}"; do
    if ! [[ "$URL" =~ ^https?:// ]]; then
      format-echo "WARNING" "URL $URL does not start with http:// or https://"
    fi
  done

  #---------------------------------------------------------------------
  # HTTP STATUS CHECK OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Checking HTTP status codes for ${#URLS[@]} URLs..."
  
  # Perform the status check
  if check_status_codes; then
    format-echo "SUCCESS" "All HTTP status checks completed successfully."
  else
    format-echo "WARNING" "Some HTTP status checks failed. Check the results for details."
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "HTTP status code check operation completed."
  print_with_separator "End of HTTP Status Code Checker Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
