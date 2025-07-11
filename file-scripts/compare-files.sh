#!/bin/bash
# compare-files.sh
# Script to compare two files and print differences

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
SOURCE_FILE=""
TARGET_FILE=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Compare Files Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script compares two files and prints their differences."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <source_file> <target_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<source_file>\033[0m     (Required) Path to the first file (source file)."
  echo -e "  \033[1;36m<target_file>\033[0m     (Required) Path to the second file (target file)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/source_file /path/to/target_file --log custom_log.log"
  echo "  $0 /path/to/source_file /path/to/target_file"
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
        if [ -z "$SOURCE_FILE" ]; then
          SOURCE_FILE="$1"
          shift
        elif [ -z "$TARGET_FILE" ]; then
          TARGET_FILE="$1"
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

  print_with_separator "Compare Files Script"
  format-echo "INFO" "Starting Compare Files Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check required arguments
  if [ -z "$SOURCE_FILE" ] || [ -z "$TARGET_FILE" ]; then
    format-echo "ERROR" "<source_file> and <target_file> are required."
    print_with_separator "End of Compare Files Script"
    exit 1
  fi

  # Validate source file exists
  if [ ! -f "$SOURCE_FILE" ]; then
    format-echo "ERROR" "Source file $SOURCE_FILE does not exist."
    print_with_separator "End of Compare Files Script"
    exit 1
  fi

  # Validate target file exists
  if [ ! -f "$TARGET_FILE" ]; then
    format-echo "ERROR" "Target file $TARGET_FILE does not exist."
    print_with_separator "End of Compare Files Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # FILE COMPARISON
  #---------------------------------------------------------------------
  format-echo "INFO" "Comparing $SOURCE_FILE and $TARGET_FILE..."

  # Perform file comparison
  if diff "$SOURCE_FILE" "$TARGET_FILE"; then
    format-echo "SUCCESS" "Files are identical."
  else
    format-echo "INFO" "Files differ. See the output above for details."
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Compare Files Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
