#!/bin/bash
# monitor-network.sh
# Script to monitor network traffic on a specified interface or Docker container.

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
INTERFACE=""
DOCKER_CONTAINER=""
DOCKER_NETWORK=""
PORT_FILTER=""
HOST_FILTER=""
PROTOCOL_FILTER=""
CAPTURE_COUNT=0
CAPTURE_FILE=""
INTERVAL=1
DURATION=0
BRIEF_OUTPUT=false
VERBOSE=false
LOG_FILE="/dev/null"
EXIT_CODE=0

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Network Monitor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script monitors network traffic on a specified interface or Docker container."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--interface <interface>] [--container <name>] [--docker-net <network>]"
  echo "     [--port <port>] [--host <host>] [--proto <protocol>] [--count <number>]"
  echo "     [--capture <file.pcap>] [--interval <seconds>] [--duration <seconds>]"
  echo "     [--brief] [--verbose] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--interface <interface>\033[0m    (Optional) Network interface to monitor (e.g., eth0, docker0)"
  echo -e "  \033[1;33m--container <name>\033[0m         (Optional) Docker container to monitor"
  echo -e "  \033[1;33m--docker-net <network>\033[0m     (Optional) Docker network to monitor"
  echo -e "  \033[1;33m--port <port>\033[0m              (Optional) Filter traffic by port"
  echo -e "  \033[1;33m--host <host>\033[0m              (Optional) Filter traffic by host"
  echo -e "  \033[1;33m--proto <protocol>\033[0m         (Optional) Filter by protocol (tcp, udp, icmp)"
  echo -e "  \033[1;33m--count <number>\033[0m           (Optional) Capture specified number of packets then exit"
  echo -e "  \033[1;33m--capture <file.pcap>\033[0m      (Optional) Save captured packets to file"
  echo -e "  \033[1;33m--interval <seconds>\033[0m       (Optional) Update interval in seconds (default: 1)"
  echo -e "  \033[1;33m--duration <seconds>\033[0m       (Optional) Monitor for specified duration then exit"
  echo -e "  \033[1;33m--brief\033[0m                    (Optional) Show brief output (less detailed)"
  echo -e "  \033[1;33m--verbose\033[0m                  (Optional) Show more detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m           (Optional) Path to save the log messages"
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --interface eth0 --log network_traffic.log"
  echo "  $0 --container webapp --port 80"
  echo "  $0 --docker-net frontend --proto tcp --capture traffic.pcap"
  echo "  $0 --interface docker0 --brief --duration 60"
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
      --interface)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No interface provided after --interface."
          usage
        fi
        INTERFACE="$2"
        shift 2
        ;;
      --container)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No container name provided after --container."
          usage
        fi
        DOCKER_CONTAINER="$2"
        shift 2
        ;;
      --docker-net)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No network name provided after --docker-net."
          usage
        fi
        DOCKER_NETWORK="$2"
        shift 2
        ;;
      --port)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No port provided after --port."
          usage
        fi
        PORT_FILTER="$2"
        shift 2
        ;;
      --host)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No host provided after --host."
          usage
        fi
        HOST_FILTER="$2"
        shift 2
        ;;
      --proto)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No protocol provided after --proto."
          usage
        fi
        PROTOCOL_FILTER="$2"
        shift 2
        ;;
      --count)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid count after --count. Must be a positive integer."
          usage
        fi
        CAPTURE_COUNT="$2"
        shift 2
        ;;
      --capture)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No file provided after --capture."
          usage
        fi
        CAPTURE_FILE="$2"
        shift 2
        ;;
      --interval)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid interval after --interval. Must be a positive integer."
          usage
        fi
        INTERVAL="$2"
        shift 2
        ;;
      --duration)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid duration after --duration. Must be a positive integer."
          usage
        fi
        DURATION="$2"
        shift 2
        ;;
      --brief)
        BRIEF_OUTPUT=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      *)
        # Legacy support for positional interface argument
        if [ -z "$INTERFACE" ]; then
          INTERFACE="$1"
          shift
        else
          format-echo "ERROR" "Unknown option or too many arguments: $1"
          usage
        fi
        ;;
    esac
  done
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
check_docker_available() {
  if ! command -v docker &> /dev/null; then
    format-echo "ERROR" "Docker is not installed or not in PATH."
    return 1
  fi
  
  # Check if Docker daemon is running
  if ! docker info &> /dev/null; then
    format-echo "ERROR" "Docker daemon is not running or current user lacks permissions."
    return 1
  fi
  
  return 0
}

get_docker_container_id() {
  local container_name="$1"
  local container_id
  
  container_id=$(docker ps -q -f "name=$container_name")
  
  if [ -z "$container_id" ]; then
    # Try matching by ID
    container_id=$(docker ps -q -f "id=$container_name")
  fi
  
  if [ -z "$container_id" ]; then
    format-echo "ERROR" "Docker container '$container_name' not found or not running."
    return 1
  fi
  
  echo "$container_id"
  return 0
}

build_tcpdump_command() {
  local cmd="tcpdump -nn"
  
  # Add level of detail options
  if [ "$BRIEF_OUTPUT" = true ]; then
    cmd="$cmd -q"
  elif [ "$VERBOSE" = true ]; then
    cmd="$cmd -vvv"
  fi
  
  # Add interface
  if [ -n "$INTERFACE" ]; then
    cmd="$cmd -i $INTERFACE"
  fi
  
  # Add packet count limit if specified
  if [ "$CAPTURE_COUNT" -gt 0 ]; then
    cmd="$cmd -c $CAPTURE_COUNT"
  fi
  
  # Add capture file if specified
  if [ -n "$CAPTURE_FILE" ]; then
    cmd="$cmd -w $CAPTURE_FILE"
  fi
  
  # Start building the filter expression
  local filter=""
  
  # Add port filter
  if [ -n "$PORT_FILTER" ]; then
    [ -n "$filter" ] && filter="$filter and "
    filter="${filter}port $PORT_FILTER"
  fi
  
  # Add host filter
  if [ -n "$HOST_FILTER" ]; then
    [ -n "$filter" ] && filter="$filter and "
    filter="${filter}host $HOST_FILTER"
  fi
  
  # Add protocol filter
  if [ -n "$PROTOCOL_FILTER" ]; then
    [ -n "$filter" ] && filter="$filter and "
    filter="${filter}$PROTOCOL_FILTER"
  fi
  
  # Add the filter expression if any filters were specified
  if [ -n "$filter" ]; then
    cmd="$cmd '$filter'"
  fi
  
  echo "$cmd"
}

monitor_interface() {
  local interface="$1"
  local cmd
  
  format-echo "INFO" "Starting network traffic monitoring on interface $interface..."
  format-echo "INFO" "Press Ctrl+C to stop monitoring."
  
  cmd=$(build_tcpdump_command)
  
  if [ "$DURATION" -gt 0 ]; then
    format-echo "INFO" "Monitoring will run for $DURATION seconds."
    timeout "$DURATION" bash -c "$cmd" || true
  else
    eval "$cmd"
  fi
}

monitor_docker_container() {
  local container="$1"
  local container_id
  local cmd
  
  container_id=$(get_docker_container_id "$container") || return 1
  
  format-echo "INFO" "Starting network traffic monitoring for Docker container $container ($container_id)..."
  format-echo "INFO" "Press Ctrl+C to stop monitoring."
  
  # We need to run tcpdump inside the container
  cmd="docker exec $container_id /bin/sh -c \"tcpdump -nn"
  
  # Add level of detail options
  if [ "$BRIEF_OUTPUT" = true ]; then
    cmd="$cmd -q"
  elif [ "$VERBOSE" = true ]; then
    cmd="$cmd -vvv"
  fi
  
  # Add capture count if specified
  if [ "$CAPTURE_COUNT" -gt 0 ]; then
    cmd="$cmd -c $CAPTURE_COUNT"
  fi
  
  # Start building the filter expression
  local filter=""
  
  # Add port filter
  if [ -n "$PORT_FILTER" ]; then
    [ -n "$filter" ] && filter="$filter and "
    filter="${filter}port $PORT_FILTER"
  fi
  
  # Add host filter
  if [ -n "$HOST_FILTER" ]; then
    [ -n "$filter" ] && filter="$filter and "
    filter="${filter}host $HOST_FILTER"
  fi
  
  # Add protocol filter
  if [ -n "$PROTOCOL_FILTER" ]; then
    [ -n "$filter" ] && filter="$filter and "
    filter="${filter}$PROTOCOL_FILTER"
  fi
  
  # Add the filter expression if any filters were specified
  if [ -n "$filter" ]; then
    cmd="$cmd '$filter'"
  fi
  
  cmd="$cmd\""
  
  if [ "$DURATION" -gt 0 ]; then
    format-echo "INFO" "Monitoring will run for $DURATION seconds."
    timeout "$DURATION" bash -c "$cmd" || true
  else
    eval "$cmd"
  fi
}

monitor_docker_network() {
  local network="$1"
  
  # Check if the network exists
  if ! docker network inspect "$network" &> /dev/null; then
    format-echo "ERROR" "Docker network '$network' not found."
    return 1
  fi
  
  format-echo "INFO" "Starting network traffic monitoring for Docker network $network..."
  format-echo "INFO" "Identifying all containers connected to this network..."
  
  # Get all containers connected to this network
  local containers
  containers=$(docker network inspect "$network" -f '{{range .Containers}}{{.Name}} {{end}}')
  
  if [ -z "$containers" ]; then
    format-echo "WARNING" "No containers found on network $network."
    return 0
  fi
  
  format-echo "INFO" "Found containers: $containers"
  
  # For Docker network monitoring, we'll use the docker0 interface or bridge interface
  local bridge_interface
  if [ -n "$INTERFACE" ]; then
    bridge_interface="$INTERFACE"
  elif ip link show docker0 &> /dev/null; then
    bridge_interface="docker0"
  elif ip link show bridge0 &> /dev/null; then
    bridge_interface="bridge0"
  else
    format-echo "ERROR" "Could not determine Docker bridge interface. Please specify with --interface."
    return 1
  fi
  
  # Add the network's subnet to the filters
  local subnet
  subnet=$(docker network inspect "$network" -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
  
  if [ -n "$subnet" ]; then
    format-echo "INFO" "Monitoring traffic on subnet $subnet via interface $bridge_interface"
    
    # Set interface and add subnet to host filter
    INTERFACE="$bridge_interface"
    if [ -n "$HOST_FILTER" ]; then
      HOST_FILTER="($HOST_FILTER or net $subnet)"
    else
      HOST_FILTER="net $subnet"
    fi
    
    # Call monitor_interface with the updated filters
    monitor_interface "$bridge_interface"
  else
    format-echo "ERROR" "Could not determine subnet for Docker network $network."
    return 1
  fi
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

  print_with_separator "Network Monitor Script"
  format-echo "INFO" "Starting Network Monitor Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check for tcpdump
  if ! command -v tcpdump &> /dev/null; then
    format-echo "ERROR" "tcpdump is not installed. Please install it and try again."
    print_with_separator "End of Network Monitor Script"
    exit 1
  fi
  
  # Ensure we have at least one target to monitor
  if [ -z "$INTERFACE" ] && [ -z "$DOCKER_CONTAINER" ] && [ -z "$DOCKER_NETWORK" ]; then
    format-echo "ERROR" "Must specify either --interface, --container, or --docker-net."
    print_with_separator "End of Network Monitor Script"
    usage
  fi
  
  # If using Docker features, validate Docker is available
  if [ -n "$DOCKER_CONTAINER" ] || [ -n "$DOCKER_NETWORK" ]; then
    if ! check_docker_available; then
      format-echo "ERROR" "Docker is required for container or network monitoring."
      print_with_separator "End of Network Monitor Script"
      exit 1
    fi
  fi
  
  # Validate interface exists if specified
  if [ -n "$INTERFACE" ]; then
    if ! ip link show "$INTERFACE" &> /dev/null; then
      format-echo "ERROR" "Network interface $INTERFACE does not exist."
      print_with_separator "End of Network Monitor Script"
      exit 1
    fi
  fi

  #---------------------------------------------------------------------
  # NETWORK MONITORING
  #---------------------------------------------------------------------
  trap 'echo; format-echo "INFO" "Monitoring stopped by user"; EXIT_CODE=0' INT
  
  # Determine what to monitor and start monitoring
  if [ -n "$DOCKER_CONTAINER" ]; then
    if ! monitor_docker_container "$DOCKER_CONTAINER"; then
      EXIT_CODE=1
    fi
  elif [ -n "$DOCKER_NETWORK" ]; then
    if ! monitor_docker_network "$DOCKER_NETWORK"; then
      EXIT_CODE=1
    fi
  elif [ -n "$INTERFACE" ]; then
    if ! monitor_interface "$INTERFACE"; then
      EXIT_CODE=1
    fi
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Network Monitor Script"
  
  if [ "$EXIT_CODE" -eq 0 ]; then
    if [ -n "$CAPTURE_FILE" ]; then
      format-echo "SUCCESS" "Network traffic monitoring completed. Capture saved to $CAPTURE_FILE."
    else
      format-echo "SUCCESS" "Network traffic monitoring completed."
    fi
  else
    format-echo "ERROR" "Network traffic monitoring failed."
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?