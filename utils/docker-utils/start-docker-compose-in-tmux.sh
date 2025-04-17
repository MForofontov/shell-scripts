#!/bin/bash
# start-docker-compose-in-tmux.sh
# Script to start Docker Compose in a new tmux session.

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
  print_with_separator "Start Docker Compose in Tmux Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script starts Docker Compose in a new tmux session."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <docker_compose_dir> <tmux_session_name> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<docker_compose_dir>\033[0m   (Required) Path to the Docker Compose directory."
  echo -e "  \033[1;33m<tmux_session_name>\033[0m    (Required) Name of the tmux session."
  echo -e "  \033[1;33m--log <log_file>\033[0m       (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                 (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/docker-compose my_session --log docker_compose.log"
  echo "  $0 /path/to/docker-compose my_session"
  print_with_separator
  exit 1
}

# Default values
DOCKER_COMPOSE_DIR=""
SESSION_NAME=""
LOG_FILE="/dev/null"

# Parse input arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      ;;
    --log)
      if [ -z "$2" ]; then
        log_message "ERROR" "No log file provided after --log."
        usage
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      if [ -z "$DOCKER_COMPOSE_DIR" ]; then
        DOCKER_COMPOSE_DIR="$1"
      elif [ -z "$SESSION_NAME" ]; then
        SESSION_NAME="$1"
      else
        log_message "ERROR" "Unknown option or too many arguments: $1"
        usage
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$DOCKER_COMPOSE_DIR" ] || [ -z "$SESSION_NAME" ]; then
  log_message "ERROR" "Both <docker_compose_dir> and <tmux_session_name> are required."
  usage
fi

# Validate log file if provided
if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
    exit 1
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log_message "INFO" "Starting Docker Compose in tmux session: $SESSION_NAME"
print_with_separator "Start Docker Compose in Tmux"

# Check if required commands are available
if ! command -v tmux &> /dev/null; then
  log_message "ERROR" "tmux is not installed. Please install tmux first."
  exit 1
fi

if ! command -v docker-compose &> /dev/null; then
  log_message "ERROR" "docker-compose is not installed. Please install Docker Compose first."
  exit 1
fi

# Check if the directory exists
if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
  log_message "ERROR" "Directory $DOCKER_COMPOSE_DIR does not exist."
  exit 1
fi

# Check if the tmux session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  log_message "INFO" "Tmux session '$SESSION_NAME' already exists."
  read -p "Do you want to attach to the existing session? (y/n) " ATTACH_EXISTING
  if [ "$ATTACH_EXISTING" = "y" ]; then
    tmux attach-session -t "$SESSION_NAME"
    exit 0
  else
    log_message "INFO" "Exiting without attaching to the existing session."
    exit 0
  fi
fi

# Create a new tmux session and start Docker Compose
log_message "INFO" "Creating a new tmux session and starting Docker Compose..."
tmux new-session -d -s "$SESSION_NAME" -c "$DOCKER_COMPOSE_DIR" "docker-compose up"

if [ $? -eq 0 ]; then
  log_message "SUCCESS" "Docker Compose started in tmux session '$SESSION_NAME'."
else
  log_message "ERROR" "Failed to start Docker Compose in tmux session."
  exit 1
fi

# Optionally, attach to the tmux session
read -p "Do you want to attach to the tmux session? (y/n) " ATTACH
if [ "$ATTACH" = "y" ]; then
  tmux attach-session -t "$SESSION_NAME"
fi

# Notify user
print_with_separator "End of Start Docker Compose in Tmux"
log_message "SUCCESS" "Docker Compose session setup complete."