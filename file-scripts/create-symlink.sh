#!/bin/bash
# create-symlink.sh
# Script to create a symbolic link

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
TARGET_FILE=""
LINK_NAME=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Create Symbolic Link Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script creates a symbolic link to a target file."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <target_file> <link_name> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<target_file>\033[0m      (Required) Path to the target file."
  echo -e "  \033[1;36m<link_name>\033[0m        (Required) Path to the symbolic link to create."
  echo -e "  \033[1;33m--log <log_file>\033[0m   (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m             (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/target /path/to/link --log custom_log.log"
  echo "  $0 /path/to/target /path/to/link"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log)
        if [[ -n "${2:-}" ]]; then
          LOG_FILE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --log"
          usage
        fi
        ;;
      --help)
        usage
        ;;
      *)
        if [ -z "$TARGET_FILE" ]; then
          TARGET_FILE="$1"
          shift
        elif [ -z "$LINK_NAME" ]; then
          LINK_NAME="$1"
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
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"

  setup_log_file

  print_with_separator "Create Symbolic Link Script"
  format-echo "INFO" "Starting Create Symbolic Link Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$TARGET_FILE" ] || [ -z "$LINK_NAME" ]; then
    format-echo "ERROR" "<target_file> and <link_name> are required."
    print_with_separator "End of Create Symbolic Link Script"
    exit 1
  fi

  if [ ! -e "$TARGET_FILE" ]; then
    format-echo "ERROR" "Target file $TARGET_FILE does not exist."
    print_with_separator "End of Create Symbolic Link Script"
    exit 1
  fi

  # Check if link already exists
  if [ -e "$LINK_NAME" ]; then
    format-echo "WARNING" "Link destination $LINK_NAME already exists."
    print_with_separator "End of Create Symbolic Link Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # LINK CREATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Creating symbolic link: $LINK_NAME -> $TARGET_FILE"

  if ln -s "$TARGET_FILE" "$LINK_NAME"; then
    format-echo "SUCCESS" "Symbolic link created: $LINK_NAME -> $TARGET_FILE"
  else
    format-echo "ERROR" "Failed to create symbolic link."
    print_with_separator "End of Create Symbolic Link Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Symbolic link creation completed."
  print_with_separator "End of Create Symbolic Link Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
