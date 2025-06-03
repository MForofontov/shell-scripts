#!/bin/bash
# firewall_configurator.sh
# Script to configure basic firewall rules using UFW.

set -euo pipefail

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
          format-echo "ERROR" "No log file provided after --log."
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
  format-echo "INFO" "Starting Firewall Configurator Script..."

  # Check if UFW is installed
  if ! command -v ufw &> /dev/null; then
    format-echo "ERROR" "UFW is not installed. Please install it and try again."
    print_with_separator "End of Firewall Configurator Script"
    exit 1
  fi

  # Configure default firewall rules
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow http
  ufw allow https
  format-echo "INFO" "Default rules applied: deny incoming, allow outgoing, allow SSH, HTTP, and HTTPS."

  # Allow additional ports if specified
  for port in "${ADDITIONAL_PORTS[@]}"; do
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
      format-echo "ERROR" "Invalid port: $port. Skipping."
      continue
    fi
    ufw allow "$port"
    format-echo "INFO" "Allowed port $port."
  done

  # Enable UFW
  if ufw enable; then
    format-echo "SUCCESS" "Firewall enabled successfully."
  else
    format-echo "ERROR" "Failed to enable the firewall."
    print_with_separator "End of Firewall Configurator Script"
    exit 1
  fi

  print_with_separator "End of Firewall Configurator Script"
  format-echo "SUCCESS" "Firewall configuration completed successfully."
}

main "$@"