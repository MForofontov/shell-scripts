#!/bin/bash
# ip-extractor-from-log-file.sh
# Script to extract unique IP addresses from a log file

# Dynamically determine the directory of the current script
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Construct the path to the logger and utility files relative to the script's directory
LOG_FUNCTION_FILE="$SCRIPT_DIR/../functions/log/log-with-levels.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

# Source the logger file
if [ -f "$LOG_FUNCTION_FILE" ]; then
  source "$LOG_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Logger file not found at $LOG_FUNCTION_FILE"
  exit 1
fi

# Source the utility file for print_with_separator
if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

# Function to display usage instructions
usage() {
    print_with_separator "IP Extractor Script"
    echo -e "\033[1;34mDescription:\033[0m"
    echo "  This script extracts unique IP addresses from a log file."
    echo "  It also supports optional output to a file."
    echo
    echo -e "\033[1;34mUsage:\033[0m"
    echo "  $0 <log_file> [output_file] [--help]"
    echo
    echo -e "\033[1;34mOptions:\033[0m"
    echo -e "  \033[1;36m<log_file>\033[0m       (Required) Path to the log file."
    echo -e "  \033[1;33m[output_file]\033[0m    (Optional) Path to save the extracted IPs."
    echo -e "  \033[1;33m--help\033[0m           (Optional) Display this help message."
    echo
    echo -e "\033[1;34mExamples:\033[0m"
    echo "  $0 /path/to/logfile.log extracted_ips.txt"
    echo "  $0 /path/to/logfile.log"
    print_with_separator
    exit 1
}

# Check if no arguments are provided
if [ "$#" -lt 1 ]; then
    log_message "ERROR" "Log file is required."
    usage
fi

# Parse arguments
LOG_FILE=""
OUTPUT_FILE=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            ;;
        *)
            if [ -z "$LOG_FILE" ]; then
                LOG_FILE="$1"
            elif [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE="$1"
            else
                log_message "ERROR" "Too many arguments provided."
                usage
            fi
            shift
            ;;
    esac
done

# Validate log file
if [ -z "$LOG_FILE" ]; then
    log_message "ERROR" "Log file is required."
    usage
fi

if [ ! -f "$LOG_FILE" ]; then
    log_message "ERROR" "Log file $LOG_FILE does not exist."
    exit 1
fi

# Validate output file if provided
if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
        log_message "ERROR" "Cannot write to output file $OUTPUT_FILE"
        exit 1
    fi
fi

log_message "INFO" "Extracting IP addresses from $LOG_FILE..."
print_with_separator "IP Extraction Output"

# Extract unique IP addresses
extract_ips() {
    if [ -n "$OUTPUT_FILE" ]; then
        if ! grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$LOG_FILE" | sort -u > "$OUTPUT_FILE"; then
            log_message "ERROR" "Failed to extract IP addresses."
            exit 1
        fi
        log_message "SUCCESS" "Extracted IPs saved to $OUTPUT_FILE"
    else
        if ! grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$LOG_FILE" | sort -u; then
            log_message "ERROR" "Failed to extract IP addresses."
            exit 1
        fi
    fi
}

# Perform IP extraction
if ! extract_ips; then
    log_message "ERROR" "IP extraction failed."
    print_with_separator "End of IP Extraction Output"
    exit 1
fi

print_with_separator "End of IP Extraction Output"
log_message "SUCCESS" "IP extraction completed successfully."