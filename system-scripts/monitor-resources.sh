#!/bin/bash
# monitor-resources.sh
# Script to monitor and log CPU, memory, disk, and network usage

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <log_file>"
    exit 1
fi

# Get the log file from the argument and ensure it's an absolute path
LOG_FILE=$(realpath "$1")

# Check if the log file exists, create it if it doesn't, and warn the user
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    echo "Warning: Log file $LOG_FILE did not exist and has been created."
fi

# Function to log CPU usage
log_cpu_usage() {
    echo "CPU Usage:" >> "$LOG_FILE"
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU Load: " 100 - $1"%"}' >> "$LOG_FILE"
}

# Function to log memory usage
log_memory_usage() {
    echo "Memory Usage:" >> "$LOG_FILE"
    free -h | awk '/^Mem/ {print "Total: " $2 ", Used: " $3 ", Free: " $4}' >> "$LOG_FILE"
}

# Function to log disk usage
log_disk_usage() {
    echo "Disk Usage:" >> "$LOG_FILE"
    df -h | awk '$NF=="/"{print "Total: " $2 ", Used: " $3 ", Available: " $4 ", Usage: " $5}' >> "$LOG_FILE"
}

# Function to log network usage
log_network_usage() {
    echo "Network Usage:" >> "$LOG_FILE"
    ifstat -t 1 1 | awk 'NR==3 {print "In: " $6 " KB/s, Out: " $8 " KB/s"}' >> "$LOG_FILE"
}

# Record current date and time
echo "Resource usage at $(date)" >> "$LOG_FILE"

# Log CPU, memory, disk, and network usage
log_cpu_usage
log_memory_usage
log_disk_usage
log_network_usage

# Add a separator for readability
echo "--------------------------------------" >> "$LOG_FILE"

# Notify user
echo "Resource usage logged to $LOG_FILE."