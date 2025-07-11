#!/usr/bin/env bash
# ip-extractor-from-log-file.sh
# Script to extract unique IP addresses from a log file

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
INPUT_LOG=""
LOG_FILE="/dev/null"
OUTPUT_FORMAT="simple"  # simple, csv, or json
INCLUDE_IPV6=false
FILTER_PRIVATE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "IP Extractor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script extracts unique IP addresses from a log file."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <input_log> [--log <log_file>] [--format <format>] [--ipv6] [--filter-private] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<input_log>\033[0m         (Required) Path to the input log file."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--format <format>\033[0m   (Optional) Output format: simple, csv, or json (default: simple)."
  echo -e "  \033[1;33m--ipv6\033[0m              (Optional) Include IPv6 addresses in the extraction."
  echo -e "  \033[1;33m--filter-private\033[0m    (Optional) Filter out private IP addresses."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/inputlog.log --log extracted_ips.txt"
  echo "  $0 /path/to/inputlog.log --format json"
  echo "  $0 /path/to/inputlog.log --ipv6 --filter-private"
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
      --format)
        if [[ -n "${2:-}" ]]; then
          case "$2" in
            simple|csv|json)
              OUTPUT_FORMAT="$2"
              ;;
            *)
              format-echo "ERROR" "Invalid format: $2. Must be 'simple', 'csv', or 'json'."
              usage
              ;;
          esac
          shift 2
        else
          format-echo "ERROR" "Missing argument for --format"
          usage
        fi
        ;;
      --ipv6)
        INCLUDE_IPV6=true
        shift
        ;;
      --filter-private)
        FILTER_PRIVATE=true
        shift
        ;;
      --help)
        usage
        ;;
      *)
        if [ -z "$INPUT_LOG" ]; then
          INPUT_LOG="$1"
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
# IP EXTRACTION FUNCTIONS
#=====================================================================
extract_ipv4() {
  local file="$1"
  local ips

  # Extract IPv4 addresses
  ips=$(grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$file" | sort -u)
  
  # Filter private IPs if requested
  if [[ "$FILTER_PRIVATE" == true && -n "$ips" ]]; then
    echo "$ips" | grep -v -E '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'
  else
    echo "$ips"
  fi
}

extract_ipv6() {
  local file="$1"
  
  # Extract IPv6 addresses - this is a simplified pattern
  grep -oE '([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}' "$file" | sort -u
}

format_output() {
  local ipv4_list="$1"
  local ipv6_list="$2"
  
  case "$OUTPUT_FORMAT" in
    simple)
      # Simple format - just the IPs, one per line
      if [[ -n "$ipv4_list" ]]; then
        echo "$ipv4_list"
      fi
      if [[ -n "$ipv6_list" ]]; then
        echo "$ipv6_list"
      fi
      ;;
    csv)
      # CSV format
      echo "IP Address,Type"
      if [[ -n "$ipv4_list" ]]; then
        echo "$ipv4_list" | awk '{print $0 ",IPv4"}'
      fi
      if [[ -n "$ipv6_list" ]]; then
        echo "$ipv6_list" | awk '{print $0 ",IPv6"}'
      fi
      ;;
    json)
      # JSON format
      echo "{"
      echo "  \"ipv4\": ["
      if [[ -n "$ipv4_list" ]]; then
        echo "$ipv4_list" | awk '{print "    \"" $0 "\","}' | sed '$ s/,$//'
      fi
      echo "  ],"
      echo "  \"ipv6\": ["
      if [[ -n "$ipv6_list" ]]; then
        echo "$ipv6_list" | awk '{print "    \"" $0 "\","}' | sed '$ s/,$//'
      fi
      echo "  ]"
      echo "}"
      ;;
  esac
}

extract_ips() {
  format-echo "INFO" "Extracting IP addresses with options:"
  format-echo "INFO" "  Include IPv6: $INCLUDE_IPV6"
  format-echo "INFO" "  Filter private IPs: $FILTER_PRIVATE"
  format-echo "INFO" "  Output format: $OUTPUT_FORMAT"
  
  local ipv4_list=""
  local ipv6_list=""
  local extracted_count=0
  
  # Extract IPv4 addresses
  ipv4_list=$(extract_ipv4 "$INPUT_LOG")
  local ipv4_count=$(echo "$ipv4_list" | grep -v '^$' | wc -l | tr -d ' ')
  extracted_count=$ipv4_count
  
  # Extract IPv6 addresses if requested
  if [[ "$INCLUDE_IPV6" == true ]]; then
    ipv6_list=$(extract_ipv6 "$INPUT_LOG")
    local ipv6_count=$(echo "$ipv6_list" | grep -v '^$' | wc -l | tr -d ' ')
    extracted_count=$((extracted_count + ipv6_count))
  fi
  
  # If no IPs were extracted, return an error
  if [[ $extracted_count -eq 0 ]]; then
    format-echo "ERROR" "No IP addresses found in the log file."
    return 1
  fi
  
  # Format and output the results
  format_output "$ipv4_list" "$ipv6_list"
  
  format-echo "INFO" "Extracted $extracted_count unique IP addresses."
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

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "IP Extractor Script"
  format-echo "INFO" "Starting IP Extractor Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate input log file
  if [ -z "$INPUT_LOG" ]; then
    format-echo "ERROR" "Input log file is required."
    print_with_separator "End of IP Extractor Script"
    usage
  fi

  if [ ! -f "$INPUT_LOG" ]; then
    format-echo "ERROR" "Input log file $INPUT_LOG does not exist."
    print_with_separator "End of IP Extractor Script"
    exit 1
  fi

  # Check if the file is readable
  if [ ! -r "$INPUT_LOG" ]; then
    format-echo "ERROR" "Input log file $INPUT_LOG is not readable."
    print_with_separator "End of IP Extractor Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # IP EXTRACTION OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Extracting unique IP addresses from $INPUT_LOG..."

  if extract_ips; then
    format-echo "SUCCESS" "IP extraction completed successfully."
  else
    format-echo "ERROR" "IP extraction failed."
    print_with_separator "End of IP Extractor Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "IP extraction operation completed."
  print_with_separator "End of IP Extractor Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
