#!/bin/bash
# dependency-updater-python.sh
# Script to update Python dependencies listed in a requirements file

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

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
REQUIREMENTS_FILE=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Python Dependency Updater Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script updates Python dependencies listed in a requirements file."
  echo "  It must be run in an environment where 'pip' is installed and accessible."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <requirements_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<requirements_file>\033[0m       (Required) Path to the requirements file."
  echo -e "  \033[1;33m--log <log_file>\033[0m          (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 requirements.txt               # Update dependencies without logging."
  echo "  $0 requirements.txt --log log.txt # Update dependencies and log output to 'log.txt'."
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log)
        if [[ -n "${2:-}" ]]; then
          LOG_FILE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --log"
          usage
        fi
        ;;
      --help)
        usage
        ;;
      *)
        if [ -z "$REQUIREMENTS_FILE" ]; then
          REQUIREMENTS_FILE="$1"
          shift
        else
          format-echo "ERROR" "Unknown option or multiple requirements files provided: $1"
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

  print_with_separator "Python Dependency Updater Script"
  format-echo "INFO" "Starting Python Dependency Updater Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate requirements file argument
  if [ -z "$REQUIREMENTS_FILE" ]; then
    format-echo "ERROR" "Requirements file is required."
    print_with_separator "End of Python Dependency Updater Script"
    usage
  fi

  if [ ! -f "$REQUIREMENTS_FILE" ]; then
    format-echo "ERROR" "Requirements file '$REQUIREMENTS_FILE' does not exist."
    print_with_separator "End of Python Dependency Updater Script"
    exit 1
  fi

  # Validate if pip is installed
  if ! command -v pip &> /dev/null; then
    format-echo "ERROR" "pip is not installed or not available in the PATH. Please install pip and try again."
    print_with_separator "End of Python Dependency Updater Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # DEPENDENCY UPDATES
  #---------------------------------------------------------------------
  format-echo "INFO" "Updating Python dependencies from '$REQUIREMENTS_FILE'..."
  format-echo "INFO" "Starting dependency update process..."

  if pip install --upgrade -r "$REQUIREMENTS_FILE"; then
    format-echo "SUCCESS" "Dependencies updated successfully!"
  else
    format-echo "ERROR" "Failed to update dependencies!"
    print_with_separator "End of Python Dependency Updater Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Dependency update process completed."
  print_with_separator "End of Python Dependency Updater Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
