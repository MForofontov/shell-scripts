#!/bin/bash
# start-docker-compose-in-tmux.sh
# Script to start Docker Compose in a new tmux session.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
DOCKER_COMPOSE_DIR=""
SESSION_NAME=""
LOG_FILE="/dev/null"

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

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
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
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        shift
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Start Docker Compose in Tmux Script"
  format-echo "INFO" "Starting Docker Compose in tmux session: $SESSION_NAME"

  # Validate required arguments
  if [ -z "$DOCKER_COMPOSE_DIR" ] || [ -z "$SESSION_NAME" ]; then
    format-echo "ERROR" "Both <docker_compose_dir> and <tmux_session_name> are required."
    print_with_separator "End of Start Docker Compose in Tmux Script"
    usage
  fi

  # Check if required commands are available
  if ! command -v tmux &> /dev/null; then
    format-echo "ERROR" "tmux is not installed. Please install tmux first."
    print_with_separator "End of Start Docker Compose in Tmux Script"
    exit 1
  fi

  if ! command -v docker-compose &> /dev/null; then
    format-echo "ERROR" "docker-compose is not installed. Please install Docker Compose first."
    print_with_separator "End of Start Docker Compose in Tmux Script"
    exit 1
  fi

  # Check if the directory exists
  if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
    format-echo "ERROR" "Directory $DOCKER_COMPOSE_DIR does not exist."
    print_with_separator "End of Start Docker Compose in Tmux Script"
    exit 1
  fi

  # Check if the tmux session already exists
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    format-echo "INFO" "Tmux session '$SESSION_NAME' already exists."
    read -p "Do you want to attach to the existing session? (y/n) " ATTACH_EXISTING
    if [ "$ATTACH_EXISTING" = "y" ]; then
      tmux attach-session -t "$SESSION_NAME"
      print_with_separator "End of Start Docker Compose in Tmux Script"
      exit 0
    else
      format-echo "INFO" "Exiting without attaching to the existing session."
      print_with_separator "End of Start Docker Compose in Tmux Script"
      exit 0
    fi
  fi

  # Create a new tmux session and start Docker Compose
  format-echo "INFO" "Creating a new tmux session and starting Docker Compose..."
  tmux new-session -d -s "$SESSION_NAME" -c "$DOCKER_COMPOSE_DIR" "docker-compose up"

  if [ $? -eq 0 ]; then
    format-echo "SUCCESS" "Docker Compose started in tmux session '$SESSION_NAME'."
  else
    format-echo "ERROR" "Failed to start Docker Compose in tmux session."
    print_with_separator "End of Start Docker Compose in Tmux Script"
    exit 1
  fi

  # Optionally, attach to the tmux session
  read -p "Do you want to attach to the tmux session? (y/n) " ATTACH
  if [ "$ATTACH" = "y" ]; then
    tmux attach-session -t "$SESSION_NAME"
  fi

  print_with_separator "End of Start Docker Compose in Tmux Script"
  format-echo "SUCCESS" "Docker Compose session setup complete."
}

main "$@"
