#!/usr/bin/env bash
# sync-directories.sh
# Script to synchronize two directories using rsync

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
SOURCE_DIR=""
DEST_DIR=""
# shellcheck disable=SC2034
LOG_FILE="/dev/null"

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Synchronize Directories Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script synchronizes two directories using rsync."
  echo "  It also supports optional logging to a file."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <source_directory> <destination_directory> [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;36m<source_directory>\033[0m       (Required) Directory to synchronize from."
  echo -e "  \033[1;36m<destination_directory>\033[0m  (Required) Directory to synchronize to."
  echo -e "  \033[1;33m--log <log_file>\033[0m         (Optional) Log output to the specified file."
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 /path/to/source /path/to/destination --log custom_log.log"
  echo "  $0 /path/to/source /path/to/destination"
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
        if [ -z "$SOURCE_DIR" ]; then
          SOURCE_DIR="$1"
          shift
        elif [ -z "$DEST_DIR" ]; then
          DEST_DIR="$1"
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

  print_with_separator "Synchronize Directories Script"
  format-echo "INFO" "Starting Synchronize Directories Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Validate arguments
  if [ -z "$SOURCE_DIR" ] || [ -z "$DEST_DIR" ]; then
    format-echo "ERROR" "<source_directory> and <destination_directory> are required."
    print_with_separator "End of Synchronize Directories Script"
    exit 1
  fi

  if [ ! -d "$SOURCE_DIR" ]; then
    format-echo "ERROR" "Source directory $SOURCE_DIR does not exist."
    print_with_separator "End of Synchronize Directories Script"
    exit 1
  fi

  if [ ! -d "$DEST_DIR" ]; then
    format-echo "INFO" "Destination directory $DEST_DIR does not exist. Creating it..."
    if ! mkdir -p "$DEST_DIR"; then
      format-echo "ERROR" "Failed to create destination directory $DEST_DIR."
      print_with_separator "End of Synchronize Directories Script"
      exit 1
    fi
    format-echo "SUCCESS" "Created destination directory $DEST_DIR."
  fi

  #---------------------------------------------------------------------
  # SYNCHRONIZATION OPERATION
  #---------------------------------------------------------------------
  format-echo "INFO" "Synchronizing directories from $SOURCE_DIR to $DEST_DIR..."
  
  # Get source directory size
  SOURCE_SIZE=$(du -sh "$SOURCE_DIR" | cut -f1)
  format-echo "INFO" "Source directory size: $SOURCE_SIZE"
  
  # Check if rsync is available
  if ! command -v rsync &> /dev/null; then
    format-echo "ERROR" "rsync is not installed or not available in the PATH."
    print_with_separator "End of Synchronize Directories Script"
    exit 1
  fi
  
  print_with_separator "Synchronization Output"

  if rsync -av --delete "$SOURCE_DIR/" "$DEST_DIR/"; then
    print_with_separator "End of Synchronization Output"
    
    # Get destination directory size after sync
    DEST_SIZE=$(du -sh "$DEST_DIR" | cut -f1)
    format-echo "INFO" "Destination directory size after sync: $DEST_SIZE"
    
    format-echo "SUCCESS" "Synchronization complete from $SOURCE_DIR to $DEST_DIR."
  else
    print_with_separator "End of Synchronization Output"
    format-echo "ERROR" "Failed to synchronize directories."
    print_with_separator "End of Synchronize Directories Script"
    exit 1
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "INFO" "Synchronization operation completed."
  print_with_separator "End of Synchronize Directories Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
