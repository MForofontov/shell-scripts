#!/bin/bash
# system-report.sh
# Script to generate a comprehensive system report.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
REPORT_FILE=""
LOG_FILE="/dev/null"
FORMAT="text"
INCLUDE_NETWORK=true
INCLUDE_PROCESSES=true
INCLUDE_PACKAGES=true
INCLUDE_DOCKER=false
VERBOSE=false
EXIT_CODE=0

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "System Report Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates a comprehensive system report and saves it to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <report_file> [--format <format>] [--skip-network] [--skip-processes]"
  echo "     [--skip-packages] [--include-docker] [--verbose] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<report_file>\033[0m              (Required) Path to save the system report."
  echo -e "  \033[1;33m--format <format>\033[0m          (Optional) Output format: text, html, json (default: text)."
  echo -e "  \033[1;33m--skip-network\033[0m             (Optional) Skip network information in the report."
  echo -e "  \033[1;33m--skip-processes\033[0m           (Optional) Skip process information in the report."
  echo -e "  \033[1;33m--skip-packages\033[0m            (Optional) Skip package information in the report."
  echo -e "  \033[1;33m--include-docker\033[0m           (Optional) Include Docker container information."
  echo -e "  \033[1;33m--verbose\033[0m                  (Optional) Include more detailed information."
  echo -e "  \033[1;33m--log <log_file>\033[0m           (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                     (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/report.txt --log system_report.log"
  echo "  $0 /path/to/report.html --format html --include-docker --verbose"
  echo "  $0 /path/to/report.json --format json --skip-processes"
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
      --format)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No format provided after --format."
          usage
        fi
        if [[ ! "$2" =~ ^(text|html|json)$ ]]; then
          format-echo "ERROR" "Invalid format: $2. Must be text, html, or json."
          usage
        fi
        FORMAT="$2"
        shift 2
        ;;
      --skip-network)
        INCLUDE_NETWORK=false
        shift
        ;;
      --skip-processes)
        INCLUDE_PROCESSES=false
        shift
        ;;
      --skip-packages)
        INCLUDE_PACKAGES=false
        shift
        ;;
      --include-docker)
        INCLUDE_DOCKER=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      *)
        if [ -z "$REPORT_FILE" ]; then
          REPORT_FILE="$1"
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
# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS"
  elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "$NAME"
  elif command_exists lsb_release; then
    lsb_release -si
  elif [[ -f /etc/lsb-release ]]; then
    source /etc/lsb-release
    echo "$DISTRIB_ID"
  else
    echo "Unknown OS"
  fi
}

# Format text based on output format
format_section_header() {
  local title="$1"
  
  case "$FORMAT" in
    html)
      echo "<h2>$title</h2>"
      ;;
    json)
      # This is handled differently in generate_report_json
      ;;
    text|*)
      echo ""
      print_with_separator "$title"
      ;;
  esac
}

# Format command output based on output format
format_command_output() {
  local cmd_name="$1"
  local cmd_output="$2"
  
  case "$FORMAT" in
    html)
      echo "<h3>$cmd_name</h3>"
      echo "<pre>$cmd_output</pre>"
      ;;
    json)
      # This is handled differently in generate_report_json
      ;;
    text|*)
      echo "--- $cmd_name ---"
      echo "$cmd_output"
      echo ""
      ;;
  esac
}

# Safe command execution with error handling
safe_exec() {
  local cmd="$1"
  local fallback_msg="$2"
  
  # Execute command and capture output, redirecting stderr
  local output
  if output=$(eval "$cmd" 2>/dev/null); then
    if [ -z "$output" ]; then
      echo "$fallback_msg"
    else
      echo "$output"
    fi
  else
    echo "$fallback_msg"
  fi
}

#=====================================================================
# REPORT GENERATION FUNCTIONS
#=====================================================================
# Get basic system information
get_system_info() {
  local hostname
  local os_type
  local kernel
  local uptime_info
  
  hostname=$(hostname 2>/dev/null || echo "Unknown")
  os_type=$(detect_os)
  kernel=$(uname -r 2>/dev/null || echo "Unknown")
  
  if [[ "$OSTYPE" == "darwin"* ]]; then
    uptime_info=$(uptime 2>/dev/null || echo "Unknown")
  else
    uptime_info=$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo "Unknown")
  fi
  
  echo "Hostname: $hostname"
  echo "Operating System: $os_type"
  echo "Kernel Version: $kernel"
  echo "Uptime: $uptime_info"
  
  # Add more detailed system info if verbose mode
  if [ "$VERBOSE" = true ]; then
    echo "Architecture: $(uname -m 2>/dev/null || echo "Unknown")"
    echo "Processor: $(grep -m 1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 || sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "OS Version: $(sw_vers -productVersion 2>/dev/null || echo "Unknown")"
    elif [[ -f /etc/os-release ]]; then
      source /etc/os-release
      echo "OS Version: $VERSION_ID"
    fi
  fi
}

# Get CPU information
get_cpu_info() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "CPU Model: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
    echo "CPU Cores: $(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")"
    echo "CPU Usage: $(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3 " user, " $5 " sys, " $7 " idle"}' 2>/dev/null || echo "Unknown")"
  else
    echo "CPU Model: $(grep -m 1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo "Unknown")"
    echo "CPU Cores: $(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo "Unknown")"
    echo "CPU Usage: $(safe_exec "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print (100 - \$1) \"%\"}'" "Unknown")"
    
    if [ "$VERBOSE" = true ]; then
      echo -e "\nDetailed CPU Info:"
      lscpu 2>/dev/null || echo "lscpu not available"
    fi
  fi
}

# Get memory information
get_memory_info() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Total Memory: $(sysctl -n hw.memsize 2>/dev/null | awk '{ printf "%.2f GB\n", $1/1024/1024/1024 }' || echo "Unknown")"
    echo "Memory Usage:"
    vm_stat 2>/dev/null | awk '
      /Pages active/ {active=$3}
      /Pages inactive/ {inactive=$3}
      /Pages speculative/ {speculative=$3}
      /Pages wired down/ {wired=$4}
      /Pages free/ {free=$3}
      END {
        total=(active+inactive+speculative+wired+free)*4096/1024/1024/1024
        used=(active+wired)*4096/1024/1024/1024
        printf "  Used: %.2f GB\n", used
        printf "  Free: %.2f GB\n", (total-used)
        printf "  Total: %.2f GB\n", total
      }' || echo "  Memory usage information unavailable"
  else
    if command_exists free; then
      echo "Memory Usage:"
      free -h 2>/dev/null | head -3 | awk 'NR==1 {printf "  %s\n", $0} NR==2 {printf "  %s\n", $0}' || echo "  Memory usage information unavailable"
      
      if [ "$VERBOSE" = true ] && command_exists vmstat; then
        echo -e "\nDetailed Memory Info:"
        vmstat -s 2>/dev/null | head -8 || echo "vmstat information unavailable"
      fi
    else
      echo "Memory information not available (free command not found)"
    fi
  fi
}

# Get disk information
get_disk_info() {
  echo "Disk Usage:"
  df -h 2>/dev/null | grep -v "tmpfs\|devtmpfs" | awk 'NR==1 || /^\/dev/' || echo "Disk usage information unavailable"
  
  if [ "$VERBOSE" = true ]; then
    if command_exists lsblk; then
      echo -e "\nBlock Devices:"
      lsblk -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null | grep -v "loop" || echo "Block device information unavailable"
    fi
    
    echo -e "\nLargest Directories:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      safe_exec "du -h -d 1 / 2>/dev/null | grep -v '^0' | sort -hr | head -5" "Directory size information unavailable"
    else
      safe_exec "du -h --max-depth=1 / 2>/dev/null | grep -v '^0' | sort -hr | head -5" "Directory size information unavailable"
    fi
  fi
}

# Get network information
get_network_info() {
  if ! $INCLUDE_NETWORK; then
    echo "Network information skipped as requested."
    return
  fi
  
  echo "Network Interfaces:"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # More concise output for macOS - show interfaces and IP addresses
    ifconfig -a 2>/dev/null | grep -E '^[a-z0-9]+:|inet ' | sed 's/netmask.*//' | head -20 || echo "Network interface information unavailable"
  else
    ip -br addr 2>/dev/null || ip addr | grep -E 'inet|^[0-9]+:' | head -20 || echo "Network interface information unavailable"
  fi
  
  echo -e "\nNetwork Routes:"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    netstat -nr 2>/dev/null | head -10 || echo "Network route information unavailable"
  else
    ip route 2>/dev/null | head -5 || echo "Network route information unavailable"
  fi
  
  if [ "$VERBOSE" = true ]; then
    echo -e "\nOpen Ports:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      netstat -an 2>/dev/null | grep LISTEN | head -10 || echo "Open port information unavailable"
    else
      if command_exists ss; then
        ss -tuln 2>/dev/null | head -10 || echo "Open port information unavailable"
      elif command_exists netstat; then
        netstat -tuln 2>/dev/null | head -10 || echo "Open port information unavailable"
      else
        echo "No tool available to list open ports"
      fi
    fi
    
    echo -e "\nDNS Configuration:"
    cat /etc/resolv.conf 2>/dev/null || echo "Cannot read DNS configuration"
  fi
}

# Get running processes - improved for better formatting and error handling
get_process_info() {
  if ! $INCLUDE_PROCESSES; then
    echo "Process information skipped as requested."
    return
  fi
  
  echo "Top CPU Processes:"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Increase width for command column and remove redundant error message
    ps -eo pcpu,pid,user,command 2>/dev/null | sort -k 1 -r | head -6 | awk '{
      cmd = "";
      for(i=4; i<=NF; i++) cmd = cmd (i==4 ? "" : " ") $i;
      printf "%-6s %-6s %-10s %.70s\n", $1, $2, $3, cmd
    }' || echo "Process information unavailable"
  else
    ps -eo pcpu,pid,user,comm --sort=-%cpu 2>/dev/null | head -6 || echo "Process information unavailable"
  fi
  
  echo -e "\nTop Memory Processes:"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # Increase width for command column and remove redundant error message
    ps -eo pmem,pid,user,command 2>/dev/null | sort -k 1 -r | head -6 | awk '{
      cmd = "";
      for(i=4; i<=NF; i++) cmd = cmd (i==4 ? "" : " ") $i;
      printf "%-6s %-6s %-10s %.70s\n", $1, $2, $3, cmd
    }' || echo "Process information unavailable"
  else
    ps -eo pmem,pid,user,comm --sort=-%mem 2>/dev/null | head -6 || echo "Process information unavailable"
  fi
  
  if [ "$VERBOSE" = true ]; then
    echo -e "\nProcess Summary:"
    ps -e 2>/dev/null | wc -l | awk '{print "Total processes: " $1}' || echo "Process count unavailable"
    
    echo -e "\nService Status (select services):"
    if command_exists systemctl; then
      systemctl status --no-pager sshd nginx apache2 docker 2>/dev/null | grep -E "Active:|●" | head -5 || echo "No common services found or systemctl unavailable"
    elif [[ "$OSTYPE" == "darwin"* ]] && command_exists brew; then
      brew services list 2>/dev/null | head -5 || echo "Homebrew services information unavailable"
    else
      echo "No service management tool available"
    fi
  fi
}

# Get package information
get_package_info() {
  if ! $INCLUDE_PACKAGES; then
    echo "Package information skipped as requested."
    return
  fi
  
  echo "Installed Packages Summary:"
  
  if command_exists dpkg; then
    echo "Debian packages: $(dpkg -l 2>/dev/null | grep -c '^ii' || echo "Unknown")"
  elif command_exists rpm; then
    echo "RPM packages: $(rpm -qa 2>/dev/null | wc -l || echo "Unknown")"
  elif command_exists pacman; then
    echo "Pacman packages: $(pacman -Q 2>/dev/null | wc -l || echo "Unknown")"
  elif [[ "$OSTYPE" == "darwin"* ]] && command_exists brew; then
    echo "Homebrew packages: $(brew list 2>/dev/null | wc -l || echo "Unknown")"
  else
    echo "No known package manager found"
  fi
  
  if [ "$VERBOSE" = true ]; then
    echo -e "\nRecently Updated Packages:"
    if command_exists apt; then
      grep -A 5 'Commandline: apt' /var/log/apt/history.log 2>/dev/null | grep 'Install\|Upgrade' | tail -5 || echo "No apt history found"
    elif command_exists yum; then
      yum history 2>/dev/null | head -7 || echo "No yum history found"
    elif [[ "$OSTYPE" == "darwin"* ]] && command_exists brew; then
      brew list --versions 2>/dev/null | tail -5 || echo "No brew history found"
    else
      echo "No package history available"
    fi
  fi
}

# Get Docker information
get_docker_info() {
  if ! $INCLUDE_DOCKER; then
    return
  fi
  
  if ! command_exists docker; then
    echo "Docker information requested but Docker is not installed."
    return
  fi
  
  echo "Docker Information:"
  
  # Check if Docker daemon is running
  if ! docker info &>/dev/null; then
    echo "Docker daemon is not running."
    return
  fi
  
  echo -e "\nDocker Version:"
  docker version --format '{{.Server.Version}}' 2>/dev/null || docker --version
  
  echo -e "\nRunning Containers:"
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || echo "No running containers"
  
  if [ "$VERBOSE" = true ]; then
    echo -e "\nDocker Images:"
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" 2>/dev/null | head -10 || echo "No Docker images"
    
    echo -e "\nDocker Networks:"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" 2>/dev/null || echo "No Docker networks"
    
    echo -e "\nDocker Volumes:"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}" 2>/dev/null | head -5 || echo "No Docker volumes"
  fi
}

# Generate a text report
generate_report_text() {
  {
    print_with_separator
    echo "SYSTEM REPORT"
    echo "Generated: $(date)"
    print_with_separator
    
    format_section_header "SYSTEM INFORMATION"
    get_system_info
    
    format_section_header "CPU INFORMATION"
    get_cpu_info
    
    format_section_header "MEMORY INFORMATION"
    get_memory_info
    
    format_section_header "DISK INFORMATION"
    get_disk_info
    
    if $INCLUDE_NETWORK; then
      format_section_header "NETWORK INFORMATION"
      get_network_info
    fi
    
    if $INCLUDE_PROCESSES; then
      format_section_header "PROCESS INFORMATION"
      get_process_info
    fi
    
    if $INCLUDE_PACKAGES; then
      format_section_header "PACKAGE INFORMATION"
      get_package_info
    fi
    
    if $INCLUDE_DOCKER; then
      format_section_header "DOCKER INFORMATION"
      get_docker_info
    fi
    
    echo ""
    print_with_separator
    echo "END OF REPORT"
    print_with_separator
    # Add an explicit end marker to ensure nothing gets appended accidentally
    echo ""
  } > "$REPORT_FILE"
}

# Generate an HTML report
generate_report_html() {
  {
    cat << EOF
<!DOCTYPE html>
<html>
<head>
  <title>System Report - $(date)</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; border-bottom: 2px solid #333; }
    h2 { color: #0066cc; margin-top: 20px; border-bottom: 1px solid #ccc; }
    h3 { color: #009900; }
    pre { background-color: #f5f5f5; padding: 10px; border: 1px solid #ddd; overflow-x: auto; }
    .footer { margin-top: 30px; border-top: 1px solid #ccc; padding-top: 10px; color: #777; }
  </style>
</head>
<body>
  <h1>System Report</h1>
  <p>Generated: $(date)</p>
EOF

    # Use function to capture content and escape HTML special characters
    capture_and_escape() {
      local content
      content=$($1 2>/dev/null || echo "Information unavailable")
      echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
    }

    echo "<h2>System Information</h2>"
    echo "<pre>$(capture_and_escape get_system_info)</pre>"
    
    echo "<h2>CPU Information</h2>"
    echo "<pre>$(capture_and_escape get_cpu_info)</pre>"
    
    echo "<h2>Memory Information</h2>"
    echo "<pre>$(capture_and_escape get_memory_info)</pre>"
    
    echo "<h2>Disk Information</h2>"
    echo "<pre>$(capture_and_escape get_disk_info)</pre>"
    
    if $INCLUDE_NETWORK; then
      echo "<h2>Network Information</h2>"
      echo "<pre>$(capture_and_escape get_network_info)</pre>"
    fi
    
    if $INCLUDE_PROCESSES; then
      echo "<h2>Process Information</h2>"
      echo "<pre>$(capture_and_escape get_process_info)</pre>"
    fi
    
    if $INCLUDE_PACKAGES; then
      echo "<h2>Package Information</h2>"
      echo "<pre>$(capture_and_escape get_package_info)</pre>"
    fi
    
    if $INCLUDE_DOCKER; then
      echo "<h2>Docker Information</h2>"
      echo "<pre>$(capture_and_escape get_docker_info)</pre>"
    fi
    
    cat << EOF
  <div class="footer">
    Report generated by System Report Script
  </div>
</body>
</html>
EOF
  } > "$REPORT_FILE"
}

# Generate a JSON report
generate_report_json() {
  # Create temporary files for each section
  local temp_dir
  temp_dir=$(mktemp -d)
  
  # Function to safely capture output for JSON
  capture_for_json() {
    local func="$1"
    local output_file="$2"
    
    if $func > "$output_file" 2>/dev/null; then
      # Escape backslashes and quotes for JSON
      sed -i.bak 's/\\/\\\\/g; s/"/\\"/g' "$output_file" 2>/dev/null || true
    else
      echo "Error retrieving information" > "$output_file"
    fi
  }
  
  # Capture output of each section
  capture_for_json get_system_info "$temp_dir/system.txt"
  capture_for_json get_cpu_info "$temp_dir/cpu.txt"
  capture_for_json get_memory_info "$temp_dir/memory.txt"
  capture_for_json get_disk_info "$temp_dir/disk.txt"
  
  if $INCLUDE_NETWORK; then
    capture_for_json get_network_info "$temp_dir/network.txt"
  fi
  
  if $INCLUDE_PROCESSES; then
    capture_for_json get_process_info "$temp_dir/processes.txt"
  fi
  
  if $INCLUDE_PACKAGES; then
    capture_for_json get_package_info "$temp_dir/packages.txt"
  fi
  
  if $INCLUDE_DOCKER; then
    capture_for_json get_docker_info "$temp_dir/docker.txt"
  fi
  
  # Function to safely convert file to JSON string
  file_to_json_string() {
    local file="$1"
    if command_exists jq; then
      jq -R -s . < "$file" 2>/dev/null || echo "\"Error generating JSON\""
    else
      echo "\"$(cat "$file" | tr '\n' ' ' | sed 's/"/\\"/g')\""
    fi
  }
  
  # Generate JSON
  {
    echo "{"
    echo "  \"report_time\": \"$(date)\"," 
    echo "  \"system_info\": $(file_to_json_string "$temp_dir/system.txt"),"
    echo "  \"cpu_info\": $(file_to_json_string "$temp_dir/cpu.txt"),"
    echo "  \"memory_info\": $(file_to_json_string "$temp_dir/memory.txt"),"
    echo "  \"disk_info\": $(file_to_json_string "$temp_dir/disk.txt")"
    
    if $INCLUDE_NETWORK; then
      echo "  ,\"network_info\": $(file_to_json_string "$temp_dir/network.txt")"
    fi
    
    if $INCLUDE_PROCESSES; then
      echo "  ,\"process_info\": $(file_to_json_string "$temp_dir/processes.txt")"
    fi
    
    if $INCLUDE_PACKAGES; then
      echo "  ,\"package_info\": $(file_to_json_string "$temp_dir/packages.txt")"
    fi
    
    if $INCLUDE_DOCKER; then
      echo "  ,\"docker_info\": $(file_to_json_string "$temp_dir/docker.txt")"
    fi
    
    echo "  ,\"verbose_mode\": $VERBOSE"
    echo "}"
  } > "$REPORT_FILE"
  
  # Clean up temporary files
  rm -rf "$temp_dir"
}

# Generate the report
generate_report() {
  format-echo "INFO" "Generating system report in $FORMAT format..."
  
  case "$FORMAT" in
    html)
      generate_report_html
      ;;
    json)
      generate_report_json
      ;;
    text|*)
      generate_report_text
      ;;
  esac
  
  if [ -f "$REPORT_FILE" ]; then
    format-echo "SUCCESS" "System report generated successfully."
    if [ "$VERBOSE" = true ]; then
      format-echo "INFO" "Report size: $(du -h "$REPORT_FILE" | cut -f1)"
    fi
  else
    format-echo "ERROR" "Failed to generate system report."
    EXIT_CODE=1
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

  setup_log_file

  print_with_separator "System Report Script"
  format-echo "INFO" "Starting System Report Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate required arguments
  if [ -z "$REPORT_FILE" ]; then
    format-echo "ERROR" "The <report_file> argument is required."
    print_with_separator "End of System Report Script"
    usage
  fi
  
  # Validate we can write to the report file
  if ! touch "$REPORT_FILE" 2>/dev/null; then
    format-echo "ERROR" "Cannot write to report file: $REPORT_FILE"
    print_with_separator "End of System Report Script"
    exit 1
  fi
  
  # Validate required tools based on format
  if [ "$FORMAT" = "json" ] && ! command_exists jq; then
    format-echo "WARNING" "jq command not found. JSON output may not be properly formatted."
  fi

  #---------------------------------------------------------------------
  # REPORT GENERATION
  #---------------------------------------------------------------------
  generate_report

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of System Report Script"
  if [ $EXIT_CODE -eq 0 ]; then
    format-echo "SUCCESS" "System report generated at $REPORT_FILE."
  else
    format-echo "ERROR" "System report generation encountered issues."
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
