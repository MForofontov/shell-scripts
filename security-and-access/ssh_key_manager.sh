#!/bin/bash
# ssh_key_manager.sh
# Script to generate and distribute SSH keys.

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
  print_with_separator "SSH Key Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates and distributes SSH keys for a user."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <username> <remote_server> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<username>\033[0m          (Required) The username for whom the SSH key will be generated."
  echo -e "  \033[1;33m<remote_server>\033[0m     (Required) The remote server to distribute the SSH key to."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 user user@hostname --log ssh_key_manager.log"
  echo "  $0 user user@hostname"
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
      if [ -z "$USERNAME" ]; then
        USERNAME="$1"
      elif [ -z "$REMOTE_SERVER" ]; then
        REMOTE_SERVER="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$USERNAME" ] || [ -z "$REMOTE_SERVER" ]; then
  log_message "ERROR" "Both <username> and <remote_server> are required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Starting SSH key management for user $USERNAME on server $REMOTE_SERVER..."
print_with_separator "SSH Key Management"

# Validate the username
if id "$USERNAME" &>/dev/null; then
  log_message "INFO" "User $USERNAME exists."
else
  log_message "ERROR" "User $USERNAME does not exist."
  exit 1
fi

# Create the .ssh directory if it does not exist
SSH_DIR="/home/$USERNAME/.ssh"
if [ ! -d "$SSH_DIR" ]; then
  log_message "INFO" "Creating .ssh directory for $USERNAME."
  mkdir -p "$SSH_DIR"
  chown "$USERNAME:$USERNAME" "$SSH_DIR"
else
  log_message "INFO" ".ssh directory already exists for $USERNAME."
fi

# Generate the SSH key
KEY_FILE="$SSH_DIR/id_rsa"
if [ ! -f "$KEY_FILE" ]; then
  log_message "INFO" "Generating SSH key for $USERNAME."
  ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N ""
  chown "$USERNAME:$USERNAME" "$KEY_FILE" "$KEY_FILE.pub"
  log_message "SUCCESS" "SSH key generated for $USERNAME."
else
  log_message "INFO" "SSH key already exists for $USERNAME."
fi

# Distribute the SSH key to the remote server
log_message "INFO" "Distributing SSH key to $REMOTE_SERVER."
if ssh-copy-id -i "$KEY_FILE.pub" "$REMOTE_SERVER"; then
  log_message "SUCCESS" "SSH key successfully distributed to $REMOTE_SERVER."
else
  print_with_separator "End of SSH Key Management"
  log_message "ERROR" "Failed to distribute SSH key to $REMOTE_SERVER."
  exit 1
fi

print_with_separator "End of SSH Key Management"
log_message "SUCCESS" "SSH key management completed."