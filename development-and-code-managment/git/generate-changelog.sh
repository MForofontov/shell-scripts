#!/bin/bash

# generate-changelog.sh
# Script to generate a changelog from the Git log

# Function to display usage instructions
usage() {
  echo "Usage: $0 <output_file> [--log <log_file>] [--help]"
  echo
  echo "Options:"
  echo "  <output_file>       (Required) The file where the changelog will be saved."
  echo "  --log <log_file>    (Optional) Log output to the specified file."
  echo "  --help              (Optional) Display this help message."
  echo
  echo "Example:"
  echo "  $0 CHANGELOG.md --log changelog.log"
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
        echo "Unknown option: $1"
        usage
      fi
      ;;
  esac
done

# Validate required arguments
if [ -z "$OUTPUT_FILE" ]; then
  echo "Error: <output_file> is required."
  usage
fi

# Validate output file
if ! touch "$OUTPUT_FILE" 2>/dev/null; then
  echo "Error: Cannot write to output file $OUTPUT_FILE"
  exit 1
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "Error: Cannot write to log file $LOG_FILE"
    exit 1
  fi
fi

# Function to log messages
log_message() {
  local MESSAGE=$1
  if [ -n "$MESSAGE" ]; then
    if [ -n "$LOG_FILE" ]; then
      echo "$MESSAGE" | tee -a "$LOG_FILE"
    else
      echo "$MESSAGE"
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