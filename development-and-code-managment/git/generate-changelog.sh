#!/bin/bash

# Generate Changelog

# Function to display usage instructions
usage() {
  echo "Usage: $0 <output_file> [log_file]"
  echo "Example: $0 CHANGELOG.md custom_log.log"
  exit 1
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
  usage
fi

# Get the output file from the first argument
OUTPUT_FILE=$1

# Check if a log file is provided as a second argument
LOG_FILE=""
if [ "$#" -ge 2 ]; then
  LOG_FILE="$2"
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