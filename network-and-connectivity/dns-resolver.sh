#!/bin/bash
# dns-resolver.sh
# Script to test DNS resolution for a list of domains

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
DOMAINS=()
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "DNS Resolver Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script tests DNS resolution for a list of domains."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <domain1> <domain2> ... [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<domain1> <domain2> ...\033[0m  (Required) List of domains to resolve."
  echo -e "  \033[1;33m--log <log_file>\033[0m         (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 google.com github.com --log custom_log.log"
  echo "  $0 example.com"
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
        DOMAINS+=("$1")
        shift
        ;;
    esac
  done
}

#=====================================================================
# DNS RESOLUTION FUNCTIONS
#=====================================================================
resolve_domains() {
  local success_count=0
  local total_domains=${#DOMAINS[@]}
  
  print_with_separator "DNS Resolution Results"
  printf "%-25s %-15s %-20s %-s\n" "DOMAIN" "STATUS" "IPv4 ADDRESS" "IPv6 ADDRESS"
  echo "----------------------------------------------------------------------------------------"
  
  for DOMAIN in "${DOMAINS[@]}"; do
    
    # A record (IPv4)
    IPv4=$(dig +short A "$DOMAIN" | head -n 1)
    
    # AAAA record (IPv6)
    IPv6=$(dig +short AAAA "$DOMAIN" | head -n 1)
    
    # MX record
    MX=$(dig +short MX "$DOMAIN" | head -n 1)
    
    # Determine resolution status and print table row
    if [ -z "$IPv4" ] && [ -z "$IPv6" ] && [ -z "$MX" ]; then
      printf "%-25s \033[1;31m%-15s\033[0m %-20s %-s\n" "$DOMAIN" "FAILED" "No records" "No records"
    else
      printf "%-25s \033[1;32m%-15s\033[0m %-20s %-s\n" "$DOMAIN" "SUCCESS" "${IPv4:-No IPv4}" "${IPv6:-No IPv6}"
      
      success_count=$((success_count + 1))
    fi
  done
  
  echo "----------------------------------------------------------------------------------------"
  echo "Resolution summary: $success_count of $total_domains domains resolved successfully."
  print_with_separator "End of DNS Resolution Results"
  
  # Return true if all domains resolved successfully
  [ "$success_count" -eq "$total_domains" ]
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

  print_with_separator "DNS Resolver Script"
  format-echo "INFO" "Starting DNS Resolver Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if dig command is available
  if ! command -v dig &> /dev/null; then
    format-echo "ERROR" "The 'dig' command is not available. Please install bind-utils or dnsutils package."
    print_with_separator "End of DNS Resolver Script"
    exit 1
  fi
  
  # Validate domains
  if [ "${#DOMAINS[@]}" -eq 0 ]; then
    format-echo "ERROR" "At least one domain is required."
    print_with_separator "End of DNS Resolver Script"
    exit 1
  fi

  format-echo "INFO" "Testing DNS resolution for the following domains: ${DOMAINS[*]}"
  
  # Check if we can reach a DNS server
  if ! dig +short +time=2 +tries=1 google.com &> /dev/null; then
    format-echo "WARNING" "DNS connectivity check failed. Name resolution may not work properly."
  else
    format-echo "INFO" "DNS connectivity check passed."
  fi

  #---------------------------------------------------------------------
  # DNS RESOLUTION OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Beginning DNS resolution..."
  
  # Perform DNS resolution
  if resolve_domains; then
    format-echo "SUCCESS" "All domains resolved successfully."
  else
    format-echo "WARNING" "Some domains failed to resolve. Check the output for details."
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "DNS resolution operation completed."
  print_with_separator "End of DNS Resolver Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
