#!/bin/bash
# password_generator.sh
# Script to generate strong, random passwords.

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
  print_with_separator "Password Generator Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates strong, random passwords."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--length <length>] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--length <length>\033[0m  (Optional) Length of the password (default: 16)."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Path to save the generated password."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --length 20 --log password.log"
  echo "  $0 --length 12"
  echo "  $0"
  print_with_separator
  exit 1
}

# Default values
LENGTH=16
LOG_FILE=""

# Parse input arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --length)
      if [ -z "$2" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
        log_message "ERROR" "Invalid length value: $2"
        usage
      fi
      LENGTH="$2"
      shift 2
      ;;
    --log)
      if [ -z "$2" ]; then
        log_message "ERROR" "No log file provided after --log."
        usage
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      log_message "ERROR" "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE."
    exit 1
  fi
fi

log_message "INFO" "Generating a password of length $LENGTH..."
print_with_separator "Password Generation"

# Function to generate a random password
generate_password() {
  local length=$1
  tr -dc 'A-Za-z0-9!@#$%^&*()_+{}[]' < /dev/urandom | head -c "$length"
}

# Generate the password
PASSWORD=$(generate_password "$LENGTH")

# Display the generated password
echo "Generated password: $PASSWORD"

# Log the password if a log file is specified
if [ -n "$LOG_FILE" ]; then
  echo "$PASSWORD" > "$LOG_FILE"
  log_message "SUCCESS" "Password saved to $LOG_FILE."
else
  log_message "SUCCESS" "Password displayed on the console."
fi

print_with_separator "End of Password Generation"