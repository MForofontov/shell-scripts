#!/usr/bin/env bash
# gcp-cloudbuild-manager.sh
# Script to manage GCP Cloud Build triggers, builds, and CI/CD pipelines.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"

#=====================================================================
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
PROJECT_ID=""
REGION="global"
TRIGGER_NAME=""
BUILD_ID=""
REPO_NAME=""
REPO_OWNER=""
BRANCH_NAME="main"
TAG_NAME=""
DOCKERFILE_PATH="Dockerfile"
BUILD_CONFIG_PATH="cloudbuild.yaml"
SUBSTITUTIONS=""
MACHINE_TYPE="e2-medium"
DISK_SIZE="100"
TIMEOUT="1200s"
LOG_BUCKET=""
SERVICE_ACCOUNT=""
WORKER_POOL=""
APPROVAL_REQUIRED=false
INCLUDE_BUILD_LOGS=""
IGNORED_FILES=""
INCLUDED_FILES=""
FILTER=""
DESCRIPTION=""
DISABLED=false
GITHUB_OWNER=""
GITHUB_NAME=""
GITHUB_APP_INSTALLATION_ID=""
GITHUB_PUSH_CONFIG=""
GITHUB_PR_CONFIG=""
BITBUCKET_REPO_OWNER=""
BITBUCKET_REPO_NAME=""
CSR_REPO_NAME=""
CSR_BRANCH_NAME=""
CSR_TAG_NAME=""
BUILD_STEPS=""
IMAGES=""
ARTIFACTS=""
OPTIONS=""
ENV_VARS=""
SECRET_ENV=""
VOLUMES=""
NETWORK=""
WEBHOOK_URL=""
SECRET_PATH=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Build Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Cloud Build triggers, builds, and CI/CD pipelines."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mBuild Actions:\033[0m"
  echo -e "  \033[1;33msubmit\033[0m                    Submit a build"
  echo -e "  \033[1;33msubmit-config\033[0m             Submit build with config file"
  echo -e "  \033[1;33mlist-builds\033[0m               List builds"
  echo -e "  \033[1;33mget-build\033[0m                 Get build details"
  echo -e "  \033[1;33mcancel-build\033[0m              Cancel a build"
  echo -e "  \033[1;33mretry-build\033[0m               Retry a failed build"
  echo -e "  \033[1;33mget-build-logs\033[0m            Get build logs"
  echo -e "  \033[1;33mstream-build-logs\033[0m         Stream build logs"
  echo
  echo -e "\033[1;34mTrigger Actions:\033[0m"
  echo -e "  \033[1;33mcreate-trigger\033[0m            Create a build trigger"
  echo -e "  \033[1;33mupdate-trigger\033[0m            Update a build trigger"
  echo -e "  \033[1;33mdelete-trigger\033[0m            Delete a build trigger"
  echo -e "  \033[1;33mlist-triggers\033[0m             List build triggers"
  echo -e "  \033[1;33mget-trigger\033[0m               Get trigger details"
  echo -e "  \033[1;33mrun-trigger\033[0m               Run a trigger manually"
  echo -e "  \033[1;33menable-trigger\033[0m            Enable a trigger"
  echo -e "  \033[1;33mdisable-trigger\033[0m           Disable a trigger"
  echo
  echo -e "\033[1;34mRepository Integration:\033[0m"
  echo -e "  \033[1;33mcreate-github-trigger\033[0m     Create GitHub trigger"
  echo -e "  \033[1;33mcreate-bitbucket-trigger\033[0m  Create Bitbucket trigger"
  echo -e "  \033[1;33mcreate-csr-trigger\033[0m        Create Cloud Source Repositories trigger"
  echo -e "  \033[1;33mconnect-github-repo\033[0m       Connect GitHub repository"
  echo -e "  \033[1;33mconnect-bitbucket-repo\033[0m    Connect Bitbucket repository"
  echo -e "  \033[1;33mlist-connected-repos\033[0m      List connected repositories"
  echo
  echo -e "\033[1;34mWorker Pool Actions:\033[0m"
  echo -e "  \033[1;33mcreate-worker-pool\033[0m        Create private worker pool"
  echo -e "  \033[1;33mupdate-worker-pool\033[0m        Update worker pool"
  echo -e "  \033[1;33mdelete-worker-pool\033[0m        Delete worker pool"
  echo -e "  \033[1;33mlist-worker-pools\033[0m         List worker pools"
  echo -e "  \033[1;33mget-worker-pool\033[0m           Get worker pool details"
  echo
  echo -e "\033[1;34mConfiguration Actions:\033[0m"
  echo -e "  \033[1;33mvalidate-config\033[0m           Validate build configuration"
  echo -e "  \033[1;33mgenerate-config\033[0m           Generate sample build config"
  echo -e "  \033[1;33mget-build-history\033[0m         Get build history"
  echo -e "  \033[1;33mget-build-metrics\033[0m         Get build metrics"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--region <region>\033[0m                (Optional) Region (default: global)"
  echo -e "  \033[1;33m--trigger <name>\033[0m                 (Required for trigger actions) Trigger name"
  echo -e "  \033[1;33m--build-id <id>\033[0m                  (Required for build actions) Build ID"
  echo -e "  \033[1;33m--repo-name <name>\033[0m               (Optional) Repository name"
  echo -e "  \033[1;33m--repo-owner <owner>\033[0m             (Optional) Repository owner"
  echo -e "  \033[1;33m--branch <branch>\033[0m                (Optional) Branch name (default: main)"
  echo -e "  \033[1;33m--tag <tag>\033[0m                      (Optional) Tag name"
  echo -e "  \033[1;33m--dockerfile <path>\033[0m              (Optional) Dockerfile path (default: Dockerfile)"
  echo -e "  \033[1;33m--config <path>\033[0m                  (Optional) Build config file path (default: cloudbuild.yaml)"
  echo -e "  \033[1;33m--substitutions <vars>\033[0m           (Optional) Build substitutions (KEY=VALUE,KEY2=VALUE2)"
  echo -e "  \033[1;33m--machine-type <type>\033[0m            (Optional) Build machine type (default: e2-medium)"
  echo -e "  \033[1;33m--disk-size <size>\033[0m               (Optional) Disk size in GB (default: 100)"
  echo -e "  \033[1;33m--timeout <duration>\033[0m             (Optional) Build timeout (default: 1200s)"
  echo -e "  \033[1;33m--service-account <email>\033[0m        (Optional) Service account for builds"
  echo -e "  \033[1;33m--worker-pool <pool>\033[0m             (Optional) Private worker pool"
  echo -e "  \033[1;33m--log-bucket <bucket>\033[0m            (Optional) Cloud Storage bucket for logs"
  echo -e "  \033[1;33m--github-owner <owner>\033[0m           (Optional) GitHub repository owner"
  echo -e "  \033[1;33m--github-name <name>\033[0m             (Optional) GitHub repository name"
  echo -e "  \033[1;33m--bitbucket-owner <owner>\033[0m        (Optional) Bitbucket repository owner"
  echo -e "  \033[1;33m--bitbucket-name <name>\033[0m          (Optional) Bitbucket repository name"
  echo -e "  \033[1;33m--csr-repo <name>\033[0m                (Optional) Cloud Source Repository name"
  echo -e "  \033[1;33m--description <text>\033[0m             (Optional) Trigger description"
  echo -e "  \033[1;33m--disabled\033[0m                       (Optional) Create trigger in disabled state"
  echo -e "  \033[1;33m--approval-required\033[0m              (Optional) Require manual approval"
  echo -e "  \033[1;33m--filter <expression>\033[0m            (Optional) File filter expression"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 submit --project my-project --tag gcr.io/my-project/app:latest"
  echo "  $0 submit-config --project my-project --config cloudbuild.yaml"
  echo "  $0 create-github-trigger --project my-project --trigger my-trigger --github-owner user --github-name repo"
  echo "  $0 create-trigger --project my-project --trigger my-trigger --repo-name my-repo --branch main"
  echo "  $0 list-builds --project my-project"
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
      --region)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No region provided after --region."
          usage
        fi
        REGION="$2"
        shift 2
        ;;
      --trigger)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No trigger name provided after --trigger."
          usage
        fi
        TRIGGER_NAME="$2"
        shift 2
        ;;
      --build-id)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No build ID provided after --build-id."
          usage
        fi
        BUILD_ID="$2"
        shift 2
        ;;
      --repo-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No repository name provided after --repo-name."
          usage
        fi
        REPO_NAME="$2"
        shift 2
        ;;
      --repo-owner)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No repository owner provided after --repo-owner."
          usage
        fi
        REPO_OWNER="$2"
        shift 2
        ;;
      --branch)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No branch name provided after --branch."
          usage
        fi
        BRANCH_NAME="$2"
        shift 2
        ;;
      --tag)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No tag provided after --tag."
          usage
        fi
        TAG_NAME="$2"
        shift 2
        ;;
      --dockerfile)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No dockerfile path provided after --dockerfile."
          usage
        fi
        DOCKERFILE_PATH="$2"
        shift 2
        ;;
      --config)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No config file provided after --config."
          usage
        fi
        BUILD_CONFIG_PATH="$2"
        shift 2
        ;;
      --substitutions)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No substitutions provided after --substitutions."
          usage
        fi
        SUBSTITUTIONS="$2"
        shift 2
        ;;
      --machine-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No machine type provided after --machine-type."
          usage
        fi
        MACHINE_TYPE="$2"
        shift 2
        ;;
      --disk-size)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No disk size provided after --disk-size."
          usage
        fi
        DISK_SIZE="$2"
        shift 2
        ;;
      --timeout)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No timeout provided after --timeout."
          usage
        fi
        TIMEOUT="$2"
        shift 2
        ;;
      --service-account)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No service account provided after --service-account."
          usage
        fi
        SERVICE_ACCOUNT="$2"
        shift 2
        ;;
      --worker-pool)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No worker pool provided after --worker-pool."
          usage
        fi
        WORKER_POOL="$2"
        shift 2
        ;;
      --log-bucket)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log bucket provided after --log-bucket."
          usage
        fi
        LOG_BUCKET="$2"
        shift 2
        ;;
      --github-owner)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No GitHub owner provided after --github-owner."
          usage
        fi
        GITHUB_OWNER="$2"
        shift 2
        ;;
      --github-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No GitHub name provided after --github-name."
          usage
        fi
        GITHUB_NAME="$2"
        shift 2
        ;;
      --bitbucket-owner)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Bitbucket owner provided after --bitbucket-owner."
          usage
        fi
        BITBUCKET_REPO_OWNER="$2"
        shift 2
        ;;
      --bitbucket-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Bitbucket name provided after --bitbucket-name."
          usage
        fi
        BITBUCKET_REPO_NAME="$2"
        shift 2
        ;;
      --csr-repo)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No CSR repo provided after --csr-repo."
          usage
        fi
        CSR_REPO_NAME="$2"
        shift 2
        ;;
      --description)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No description provided after --description."
          usage
        fi
        DESCRIPTION="$2"
        shift 2
        ;;
      --filter)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No filter provided after --filter."
          usage
        fi
        FILTER="$2"
        shift 2
        ;;
      --disabled)
        DISABLED=true
        shift
        ;;
      --approval-required)
        APPROVAL_REQUIRED=true
        shift
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
  local missing_deps=()
  
  if ! command_exists gcloud; then
    missing_deps+=("gcloud")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    format-echo "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    format-echo "INFO" "Please install Google Cloud SDK"
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

# Function to generate sample cloudbuild.yaml
generate_sample_config() {
  cat << 'EOF'
# Cloud Build configuration file
# https://cloud.google.com/cloud-build/docs/build-config

steps:
  # Build the container image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/${_SERVICE_NAME}:$COMMIT_SHA', '.']
  
  # Push the container image to Container Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/${_SERVICE_NAME}:$COMMIT_SHA']
  
  # Deploy container image to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
    - 'run'
    - 'deploy'
    - '${_SERVICE_NAME}'
    - '--image'
    - 'gcr.io/$PROJECT_ID/${_SERVICE_NAME}:$COMMIT_SHA'
    - '--region'
    - '${_REGION}'
    - '--platform'
    - 'managed'
    - '--allow-unauthenticated'

# Store images in Container Registry
images:
  - 'gcr.io/$PROJECT_ID/${_SERVICE_NAME}:$COMMIT_SHA'

# Build configuration
options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'E2_MEDIUM'
  diskSizeGb: 100

# Substitution variables
substitutions:
  _SERVICE_NAME: 'my-service'
  _REGION: 'us-central1'

# Build timeout
timeout: '1200s'
EOF
}

#=====================================================================
# BUILD MANAGEMENT
#=====================================================================
# Function to submit build
submit_build() {
  local project="$1"
  local tag="${2:-}"
  
  format-echo "INFO" "Submitting build"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would submit build:"
    if [ -n "$tag" ]; then
      format-echo "INFO" "  Tag: $tag"
    fi
    format-echo "INFO" "  Source: current directory"
    return 0
  fi
  
  local submit_cmd="gcloud builds submit"
  submit_cmd+=" --project=$project"
  
  if [ -n "$tag" ]; then
    submit_cmd+=" --tag=$tag"
  fi
  
  if [ -n "$MACHINE_TYPE" ]; then
    submit_cmd+=" --machine-type=$MACHINE_TYPE"
  fi
  
  if [ -n "$DISK_SIZE" ]; then
    submit_cmd+=" --disk-size=$DISK_SIZE"
  fi
  
  if [ -n "$TIMEOUT" ]; then
    submit_cmd+=" --timeout=$TIMEOUT"
  fi
  
  if [ -n "$SUBSTITUTIONS" ]; then
    submit_cmd+=" --substitutions=$SUBSTITUTIONS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $submit_cmd"
  fi
  
  if ! eval "$submit_cmd"; then
    format-echo "ERROR" "Failed to submit build"
    return 1
  fi
  
  format-echo "SUCCESS" "Build submitted successfully"
  return 0
}

# Function to submit build with config file
submit_build_config() {
  local project="$1"
  local config_file="$2"
  
  format-echo "INFO" "Submitting build with config file: $config_file"
  
  if [ ! -f "$config_file" ]; then
    format-echo "ERROR" "Config file not found: $config_file"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would submit build with config: $config_file"
    return 0
  fi
  
  local submit_cmd="gcloud builds submit"
  submit_cmd+=" --project=$project"
  submit_cmd+=" --config=$config_file"
  
  if [ -n "$SUBSTITUTIONS" ]; then
    submit_cmd+=" --substitutions=$SUBSTITUTIONS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $submit_cmd"
  fi
  
  if ! eval "$submit_cmd"; then
    format-echo "ERROR" "Failed to submit build with config"
    return 1
  fi
  
  format-echo "SUCCESS" "Build submitted with config successfully"
  return 0
}

# Function to list builds
list_builds() {
  local project="$1"
  
  format-echo "INFO" "Listing builds"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list builds"
    return 0
  fi
  
  if ! gcloud builds list \
    --project="$project" \
    --limit=20 \
    --format="table(id,status,source.repoSource.repoName,createTime.date())"; then
    format-echo "ERROR" "Failed to list builds"
    return 1
  fi
  
  return 0
}

# Function to get build details
get_build() {
  local project="$1"
  local build_id="$2"
  
  format-echo "INFO" "Getting build details: $build_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get build details for: $build_id"
    return 0
  fi
  
  if ! gcloud builds describe "$build_id" \
    --project="$project"; then
    format-echo "ERROR" "Failed to get build details"
    return 1
  fi
  
  return 0
}

# Function to cancel build
cancel_build() {
  local project="$1"
  local build_id="$2"
  
  format-echo "INFO" "Cancelling build: $build_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would cancel build: $build_id"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will cancel the build '$build_id'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud builds cancel "$build_id" \
    --project="$project"; then
    format-echo "ERROR" "Failed to cancel build"
    return 1
  fi
  
  format-echo "SUCCESS" "Build cancelled successfully"
  return 0
}

# Function to get build logs
get_build_logs() {
  local project="$1"
  local build_id="$2"
  
  format-echo "INFO" "Getting build logs: $build_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get build logs for: $build_id"
    return 0
  fi
  
  if ! gcloud builds log "$build_id" \
    --project="$project"; then
    format-echo "ERROR" "Failed to get build logs"
    return 1
  fi
  
  return 0
}

#=====================================================================
# TRIGGER MANAGEMENT
#=====================================================================
# Function to create build trigger
create_trigger() {
  local project="$1"
  local trigger_name="$2"
  
  format-echo "INFO" "Creating build trigger: $trigger_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create trigger:"
    format-echo "INFO" "  Name: $trigger_name"
    format-echo "INFO" "  Repository: $REPO_NAME"
    format-echo "INFO" "  Branch: $BRANCH_NAME"
    return 0
  fi
  
  local create_cmd="gcloud builds triggers create cloud-source-repositories"
  create_cmd+=" --project=$project"
  create_cmd+=" --trigger-config=-"
  
  # Create trigger configuration
  local trigger_config
  trigger_config=$(cat << EOF
name: $trigger_name
description: $DESCRIPTION
disabled: $DISABLED
substitutions:
  _REPO_NAME: $REPO_NAME
  _BRANCH_NAME: $BRANCH_NAME
trigger:
  branch:
    name: $BRANCH_NAME
sourceToBuild:
  repoName: $REPO_NAME
  ref: refs/heads/$BRANCH_NAME
build:
  steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/\${_REPO_NAME}:\$COMMIT_SHA', '.']
  images:
  - 'gcr.io/$PROJECT_ID/\${_REPO_NAME}:\$COMMIT_SHA'
EOF
)
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Trigger configuration:"
    echo "$trigger_config"
  fi
  
  if ! echo "$trigger_config" | eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create build trigger"
    return 1
  fi
  
  format-echo "SUCCESS" "Created build trigger: $trigger_name"
  return 0
}

# Function to create GitHub trigger
create_github_trigger() {
  local project="$1"
  local trigger_name="$2"
  
  format-echo "INFO" "Creating GitHub build trigger: $trigger_name"
  
  if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_NAME" ]; then
    format-echo "ERROR" "GitHub owner and name are required"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create GitHub trigger:"
    format-echo "INFO" "  Name: $trigger_name"
    format-echo "INFO" "  Repository: $GITHUB_OWNER/$GITHUB_NAME"
    format-echo "INFO" "  Branch: $BRANCH_NAME"
    return 0
  fi
  
  local create_cmd="gcloud builds triggers create github"
  create_cmd+=" --project=$project"
  create_cmd+=" --name=$trigger_name"
  create_cmd+=" --repo-owner=$GITHUB_OWNER"
  create_cmd+=" --repo-name=$GITHUB_NAME"
  create_cmd+=" --branch-pattern=$BRANCH_NAME"
  
  if [ -f "$BUILD_CONFIG_PATH" ]; then
    create_cmd+=" --build-config=$BUILD_CONFIG_PATH"
  else
    create_cmd+=" --dockerfile=$DOCKERFILE_PATH"
  fi
  
  if [ -n "$DESCRIPTION" ]; then
    create_cmd+=" --description='$DESCRIPTION'"
  fi
  
  if [ "$DISABLED" = true ]; then
    create_cmd+=" --disabled"
  fi
  
  if [ -n "$SUBSTITUTIONS" ]; then
    create_cmd+=" --substitutions=$SUBSTITUTIONS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create GitHub trigger"
    return 1
  fi
  
  format-echo "SUCCESS" "Created GitHub trigger: $trigger_name"
  return 0
}

# Function to list triggers
list_triggers() {
  local project="$1"
  
  format-echo "INFO" "Listing build triggers"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list build triggers"
    return 0
  fi
  
  if ! gcloud builds triggers list \
    --project="$project" \
    --format="table(name,status,github.name,trigger.branch.name,createTime.date())"; then
    format-echo "ERROR" "Failed to list build triggers"
    return 1
  fi
  
  return 0
}

# Function to delete trigger
delete_trigger() {
  local project="$1"
  local trigger_name="$2"
  
  format-echo "INFO" "Deleting build trigger: $trigger_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete trigger: $trigger_name"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the trigger '$trigger_name'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud builds triggers delete "$trigger_name" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete build trigger"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted build trigger: $trigger_name"
  return 0
}

# Function to run trigger
run_trigger() {
  local project="$1"
  local trigger_name="$2"
  
  format-echo "INFO" "Running build trigger: $trigger_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would run trigger: $trigger_name"
    return 0
  fi
  
  local run_cmd="gcloud builds triggers run $trigger_name"
  run_cmd+=" --project=$project"
  
  if [ -n "$BRANCH_NAME" ]; then
    run_cmd+=" --branch=$BRANCH_NAME"
  fi
  
  if [ -n "$SUBSTITUTIONS" ]; then
    run_cmd+=" --substitutions=$SUBSTITUTIONS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $run_cmd"
  fi
  
  if ! eval "$run_cmd"; then
    format-echo "ERROR" "Failed to run build trigger"
    return 1
  fi
  
  format-echo "SUCCESS" "Build trigger executed: $trigger_name"
  return 0
}

#=====================================================================
# CONFIGURATION MANAGEMENT
#=====================================================================
# Function to validate build config
validate_config() {
  local config_file="$1"
  
  format-echo "INFO" "Validating build configuration: $config_file"
  
  if [ ! -f "$config_file" ]; then
    format-echo "ERROR" "Config file not found: $config_file"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would validate config: $config_file"
    return 0
  fi
  
  # Check YAML syntax
  if ! python3 -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
    format-echo "ERROR" "Invalid YAML syntax in config file"
    return 1
  fi
  
  format-echo "SUCCESS" "Build configuration is valid"
  return 0
}

# Function to generate sample config
generate_config() {
  local output_file="${1:-cloudbuild.yaml}"
  
  format-echo "INFO" "Generating sample build configuration: $output_file"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would generate config file: $output_file"
    return 0
  fi
  
  if [ -f "$output_file" ] && [ "$FORCE" != true ]; then
    echo "WARNING: File '$output_file' already exists."
    read -p "Overwrite? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  generate_sample_config > "$output_file"
  
  format-echo "SUCCESS" "Generated sample build configuration: $output_file"
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
  
  print_with_separator "GCP Cloud Build Manager Script"
  format-echo "INFO" "Starting GCP Cloud Build Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Cloud Build Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Cloud Build Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Cloud Build Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    submit)
      # Tag is optional for submit
      ;;
    submit-config)
      if [ -z "$BUILD_CONFIG_PATH" ]; then
        format-echo "ERROR" "Config file path is required for submit-config"
        exit 1
      fi
      ;;
    get-build|cancel-build|retry-build|get-build-logs|stream-build-logs)
      if [ -z "$BUILD_ID" ]; then
        format-echo "ERROR" "Build ID is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-trigger|update-trigger|delete-trigger|get-trigger|run-trigger|enable-trigger|disable-trigger)
      if [ -z "$TRIGGER_NAME" ]; then
        format-echo "ERROR" "Trigger name is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-github-trigger)
      if [ -z "$TRIGGER_NAME" ] || [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_NAME" ]; then
        format-echo "ERROR" "Trigger name, GitHub owner, and GitHub name are required"
        exit 1
      fi
      ;;
    validate-config)
      if [ -z "$BUILD_CONFIG_PATH" ]; then
        format-echo "ERROR" "Config file path is required for validation"
        exit 1
      fi
      ;;
    list-builds|list-triggers|generate-config|list-connected-repos)
      # No additional requirements
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: submit, create-trigger, list-builds, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    submit)
      if submit_build "$PROJECT_ID" "$TAG_NAME"; then
        format-echo "SUCCESS" "Build submission completed successfully"
      else
        format-echo "ERROR" "Failed to submit build"
        exit 1
      fi
      ;;
    submit-config)
      if submit_build_config "$PROJECT_ID" "$BUILD_CONFIG_PATH"; then
        format-echo "SUCCESS" "Build submission with config completed successfully"
      else
        format-echo "ERROR" "Failed to submit build with config"
        exit 1
      fi
      ;;
    list-builds)
      if list_builds "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed builds successfully"
      else
        format-echo "ERROR" "Failed to list builds"
        exit 1
      fi
      ;;
    get-build)
      if get_build "$PROJECT_ID" "$BUILD_ID"; then
        format-echo "SUCCESS" "Got build details successfully"
      else
        format-echo "ERROR" "Failed to get build details"
        exit 1
      fi
      ;;
    cancel-build)
      if cancel_build "$PROJECT_ID" "$BUILD_ID"; then
        format-echo "SUCCESS" "Build cancellation completed successfully"
      else
        format-echo "ERROR" "Failed to cancel build"
        exit 1
      fi
      ;;
    get-build-logs)
      if get_build_logs "$PROJECT_ID" "$BUILD_ID"; then
        format-echo "SUCCESS" "Retrieved build logs successfully"
      else
        format-echo "ERROR" "Failed to get build logs"
        exit 1
      fi
      ;;
    create-trigger)
      if create_trigger "$PROJECT_ID" "$TRIGGER_NAME"; then
        format-echo "SUCCESS" "Build trigger creation completed successfully"
      else
        format-echo "ERROR" "Failed to create build trigger"
        exit 1
      fi
      ;;
    create-github-trigger)
      if create_github_trigger "$PROJECT_ID" "$TRIGGER_NAME"; then
        format-echo "SUCCESS" "GitHub trigger creation completed successfully"
      else
        format-echo "ERROR" "Failed to create GitHub trigger"
        exit 1
      fi
      ;;
    list-triggers)
      if list_triggers "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed build triggers successfully"
      else
        format-echo "ERROR" "Failed to list build triggers"
        exit 1
      fi
      ;;
    delete-trigger)
      if delete_trigger "$PROJECT_ID" "$TRIGGER_NAME"; then
        format-echo "SUCCESS" "Build trigger deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete build trigger"
        exit 1
      fi
      ;;
    run-trigger)
      if run_trigger "$PROJECT_ID" "$TRIGGER_NAME"; then
        format-echo "SUCCESS" "Build trigger execution completed successfully"
      else
        format-echo "ERROR" "Failed to run build trigger"
        exit 1
      fi
      ;;
    validate-config)
      if validate_config "$BUILD_CONFIG_PATH"; then
        format-echo "SUCCESS" "Build configuration validation completed successfully"
      else
        format-echo "ERROR" "Failed to validate build configuration"
        exit 1
      fi
      ;;
    generate-config)
      if generate_config "$BUILD_CONFIG_PATH"; then
        format-echo "SUCCESS" "Sample configuration generation completed successfully"
      else
        format-echo "ERROR" "Failed to generate sample configuration"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Cloud Build Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
