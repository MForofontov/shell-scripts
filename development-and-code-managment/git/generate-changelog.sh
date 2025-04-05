#!/bin/bash

# generate-changelog.sh
# Script to generate a changelog from the Git log

# Function to display usage instructions
usage() {
  # Get the terminal width
  TERMINAL_WIDTH=$(tput cols)
  # Generate a separator line based on the terminal width
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mGenerate Changelog Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates a changelog file from the Git log of the current repository."
  echo "  It includes commit hashes, messages, authors, and relative commit times."
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
  echo "$SEPARATOR"
  echo
  exit 0
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Initialize variables
OUTPUT_FILE=""
LOG_FILE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --log)
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$1"
        shift
      else
        echo -e "\033[1;31mError:\033[0m Unknown option: $1"
        usage
      fi
      ;;
  esac
done

# Validate required arguments
if [ -z "$OUTPUT_FILE" ]; then
  echo -e "\033[1;31mError:\033[0m <output_file> is required."
  usage
fi

# Validate output file
if ! touch "$OUTPUT_FILE" 2>/dev/null; then
  echo -e "\033[1;31mError:\033[0m Cannot write to output file $OUTPUT_FILE"
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Function to log messages
log_message() {
  local MESSAGE=$1
  # Remove color codes for the log file
  local PLAIN_MESSAGE=$(echo -e "$MESSAGE" | sed 's/\x1b\[[0-9;]*m//g')
  
  if [ -n "$MESSAGE" ]; then
    if [ -n "$LOG_FILE" ]; then
      # Write plain text to the log file
      echo "$PLAIN_MESSAGE" | tee -a "$LOG_FILE"
    else
      # Print colored message to the console
      echo -e "$MESSAGE"
    fi
  fi
}

# Get the project name from the current directory
PROJECT_NAME=$(basename "$(pwd)")

# Get the current date
CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

log_message "Generating changelog for $PROJECT_NAME..."

# Add a header to the changelog
{
  echo "# Changelog for $PROJECT_NAME"
  echo "Generated on $CURRENT_DATE"
  echo
} > "$OUTPUT_FILE"

# Append the git log to the changelog
if ! git log --pretty=format:"- %h %s (%an, %ar)" >> "$OUTPUT_FILE"; then
  log_message "Error: Failed to generate changelog."
  exit 1
fi

log_message "Changelog saved to $OUTPUT_FILE"