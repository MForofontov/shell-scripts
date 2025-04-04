#!/bin/bash
# shell-scripts.sh
# A wrapper script to manage and execute all shell scripts in the same directory as this script

# Dynamically determine the base directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display usage instructions with organized folder structure
usage() {
    echo -e "\n\033[1;34mUsage:\033[0m $0 <script_name> [arguments]"
    echo -e "\033[1;34mAvailable scripts:\033[0m"
    echo

    # Find all scripts and group them by folder
    find "$BASE_DIR" -type f -name "*.sh" | while read -r SCRIPT; do
        # Extract the folder name and script name
        FOLDER=$(dirname "$SCRIPT" | sed "s|$BASE_DIR/||")
        SCRIPT_NAME=$(basename "$SCRIPT" .sh)

        # Display folder and script names
        if [ "$CURRENT_FOLDER" != "$FOLDER" ]; then
            CURRENT_FOLDER="$FOLDER"
            echo -e "\033[1;33m$FOLDER:\033[0m"
        fi
        echo -e "  \033[1;32m$SCRIPT_NAME\033[0m"
    done
    echo
    echo -e "\033[1;34mExample:\033[0m"
    echo "  $0 npm-list-global npm_global_packages.log"
    echo "  $0 ping ping_results.txt"
    exit 1
}

# Check if the script name is provided
if [ "$#" -lt 1 ]; then
    usage
fi

# Get the script name and shift arguments
SCRIPT_NAME="$1"
shift

# Find the script in the directory (without requiring .sh extension)
SCRIPT_PATH=$(find "$BASE_DIR" -type f -name "$SCRIPT_NAME.sh" 2>/dev/null)

if [ -z "$SCRIPT_PATH" ]; then
    echo -e "\033[1;31mError:\033[0m Script '$SCRIPT_NAME' not found in $BASE_DIR."
    usage
fi

# Make the script executable (just in case)
chmod +x "$SCRIPT_PATH"

# Execute the script with any additional arguments
exec "$SCRIPT_PATH" "$@"