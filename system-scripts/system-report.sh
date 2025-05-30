#!/bin/bash
# system-report.sh
# Script to generate a system report.

set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

REPORT_FILE=""
LOG_FILE="/dev/null"

usage() {
  print_with_separator "System Report Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates a system report and saves it to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <report_file> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m<report_file>\033[0m      (Required) Path to save the system report."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/report.txt --log system_report.log"
  echo "  $0 /path/to/report.txt"
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
          log_message "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      *)
        if [ -z "$REPORT_FILE" ]; then
          REPORT_FILE="$1"
          shift
        else
          log_message "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

generate_report() {
  {
    echo "System Report - $(date)"
    echo "----------------------------------"
    echo "Uptime:"
    uptime
    echo ""
    echo "Disk Usage:"
    df -h
    echo ""
    echo "Memory Usage:"
    if command -v free > /dev/null; then
      free -h
    else
      vm_stat | awk '
        /Pages active/ {active=$3}
        /Pages inactive/ {inactive=$3}
        /Pages speculative/ {speculative=$3}
        /Pages wired down/ {wired=$4}
        /Pages free/ {free=$3}
        END {
          total=active+inactive+speculative+wired+free
          used=active+inactive+speculative+wired
          printf "Used: %.2f GB\nFree: %.2f GB\n", used/256, free/256
        }'
    fi
    echo ""
    echo "CPU Usage:"
    if command -v top > /dev/null; then
      top -l 1 | grep "CPU usage"
    else
      ps -A -o %cpu | awk '{s+=$1} END {print "CPU Usage: " s "%"}'
    fi
  } > "$REPORT_FILE"
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

  print_with_separator "System Report Script"
  log_message "INFO" "Starting System Report Script..."

  # Validate required arguments
  if [ -z "$REPORT_FILE" ]; then
    log_message "ERROR" "The <report_file> argument is required."
    print_with_separator "End of System Report Script"
    usage
  fi

  generate_report

  print_with_separator "End of System Report Script"
  log_message "SUCCESS" "System report generated at $REPORT_FILE."
}

main "$@"