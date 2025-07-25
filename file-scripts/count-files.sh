#!/bin/bash
# count-files.sh
# Script to count the number of files and directories in a given path

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
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
          format-echo "ERROR" "Missing argument for --log"
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

  setup_log_file

  print_with_separator "Count Files Script"
  format-echo "INFO" "Starting Count Files Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$DIRECTORY" ]; then
    format-echo "ERROR" "<directory> is required."
    print_with_separator "End of Count Files Script"
    exit 1
  fi

  if [ ! -d "$DIRECTORY" ]; then
    format-echo "ERROR" "Directory $DIRECTORY does not exist."
    print_with_separator "End of Count Files Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COUNTING OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Counting files and directories in $DIRECTORY..."

  # Count files and directories
  FILE_COUNT=$(find "$DIRECTORY" -type f | wc -l | tr -d ' ')
  DIR_COUNT=$(find "$DIRECTORY" -type d | wc -l | tr -d ' ')
  
  # Remove the leading directory from the count of directories
  DIR_COUNT=$((DIR_COUNT - 1))

  format-echo "INFO" "Number of files in $DIRECTORY: $FILE_COUNT"
  format-echo "INFO" "Number of directories in $DIRECTORY: $DIR_COUNT"
  format-echo "INFO" "Total items: $((FILE_COUNT + DIR_COUNT))"

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "File counting operation completed."
  print_with_separator "End of Count Files Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
