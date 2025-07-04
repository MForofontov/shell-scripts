#!/bin/bash
# monitor-resources.sh
# Script to monitor system resources (CPU, memory, disk) and log the usage.

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
INTERVAL=5
DURATION=0
WATCH_MODE=false
CONTAINER=""
THRESHOLD_CPU=90
THRESHOLD_MEM=90
THRESHOLD_DISK=90
ALERT_MODE=false
EMAIL=""
OUTPUT_FORMAT="text" # text, csv, json
OUTPUT_FILE=""
EXIT_CODE=0
CHECK_SWAP=false
VERBOSE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Resource Monitor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script monitors system resources (CPU, memory, disk) and logs the usage."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--interval <seconds>] [--duration <seconds>] [--watch] [--container <name>]"
  echo "     [--threshold-cpu <percent>] [--threshold-mem <percent>] [--threshold-disk <percent>]"
  echo "     [--alert] [--email <address>] [--format <format>] [--output <file>]"
  echo "     [--check-swap] [--verbose] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--interval <seconds>\033[0m      (Optional) Check interval in seconds (default: 5)"
  echo -e "  \033[1;33m--duration <seconds>\033[0m      (Optional) Total monitoring duration (default: run once)"
  echo -e "  \033[1;33m--watch\033[0m                   (Optional) Run in watch mode (continuous display)"
  echo -e "  \033[1;33m--container <name>\033[0m        (Optional) Monitor a specific Docker container"
  echo -e "  \033[1;33m--threshold-cpu <percent>\033[0m (Optional) CPU usage threshold (default: 90%)"
  echo -e "  \033[1;33m--threshold-mem <percent>\033[0m (Optional) Memory usage threshold (default: 90%)"
  echo -e "  \033[1;33m--threshold-disk <percent>\033[0m (Optional) Disk usage threshold (default: 90%)"
  echo -e "  \033[1;33m--alert\033[0m                   (Optional) Enable alerting when thresholds are exceeded"
  echo -e "  \033[1;33m--email <address>\033[0m         (Optional) Email address for alerts"
  echo -e "  \033[1;33m--format <format>\033[0m         (Optional) Output format: text, csv, json (default: text)"
  echo -e "  \033[1;33m--output <file>\033[0m           (Optional) Save results to file"
  echo -e "  \033[1;33m--check-swap\033[0m              (Optional) Include swap usage in monitoring"
  echo -e "  \033[1;33m--verbose\033[0m                 (Optional) Show more detailed resource information"
  echo -e "  \033[1;33m--log <log_file>\033[0m          (Optional) Path to save the log messages"
  echo -e "  \033[1;33m--help\033[0m                    (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --watch --interval 2"
  echo "  $0 --duration 300 --output resources.csv --format csv"
  echo "  $0 --container webapp --threshold-mem 80 --alert --email admin@example.com"
  echo "  $0 --verbose --log resource_monitor.log"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
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
      --interval)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid interval: $2. Must be a positive integer."
          usage
        fi
        INTERVAL="$2"
        shift 2
        ;;
      --duration)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid duration: $2. Must be a positive integer."
          usage
        fi
        DURATION="$2"
        shift 2
        ;;
      --watch)
        WATCH_MODE=true
        shift
        ;;
      --container)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No container name provided after --container."
          usage
        fi
        CONTAINER="$2"
        shift 2
        ;;
      --threshold-cpu)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -gt 100 ]; then
          format-echo "ERROR" "Invalid CPU threshold: $2. Must be a positive integer <= 100."
          usage
        fi
        THRESHOLD_CPU="$2"
        shift 2
        ;;
      --threshold-mem)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -gt 100 ]; then
          format-echo "ERROR" "Invalid memory threshold: $2. Must be a positive integer <= 100."
          usage
        fi
        THRESHOLD_MEM="$2"
        shift 2
        ;;
      --threshold-disk)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -gt 100 ]; then
          format-echo "ERROR" "Invalid disk threshold: $2. Must be a positive integer <= 100."
          usage
        fi
        THRESHOLD_DISK="$2"
        shift 2
        ;;
      --alert)
        ALERT_MODE=true
        shift
        ;;
      --email)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No email address provided after --email."
          usage
        fi
        EMAIL="$2"
        shift 2
        ;;
      --format)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^(text|csv|json)$ ]]; then
          format-echo "ERROR" "Invalid format: $2. Must be one of: text, csv, json"
          usage
        fi
        OUTPUT_FORMAT="$2"
        shift 2
        ;;
      --output)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No output file provided after --output."
          usage
        fi
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --check-swap)
        CHECK_SWAP=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
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
# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to get current CPU usage
get_cpu_usage() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS approach
    top -l 1 -n 0 | grep "CPU usage" | awk '{print $3+$5}' | tr -d '%'
  else
    # Linux approach
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'
  fi
}

# Function to get memory usage
get_memory_usage() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS approach
    top -l 1 -n 0 | grep "PhysMem" | awk '{print $2}' | sed 's/M//' | awk -v total=$(sysctl -n hw.memsize | awk '{print $1/1024/1024}') '{print $1*100/total}'
  else
    # Linux approach
    free -m | awk 'NR==2{printf "%.2f", $3*100/$2 }'
  fi
}

# Function to get swap usage
get_swap_usage() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS approach
    sysctl -n vm.swapusage | awk '{print $3}' | sed 's/M//' | awk -v total=$(sysctl -n vm.swapusage | awk '{print $6}' | sed 's/M//') '{print $1*100/total}'
  else
    # Linux approach
    free -m | awk 'NR==3{printf "%.2f", $3*100/($3+$4) }'
  fi
}

# Function to get disk usage
get_disk_usage() {
  local path="$1"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS approach
    df -h "$path" | awk 'NR==2{print $5}' | tr -d '%'
  else
    # Linux approach
    df -h "$path" | awk '$NF=="'"$path"'"{print $5}' | tr -d '%'
  fi
}

# Function to get docker container stats
get_container_stats() {
  local container="$1"
  if ! command_exists docker; then
    format-echo "ERROR" "Docker is not installed or not in PATH."
    return 1
  fi
  
  # Check if container exists and is running
  if ! docker ps --filter "name=$container" --filter "status=running" -q | grep -q .; then
    format-echo "ERROR" "Container $container not found or not running."
    return 1
  fi
  
  # Get container CPU usage
  local cpu_usage
  cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "$container" | tr -d '%')
  
  # Get container memory usage
  local mem_usage
  mem_usage=$(docker stats --no-stream --format "{{.MemPerc}}" "$container" | tr -d '%')
  
  echo "$cpu_usage:$mem_usage"
}

# Function to send email alert
send_alert() {
  local subject="$1"
  local message="$2"
  
  if [ -z "$EMAIL" ]; then
    format-echo "WARNING" "No email address specified for alerts."
    return 1
  fi
  
  if command_exists mail; then
    echo -e "$message" | mail -s "$subject" "$EMAIL"
    format-echo "INFO" "Alert email sent to $EMAIL"
    return 0
  else
    format-echo "ERROR" "mail command not found. Cannot send email alert."
    return 1
  fi
}

# Function to format output
format_output() {
  local timestamp="$1"
  local cpu="$2"
  local memory="$3"
  local disk="$4"
  local swap="${5:-N/A}"
  
  case "$OUTPUT_FORMAT" in
    text)
      echo "Time: $timestamp | CPU: ${cpu}% | Memory: ${memory}% | Disk: ${disk}% | Swap: ${swap}%"
      ;;
    csv)
      echo "$timestamp,$cpu,$memory,$disk,$swap"
      ;;
    json)
      echo "{\"timestamp\":\"$timestamp\",\"cpu\":$cpu,\"memory\":$memory,\"disk\":$disk,\"swap\":\"$swap\"}"
      ;;
  esac
}

# Function to check thresholds and alert
check_thresholds() {
  local cpu="$1"
  local memory="$2"
  local disk="$3"
  local hostname
  hostname=$(hostname)
  local alerts=()
  
  if (( $(echo "$cpu > $THRESHOLD_CPU" | bc -l) )); then
    alerts+=("CPU usage is at ${cpu}% (threshold: ${THRESHOLD_CPU}%)")
  fi
  
  if (( $(echo "$memory > $THRESHOLD_MEM" | bc -l) )); then
    alerts+=("Memory usage is at ${memory}% (threshold: ${THRESHOLD_MEM}%)")
  fi
  
  if (( $(echo "$disk > $THRESHOLD_DISK" | bc -l) )); then
    alerts+=("Disk usage is at ${disk}% (threshold: ${THRESHOLD_DISK}%)")
  fi
  
  # If any thresholds were exceeded
  if [ ${#alerts[@]} -gt 0 ]; then
    EXIT_CODE=1
    
    # Format alert message
    local alert_subject="Resource Alert on $hostname - Thresholds Exceeded"
    local alert_message="The following resource thresholds were exceeded on $hostname:\n\n"
    
    for alert in "${alerts[@]}"; do
      format-echo "WARNING" "$alert"
      alert_message+="- $alert\n"
    done
    
    alert_message+="\nTimestamp: $(date)\n"
    alert_message+="Hostname: $hostname\n"
    
    # Send alert if in alert mode
    if [ "$ALERT_MODE" = true ]; then
      send_alert "$alert_subject" "$alert_message"
    fi
  fi
}

# Function to monitor resources for a specific interval
monitor_resources() {
  local timestamp
  local cpu_usage
  local memory_usage
  local disk_usage
  local swap_usage
  
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Get resource usage
  if [ -n "$CONTAINER" ]; then
    # Monitoring Docker container
    local container_stats
    container_stats=$(get_container_stats "$CONTAINER")
    
    if [ $? -eq 0 ]; then
      # Parse container stats
      cpu_usage=$(echo "$container_stats" | cut -d':' -f1)
      memory_usage=$(echo "$container_stats" | cut -d':' -f2)
      disk_usage="N/A" # Container disk usage not directly available
      
      if [ "$VERBOSE" = true ]; then
        format-echo "INFO" "Container: $CONTAINER"
        format-echo "INFO" "  CPU Usage: ${cpu_usage}%"
        format-echo "INFO" "  Memory Usage: ${memory_usage}%"
      else
        format-echo "INFO" "Container $CONTAINER - CPU: ${cpu_usage}%, Memory: ${memory_usage}%"
      fi
    else
      return 1
    fi
  else
    # Monitoring host system
    cpu_usage=$(get_cpu_usage)
    memory_usage=$(get_memory_usage)
    disk_usage=$(get_disk_usage "/")
    
    if [ "$CHECK_SWAP" = true ]; then
      swap_usage=$(get_swap_usage)
    else
      swap_usage="N/A"
    fi
    
    if [ "$VERBOSE" = true ]; then
      format-echo "INFO" "Resource Usage:"
      format-echo "INFO" "  CPU Usage: ${cpu_usage}%"
      format-echo "INFO" "  Memory Usage: ${memory_usage}%"
      format-echo "INFO" "  Disk Usage: ${disk_usage}%"
      
      if [ "$CHECK_SWAP" = true ]; then
        format-echo "INFO" "  Swap Usage: ${swap_usage}%"
      fi
      
      # If verbose, add load average
      local load_avg
      if [[ "$OSTYPE" == "darwin"* ]]; then
        load_avg=$(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')
      else
        load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
      fi
      format-echo "INFO" "  Load Average: $load_avg"
      
      # Add process info if verbose
      format-echo "INFO" "  Top CPU Processes:"
      if [[ "$OSTYPE" == "darwin"* ]]; then
        ps -eo pcpu,pid,user,args | sort -k 1 -r | head -n 5 | while read -r line; do
          format-echo "INFO" "    $line"
        done
      else
        ps -eo pcpu,pid,user,args --sort=-%cpu | head -n 6 | tail -n 5 | while read -r line; do
          format-echo "INFO" "    $line"
        done
      fi
    else
      format-echo "INFO" "CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%"
    fi
  fi
  
  # Check thresholds and alert if necessary
  if [ "$ALERT_MODE" = true ]; then
    check_thresholds "$cpu_usage" "$memory_usage" "$disk_usage"
  fi
  
  # Format and save output if needed
  if [ -n "$OUTPUT_FILE" ]; then
    # Add CSV header if it's a new file and format is CSV
    if [ "$OUTPUT_FORMAT" = "csv" ] && [ ! -f "$OUTPUT_FILE" ]; then
      echo "Timestamp,CPU Usage (%),Memory Usage (%),Disk Usage (%),Swap Usage (%)" > "$OUTPUT_FILE"
    fi
    
    # Append data to the file
    format_output "$timestamp" "$cpu_usage" "$memory_usage" "$disk_usage" "$swap_usage" >> "$OUTPUT_FILE"
  fi
}

# Function to run continuous monitoring
run_monitoring() {
  local iterations=0
  local end_time=0
  
  # Calculate end time if duration is specified
  if [ "$DURATION" -gt 0 ]; then
    end_time=$(($(date +%s) + DURATION))
    format-echo "INFO" "Monitoring for $DURATION seconds (interval: $INTERVAL seconds)"
  fi
  
  # Setup for watch mode
  if [ "$WATCH_MODE" = true ]; then
    format-echo "INFO" "Running in watch mode. Press Ctrl+C to stop."
    clear
  fi
  
  # Continuous monitoring loop
  while true; do
    # For watch mode, move cursor to beginning
    if [ "$WATCH_MODE" = true ]; then
      clear
      echo "Resource Monitor - $(date)"
      echo "Press Ctrl+C to stop"
      echo "--------------------------------------------------"
    fi
    
    # Monitor resources
    monitor_resources
    iterations=$((iterations + 1))
    
    # Exit if duration is reached
    if [ "$DURATION" -gt 0 ] && [ "$(date +%s)" -ge "$end_time" ]; then
      format-echo "INFO" "Monitoring completed after $DURATION seconds ($iterations samples)"
      break
    fi
    
    # Exit if this is a one-time check
    if [ "$DURATION" -eq 0 ] && [ "$WATCH_MODE" = false ]; then
      break
    fi
    
    # Sleep until next interval
    sleep "$INTERVAL"
  done
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

  print_with_separator "Resource Monitor Script"
  format-echo "INFO" "Starting Resource Monitor Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # If alert mode is enabled, validate email
  if [ "$ALERT_MODE" = true ] && [ -z "$EMAIL" ]; then
    format-echo "WARNING" "Alert mode is enabled but no email address specified."
  fi
  
  # If output file is specified, verify we can write to it
  if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
      format-echo "ERROR" "Cannot write to output file $OUTPUT_FILE."
      print_with_separator "End of Resource Monitor Script"
      exit 1
    fi
  fi
  
  # If Docker container is specified, verify Docker is available
  if [ -n "$CONTAINER" ] && ! command_exists docker; then
    format-echo "ERROR" "Docker is required for container monitoring but is not installed."
    print_with_separator "End of Resource Monitor Script"
    exit 1
  fi
  
  # Check if bc is available for threshold comparison
  if [ "$ALERT_MODE" = true ] && ! command_exists bc; then
    format-echo "ERROR" "bc command is required for threshold alerts but is not installed."
    print_with_separator "End of Resource Monitor Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # RESOURCE MONITORING
  #---------------------------------------------------------------------
  # Set up trap to catch Ctrl+C in watch mode
  trap 'echo; format-echo "INFO" "Monitoring stopped by user"; break' INT
  
  # Run the monitoring
  run_monitoring

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Resource Monitor Script"
  
  if [ "$EXIT_CODE" -eq 0 ]; then
    format-echo "SUCCESS" "Resource monitoring completed successfully."
  else
    format-echo "WARNING" "Resource monitoring completed. Some thresholds were exceeded."
  fi
  
  if [ -n "$OUTPUT_FILE" ]; then
    format-echo "INFO" "Results saved to $OUTPUT_FILE"
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
