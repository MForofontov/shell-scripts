#!/bin/bash
# Utility script to log messages with log levels, timestamps, and optional file logging

# Function to log messages with log levels and timestamps
log_message() {
  local LEVEL=$1
  local MESSAGE=$2
  local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
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
      LEVEL_COLOR=""  # Default (no color)
      ;;
    DEBUG)
      LEVEL_COLOR="\033[1;33m"  # Yellow
      ;;
    *)
      echo -e "\033[1;31mError:\033[0m Invalid log level '$LEVEL'. Valid levels are ERROR, INFO, DEBUG, SUCCESS."
      return 1
      ;;
  esac

  # Format the log message
  local FORMATTED_MESSAGE="$TIMESTAMP [${LEVEL_COLOR}${LEVEL}\033[0m] $MESSAGE"

  # Remove color codes for the log file
  local PLAIN_MESSAGE=$(echo -e "$FORMATTED_MESSAGE" | sed 's/\x1b\[[0-9;]*m//g')

  # Log to file and console using tee
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    echo "$PLAIN_MESSAGE" | tee -a "$LOG_FILE"
  else
    echo -e "$FORMATTED_MESSAGE"
  fi
}