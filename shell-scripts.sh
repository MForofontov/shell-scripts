#!/bin/bash
# shell-scripts.sh
# A wrapper script to manage and execute all shell scripts in the same directory as this script

# Dynamically determine the base directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display usage instructions
usage() {
    echo "Usage: $0 <script_name> [arguments]"
    echo "Available scripts:"
    find "$BASE_DIR" -type f -name "*.sh" -exec basename {} .sh \; | sed 's/^/  /'
    echo
    echo "Example:"
    echo "  $0 npm-list-global npm_global_packages.log"
    echo "  $0 ping ping_results.txt"
    exit 1
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the script name and shift arguments
SCRIPT_NAME="$1"
shift

# Find the script in the directory (without requiring .sh extension)
SCRIPT_PATH=$(find "$BASE_DIR" -type f -name "$SCRIPT_NAME.sh" 2>/dev/null)

if [ -z "$SCRIPT_PATH" ]; then
    echo "Error: Script '$SCRIPT_NAME' not found in $BASE_DIR."
    usage
fi

# Make the script executable (just in case)
chmod +x "$SCRIPT_PATH"

# Execute the script with any additional arguments
"$SCRIPT_PATH" "$@"