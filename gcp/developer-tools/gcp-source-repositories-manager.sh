#!/usr/bin/env bash
# gcp-source-repositories-manager.sh
# Script to manage Google Cloud Source Repositories

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"

#=====================================================================
# DEFAULT VALUES
#=====================================================================
PROJECT_ID=""
COMMAND=""
REPO_NAME=""
CLONE_URL=""
MIRROR_URL=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Source Repositories Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Source Repositories (Git repositories) resources."
  echo "  Provides comprehensive management capabilities for Git repositories in GCP."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-r, --repo REPO_NAME\033[0m        Set repository name"
  echo -e "  \033[1;33m-u, --clone-url URL\033[0m         Set clone URL"
  echo -e "  \033[1;33m-m, --mirror-url URL\033[0m        Set mirror URL"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate\033[0m                      Create new repository"
  echo -e "  \033[1;36mlist\033[0m                        List repositories"
  echo -e "  \033[1;36mget\033[0m                         Get repository details"
  echo -e "  \033[1;36mdelete\033[0m                      Delete repository"
  echo -e "  \033[1;36mclone\033[0m                       Clone repository locally"
  echo -e "  \033[1;36mget-clone-url\033[0m               Get repository clone URL"
  echo -e "  \033[1;36mset-mirror\033[0m                  Set up repository mirroring"
  echo -e "  \033[1;36mlist-mirrors\033[0m                List repository mirrors"
  echo -e "  \033[1;36mdelete-mirror\033[0m               Delete repository mirror"
  echo -e "  \033[1;36mget-iam-policy\033[0m              Get repository IAM policy"
  echo -e "  \033[1;36mset-iam-policy\033[0m              Set repository IAM policy"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project -r my-repo create"
  echo "  $0 --project my-project list"
  echo "  $0 -p my-project -r my-repo clone"
  echo "  $0 -p my-project -r my-repo -m https://github.com/user/repo.git set-mirror"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -p|--project)
        if [[ -n "${2:-}" ]]; then
          PROJECT_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --project"
          usage
        fi
        ;;
      -r|--repo)
        if [[ -n "${2:-}" ]]; then
          REPO_NAME="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --repo"
          usage
        fi
        ;;
      -u|--clone-url)
        if [[ -n "${2:-}" ]]; then
          CLONE_URL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --clone-url"
          usage
        fi
        ;;
      -m|--mirror-url)
        if [[ -n "${2:-}" ]]; then
          MIRROR_URL="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --mirror-url"
          usage
        fi
        ;;
      -h|--help)
        usage
        ;;
      *)
        if [[ -z "$COMMAND" ]]; then
          COMMAND="$1"
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
# AUTHENTICATION AND PROJECT SETUP
#=====================================================================
check_auth() {
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    format-echo "ERROR" "Not authenticated with gcloud. Please run 'gcloud auth login'"
    exit 1
  fi
}

set_project() {
  if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [[ -z "$PROJECT_ID" ]]; then
      format-echo "ERROR" "No project set. Use -p flag or run 'gcloud config set project PROJECT_ID'"
      exit 1
    fi
  fi
  
  format-echo "INFO" "Using project: $PROJECT_ID"
  gcloud config set project "$PROJECT_ID" >/dev/null 2>&1
}

enable_apis() {
  format-echo "INFO" "Enabling required APIs..."
  
  local apis=(
    "sourcerepo.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# SOURCE REPOSITORIES OPERATIONS
#=====================================================================
create_repo() {
  format-echo "INFO" "Creating Source Repository..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required for create operation"
    exit 1
  fi
  
  gcloud source repos create "$REPO_NAME" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Source Repository '$REPO_NAME' created successfully"
  
  # Display clone URL
  local clone_url="https://source.developers.google.com/p/${PROJECT_ID}/r/${REPO_NAME}"
  format-echo "INFO" "Clone URL: $clone_url"
}

list_repos() {
  format-echo "INFO" "Listing Source Repositories..."
  
  print_with_separator "Source Repositories"
  gcloud source repos list --project="$PROJECT_ID"
  print_with_separator "End of Source Repositories"
}

get_repo() {
  format-echo "INFO" "Getting Source Repository details..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required"
    exit 1
  fi
  
  print_with_separator "Source Repository: $REPO_NAME"
  gcloud source repos describe "$REPO_NAME" --project="$PROJECT_ID"
  print_with_separator "End of Source Repository Details"
}

delete_repo() {
  format-echo "INFO" "Deleting Source Repository..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the repository and all its data"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud source repos delete "$REPO_NAME" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Source Repository '$REPO_NAME' deleted successfully"
}

clone_repo() {
  format-echo "INFO" "Cloning Source Repository..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required"
    exit 1
  fi
  
  local clone_url="https://source.developers.google.com/p/${PROJECT_ID}/r/${REPO_NAME}"
  
  format-echo "INFO" "Cloning repository from: $clone_url"
  
  if command -v git &> /dev/null; then
    git clone "$clone_url"
    format-echo "SUCCESS" "Repository cloned successfully"
  else
    format-echo "ERROR" "Git is not installed. Please install Git to clone repositories"
    format-echo "INFO" "Clone URL: $clone_url"
  fi
}

get_clone_url() {
  format-echo "INFO" "Getting repository clone URL..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required"
    exit 1
  fi
  
  local clone_url="https://source.developers.google.com/p/${PROJECT_ID}/r/${REPO_NAME}"
  
  print_with_separator "Clone Information"
  format-echo "INFO" "Repository: $REPO_NAME"
  format-echo "INFO" "HTTPS Clone URL: $clone_url"
  format-echo "INFO" "SSH Clone URL: ssh://source.developers.google.com:2022/p/${PROJECT_ID}/r/${REPO_NAME}"
  echo
  echo "To clone this repository:"
  echo "  git clone $clone_url"
  echo
  echo "To add as remote:"
  echo "  git remote add google $clone_url"
  print_with_separator "End of Clone Information"
}

set_mirror() {
  format-echo "INFO" "Setting up repository mirroring..."
  
  if [[ -z "$REPO_NAME" ]] || [[ -z "$MIRROR_URL" ]]; then
    format-echo "ERROR" "Repository name and mirror URL are required"
    exit 1
  fi
  
  format-echo "INFO" "Setting up mirror from $MIRROR_URL to $REPO_NAME"
  
  # Note: Cloud Source Repositories mirroring is typically set up through the console
  # This provides instructions for manual setup
  print_with_separator "Mirror Setup Instructions"
  echo "1. Go to https://console.cloud.google.com/source/repos"
  echo "2. Select your repository: $REPO_NAME"
  echo "3. Click 'Settings' tab"
  echo "4. Click 'Add mirror'"
  echo "5. Enter mirror URL: $MIRROR_URL"
  echo "6. Configure authentication if needed"
  echo "7. Click 'Create'"
  print_with_separator "End of Mirror Setup Instructions"
}

list_mirrors() {
  format-echo "INFO" "Listing repository mirrors..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required"
    exit 1
  fi
  
  print_with_separator "Repository Mirrors"
  format-echo "INFO" "Repository: $REPO_NAME"
  format-echo "INFO" "Use the Cloud Console to view and manage mirrors:"
  echo "  https://console.cloud.google.com/source/repos/repo/$REPO_NAME/settings"
  print_with_separator "End of Repository Mirrors"
}

delete_mirror() {
  format-echo "INFO" "Deleting repository mirror..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required"
    exit 1
  fi
  
  print_with_separator "Mirror Deletion Instructions"
  echo "1. Go to https://console.cloud.google.com/source/repos"
  echo "2. Select your repository: $REPO_NAME"
  echo "3. Click 'Settings' tab"
  echo "4. Find the mirror you want to delete"
  echo "5. Click 'Delete' next to the mirror"
  print_with_separator "End of Mirror Deletion Instructions"
}

get_iam_policy() {
  format-echo "INFO" "Getting repository IAM policy..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required"
    exit 1
  fi
  
  print_with_separator "IAM Policy for $REPO_NAME"
  gcloud source repos get-iam-policy "$REPO_NAME" --project="$PROJECT_ID"
  print_with_separator "End of IAM Policy"
}

set_iam_policy() {
  format-echo "INFO" "Setting repository IAM policy..."
  
  if [[ -z "$REPO_NAME" ]]; then
    format-echo "ERROR" "Repository name is required"
    exit 1
  fi
  
  format-echo "INFO" "This requires a policy file in JSON or YAML format"
  read -p "Enter path to policy file: " policy_file
  
  if [[ -z "$policy_file" ]] || [[ ! -f "$policy_file" ]]; then
    format-echo "ERROR" "Policy file not found"
    exit 1
  fi
  
  gcloud source repos set-iam-policy "$REPO_NAME" "$policy_file" --project="$PROJECT_ID"
  format-echo "SUCCESS" "IAM policy updated successfully"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    create)
      enable_apis
      create_repo
      ;;
    list)
      list_repos
      ;;
    get)
      get_repo
      ;;
    delete)
      delete_repo
      ;;
    clone)
      clone_repo
      ;;
    get-clone-url)
      get_clone_url
      ;;
    set-mirror)
      set_mirror
      ;;
    list-mirrors)
      list_mirrors
      ;;
    delete-mirror)
      delete_mirror
      ;;
    get-iam-policy)
      get_iam_policy
      ;;
    set-iam-policy)
      set_iam_policy
      ;;
    *)
      format-echo "ERROR" "Unknown command: $COMMAND"
      format-echo "INFO" "Use --help to see available commands"
      exit 1
      ;;
  esac
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  #---------------------------------------------------------------------
  # INITIALIZATION
  #---------------------------------------------------------------------
  parse_args "$@"
  
  print_with_separator "GCP Cloud Source Repositories Manager"
  format-echo "INFO" "Starting Source Repositories management operations..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  if [[ -z "$COMMAND" ]]; then
    format-echo "ERROR" "Command is required."
    usage
  fi
  
  #---------------------------------------------------------------------
  # AUTHENTICATION AND SETUP
  #---------------------------------------------------------------------
  check_auth
  set_project
  
  #---------------------------------------------------------------------
  # COMMAND EXECUTION
  #---------------------------------------------------------------------
  execute_command
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  format-echo "SUCCESS" "Source Repositories management operation completed successfully."
  print_with_separator "End of GCP Cloud Source Repositories Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
