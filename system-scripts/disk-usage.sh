#!/bin/bash
# disk-usage.sh
# Script to check disk usage and alert if it exceeds a threshold.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0" 2>/dev/null || echo "$0")")
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
THRESHOLD=""
EMAIL=""
LOG_FILE="/dev/null"
FILESYSTEM="/"
CHECK_ALL=false
VERBOSE=false
EXIT_CODE=0

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Disk Usage Monitor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks disk usage and sends an alert if it exceeds a threshold."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <threshold> <email> [--filesystem <path>] [--all] [--verbose] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<threshold>\033[0m              (Required) Disk usage threshold percentage."
  echo -e "  \033[1;36m<email>\033[0m                  (Required) Email address to send alerts."
  echo -e "  \033[1;33m--filesystem <path>\033[0m      (Optional) Specific filesystem to check (default: /)."
  echo -e "  \033[1;33m--all\033[0m                    (Optional) Check all mounted filesystems."
  echo -e "  \033[1;33m--verbose\033[0m                (Optional) Show detailed output."
  echo -e "  \033[1;33m--log <log_file>\033[0m         (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 80 user@example.com --log disk_usage.log"
  echo "  $0 90 admin@example.com --filesystem /home"
  echo "  $0 85 sysadmin@company.com --all --verbose"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
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
      --filesystem)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No filesystem path provided after --filesystem."
          usage
        fi
        FILESYSTEM="$2"
        shift 2
        ;;
      --all)
        CHECK_ALL=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      *)
        if [ -z "$THRESHOLD" ]; then
          if ! [[ "$1" =~ ^[0-9]+$ ]]; then
            format-echo "ERROR" "Threshold must be a number: $1"
            usage
          fi
          THRESHOLD="$1"
        elif [ -z "$EMAIL" ]; then
          # Simple email validation
          if ! [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            format-echo "ERROR" "Invalid email address: $1"
            usage
          fi
          EMAIL="$1"
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        shift
        ;;
    esac
  done
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Function to check disk usage for a specific filesystem
check_fs_usage() {
  local fs="$1"
  local mount_point=$(df "$fs" | tail -1 | awk '{print $6}')
  local usage=$(df "$fs" | tail -1 | awk '{print $5}' | sed 's/%//g')
  local size=$(df -h "$fs" | tail -1 | awk '{print $2}')
  local used=$(df -h "$fs" | tail -1 | awk '{print $3}')
  local avail=$(df -h "$fs" | tail -1 | awk '{print $4}')
  
  if [[ "$VERBOSE" == "true" ]]; then
    format-echo "INFO" "Filesystem: $fs (mounted at $mount_point)"
    format-echo "INFO" "  Size: $size, Used: $used, Available: $avail, Usage: $usage%"
  fi
  
  if [ "$usage" -ge "$THRESHOLD" ]; then
    local alert_message="Disk usage alert for $fs (mounted at $mount_point): ${usage}% used (exceeds threshold of ${THRESHOLD}%)"
    format-echo "WARNING" "$alert_message"
    
    # Add more details to email
    local email_message="$alert_message\n\n"
    email_message+="Filesystem details:\n"
    email_message+="  Total size: $size\n"
    email_message+="  Used: $used\n"
    email_message+="  Available: $avail\n\n"
    email_message+="Server: $(hostname)\n"
    email_message+="Timestamp: $(date)"
    
    if command -v mail &>/dev/null; then
      echo -e "$email_message" | mail -s "Disk Usage Alert: $fs at ${usage}%" "$EMAIL"
      format-echo "INFO" "Alert email sent to $EMAIL"
    else
      format-echo "ERROR" "mail command not found. Cannot send email alert."
    fi
    
    EXIT_CODE=1
    return 1
  else
    format-echo "SUCCESS" "Disk usage for $fs is at ${usage}%, below the threshold of ${THRESHOLD}%."
    return 0
  fi
}

# Function to check all mounted filesystems
check_all_filesystems() {
  local fs_list=$(df -t ext2 -t ext3 -t ext4 -t xfs -t btrfs -t hfs -t apfs 2>/dev/null | tail -n +2 | awk '{print $6}' || echo "/")
  
  # On macOS, fallback to simpler approach if the above fails
  if [ -z "$fs_list" ]; then
    fs_list=$(df | tail -n +2 | awk '{print $9}' | grep -v "^/dev" || echo "/")
  fi
  
  format-echo "INFO" "Checking all mounted filesystems..."
  local checked=0
  local exceeded=0
  
  for fs in $fs_list; do
    # Skip certain special filesystems
    if [[ "$fs" == "/dev" || "$fs" == "/dev/"* || "$fs" == "/proc" || "$fs" == "/sys" || "$fs" == "/run" ]]; then
      [[ "$VERBOSE" == "true" ]] && format-echo "INFO" "Skipping special filesystem: $fs"
      continue
    fi
    
    checked=$((checked+1))
    check_fs_usage "$fs" || exceeded=$((exceeded+1))
  done
  
  format-echo "INFO" "Checked $checked filesystems, $exceeded exceeded the threshold."
  
  if [ $exceeded -gt 0 ]; then
    return 1
  else
    return 0
  fi
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

  print_with_separator "Disk Usage Monitor Script"
  format-echo "INFO" "Starting Disk Usage Monitor Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate required arguments
  if [ -z "$THRESHOLD" ] || [ -z "$EMAIL" ]; then
    format-echo "ERROR" "Both <threshold> and <email> are required."
    print_with_separator "End of Disk Usage Monitor Script"
    usage
  fi
  
  # Check if mail command is available
  if ! command -v mail &>/dev/null; then
    format-echo "WARNING" "mail command not available. Email alerts will not be sent."
  fi

  #---------------------------------------------------------------------
  # DISK USAGE CHECKING
  #---------------------------------------------------------------------
  if [[ "$CHECK_ALL" == "true" ]]; then
    check_all_filesystems
  else
    check_fs_usage "$FILESYSTEM"
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Disk Usage Monitor Script"
  if [ $EXIT_CODE -eq 0 ]; then
    format-echo "SUCCESS" "Disk usage monitoring completed successfully."
  else
    format-echo "WARNING" "Disk usage monitoring completed. Threshold exceeded on one or more filesystems."
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
