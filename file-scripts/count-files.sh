#!/bin/bash
# count-files.sh
# Script to count the number of files and directories in a given path

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
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

#=====================================================================
# DEFAULT VALUES
#=====================================================================
DIRECTORY=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Count Files Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script counts the number of files and directories in a given path."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <directory> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<directory>\033[0m       (Required) Directory to count files and directories."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/directory --log custom_log.log"
  echo "  $0 /path/to/directory"
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
          log_message "ERROR" "Missing argument for --log"
          usage
        fi
        ;;
      --help)
        usage
        ;;
      *)
        if [ -z "$DIRECTORY" ]; then
          DIRECTORY="$1"
          shift
        else
          log_message "ERROR" "Unknown option or too many arguments: $1"
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

  print_with_separator "Count Files Script"
  log_message "INFO" "Starting Count Files Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$DIRECTORY" ]; then
    log_message "ERROR" "<directory> is required."
    print_with_separator "End of Count Files Script"
    exit 1
  fi

  if [ ! -d "$DIRECTORY" ]; then
    log_message "ERROR" "Directory $DIRECTORY does not exist."
    print_with_separator "End of Count Files Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COUNTING OPERATION
  #---------------------------------------------------------------------
  log_message "INFO" "Counting files and directories in $DIRECTORY..."

  # Count files and directories
  FILE_COUNT=$(find "$DIRECTORY" -type f | wc -l | tr -d ' ')
  DIR_COUNT=$(find "$DIRECTORY" -type d | wc -l | tr -d ' ')
  
  # Remove the leading directory from the count of directories
  DIR_COUNT=$((DIR_COUNT - 1))

  log_message "INFO" "Number of files in $DIRECTORY: $FILE_COUNT"
  log_message "INFO" "Number of directories in $DIRECTORY: $DIR_COUNT"
  log_message "INFO" "Total items: $((FILE_COUNT + DIR_COUNT))"

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  log_message "INFO" "File counting operation completed."
  print_with_separator "End of Count Files Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"