#!/bin/bash
# system-report.sh
# Script to generate a system report

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <report_file>"
    exit 1
fi

# Get the report file path from the argument
REPORT_FILE="$1"

# Generate system report
echo "System Report - $(date)" > "$REPORT_FILE"
echo "----------------------------------" >> "$REPORT_FILE"
echo "Uptime:" >> "$REPORT_FILE"
uptime >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Disk Usage:" >> "$REPORT_FILE"
df -h >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Memory Usage:" >> "$REPORT_FILE"
free -h >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "CPU Usage:" >> "$REPORT_FILE"
top -bn1 | grep "Cpu(s)" >> "$REPORT_FILE"

# Notify user
echo "System report generated at $REPORT_FILE."