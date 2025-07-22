#!/bin/bash
# find-large-files.sh
# Script to find and list files larger than a specified size

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
SIZE=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Find Large Files Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script finds and lists files larger than a specified size in a given directory."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <directory> <size> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<directory>\033[0m       (Required) Directory to search for large files."
  echo -e "  \033[1;36m<size>\033[0m            (Required) Minimum size of files to find (e.g., +100M)."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/directory +100M --log custom_log.log"
  echo "  $0 /path/to/directory +500K"
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
        elif [ -z "$SIZE" ]; then
          SIZE="$1"
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

  print_with_separator "Find Large Files Script"
  format-echo "INFO" "Starting Find Large Files Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$DIRECTORY" ] || [ -z "$SIZE" ]; then
    format-echo "ERROR" "<directory> and <size> are required."
    print_with_separator "End of Find Large Files Script"
    exit 1
  fi

  if [ ! -d "$DIRECTORY" ]; then
    format-echo "ERROR" "Directory $DIRECTORY does not exist."
    print_with_separator "End of Find Large Files Script"
    exit 1
  fi

  # Validate size format
  if ! [[ "$SIZE" =~ ^\+?[0-9]+[KMG]$ ]]; then
    format-echo "ERROR" "Invalid size format. Use +<size>[KMG] (e.g., +100M)."
    print_with_separator "End of Find Large Files Script"
    exit 1
  fi

  # Ensure size has a leading plus sign
  if [[ "$SIZE" != +* ]]; then
    SIZE="+$SIZE"
    format-echo "INFO" "Added '+' prefix to size: $SIZE"
  fi

  #---------------------------------------------------------------------
  # FILE SEARCH OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Finding files larger than $SIZE in $DIRECTORY..."
  print_with_separator "Large Files Output"

  # Count number of files matching the criteria
  FILE_COUNT=$(find "$DIRECTORY" -type f -size "$SIZE" | wc -l | tr -d ' ')
  
  if [ "$FILE_COUNT" -eq 0 ]; then
    format-echo "INFO" "No files larger than $SIZE found in $DIRECTORY."
  else
    format-echo "INFO" "Found $FILE_COUNT files larger than $SIZE."
    
    # List files with their sizes, sorted by size (largest first)
    find "$DIRECTORY" -type f -size "$SIZE" -exec du -h {} \; | sort -hr | \
    while read -r size file; do
      echo "Size: $size - File: $file"
    done
    
    # Show total disk space used by these files
    TOTAL_SIZE=$(find "$DIRECTORY" -type f -size "$SIZE" -exec du -ch {} \; | grep total$ | cut -f1)
    format-echo "INFO" "Total disk space used by these files: $TOTAL_SIZE"
  fi
  
  print_with_separator "End of Large Files Output"

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "File search operation completed."
  print_with_separator "End of Find Large Files Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
