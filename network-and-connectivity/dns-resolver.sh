#!/bin/bash
# dns-resolver.sh
# Script to test DNS resolution for a list of domains

set -euo pipefail

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

DOMAINS=()
LOG_FILE="/dev/null"

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
        DOMAINS+=("$1")
        shift
        ;;
    esac
  done
}

resolve_domains() {
  for DOMAIN in "${DOMAINS[@]}"; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    IP=$(dig +short "$DOMAIN" | head -n 1)
    if [ -z "$IP" ]; then
      log_message "ERROR" "$TIMESTAMP: $DOMAIN: DNS resolution failed"
    else
      log_message "INFO" "$TIMESTAMP: $DOMAIN: Resolved to $IP"
    fi
  done
}

main() {
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "DNS Resolver Script"
  log_message "INFO" "Starting DNS Resolver Script..."

  # Validate domains
  if [ "${#DOMAINS[@]}" -eq 0 ]; then
    log_message "ERROR" "At least one domain is required."
    print_with_separator "End of DNS Resolver Script"
    exit 1
  fi

  log_message "INFO" "Testing DNS resolution for the following domains: ${DOMAINS[*]}"

  if resolve_domains; then
    log_message "SUCCESS" "DNS resolution complete."
  else
    log_message "ERROR" "Failed to resolve domains."
    print_with_separator "End of DNS Resolver Script"
    exit 1
  fi

  print_with_separator "End of DNS Resolver Script"
}

main "$@"