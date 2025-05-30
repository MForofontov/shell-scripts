#!/bin/bash
# firewall_configurator.sh
# Script to configure basic firewall rules using UFW.

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

ADDITIONAL_PORTS=()
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Firewall Configurator Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script configures basic firewall rules using UFW."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [additional_ports]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Path to save the log messages."
  echo -e "  \033[1;36m[additional_ports]\033[0m  (Optional) Space-separated list of additional ports to allow."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log firewall.log 8080 3306"
  echo "  $0 8080"
  echo "  $0"
  print_with_separator
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          log_message "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        ADDITIONAL_PORTS+=("$1")
        shift
        ;;
    esac
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

  print_with_separator "Firewall Configurator Script"
  log_message "INFO" "Starting Firewall Configurator Script..."

  # Check if UFW is installed
  if ! command -v ufw &> /dev/null; then
    log_message "ERROR" "UFW is not installed. Please install it and try again."
    print_with_separator "End of Firewall Configurator Script"
    exit 1
  fi

  # Configure default firewall rules
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow http
  ufw allow https
  log_message "INFO" "Default rules applied: deny incoming, allow outgoing, allow SSH, HTTP, and HTTPS."

  # Allow additional ports if specified
  for port in "${ADDITIONAL_PORTS[@]}"; do
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
      log_message "ERROR" "Invalid port: $port. Skipping."
      continue
    fi
    ufw allow "$port"
    log_message "INFO" "Allowed port $port."
  done

  # Enable UFW
  if ufw enable; then
    log_message "SUCCESS" "Firewall enabled successfully."
  else
    log_message "ERROR" "Failed to enable the firewall."
    print_with_separator "End of Firewall Configurator Script"
    exit 1
  fi

  print_with_separator "End of Firewall Configurator Script"
  log_message "SUCCESS" "Firewall configuration completed successfully."
}

main "$@"