#!/usr/bin/env bash
# gcp-iam-manager.sh
# Script to manage GCP IAM permissions - grant, revoke, and audit IAM roles.

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
MEMBER=""
ROLE=""
RESOURCE_TYPE="project"
RESOURCE_NAME=""
ACTION=""
OUTPUT_FORMAT="table"
VERBOSE=false
DRY_RUN=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP IAM Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP IAM permissions - grant, revoke, and audit IAM roles."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mgrant\033[0m          Grant a role to a member"
  echo -e "  \033[1;33mrevoke\033[0m         Revoke a role from a member"
  echo -e "  \033[1;33mlist\033[0m           List all IAM bindings"
  echo -e "  \033[1;33maudit\033[0m          Audit permissions for a member"
  echo -e "  \033[1;33mroles\033[0m          List available roles"
  echo -e "  \033[1;33mmembers\033[0m        List all members with permissions"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--member <member>\033[0m            (Required for grant/revoke/audit) Member (user:, serviceAccount:, etc.)"
  echo -e "  \033[1;33m--role <role>\033[0m                (Required for grant/revoke) IAM role"
  echo -e "  \033[1;33m--resource-type <type>\033[0m       (Optional) Resource type (project, bucket, instance, etc.)"
  echo -e "  \033[1;33m--resource-name <name>\033[0m       (Optional) Resource name (for non-project resources)"
  echo -e "  \033[1;33m--format <format>\033[0m            (Optional) Output format: table, json, yaml (default: table)"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mMember Types:\033[0m"
  echo "  user:email@domain.com          - Individual user"
  echo "  serviceAccount:name@project.iam.gserviceaccount.com - Service account"
  echo "  group:group@domain.com         - Google group"
  echo "  domain:domain.com              - Domain"
  echo "  allUsers                       - All users (public)"
  echo "  allAuthenticatedUsers          - All authenticated users"
  echo
  echo -e "\033[1;34mCommon Roles:\033[0m"
  echo "  roles/viewer, roles/editor, roles/owner"
  echo "  roles/storage.objectViewer, roles/storage.objectAdmin"
  echo "  roles/compute.instanceAdmin, roles/compute.viewer"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list --project my-project"
  echo "  $0 grant --project my-project --member user:john@example.com --role roles/viewer"
  echo "  $0 revoke --project my-project --member user:john@example.com --role roles/viewer"
  echo "  $0 audit --project my-project --member user:john@example.com"
  echo "  $0 roles --project my-project"
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
      --member)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No member provided after --member."
          usage
        fi
        MEMBER="$2"
        shift 2
        ;;
      --role)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No role provided after --role."
          usage
        fi
        ROLE="$2"
        shift 2
        ;;
      --resource-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No resource type provided after --resource-type."
          usage
        fi
        RESOURCE_TYPE="$2"
        shift 2
        ;;
      --resource-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No resource name provided after --resource-name."
          usage
        fi
        RESOURCE_NAME="$2"
        shift 2
        ;;
      --format)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^(table|json|yaml)$ ]]; then
          format-echo "ERROR" "Invalid format: $2. Must be table, json, or yaml."
          usage
        fi
        OUTPUT_FORMAT="$2"
        shift 2
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

# Function to build resource path
build_resource_path() {
  local project="$1"
  local resource_type="$2"
  local resource_name="$3"
  
  case "$resource_type" in
    project)
      echo "projects/$project"
      ;;
    bucket)
      echo "projects/_/buckets/$resource_name"
      ;;
    instance)
      echo "projects/$project/zones/*/instances/$resource_name"
      ;;
    *)
      echo "projects/$project"
      ;;
  esac
}

#=====================================================================
# ACTION FUNCTIONS
#=====================================================================
# Function to list IAM bindings
list_iam_bindings() {
  local project="$1"
  
  format-echo "INFO" "Listing IAM bindings for project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list IAM bindings for project: $project"
    return 0
  fi
  
  local resource_path
  resource_path=$(build_resource_path "$project" "$RESOURCE_TYPE" "$RESOURCE_NAME")
  
  if ! gcloud projects get-iam-policy "$project" --format="$OUTPUT_FORMAT"; then
    format-echo "ERROR" "Failed to list IAM bindings"
    return 1
  fi
  
  return 0
}

# Function to grant role
grant_role() {
  local project="$1"
  local member="$2"
  local role="$3"
  
  format-echo "INFO" "Granting role '$role' to '$member' on project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would grant role '$role' to '$member'"
    return 0
  fi
  
  if ! gcloud projects add-iam-policy-binding "$project" \
    --member="$member" \
    --role="$role" \
    --format="$OUTPUT_FORMAT"; then
    format-echo "ERROR" "Failed to grant role"
    return 1
  fi
  
  format-echo "SUCCESS" "Granted role '$role' to '$member'"
  return 0
}

# Function to revoke role
revoke_role() {
  local project="$1"
  local member="$2"
  local role="$3"
  
  format-echo "INFO" "Revoking role '$role' from '$member' on project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would revoke role '$role' from '$member'"
    return 0
  fi
  
  if ! gcloud projects remove-iam-policy-binding "$project" \
    --member="$member" \
    --role="$role" \
    --format="$OUTPUT_FORMAT"; then
    format-echo "ERROR" "Failed to revoke role"
    return 1
  fi
  
  format-echo "SUCCESS" "Revoked role '$role' from '$member'"
  return 0
}

# Function to audit member permissions
audit_member() {
  local project="$1"
  local member="$2"
  
  format-echo "INFO" "Auditing permissions for member: $member"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would audit permissions for member: $member"
    return 0
  fi
  
  local policy
  if ! policy=$(gcloud projects get-iam-policy "$project" --format="json"); then
    format-echo "ERROR" "Failed to get IAM policy"
    return 1
  fi
  
  echo "$policy" | jq -r --arg member "$member" '
    .bindings[] | 
    select(.members[]? == $member) | 
    .role as $role | 
    .members[] | 
    select(. == $member) | 
    "Role: \($role), Member: \(.)"
  ' || {
    format-echo "INFO" "No permissions found for member: $member"
  }
  
  return 0
}

# Function to list available roles
list_roles() {
  local project="$1"
  
  format-echo "INFO" "Listing available roles for project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list available roles"
    return 0
  fi
  
  if [ "$VERBOSE" = true ]; then
    # List all roles including custom ones
    if ! gcloud iam roles list --project="$project" --format="table(name,title,description)"; then
      format-echo "ERROR" "Failed to list custom roles"
      return 1
    fi
    
    echo
    format-echo "INFO" "Predefined roles:"
  fi
  
  # List predefined roles
  if ! gcloud iam roles list --format="table(name,title)" | head -20; then
    format-echo "ERROR" "Failed to list predefined roles"
    return 1
  fi
  
  format-echo "INFO" "Use 'gcloud iam roles list' to see all available roles"
  return 0
}

# Function to list all members
list_members() {
  local project="$1"
  
  format-echo "INFO" "Listing all members with permissions on project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list all members"
    return 0
  fi
  
  local policy
  if ! policy=$(gcloud projects get-iam-policy "$project" --format="json"); then
    format-echo "ERROR" "Failed to get IAM policy"
    return 1
  fi
  
  echo "$policy" | jq -r '
    .bindings[] | 
    .role as $role | 
    .members[]? | 
    "\(.), Role: \($role)"
  ' | sort -u || {
    format-echo "INFO" "No members found"
  }
  
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
  
  print_with_separator "GCP IAM Manager Script"
  format-echo "INFO" "Starting GCP IAM Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP IAM Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP IAM Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP IAM Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    grant|revoke)
      if [ -z "$MEMBER" ]; then
        format-echo "ERROR" "Member is required for action: $ACTION"
        print_with_separator "End of GCP IAM Manager Script"
        exit 1
      fi
      if [ -z "$ROLE" ]; then
        format-echo "ERROR" "Role is required for action: $ACTION"
        print_with_separator "End of GCP IAM Manager Script"
        exit 1
      fi
      ;;
    audit)
      if [ -z "$MEMBER" ]; then
        format-echo "ERROR" "Member is required for action: $ACTION"
        print_with_separator "End of GCP IAM Manager Script"
        exit 1
      fi
      ;;
    list|roles|members)
      # No additional requirements for these actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: grant, revoke, list, audit, roles, members"
      print_with_separator "End of GCP IAM Manager Script"
      exit 1
      ;;
  esac
  
  # Check if jq is available for audit and members actions
  if [[ "$ACTION" == "audit" || "$ACTION" == "members" ]] && ! command_exists jq; then
    format-echo "ERROR" "jq is required for $ACTION action but not installed."
    format-echo "INFO" "Please install jq: brew install jq (macOS) or apt-get install jq (Ubuntu)"
    print_with_separator "End of GCP IAM Manager Script"
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    list)
      if list_iam_bindings "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed IAM bindings successfully"
      else
        format-echo "ERROR" "Failed to list IAM bindings"
        exit 1
      fi
      ;;
    grant)
      if grant_role "$PROJECT_ID" "$MEMBER" "$ROLE"; then
        format-echo "SUCCESS" "IAM management completed successfully"
      else
        format-echo "ERROR" "Failed to grant role"
        exit 1
      fi
      ;;
    revoke)
      if revoke_role "$PROJECT_ID" "$MEMBER" "$ROLE"; then
        format-echo "SUCCESS" "IAM management completed successfully"
      else
        format-echo "ERROR" "Failed to revoke role"
        exit 1
      fi
      ;;
    audit)
      if audit_member "$PROJECT_ID" "$MEMBER"; then
        format-echo "SUCCESS" "Audit completed successfully"
      else
        format-echo "ERROR" "Failed to audit member"
        exit 1
      fi
      ;;
    roles)
      if list_roles "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed roles successfully"
      else
        format-echo "ERROR" "Failed to list roles"
        exit 1
      fi
      ;;
    members)
      if list_members "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed members successfully"
      else
        format-echo "ERROR" "Failed to list members"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP IAM Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
