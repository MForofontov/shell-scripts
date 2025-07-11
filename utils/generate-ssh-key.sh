#!/usr/bin/env bash
# generate-ssh-key.sh
# Script to generate an SSH key pair.

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
KEY_NAME=""
KEY_DIR=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Generate SSH Key Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates an SSH key pair."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <key_name> <key_dir> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<key_name>\033[0m       (Required) Name of the SSH key."
  echo -e "  \033[1;33m<key_dir>\033[0m        (Required) Directory to save the SSH key."
  echo -e "  \033[1;33m--log <log_file>\033[0m (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m           (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 my_key /path/to/keys --log generate_ssh.log"
  echo "  $0 my_key /path/to/keys"
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
        if [ -z "$KEY_NAME" ]; then
          KEY_NAME="$1"
        elif [ -z "$KEY_DIR" ]; then
          KEY_DIR="$1"
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
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

  print_with_separator "Generate SSH Key Script"
  format-echo "INFO" "Starting Generate SSH Key Script..."

  # Validate required arguments
  if [ -z "$KEY_NAME" ] || [ -z "$KEY_DIR" ]; then
    format-echo "ERROR" "Both <key_name> and <key_dir> are required."
    print_with_separator "End of Generate SSH Key Script"
    usage
  fi

  # Check if ssh-keygen is installed
  if ! command -v ssh-keygen &> /dev/null; then
    format-echo "ERROR" "ssh-keygen is not installed. Please install OpenSSH tools."
    print_with_separator "End of Generate SSH Key Script"
    exit 1
  fi

  # Ensure the key directory exists
  format-echo "INFO" "Ensuring the key directory exists: $KEY_DIR"
  mkdir -p "$KEY_DIR"

  # Generate SSH key pair
  format-echo "INFO" "Generating SSH key pair..."
  if ssh-keygen -t rsa -b 4096 -f "$KEY_DIR/$KEY_NAME" -N ""; then
    format-echo "SUCCESS" "SSH key pair generated successfully at:"
    format-echo "SUCCESS" "Private key: $KEY_DIR/$KEY_NAME"
    format-echo "SUCCESS" "Public key: $KEY_DIR/${KEY_NAME}.pub"
  else
    print_with_separator "End of Generate SSH Key Script"
    format-echo "ERROR" "Failed to generate SSH key pair."
    exit 1
  fi

  print_with_separator "End of Generate SSH Key Script"
  format-echo "SUCCESS" "SSH key generation process completed successfully."
}

main "$@"
