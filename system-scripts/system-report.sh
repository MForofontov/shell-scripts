#!/bin/bash
# system-report.sh
# Script to generate a system report

# Configuration
REPORT_FILE="/path/to/system_report.txt"  # File to save the report

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
