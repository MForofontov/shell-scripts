#!/bin/bash
# Script to log messages with log levels, timestamps, and optional file logging

# Function to display usage instructions
usage() {
  echo "Usage: $0 --level <log_level> --message <message> [--log <log_file>] [--help]"
  echo
  echo "Options:"
  echo "  --level <log_level>    The log level (e.g., ERROR, INFO, DEBUG, SUCCESS)."
  echo "  --message <message>    The message to log or echo."
  echo "  --log <log_file>       (Optional) Log output to the specified file."
  echo "  --help                 Display this help message."
  echo
  echo "Example:"
  echo "  $0 --level INFO --message 'Operation started' --log operations.log"
  echo "  $0 --level ERROR --message 'File not found'"
  exit 0
}

# Function to log messages with log levels and timestamps
log_message() {
  local LEVEL=$1
  local MESSAGE=$2
  local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  local COLOR=""

  # Set color based on log level
  case "$LEVEL" in
    ERROR)
      COLOR="\033[1;31m"  # Red
      ;;
    SUCCESS)
      COLOR="\033[1;32m"  # Green
      ;;
    INFO)
      COLOR=""  # Default terminal color
      ;;
    DEBUG)
      COLOR="\033[1;33m"  # Yellow
      ;;
    *)
      COLOR=""  # Default terminal color
      ;;
  esac

  # Format the log message
  local FORMATTED_MESSAGE="$TIMESTAMP [$LEVEL] $MESSAGE"

  # Remove color codes for the log file
  local PLAIN_MESSAGE=$(echo -e "$FORMATTED_MESSAGE" | sed 's/\x1b\[[0-9;]*m//g')

  # Log to file if specified, otherwise just echo
  if [ -n "$LOG_FILE" ]; then
    echo "$PLAIN_MESSAGE" >> "$LOG_FILE"
  fi

  # Echo to console with color
  echo -e "${COLOR}${FORMATTED_MESSAGE}\033[0m"
}

# Initialize variables
LOG_LEVEL=""
MESSAGE=""
LOG_FILE=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --level)
      LOG_LEVEL="$2"
      shift 2
      ;;
    --message)
      MESSAGE="$2"
      shift 2
      ;;
    --log)
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate required arguments
if [ -z "$LOG_LEVEL" ] || [ -z "$MESSAGE" ]; then
  echo "Error: --level and --message are required."
  usage
fi

# Call the log_message function with the provided arguments
log_message "$LOG_LEVEL" "$MESSAGE"