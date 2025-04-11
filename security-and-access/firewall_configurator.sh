#!/bin/bash
# firewall_configurator.sh
# Script to configure basic firewall rules using UFW.

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
usage() {
  print_with_separator "Firewall Configurator Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script configures basic firewall rules using UFW."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [additional_ports]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m[additional_ports]\033[0m  (Optional) Space-separated list of additional ports to allow."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 8080 3306"
  echo "  $0"
  print_with_separator
  exit 1
}

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
  log_message "ERROR" "UFW is not installed. Please install it and try again."
  exit 1
fi

# Parse input arguments
ADDITIONAL_PORTS=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    *)
      ADDITIONAL_PORTS+=("$1")
      shift
      ;;
  esac
done

log_message "INFO" "Starting firewall configuration..."
print_with_separator "Firewall Configuration"

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
  print_with_separator "End of Firewall Configuration"
  exit 1
fi

print_with_separator "End of Firewall Configuration"
log_message "SUCCESS" "Firewall configuration completed."