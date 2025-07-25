#!/bin/bash
# check-updates.sh
# Script to check for and install system updates.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
LOG_FILE="/dev/null"
AUTO_INSTALL=true
DRY_RUN=false
EXIT_CODE=0

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Check Updates Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script checks for and installs system updates."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [--check-only] [--dry-run] [--log <log_file>] [--help]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--check-only\033[0m           (Optional) Only check for updates, don't install them."
  echo -e "  \033[1;33m--dry-run\033[0m              (Optional) Show commands without executing them."
  echo -e "  \033[1;33m--log <log_file>\033[0m       (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--help\033[0m                 (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log updates.log"
  echo "  $0 --check-only"
  echo "  $0 --dry-run"
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
      --check-only)
        AUTO_INSTALL=false
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Function to execute or simulate a command
run_command() {
  local cmd="$*"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "DRY-RUN" "Would execute: $cmd"
    return 0
  else
    format-echo "INFO" "Executing: $cmd"
    if eval "$cmd"; then
      return 0
    else
      EXIT_CODE=1
      return 1
    fi
  fi
}

# Function to detect package manager
detect_package_manager() {
  if [ "$(uname)" = "Darwin" ]; then
    echo "brew"
  elif [ -x "$(command -v apt-get)" ]; then
    echo "apt"
  elif [ -x "$(command -v dnf)" ]; then
    echo "dnf"
  elif [ -x "$(command -v yum)" ]; then
    echo "yum"
  elif [ -x "$(command -v pacman)" ]; then
    echo "pacman"
  elif [ -x "$(command -v zypper)" ]; then
    echo "zypper"
  else
    echo "unknown"
  fi
}

# Function to check for updates
check_updates() {
  local pkg_manager="$1"
  format-echo "INFO" "Checking for updates using $pkg_manager..."
  
  case "$pkg_manager" in
    brew)
      run_command "brew update"
      run_command "brew outdated"
      ;;
    apt)
      run_command "sudo apt-get update"
      run_command "apt list --upgradable"
      ;;
    dnf)
      run_command "sudo dnf check-update" || true  # dnf returns exit code 100 when updates are available
      ;;
    yum)
      run_command "sudo yum check-update" || true  # yum also returns non-zero when updates are available
      ;;
    pacman)
      run_command "sudo pacman -Syup"
      ;;
    zypper)
      run_command "sudo zypper list-updates"
      ;;
    *)
      format-echo "ERROR" "Unsupported package manager."
      return 1
      ;;
  esac
  
  return 0
}

# Function to install updates
install_updates() {
  local pkg_manager="$1"
  format-echo "INFO" "Installing updates using $pkg_manager..."
  
  case "$pkg_manager" in
    brew)
      run_command "brew upgrade"
      ;;
    apt)
      run_command "sudo apt-get upgrade -y"
      ;;
    dnf)
      run_command "sudo dnf upgrade -y"
      ;;
    yum)
      run_command "sudo yum update -y"
      ;;
    pacman)
      run_command "sudo pacman -Syu --noconfirm"
      ;;
    zypper)
      run_command "sudo zypper update -y"
      ;;
    *)
      format-echo "ERROR" "Unsupported package manager."
      return 1
      ;;
  esac
  
  return 0
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

  print_with_separator "Check Updates Script"
  format-echo "INFO" "Starting Check Updates Script..."
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "WARNING" "Running in DRY-RUN mode. No changes will be applied."
  fi

  #---------------------------------------------------------------------
  # PACKAGE MANAGER DETECTION
  #---------------------------------------------------------------------
  # Detect package manager
  PKG_MANAGER=$(detect_package_manager)
  
  if [ "$PKG_MANAGER" = "unknown" ]; then
    format-echo "ERROR" "No supported package manager found."
    print_with_separator "End of Check Updates Script"
    exit 1
  fi
  
  format-echo "INFO" "Detected package manager: $PKG_MANAGER"

  #---------------------------------------------------------------------
  # UPDATE CHECK AND INSTALLATION
  #---------------------------------------------------------------------
  # Check for updates
  if ! check_updates "$PKG_MANAGER"; then
    format-echo "ERROR" "Failed to check for updates."
    EXIT_CODE=1
  fi
  
  # Install updates if requested
  if [ "$AUTO_INSTALL" = true ] && [ "$EXIT_CODE" -eq 0 ]; then
    if ! install_updates "$PKG_MANAGER"; then
      format-echo "ERROR" "Failed to install updates."
      EXIT_CODE=1
    else
      format-echo "SUCCESS" "System updates completed successfully."
    fi
  elif [ "$AUTO_INSTALL" = false ]; then
    format-echo "INFO" "Skipping update installation (--check-only was specified)."
  fi

  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of Check Updates Script"
  
  if [ "$EXIT_CODE" -eq 0 ]; then
    format-echo "SUCCESS" "Update check completed successfully."
  else
    format-echo "WARNING" "Update process completed with issues."
  fi
  
  return $EXIT_CODE
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
