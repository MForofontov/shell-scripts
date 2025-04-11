#!/bin/bash
# secure_file_permissions.sh
# Script to set secure permissions for sensitive files.

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
  print_with_separator "Secure File Permissions Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script sets secure permissions for sensitive files."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m           (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log secure_permissions.log"
  echo "  $0"
  print_with_separator
  exit 1
}

# Parse input arguments
LOG_FILE="/dev/null"
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
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
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Starting to secure file permissions..."
print_with_separator "Secure File Permissions"

# List of sensitive files to secure
FILES=(
  "/etc/passwd"
  "/etc/shadow"
  "/etc/ssh/sshd_config"
)

# Secure permissions for each file
for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    log_message "INFO" "Securing permissions for $file..."
    chmod 600 "$file"
    chown root:root "$file"
    log_message "SUCCESS" "Permissions secured for $file."
  else
    log_message "WARNING" "File $file does not exist. Skipping."
  fi
done

print_with_separator "End of Secure File Permissions"
log_message "SUCCESS" "Secure file permissions enforced."