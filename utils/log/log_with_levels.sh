#!/bin/bash
# Script to log messages with log levels, timestamps, and optional file logging

# Function to display usage instructions
usage() {
  # Get the terminal width
  TERMINAL_WIDTH=$(tput cols)
  # Generate a separator line based on the terminal width
  SEPARATOR=$(printf '%*s' "$TERMINAL_WIDTH" '' | tr ' ' '-')

  echo
  echo "$SEPARATOR"
  echo -e "\033[1;34mLog Message Script\033[0m"
  echo
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script logs messages with log levels, timestamps, and optional file logging."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 --level <log_level> --message <message> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m--level <log_level>\033[0m    (Required) The log level (e.g., ERROR, INFO, DEBUG, SUCCESS)."
  echo -e "  \033[1;36m--message <message>\033[0m    (Required) The message to log or echo."
  echo -e "  \033[1;33m--log <log_file>\033[0m       (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m                 (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExample:\033[0m"
  echo "  $0 --level INFO --message 'Operation started' --log operations.log"
  echo "  $0 --level ERROR --message 'File not found'"
  echo "$SEPARATOR"
  echo
  exit 0
}

# Function to log messages with log levels and timestamps
log_message() {
  local LEVEL=$1
  local MESSAGE=$2
  local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
  local COLOR=""
  local LEVEL_COLOR=""

  # Set color based on log level
  case "$LEVEL" in
    ERROR)
      LEVEL_COLOR="\033[1;31m"  # Red
      ;;
    SUCCESS)
      LEVEL_COLOR="\033[1;32m"  # Green
      ;;
    INFO)
      LEVEL_COLOR="\033[1;34m"  # Blue
      ;;
    DEBUG)
      LEVEL_COLOR="\033[1;33m"  # Yellow
      ;;
    *)
      echo -e "\033[1;31mError:\033[0m Invalid log level '$LEVEL'. Valid levels are ERROR, INFO, DEBUG, SUCCESS."
      echo
      usage
      ;;
  esac

  # Format the log message
  local FORMATTED_MESSAGE="$TIMESTAMP [${LEVEL_COLOR}${LEVEL}\033[0m] $MESSAGE"

  # Remove color codes for the log file
  local PLAIN_MESSAGE=$(echo -e "$FORMATTED_MESSAGE" | sed 's/\x1b\[[0-9;]*m//g')

  # Log to file if specified, otherwise just echo
  if [ -n "$LOG_FILE" ]; then
    echo "$PLAIN_MESSAGE" >> "$LOG_FILE"
  fi

  # Echo to console
  echo -e "$FORMATTED_MESSAGE"
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
      echo -e "\033[1;31mError:\033[0m Unknown option: $1"
      echo
      usage
      ;;
  esac
done

# Validate required arguments
if [ -z "$LOG_LEVEL" ]; then
  echo -e "\033[1;31mError:\033[0m --level is required."
  echo
  usage
fi

if [ -z "$MESSAGE" ]; then
  echo -e "\033[1;31mError:\033[0m --message is required."
  echo
  usage
fi

# Call the log_message function with the provided arguments
log_message "$LOG_LEVEL" "$MESSAGE"