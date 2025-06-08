#!/bin/bash
# check-services.sh
# Script to check if a list of services are running.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0" 2>/dev/null || echo "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
LOG_FILE="/dev/null"
SERVICES=("nginx" "apache2" "postgresql" "django" "react" "celery-worker") # Default services to check
CELERY_APP="" # Optional: specify Celery app name
EXIT_CODE=0

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Check Services Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks if a list of services are running."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--service <service_name>] [--celery-app <app_name>] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--service <service_name>\033[0m  (Optional) Add a service to check. Can be used multiple times."
  echo -e "  \033[1;33m--celery-app <app_name>\033[0m   (Optional) Specify the Celery application name."
  echo -e "  \033[1;33m--log <log_file>\033[0m          (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --service mysql --service redis --log services_check.log"
  echo "  $0 --celery-app myproject"
  echo "  $0"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  local custom_services=false
  
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
      --service)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No service name provided after --service."
          usage
        fi
        # If this is the first custom service, clear the default list
        if [ "$custom_services" = false ]; then
          SERVICES=()
          custom_services=true
        fi
        SERVICES+=("$2")
        shift 2
        ;;
      --celery-app)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No app name provided after --celery-app."
          usage
        fi
        CELERY_APP="$2"
        shift 2
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Check if a service is running
is_running() {
  local service_name=$1
  local pid
  
  pid=$(pgrep -f "$service_name" 2>/dev/null || echo "")
  
  if [ -n "$pid" ]; then
    format-echo "SUCCESS" "$service_name is running with PID(s): $pid"
    return 0
  else
    format-echo "ERROR" "$service_name is not running"
    EXIT_CODE=1
    return 1
  fi
}

# Check Celery workers status
check_celery() {
  format-echo "INFO" "Checking for Celery workers..."
  
  # Skip if celery-worker was already checked in the main service loop
  if [[ " ${SERVICES[*]} " == *" celery-worker "* ]]; then
    return 0
  fi
  
  if command -v celery > /dev/null 2>&1; then
    # If app name is specified, use it
    if [ -n "$CELERY_APP" ]; then
      if celery -A "$CELERY_APP" status > /dev/null 2>&1; then
        format-echo "SUCCESS" "Celery workers for app '$CELERY_APP' are running."
      else
        format-echo "ERROR" "No Celery workers for app '$CELERY_APP' are running."
        EXIT_CODE=1
      fi
    else
      # Try generic check without app name
      format-echo "WARNING" "No Celery app name specified. Using basic process check."
      if pgrep -f "celery worker" > /dev/null 2>&1; then
        format-echo "SUCCESS" "Celery worker is running (detected by process name)."
      else
        format-echo "ERROR" "No Celery worker is running."
        EXIT_CODE=1
      fi
    fi
  else
    format-echo "WARNING" "Celery CLI is not installed. Falling back to process name check."
    if pgrep -f "celery" > /dev/null 2>&1; then
      format-echo "SUCCESS" "Celery worker is running (detected by process name)."
    else
      format-echo "ERROR" "No Celery worker is running."
      EXIT_CODE=1
    fi
  fi
}

# Check systemd service status if applicable
check_systemd_service() {
  local service_name=$1
  
  # Only try systemctl if it exists and we're not on macOS
  if [[ "$OSTYPE" != "darwin"* ]] && command -v systemctl > /dev/null 2>&1; then
    if systemctl is-active --quiet "$service_name"; then
      format-echo "SUCCESS" "$service_name systemd service is active"
      return 0
    else
      format-echo "WARNING" "$service_name systemd service is not active, checking processes..."
      return 1
    fi
  fi
  return 1  # Not using systemd or on macOS
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi

  print_with_separator "Check Services Script"
  format-echo "INFO" "Starting Check Services Script..."
  
  # Display the services that will be checked
  if [ ${#SERVICES[@]} -gt 0 ]; then
    format-echo "INFO" "Services to check: ${SERVICES[*]}"
  else
    format-echo "WARNING" "No services specified for checking."
  fi

  #---------------------------------------------------------------------
  # SERVICE CHECKS
  #---------------------------------------------------------------------
  # Check each service
  for service in "${SERVICES[@]}"; do
    # First try systemd if available (not on macOS)
    if ! check_systemd_service "$service"; then
      # Fall back to process check
      is_running "$service"
    fi
  done

  # Additional Celery specific check
  check_celery

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Check Services Script"
  
  if [ $EXIT_CODE -eq 0 ]; then
    format-echo "SUCCESS" "All service checks completed successfully."
  else
    format-echo "WARNING" "Service checks completed with issues. Some services are not running."
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?