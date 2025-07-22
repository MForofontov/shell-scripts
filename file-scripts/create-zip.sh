#!/bin/bash
# create-zip.sh
# Script to create a zip archive of a directory or file

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
SOURCE=""
OUTPUT_ZIP=""
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Create Zip Archive Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a zip archive of a directory or file."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <source> <output_zip> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<source>\033[0m          (Required) Path to the file or directory to zip."
  echo -e "  \033[1;36m<output_zip>\033[0m     (Required) Path to the output zip file."
  echo -e "  \033[1;33m--log <log_file>\033[0m  (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m            (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/source /path/to/output.zip --log custom_log.log"
  echo "  $0 /path/to/source /path/to/output.zip"
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
        if [ -z "$SOURCE" ]; then
          SOURCE="$1"
          shift
        elif [ -z "$OUTPUT_ZIP" ]; then
          OUTPUT_ZIP="$1"
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

  print_with_separator "Create Zip Archive Script"
  format-echo "INFO" "Starting Create Zip Archive Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$SOURCE" ] || [ -z "$OUTPUT_ZIP" ]; then
    format-echo "ERROR" "<source> and <output_zip> are required."
    print_with_separator "End of Create Zip Archive Script"
    exit 1
  fi

  if [ ! -e "$SOURCE" ]; then
    format-echo "ERROR" "Source $SOURCE does not exist."
    print_with_separator "End of Create Zip Archive Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # ZIP CREATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Creating zip archive: $OUTPUT_ZIP from $SOURCE"

  # Get source size before compression
  if [ -d "$SOURCE" ]; then
    SOURCE_SIZE=$(du -sh "$SOURCE" | cut -f1)
    format-echo "INFO" "Source directory size: $SOURCE_SIZE"
  elif [ -f "$SOURCE" ]; then
    SOURCE_SIZE=$(du -sh "$SOURCE" | cut -f1)
    format-echo "INFO" "Source file size: $SOURCE_SIZE"
  fi

  # Create the zip archive
  if zip -r "$OUTPUT_ZIP" "$SOURCE"; then
    ZIP_SIZE=$(du -sh "$OUTPUT_ZIP" | cut -f1)
    format-echo "SUCCESS" "Zip archive created: $OUTPUT_ZIP"
    format-echo "INFO" "Archive size: $ZIP_SIZE"
  else
    format-echo "ERROR" "Failed to create zip archive."
    print_with_separator "End of Create Zip Archive Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Zip creation operation completed."
  print_with_separator "End of Create Zip Archive Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
