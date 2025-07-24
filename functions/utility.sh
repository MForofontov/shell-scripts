# Shared utility functions

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Configure logging by validating and creating the log file if needed
# and redirecting all output through tee for real-time display.
setup_log_file() {
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
}
