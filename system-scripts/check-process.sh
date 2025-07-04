#!/bin/bash
# check-process.sh
# Script to check if a specific process is running.

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
PROCESS_NAME=""
LOG_FILE="/dev/null"
EXIT_CODE=0

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Check Process Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks if a specific process is running."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <process_name> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<process_name>\033[0m   (Required) Name of the process to check."
  echo -e "  \033[1;33m--log <log_file>\033[0m (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m           (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 nginx --log process_check.log"
  echo "  $0 apache2"
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
      *)
        if [ -z "$PROCESS_NAME" ]; then
          PROCESS_NAME="$1"
          shift
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Check Process Script"
  format-echo "INFO" "Starting Check Process Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate process name
  if [ -z "$PROCESS_NAME" ]; then
    format-echo "ERROR" "Process name is required."
    print_with_separator "End of Check Process Script"
    usage
  fi

  #---------------------------------------------------------------------
  # PROCESS CHECKING
  #---------------------------------------------------------------------
  format-echo "INFO" "Checking if process $PROCESS_NAME is running..."

  if pgrep "$PROCESS_NAME" > /dev/null; then
    format-echo "SUCCESS" "Process $PROCESS_NAME is running."
  else
    format-echo "ERROR" "Process $PROCESS_NAME is not running."
    EXIT_CODE=1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Check Process Script"
  if [ $EXIT_CODE -eq 0 ]; then
    format-echo "SUCCESS" "Process check completed successfully."
  else
    format-echo "WARNING" "Process check completed. Process not found."
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $? 
