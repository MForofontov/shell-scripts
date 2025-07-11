#!/usr/bin/env bash
# add-prefix-to-files.sh
# Script to add a prefix to all files in a specified directory

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
DIRECTORY=""
PREFIX=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Add Prefix to Files Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script adds a specified prefix to all files in a given directory."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <directory> <prefix> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<directory>\033[0m       (Required) Directory containing the files to rename."
  echo -e "  \033[1;36m<prefix>\033[0m          (Required) Prefix to add to the files."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/directory my_prefix --log custom_log.log"
  echo "  $0 /path/to/directory my_prefix"
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
        elif [ -z "$PREFIX" ]; then
          PREFIX="$1"
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

  print_with_separator "Add Prefix to Files Script"
  format-echo "INFO" "Starting Add Prefix to Files Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate required arguments
  if [ -z "$DIRECTORY" ] || [ -z "$PREFIX" ]; then
    format-echo "ERROR" "<directory> and <prefix> are required."
    print_with_separator "End of Add Prefix to Files Script"
    exit 1
  fi

  # Validate directory exists
  if [ ! -d "$DIRECTORY" ]; then
    format-echo "ERROR" "Directory $DIRECTORY does not exist."
    print_with_separator "End of Add Prefix to Files Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # FILE PROCESSING
  #---------------------------------------------------------------------
  format-echo "INFO" "Adding prefix '$PREFIX' to files in $DIRECTORY..."

  # Count files to be processed
  FILE_COUNT=$(find "$DIRECTORY" -maxdepth 1 -type f | wc -l | tr -d ' ')
  format-echo "INFO" "Found $FILE_COUNT files to process in directory"
  
  # Process each file
  RENAMED_COUNT=0
  for FILE in "$DIRECTORY"/*; do
    if [ -f "$FILE" ]; then
      BASENAME=$(basename "$FILE")
      NEW_NAME="${DIRECTORY}/${PREFIX}${BASENAME}"
      
      if [ "$FILE" = "$NEW_NAME" ]; then
        format-echo "INFO" "Skipping $BASENAME (already has prefix)"
        continue
      fi
      
      if mv "$FILE" "$NEW_NAME"; then
        format-echo "SUCCESS" "Renamed $BASENAME to ${PREFIX}${BASENAME}"
        RENAMED_COUNT=$((RENAMED_COUNT + 1))
      else
        format-echo "ERROR" "Failed to rename $BASENAME"
      fi
    fi
  done

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Prefix addition completed: $RENAMED_COUNT of $FILE_COUNT files renamed."
  print_with_separator "End of Add Prefix to Files Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
