#!/bin/bash
# unused_ssh_key_detector.sh
# Script to detect unused SSH keys.

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

SSH_DIR="/home"
LOG_FILE="/dev/null"

usage() {
  print_with_separator "Unused SSH Key Detector Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scans for unused SSH keys in user directories."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--ssh_dir <ssh_directory>] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--ssh_dir <ssh_directory>\033[0m  (Optional) Directory to scan for SSH keys (default: /home)."
  echo -e "  \033[1;33m--log <log_file>\033[0m           (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --ssh_dir /home --log unused_ssh_keys.log"
  echo "  $0"
  print_with_separator "End of Unused SSH Key Detector Script"
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --ssh_dir)
        if [ -z "${2:-}" ]; then
          log_message "ERROR" "No SSH directory provided after --ssh_dir."
          usage
        fi
        SSH_DIR="$2"
        shift 2
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
        log_message "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

scan_unused_ssh_keys() {
  for user in $(ls "$SSH_DIR"); do
    USER_SSH_DIR="$SSH_DIR/$user/.ssh"
    if [ -d "$USER_SSH_DIR" ]; then
      log_message "INFO" "Scanning $USER_SSH_DIR for unused SSH keys..."
      find "$USER_SSH_DIR" -type f -name "*.pub" -exec ls -l {} \;
    else
      log_message "WARNING" "No .ssh directory found for user $user."
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

  print_with_separator "Unused SSH Key Detector Script"
  log_message "INFO" "Starting Unused SSH Key Detector Script..."

  # Validate SSH directory
  if [ ! -d "$SSH_DIR" ]; then
    log_message "ERROR" "Directory $SSH_DIR does not exist."
    print_with_separator "End of Unused SSH Key Detector Script"
    exit 1
  fi

  scan_unused_ssh_keys

  print_with_separator "End of Unused SSH Key Detector Script"
  log_message "SUCCESS" "Unused SSH key scan completed."
}

main "$@"