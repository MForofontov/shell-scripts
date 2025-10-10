#!/usr/bin/env bash
# gcp-project-manager.sh
# Script to manage GCP projects - create, delete, list, and configure projects.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
PROJECT_ID=""
PROJECT_NAME=""
ORGANIZATION_ID=""
BILLING_ACCOUNT=""
ACTION=""
FOLDER_ID=""
LABELS=""
ENABLE_APIS=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Project Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP projects - create, delete, list, and configure projects."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate\033[0m      Create a new project"
  echo -e "  \033[1;33mdelete\033[0m      Delete an existing project"
  echo -e "  \033[1;33mlist\033[0m        List all accessible projects"
  echo -e "  \033[1;33minfo\033[0m        Show detailed project information"
  echo -e "  \033[1;33menable-apis\033[0m Enable APIs on a project"
  echo -e "  \033[1;33mset-billing\033[0m Set billing account for a project"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required for most actions) GCP project ID"
  echo -e "  \033[1;33m--name <project-name>\033[0m        (Optional) Human-readable project name"
  echo -e "  \033[1;33m--organization <org-id>\033[0m      (Optional) Organization ID"
  echo -e "  \033[1;33m--folder <folder-id>\033[0m         (Optional) Folder ID"
  echo -e "  \033[1;33m--billing <account-id>\033[0m       (Optional) Billing account ID"
  echo -e "  \033[1;33m--labels <key=value,...>\033[0m     (Optional) Project labels (comma-separated)"
  echo -e "  \033[1;33m--apis <api1,api2,...>\033[0m       (Optional) APIs to enable (comma-separated)"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force deletion without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list"
  echo "  $0 create --project my-new-project --name \"My Project\" --billing 012345-ABCDEF-678901"
  echo "  $0 info --project my-project"
  echo "  $0 enable-apis --project my-project --apis compute.googleapis.com,storage.googleapis.com"
  echo "  $0 delete --project my-old-project --force"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  if [[ "$#" -eq 0 ]]; then
    usage
  fi
  
  ACTION="$1"
  shift
  
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
      --project)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No project ID provided after --project."
          usage
        fi
        PROJECT_ID="$2"
        shift 2
        ;;
      --name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No project name provided after --name."
          usage
        fi
        PROJECT_NAME="$2"
        shift 2
        ;;
      --organization)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No organization ID provided after --organization."
          usage
        fi
        ORGANIZATION_ID="$2"
        shift 2
        ;;
      --folder)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No folder ID provided after --folder."
          usage
        fi
        FOLDER_ID="$2"
        shift 2
        ;;
      --billing)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No billing account provided after --billing."
          usage
        fi
        BILLING_ACCOUNT="$2"
        shift 2
        ;;
      --labels)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No labels provided after --labels."
          usage
        fi
        LABELS="$2"
        shift 2
        ;;
      --apis)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No APIs provided after --apis."
          usage
        fi
        ENABLE_APIS="$2"
        shift 2
        ;;
      --force)
        FORCE=true
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
# Function to check dependencies
check_dependencies() {
  if ! command_exists gcloud; then
    format-echo "ERROR" "gcloud CLI is required but not installed."
    format-echo "INFO" "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  return 0
}

# Function to validate authentication
validate_auth() {
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    format-echo "ERROR" "No active GCP authentication found."
    format-echo "INFO" "Please run: gcloud auth login"
    return 1
  fi
  return 0
}

#=====================================================================
# ACTION FUNCTIONS
#=====================================================================
# Function to list all projects
list_projects() {
  format-echo "INFO" "Listing all accessible projects..."
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list all projects"
    return 0
  fi
  
  if ! gcloud projects list --format="table(projectId,name,projectNumber,lifecycleState)"; then
    format-echo "ERROR" "Failed to list projects"
    return 1
  fi
  
  return 0
}

# Function to show project information
show_project_info() {
  local project="$1"
  
  format-echo "INFO" "Getting information for project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would show info for project: $project"
    return 0
  fi
  
  # Project details
  echo
  format-echo "INFO" "Project Details:"
  if ! gcloud projects describe "$project" --format="yaml"; then
    format-echo "ERROR" "Failed to get project details"
    return 1
  fi
  
  # Billing info
  echo
  format-echo "INFO" "Billing Information:"
  if billing_info=$(gcloud billing projects describe "$project" --format="value(billingAccountName)" 2>/dev/null); then
    if [ -n "$billing_info" ]; then
      echo "Billing Account: $billing_info"
    else
      echo "No billing account linked"
    fi
  else
    echo "Unable to retrieve billing information"
  fi
  
  # Enabled APIs
  if [ "$VERBOSE" = true ]; then
    echo
    format-echo "INFO" "Enabled APIs:"
    if ! gcloud services list --project="$project" --format="table(name,title)" 2>/dev/null; then
      format-echo "WARNING" "Unable to list enabled APIs"
    fi
  fi
  
  return 0
}

# Function to create a new project
create_project() {
  local project="$1"
  local name="$2"
  
  format-echo "INFO" "Creating project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create project:"
    format-echo "INFO" "  Project ID: $project"
    format-echo "INFO" "  Project Name: ${name:-$project}"
    [ -n "$ORGANIZATION_ID" ] && format-echo "INFO" "  Organization: $ORGANIZATION_ID"
    [ -n "$FOLDER_ID" ] && format-echo "INFO" "  Folder: $FOLDER_ID"
    [ -n "$LABELS" ] && format-echo "INFO" "  Labels: $LABELS"
    return 0
  fi
  
  # Build create command
  local create_cmd="gcloud projects create $project"
  
  if [ -n "$name" ]; then
    create_cmd+=" --name=\"$name\""
  fi
  
  if [ -n "$ORGANIZATION_ID" ]; then
    create_cmd+=" --organization=$ORGANIZATION_ID"
  elif [ -n "$FOLDER_ID" ]; then
    create_cmd+=" --folder=$FOLDER_ID"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --labels=$LABELS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd" >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to create project: $project"
    return 1
  fi
  
  format-echo "SUCCESS" "Created project: $project"
  
  # Set billing if provided
  if [ -n "$BILLING_ACCOUNT" ]; then
    set_billing "$project" "$BILLING_ACCOUNT"
  fi
  
  # Enable APIs if provided
  if [ -n "$ENABLE_APIS" ]; then
    enable_apis "$project" "$ENABLE_APIS"
  fi
  
  return 0
}

# Function to delete a project
delete_project() {
  local project="$1"
  
  # Confirmation unless forced
  if [ "$FORCE" = false ]; then
    echo
    format-echo "WARNING" "This will permanently delete project: $project"
    format-echo "WARNING" "This action cannot be undone!"
    echo
    read -p "Are you sure you want to delete this project? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      format-echo "INFO" "Project deletion cancelled"
      return 0
    fi
  fi
  
  format-echo "INFO" "Deleting project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete project: $project"
    return 0
  fi
  
  if ! gcloud projects delete "$project" --quiet >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to delete project: $project"
    return 1
  fi
  
  format-echo "SUCCESS" "Project deletion initiated: $project"
  format-echo "INFO" "Note: It may take a few minutes for the deletion to complete"
  
  return 0
}

# Function to enable APIs
enable_apis() {
  local project="$1"
  local apis="$2"
  
  format-echo "INFO" "Enabling APIs on project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would enable APIs: $apis"
    return 0
  fi
  
  # Convert comma-separated list to space-separated
  local api_list
  api_list=$(echo "$apis" | tr ',' ' ')
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "APIs to enable: $api_list"
  fi
  
  # Intentional word splitting for multiple API names
  # shellcheck disable=SC2086
  if ! gcloud services enable $api_list --project="$project" >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to enable APIs"
    return 1
  fi
  
  format-echo "SUCCESS" "Enabled APIs on project: $project"
  return 0
}

# Function to set billing account
set_billing() {
  local project="$1"
  local billing_account="$2"
  
  format-echo "INFO" "Setting billing account for project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set billing account: $billing_account"
    return 0
  fi
  
  if ! gcloud billing projects link "$project" --billing-account="$billing_account" >/dev/null 2>&1; then
    format-echo "ERROR" "Failed to set billing account"
    return 1
  fi
  
  format-echo "SUCCESS" "Set billing account for project: $project"
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
  
  print_with_separator "GCP Project Manager Script"
  format-echo "INFO" "Starting GCP Project Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Project Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Project Manager Script"
    exit 1
  fi
  
  # Validate action
  case "$ACTION" in
    create|delete|info|enable-apis|set-billing)
      if [ -z "$PROJECT_ID" ]; then
        format-echo "ERROR" "Project ID is required for action: $ACTION"
        print_with_separator "End of GCP Project Manager Script"
        exit 1
      fi
      ;;
    list)
      # No project ID required for list
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create, delete, list, info, enable-apis, set-billing"
      print_with_separator "End of GCP Project Manager Script"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    list)
      if list_projects; then
        format-echo "SUCCESS" "Listed projects successfully"
      else
        format-echo "ERROR" "Failed to list projects"
        exit 1
      fi
      ;;
    info)
      if show_project_info "$PROJECT_ID"; then
        format-echo "SUCCESS" "Retrieved project information successfully"
      else
        format-echo "ERROR" "Failed to get project information"
        exit 1
      fi
      ;;
    create)
      if create_project "$PROJECT_ID" "$PROJECT_NAME"; then
        format-echo "SUCCESS" "Project management completed successfully"
      else
        format-echo "ERROR" "Failed to create project"
        exit 1
      fi
      ;;
    delete)
      if delete_project "$PROJECT_ID"; then
        format-echo "SUCCESS" "Project management completed successfully"
      else
        format-echo "ERROR" "Failed to delete project"
        exit 1
      fi
      ;;
    enable-apis)
      if [ -z "$ENABLE_APIS" ]; then
        format-echo "ERROR" "APIs list is required for enable-apis action. Use --apis"
        exit 1
      fi
      if enable_apis "$PROJECT_ID" "$ENABLE_APIS"; then
        format-echo "SUCCESS" "APIs enabled successfully"
      else
        format-echo "ERROR" "Failed to enable APIs"
        exit 1
      fi
      ;;
    set-billing)
      if [ -z "$BILLING_ACCOUNT" ]; then
        format-echo "ERROR" "Billing account is required for set-billing action. Use --billing"
        exit 1
      fi
      if set_billing "$PROJECT_ID" "$BILLING_ACCOUNT"; then
        format-echo "SUCCESS" "Billing account set successfully"
      else
        format-echo "ERROR" "Failed to set billing account"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Project Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
