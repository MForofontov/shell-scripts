#!/bin/bash
# clean-old-files.sh
# Script to delete files older than a specified number of days

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
DIRECTORY=""
DAYS=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Clean Old Files Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script deletes files older than a specified number of days from a given directory."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <directory> <days> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<directory>\033[0m       (Required) Directory to clean."
  echo -e "  \033[1;36m<days>\033[0m            (Required) Age threshold for files to be deleted (e.g., 30 days)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/directory 30 --log custom_log.log"
  echo "  $0 /path/to/directory 30"
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
        elif [ -z "$DAYS" ]; then
          DAYS="$1"
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

  print_with_separator "Clean Old Files Script"
  format-echo "INFO" "Starting Clean Old Files Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check required arguments
  if [ -z "$DIRECTORY" ] || [ -z "$DAYS" ]; then
    format-echo "ERROR" "<directory> and <days> are required."
    print_with_separator "End of Clean Old Files Script"
    exit 1
  fi

  # Validate directory
  if [ ! -d "$DIRECTORY" ]; then
    format-echo "ERROR" "Directory $DIRECTORY does not exist."
    print_with_separator "End of Clean Old Files Script"
    exit 1
  fi

  # Validate DAYS is a positive integer
  if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    format-echo "ERROR" "DAYS must be a valid positive number."
    print_with_separator "End of Clean Old Files Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # FILE CLEANING
  #---------------------------------------------------------------------
  format-echo "INFO" "Removing files older than $DAYS days from $DIRECTORY..."
  
  # Count files to be removed
  FILE_COUNT=$(find "$DIRECTORY" -type f -mtime +"$DAYS" | wc -l | tr -d ' ')
  
  if [ "$FILE_COUNT" -eq 0 ]; then
    format-echo "INFO" "No files older than $DAYS days found in $DIRECTORY."
  else
    format-echo "INFO" "Found $FILE_COUNT files to remove."
    
    # Remove the files
    if find "$DIRECTORY" -type f -mtime +"$DAYS" -exec rm -v {} \; ; then
      format-echo "SUCCESS" "Successfully removed $FILE_COUNT files older than $DAYS days from $DIRECTORY."
    else
      format-echo "ERROR" "Failed to remove some files from $DIRECTORY."
      print_with_separator "End of Clean Old Files Script"
      exit 1
    fi
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Clean Old Files operation completed."
  print_with_separator "End of Clean Old Files Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
