#!/bin/bash
# Script to set secure permissions for sensitive files.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
LOG_FILE="/dev/null"
FILES=()
DIRECTORIES=()
DEFAULT_FILE_PERMS="600"
DEFAULT_DIR_PERMS="700"
FILE_OWNER=""
FILE_GROUP=""
RECURSIVE=false
DRY_RUN=false
VERBOSE=false
AUTO_DETECT=false
AUTO_DETECT_PATHS=("$HOME/.ssh" "$HOME/.kube" "$HOME/.aws" "$HOME/.gnupg")
FIND_PATTERNS=("*.key" "*.pem" "*.crt" "id_rsa" "id_dsa" "kubeconfig" "config" "credentials" "*.p12" "*.pfx")

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Secure File Permissions Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script sets secure permissions for sensitive files and directories."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options] [file1 file2 ... | directory1 directory2 ...]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--file-perm <permissions>\033[0m   (Optional) Permissions to set for files (default: $DEFAULT_FILE_PERMS)"
  echo -e "  \033[1;33m--dir-perm <permissions>\033[0m    (Optional) Permissions to set for directories (default: $DEFAULT_DIR_PERMS)"
  echo -e "  \033[1;33m--owner <user>\033[0m              (Optional) Owner to set for files/directories"
  echo -e "  \033[1;33m--group <group>\033[0m             (Optional) Group to set for files/directories"
  echo -e "  \033[1;33m--recursive\033[0m                 (Optional) Recursively process directories"
  echo -e "  \033[1;33m--auto-detect\033[0m               (Optional) Auto-detect sensitive files in common locations"
  echo -e "  \033[1;33m--dry-run\033[0m                   (Optional) Show what would be done without making changes"
  echo -e "  \033[1;33m--verbose\033[0m                   (Optional) Show detailed information"
  echo -e "  \033[1;33m--log <log_file>\033[0m            (Optional) Path to save the log messages"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --auto-detect"
  echo "  $0 --recursive ~/.ssh ~/.kube"
  echo "  $0 --file-perm 400 --owner root --group root /etc/shadow /etc/ssh/ssh_host_*_key"
  echo "  $0 --dry-run --file-perm 600 --dir-perm 700 --recursive ~/.aws"
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
          format-echo "ERROR" "No log file provided after --log"
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --file-perm)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-7]{3,4}$ ]]; then
          format-echo "ERROR" "Invalid file permissions: $2. Must be in octal format (e.g., 600)"
          usage
        fi
        DEFAULT_FILE_PERMS="$2"
        shift 2
        ;;
      --dir-perm)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-7]{3,4}$ ]]; then
          format-echo "ERROR" "Invalid directory permissions: $2. Must be in octal format (e.g., 700)"
          usage
        fi
        DEFAULT_DIR_PERMS="$2"
        shift 2
        ;;
      --owner)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No owner provided after --owner"
          usage
        fi
        FILE_OWNER="$2"
        shift 2
        ;;
      --group)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No group provided after --group"
          usage
        fi
        FILE_GROUP="$2"
        shift 2
        ;;
      --recursive)
        RECURSIVE=true
        shift
        ;;
      --auto-detect)
        AUTO_DETECT=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      -*)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
      *)
        # If argument doesn't start with -, treat it as a file/directory
        if [ -f "$1" ]; then
          FILES+=("$1")
        elif [ -d "$1" ]; then
          DIRECTORIES+=("$1")
        else
          format-echo "WARNING" "File or directory does not exist: $1"
        fi
        shift
        ;;
    esac
  done
  
  # Validate arguments
  validate_args
}

validate_args() {
  # Check if we have files, directories, or auto-detect mode
  if [[ ${#FILES[@]} -eq 0 && ${#DIRECTORIES[@]} -eq 0 && "$AUTO_DETECT" == "false" ]]; then
    format-echo "ERROR" "No files or directories specified and auto-detect not enabled"
    usage
  fi
  
  # Verify owner exists if specified
  if [[ -n "$FILE_OWNER" ]] && ! id "$FILE_OWNER" &>/dev/null; then
    format-echo "ERROR" "Specified owner does not exist: $FILE_OWNER"
    exit 1
  fi
  
  # Verify group exists if specified
  if [[ -n "$FILE_GROUP" ]] && ! getent group "$FILE_GROUP" &>/dev/null; then
    format-echo "ERROR" "Specified group does not exist: $FILE_GROUP"
    exit 1
  fi
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Check if running as root
check_root() {
  if [[ $EUID -ne 0 && ( -n "$FILE_OWNER" || -n "$FILE_GROUP" ) ]]; then
    format-echo "WARNING" "Changing ownership requires root privileges. Some operations may fail."
    format-echo "INFO" "Consider running with sudo: sudo $0 ${ARGS[*]}"
  fi
}

# Set permissions for a file
secure_file() {
  local file="$1"
  local perms="$DEFAULT_FILE_PERMS"
  
  if [[ ! -f "$file" ]]; then
    format-echo "WARNING" "Not a regular file: $file. Skipping."
    return
  fi
  
  # Get current permissions
  local current_perms=$(stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)
  local current_owner=$(stat -f "%Su" "$file" 2>/dev/null || stat -c "%U" "$file" 2>/dev/null)
  local current_group=$(stat -f "%Sg" "$file" 2>/dev/null || stat -c "%G" "$file" 2>/dev/null)
  
  # Check if permissions are already secure
  local needs_perm_change=false
  local needs_owner_change=false
  local needs_group_change=false
  
  if [[ "$current_perms" != "$perms" ]]; then
    needs_perm_change=true
  fi
  
  if [[ -n "$FILE_OWNER" && "$current_owner" != "$FILE_OWNER" ]]; then
    needs_owner_change=true
  fi
  
  if [[ -n "$FILE_GROUP" && "$current_group" != "$FILE_GROUP" ]]; then
    needs_group_change=true
  fi
  
  # Log the details if verbose
  if [[ "$VERBOSE" == "true" ]]; then
    format-echo "INFO" "File: $file"
    format-echo "INFO" "  Current permissions: $current_perms -> Target: $perms"
    format-echo "INFO" "  Current owner: $current_owner -> Target: ${FILE_OWNER:-$current_owner}"
    format-echo "INFO" "  Current group: $current_group -> Target: ${FILE_GROUP:-$current_group}"
  fi
  
  # Skip if no changes needed
  if [[ "$needs_perm_change" == "false" && "$needs_owner_change" == "false" && "$needs_group_change" == "false" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
      format-echo "INFO" "File already has secure permissions: $file"
    fi
    return
  fi
  
  # Change permissions if needed
  if [[ "$needs_perm_change" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      format-echo "DRY-RUN" "Would change permissions of $file from $current_perms to $perms"
    else
      if chmod "$perms" "$file" 2>/dev/null; then
        format-echo "SUCCESS" "Changed permissions of $file to $perms"
      else
        format-echo "ERROR" "Failed to change permissions of $file"
      fi
    fi
  fi
  
  # Change ownership if needed
  if [[ "$needs_owner_change" == "true" || "$needs_group_change" == "true" ]]; then
    local ownership="${FILE_OWNER:-$current_owner}:${FILE_GROUP:-$current_group}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
      format-echo "DRY-RUN" "Would change ownership of $file to $ownership"
    else
      if chown "$ownership" "$file" 2>/dev/null; then
        format-echo "SUCCESS" "Changed ownership of $file to $ownership"
      else
        format-echo "ERROR" "Failed to change ownership of $file"
      fi
    fi
  fi
}

# Set permissions for a directory
secure_directory() {
  local dir="$1"
  local perms="$DEFAULT_DIR_PERMS"
  
  if [[ ! -d "$dir" ]]; then
    format-echo "WARNING" "Not a directory: $dir. Skipping."
    return
  fi
  
  # Get current permissions
  local current_perms=$(stat -f "%Lp" "$dir" 2>/dev/null || stat -c "%a" "$dir" 2>/dev/null)
  local current_owner=$(stat -f "%Su" "$dir" 2>/dev/null || stat -c "%U" "$dir" 2>/dev/null)
  local current_group=$(stat -f "%Sg" "$dir" 2>/dev/null || stat -c "%G" "$dir" 2>/dev/null)
  
  # Check if permissions are already secure
  local needs_perm_change=false
  local needs_owner_change=false
  local needs_group_change=false
  
  if [[ "$current_perms" != "$perms" ]]; then
    needs_perm_change=true
  fi
  
  if [[ -n "$FILE_OWNER" && "$current_owner" != "$FILE_OWNER" ]]; then
    needs_owner_change=true
  fi
  
  if [[ -n "$FILE_GROUP" && "$current_group" != "$FILE_GROUP" ]]; then
    needs_group_change=true
  fi
  
  # Log the details if verbose
  if [[ "$VERBOSE" == "true" ]]; then
    format-echo "INFO" "Directory: $dir"
    format-echo "INFO" "  Current permissions: $current_perms -> Target: $perms"
    format-echo "INFO" "  Current owner: $current_owner -> Target: ${FILE_OWNER:-$current_owner}"
    format-echo "INFO" "  Current group: $current_group -> Target: ${FILE_GROUP:-$current_group}"
  fi
  
  # Skip if no changes needed
  if [[ "$needs_perm_change" == "false" && "$needs_owner_change" == "false" && "$needs_group_change" == "false" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
      format-echo "INFO" "Directory already has secure permissions: $dir"
    fi
    return
  fi
  
  # Change permissions if needed
  if [[ "$needs_perm_change" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      format-echo "DRY-RUN" "Would change permissions of directory $dir from $current_perms to $perms"
    else
      if chmod "$perms" "$dir" 2>/dev/null; then
        format-echo "SUCCESS" "Changed permissions of directory $dir to $perms"
      else
        format-echo "ERROR" "Failed to change permissions of directory $dir"
      fi
    fi
  fi
  
  # Change ownership if needed
  if [[ "$needs_owner_change" == "true" || "$needs_group_change" == "true" ]]; then
    local ownership="${FILE_OWNER:-$current_owner}:${FILE_GROUP:-$current_group}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
      format-echo "DRY-RUN" "Would change ownership of directory $dir to $ownership"
    else
      if chown "$ownership" "$dir" 2>/dev/null; then
        format-echo "SUCCESS" "Changed ownership of directory $dir to $ownership"
      else
        format-echo "ERROR" "Failed to change ownership of directory $dir"
      fi
    fi
  fi
  
  # Process contents if recursive
  if [[ "$RECURSIVE" == "true" ]]; then
    format-echo "INFO" "Processing contents of directory: $dir"
    
    # Process files
    find "$dir" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
      secure_file "$file"
    done
    
    # Process subdirectories
    find "$dir" -type d -print0 2>/dev/null | while IFS= read -r -d '' subdir; do
      if [[ "$subdir" != "$dir" ]]; then
        secure_directory "$subdir"
      fi
    done
  fi
}

# Auto-detect sensitive files
auto_detect_sensitive_files() {
  format-echo "INFO" "Auto-detecting sensitive files..."
  local found_files=0
  
  # Process default sensitive paths
  for path in "${AUTO_DETECT_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
      format-echo "INFO" "Checking $path for sensitive files..."
      
      # Use find to get files matching patterns
      for pattern in "${FIND_PATTERNS[@]}"; do
        # Find command may fail if directories are not accessible, so we redirect errors
        while IFS= read -r -d '' file; do
          FILES+=("$file")
          ((found_files++))
          if [[ "$VERBOSE" == "true" ]]; then
            format-echo "INFO" "Found sensitive file: $file"
          fi
        done < <(find "$path" -type f -name "$pattern" -print0 2>/dev/null)
      done
      
      # Add the directory itself
      DIRECTORIES+=("$path")
    fi
  done
  
  # Special handling for known sensitive file locations
  local known_locations=(
    "$HOME/.kube/config"
    "$HOME/.ssh/id_rsa"
    "$HOME/.ssh/id_dsa"
    "$HOME/.ssh/id_ecdsa"
    "$HOME/.ssh/id_ed25519"
    "$HOME/.aws/credentials"
    "$HOME/.aws/config"
  )
  
  for file in "${known_locations[@]}"; do
    if [[ -f "$file" ]]; then
      FILES+=("$file")
      ((found_files++))
      if [[ "$VERBOSE" == "true" ]]; then
        format-echo "INFO" "Found sensitive file: $file"
      fi
    fi
  done
  
  format-echo "INFO" "Auto-detection found $found_files sensitive files"
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  # Store original arguments for potential sudo message
  ARGS=("$@")
  
  # Parse command-line arguments
  parse_args "$@"
  
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  print_with_separator "Secure File Permissions Script"
  format-echo "INFO" "Starting Secure File Permissions Script..."
  
  # Display operation mode
  if [[ "$DRY_RUN" == "true" ]]; then
    format-echo "INFO" "Running in dry-run mode - no changes will be made"
  fi
  
  # Check if running as root
  check_root
  
  # Auto-detect sensitive files if requested
  if [[ "$AUTO_DETECT" == "true" ]]; then
    auto_detect_sensitive_files
  fi
  
  # Display configuration
  format-echo "INFO" "Configuration:"
  format-echo "INFO" "  File permissions: $DEFAULT_FILE_PERMS"
  format-echo "INFO" "  Directory permissions: $DEFAULT_DIR_PERMS"
  if [[ -n "$FILE_OWNER" ]]; then
    format-echo "INFO" "  Owner: $FILE_OWNER"
  fi
  if [[ -n "$FILE_GROUP" ]]; then
    format-echo "INFO" "  Group: $FILE_GROUP"
  fi
  format-echo "INFO" "  Recursive: $RECURSIVE"
  
  # Process files
  if [[ ${#FILES[@]} -gt 0 ]]; then
    format-echo "INFO" "Processing ${#FILES[@]} files..."
    for file in "${FILES[@]}"; do
      secure_file "$file"
    done
  fi
  
  # Process directories
  if [[ ${#DIRECTORIES[@]} -gt 0 ]]; then
    format-echo "INFO" "Processing ${#DIRECTORIES[@]} directories..."
    for dir in "${DIRECTORIES[@]}"; do
      secure_directory "$dir"
    done
  fi
  
  # Display summary
  local message="Secure file permissions enforced"
  if [[ "$DRY_RUN" == "true" ]]; then
    message="Dry run completed - no changes were made"
  fi
  
  print_with_separator "End of Secure File Permissions Script"
  format-echo "SUCCESS" "$message"
}

main "$@"
