#!/bin/bash

# generate-changelog.sh
# Script to generate a changelog from the Git log

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
usage() {
  print_with_separator "Generate Changelog Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates a changelog file from the Git log of the current repository."
  echo "  It includes commit hashes, messages, authors, and relative commit times."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <output_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<output_file>\033[0m       (Required) The file where the changelog will be saved."
  echo -e "  \033[1;33m--log <log_file>\033[0m    (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m              (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExample:\033[0m"
  echo "  $0 CHANGELOG.md --log changelog.log"
  print_with_separator
  exit 0
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
  log_message "ERROR" "<output_file> is required."
  usage
fi

# Initialize variables
OUTPUT_FILE=""
LOG_FILE="/dev/null"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --log)
      if [[ -n "$2" ]]; then
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
      if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$1"
        shift
      else
        log_message "ERROR" "Unknown option: $1"
        usage
      fi
      ;;
  esac
done

# Validate required arguments
if [ -z "$OUTPUT_FILE" ]; then
  log_message "ERROR" "<output_file> is required."
  usage
fi

# Validate output file
if ! touch "$OUTPUT_FILE" 2>/dev/null; then
  log_message "ERROR" "Cannot write to output file $OUTPUT_FILE"
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    log_message "ERROR" "Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Get the project name from the current directory
PROJECT_NAME=$(basename "$(pwd)")

# Get the current date
CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

log_message "INFO" "Generating changelog for $PROJECT_NAME..."

# Add a header to the changelog
{
  echo "# Changelog for $PROJECT_NAME"
  echo "Generated on $CURRENT_DATE"
  echo
} > "$OUTPUT_FILE"

# Append the git log to the changelog with separators
print_with_separator "git log output"
if git log --pretty=format:"- %h %s (%an, %ar)" 2>&1 | tee -a "$OUTPUT_FILE" | tee -a "$LOG_FILE"; then
  print_with_separator "End of git log"
  log_message "SUCCESS" "Changelog saved to $OUTPUT_FILE"
else
  print_with_separator "End of git log"
  log_message "ERROR" "Failed to generate changelog. Check the log file for details: $LOG_FILE"
  exit 1
fi