#!/usr/bin/env bash
# gcp-artifact-registry-manager.sh
# Script to manage GCP Artifact Registry repositories, containers, and packages.

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
LOCATION="us-central1"
REPOSITORY=""
FORMAT="docker"
PACKAGE=""
VERSION=""
TAG=""
DESCRIPTION=""
LABELS=""
KMS_KEY=""
CLEANUP_POLICY=""
CLEANUP_DAYS="30"
REMOTE_REPO_CONFIG=""
UPSTREAM_POLICIES=""
MODE="standard"
DOCKER_IMAGE=""
DOCKER_TAG="latest"
MAVEN_GROUP_ID=""
MAVEN_ARTIFACT_ID=""
MAVEN_VERSION=""
NPM_PACKAGE=""
NPM_VERSION=""
PYTHON_PACKAGE=""
PYTHON_VERSION=""
VULNERABILITY_SCANNING=true
IMMUTABLE_TAGS=false
POLICY_FILE=""
SERVICE_ACCOUNT=""
MEMBER=""
ROLE=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Artifact Registry Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Artifact Registry repositories, packages, and access control."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mRepository Actions:\033[0m"
  echo -e "  \033[1;33mcreate-repo\033[0m               Create a repository"
  echo -e "  \033[1;33mdelete-repo\033[0m               Delete a repository"
  echo -e "  \033[1;33mlist-repos\033[0m                List repositories"
  echo -e "  \033[1;33mdescribe-repo\033[0m             Describe a repository"
  echo -e "  \033[1;33mupdate-repo\033[0m               Update repository configuration"
  echo
  echo -e "\033[1;34mPackage Actions:\033[0m"
  echo -e "  \033[1;33mlist-packages\033[0m             List packages in repository"
  echo -e "  \033[1;33mdescribe-package\033[0m          Describe a package"
  echo -e "  \033[1;33mdelete-package\033[0m            Delete a package"
  echo -e "  \033[1;33mlist-versions\033[0m             List package versions"
  echo -e "  \033[1;33mdescribe-version\033[0m          Describe a package version"
  echo -e "  \033[1;33mdelete-version\033[0m            Delete a package version"
  echo
  echo -e "\033[1;34mDocker Actions:\033[0m"
  echo -e "  \033[1;33mpush-docker\033[0m               Push Docker image"
  echo -e "  \033[1;33mpull-docker\033[0m               Pull Docker image"
  echo -e "  \033[1;33mlist-docker-images\033[0m        List Docker images"
  echo -e "  \033[1;33mlist-docker-tags\033[0m          List Docker image tags"
  echo -e "  \033[1;33mdelete-docker-image\033[0m       Delete Docker image"
  echo -e "  \033[1;33mtag-docker-image\033[0m          Tag Docker image"
  echo -e "  \033[1;33mget-docker-manifest\033[0m       Get Docker manifest"
  echo
  echo -e "\033[1;34mVulnerability Scanning:\033[0m"
  echo -e "  \033[1;33mscan-vulnerabilities\033[0m      Scan for vulnerabilities"
  echo -e "  \033[1;33mlist-vulnerabilities\033[0m      List vulnerabilities"
  echo -e "  \033[1;33mget-scan-config\033[0m           Get vulnerability scan config"
  echo -e "  \033[1;33mupdate-scan-config\033[0m        Update vulnerability scan config"
  echo
  echo -e "\033[1;34mAccess Control:\033[0m"
  echo -e "  \033[1;33mget-iam-policy\033[0m            Get IAM policy"
  echo -e "  \033[1;33mset-iam-policy\033[0m            Set IAM policy"
  echo -e "  \033[1;33madd-iam-binding\033[0m           Add IAM policy binding"
  echo -e "  \033[1;33mremove-iam-binding\033[0m        Remove IAM policy binding"
  echo -e "  \033[1;33mtest-iam-permissions\033[0m      Test IAM permissions"
  echo
  echo -e "\033[1;34mCleanup Actions:\033[0m"
  echo -e "  \033[1;33mset-cleanup-policy\033[0m        Set repository cleanup policy"
  echo -e "  \033[1;33mget-cleanup-policy\033[0m        Get repository cleanup policy"
  echo -e "  \033[1;33mcleanup-versions\033[0m          Clean up old package versions"
  echo -e "  \033[1;33mlist-untagged\033[0m             List untagged images"
  echo -e "  \033[1;33mdelete-untagged\033[0m           Delete untagged images"
  echo
  echo -e "\033[1;34mConfiguration Actions:\033[0m"
  echo -e "  \033[1;33mconfigure-docker\033[0m          Configure Docker authentication"
  echo -e "  \033[1;33mprint-docker-login\033[0m        Print Docker login command"
  echo -e "  \033[1;33msetup-remote-repo\033[0m         Setup remote repository"
  echo -e "  \033[1;33mvalidate-config\033[0m           Validate repository configuration"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--location <location>\033[0m            (Optional) Repository location (default: us-central1)"
  echo -e "  \033[1;33m--repository <name>\033[0m              (Required for most actions) Repository name"
  echo -e "  \033[1;33m--format <format>\033[0m                (Optional) Repository format: docker, maven, npm, python, apt, yum"
  echo -e "  \033[1;33m--package <name>\033[0m                 (Optional) Package name"
  echo -e "  \033[1;33m--version <version>\033[0m              (Optional) Package version"
  echo -e "  \033[1;33m--tag <tag>\033[0m                      (Optional) Docker image tag"
  echo -e "  \033[1;33m--docker-image <image>\033[0m           (Optional) Docker image name"
  echo -e "  \033[1;33m--description <text>\033[0m             (Optional) Repository description"
  echo -e "  \033[1;33m--labels <labels>\033[0m                (Optional) Labels (KEY=VALUE,KEY2=VALUE2)"
  echo -e "  \033[1;33m--kms-key <key>\033[0m                  (Optional) KMS encryption key"
  echo -e "  \033[1;33m--cleanup-days <days>\033[0m            (Optional) Days to keep versions (default: 30)"
  echo -e "  \033[1;33m--mode <mode>\033[0m                    (Optional) Repository mode: standard, remote"
  echo -e "  \033[1;33m--member <member>\033[0m                (Optional) IAM member (user:email, serviceAccount:email)"
  echo -e "  \033[1;33m--role <role>\033[0m                    (Optional) IAM role"
  echo -e "  \033[1;33m--policy-file <file>\033[0m             (Optional) IAM policy file"
  echo -e "  \033[1;33m--immutable-tags\033[0m                 (Optional) Enable immutable tags"
  echo -e "  \033[1;33m--no-vulnerability-scanning\033[0m      (Optional) Disable vulnerability scanning"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 create-repo --project my-project --repository docker-repo --format docker"
  echo "  $0 push-docker --project my-project --repository docker-repo --docker-image my-app --tag latest"
  echo "  $0 list-packages --project my-project --repository docker-repo"
  echo "  $0 scan-vulnerabilities --project my-project --repository docker-repo --package my-app"
  echo "  $0 add-iam-binding --project my-project --repository docker-repo --member user:john@example.com --role roles/artifactregistry.reader"
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
      --location)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No location provided after --location."
          usage
        fi
        LOCATION="$2"
        shift 2
        ;;
      --repository)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No repository name provided after --repository."
          usage
        fi
        REPOSITORY="$2"
        shift 2
        ;;
      --format)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No format provided after --format."
          usage
        fi
        FORMAT="$2"
        shift 2
        ;;
      --package)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No package name provided after --package."
          usage
        fi
        PACKAGE="$2"
        shift 2
        ;;
      --version)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No version provided after --version."
          usage
        fi
        VERSION="$2"
        shift 2
        ;;
      --tag)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No tag provided after --tag."
          usage
        fi
        TAG="$2"
        shift 2
        ;;
      --docker-image)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Docker image provided after --docker-image."
          usage
        fi
        DOCKER_IMAGE="$2"
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
      --labels)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No labels provided after --labels."
          usage
        fi
        LABELS="$2"
        shift 2
        ;;
      --kms-key)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No KMS key provided after --kms-key."
          usage
        fi
        KMS_KEY="$2"
        shift 2
        ;;
      --cleanup-days)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No cleanup days provided after --cleanup-days."
          usage
        fi
        CLEANUP_DAYS="$2"
        shift 2
        ;;
      --mode)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No mode provided after --mode."
          usage
        fi
        MODE="$2"
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
      --policy-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No policy file provided after --policy-file."
          usage
        fi
        POLICY_FILE="$2"
        shift 2
        ;;
      --immutable-tags)
        IMMUTABLE_TAGS=true
        shift
        ;;
      --no-vulnerability-scanning)
        VULNERABILITY_SCANNING=false
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
  
  if ! command_exists docker; then
    missing_deps+=("docker")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    format-echo "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    format-echo "INFO" "Please install Google Cloud SDK and Docker"
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

# Function to get repository full name
get_repo_full_name() {
  echo "projects/$PROJECT_ID/locations/$LOCATION/repositories/$REPOSITORY"
}

# Function to get package full name
get_package_full_name() {
  echo "projects/$PROJECT_ID/locations/$LOCATION/repositories/$REPOSITORY/packages/$PACKAGE"
}

# Function to get docker image URL
get_docker_image_url() {
  local image_name="$1"
  local tag="${2:-latest}"
  echo "$LOCATION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$image_name:$tag"
}

#=====================================================================
# REPOSITORY MANAGEMENT
#=====================================================================
# Function to create repository
create_repository() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local format="$4"
  
  format-echo "INFO" "Creating Artifact Registry repository: $repository"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create repository:"
    format-echo "INFO" "  Name: $repository"
    format-echo "INFO" "  Location: $location"
    format-echo "INFO" "  Format: $format"
    return 0
  fi
  
  local create_cmd="gcloud artifacts repositories create $repository"
  create_cmd+=" --project=$project"
  create_cmd+=" --location=$location"
  create_cmd+=" --repository-format=$format"
  
  if [ -n "$DESCRIPTION" ]; then
    create_cmd+=" --description='$DESCRIPTION'"
  fi
  
  if [ -n "$KMS_KEY" ]; then
    create_cmd+=" --kms-key=$KMS_KEY"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --labels=$LABELS"
  fi
  
  if [ "$MODE" = "remote" ]; then
    create_cmd+=" --mode=remote-repository"
  fi
  
  if [ "$IMMUTABLE_TAGS" = true ]; then
    create_cmd+=" --immutable-tags"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create repository: $repository"
    return 1
  fi
  
  format-echo "SUCCESS" "Created repository: $repository"
  
  # Configure Docker authentication if it's a Docker repository
  if [ "$format" = "docker" ]; then
    configure_docker_auth "$project" "$location"
  fi
  
  return 0
}

# Function to delete repository
delete_repository() {
  local project="$1"
  local location="$2"
  local repository="$3"
  
  format-echo "INFO" "Deleting Artifact Registry repository: $repository"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete repository: $repository"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the repository '$repository' and all its packages."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud artifacts repositories delete "$repository" \
    --project="$project" \
    --location="$location" \
    --quiet; then
    format-echo "ERROR" "Failed to delete repository: $repository"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted repository: $repository"
  return 0
}

# Function to list repositories
list_repositories() {
  local project="$1"
  local location="$2"
  
  format-echo "INFO" "Listing Artifact Registry repositories"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list repositories"
    return 0
  fi
  
  if ! gcloud artifacts repositories list \
    --project="$project" \
    --location="$location" \
    --format="table(name.basename(),format,mode,description,createTime.date())"; then
    format-echo "ERROR" "Failed to list repositories"
    return 1
  fi
  
  return 0
}

# Function to describe repository
describe_repository() {
  local project="$1"
  local location="$2"
  local repository="$3"
  
  format-echo "INFO" "Describing repository: $repository"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would describe repository: $repository"
    return 0
  fi
  
  if ! gcloud artifacts repositories describe "$repository" \
    --project="$project" \
    --location="$location"; then
    format-echo "ERROR" "Failed to describe repository: $repository"
    return 1
  fi
  
  return 0
}

#=====================================================================
# PACKAGE MANAGEMENT
#=====================================================================
# Function to list packages
list_packages() {
  local project="$1"
  local location="$2"
  local repository="$3"
  
  format-echo "INFO" "Listing packages in repository: $repository"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list packages in repository: $repository"
    return 0
  fi
  
  if ! gcloud artifacts packages list \
    --project="$project" \
    --location="$location" \
    --repository="$repository" \
    --format="table(name.basename(),createTime.date(),updateTime.date())"; then
    format-echo "ERROR" "Failed to list packages"
    return 1
  fi
  
  return 0
}

# Function to delete package
delete_package() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local package="$4"
  
  format-echo "INFO" "Deleting package: $package"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete package: $package"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the package '$package' and all its versions."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud artifacts packages delete "$package" \
    --project="$project" \
    --location="$location" \
    --repository="$repository" \
    --quiet; then
    format-echo "ERROR" "Failed to delete package: $package"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted package: $package"
  return 0
}

# Function to list package versions
list_versions() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local package="$4"
  
  format-echo "INFO" "Listing versions for package: $package"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list versions for package: $package"
    return 0
  fi
  
  if ! gcloud artifacts versions list \
    --project="$project" \
    --location="$location" \
    --repository="$repository" \
    --package="$package" \
    --format="table(name.basename(),createTime.date(),updateTime.date())"; then
    format-echo "ERROR" "Failed to list package versions"
    return 1
  fi
  
  return 0
}

# Function to delete package version
delete_version() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local package="$4"
  local version="$5"
  
  format-echo "INFO" "Deleting version: $version for package: $package"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete version: $version"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete version '$version' of package '$package'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud artifacts versions delete "$version" \
    --project="$project" \
    --location="$location" \
    --repository="$repository" \
    --package="$package" \
    --quiet; then
    format-echo "ERROR" "Failed to delete version: $version"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted version: $version"
  return 0
}

#=====================================================================
# DOCKER OPERATIONS
#=====================================================================
# Function to configure Docker authentication
configure_docker_auth() {
  local project="$1"
  local location="$2"
  
  format-echo "INFO" "Configuring Docker authentication for Artifact Registry"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would configure Docker authentication"
    return 0
  fi
  
  if ! gcloud auth configure-docker "$location-docker.pkg.dev" --quiet; then
    format-echo "ERROR" "Failed to configure Docker authentication"
    return 1
  fi
  
  format-echo "SUCCESS" "Configured Docker authentication"
  return 0
}

# Function to push Docker image
push_docker_image() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local image="$4"
  local tag="${5:-latest}"
  
  format-echo "INFO" "Pushing Docker image: $image:$tag"
  
  local registry_url
  registry_url=$(get_docker_image_url "$image" "$tag")
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would push Docker image to: $registry_url"
    return 0
  fi
  
  # Tag the local image for the registry
  if ! docker tag "$image:$tag" "$registry_url"; then
    format-echo "ERROR" "Failed to tag Docker image"
    return 1
  fi
  
  # Push the image
  if ! docker push "$registry_url"; then
    format-echo "ERROR" "Failed to push Docker image"
    return 1
  fi
  
  format-echo "SUCCESS" "Pushed Docker image: $registry_url"
  return 0
}

# Function to pull Docker image
pull_docker_image() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local image="$4"
  local tag="${5:-latest}"
  
  format-echo "INFO" "Pulling Docker image: $image:$tag"
  
  local registry_url
  registry_url=$(get_docker_image_url "$image" "$tag")
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would pull Docker image from: $registry_url"
    return 0
  fi
  
  if ! docker pull "$registry_url"; then
    format-echo "ERROR" "Failed to pull Docker image"
    return 1
  fi
  
  format-echo "SUCCESS" "Pulled Docker image: $registry_url"
  return 0
}

# Function to list Docker images
list_docker_images() {
  local project="$1"
  local location="$2"
  local repository="$3"
  
  format-echo "INFO" "Listing Docker images in repository: $repository"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list Docker images"
    return 0
  fi
  
  if ! gcloud artifacts docker images list \
    "$location-docker.pkg.dev/$project/$repository" \
    --include-tags \
    --format="table(package,version,tags,createTime.date(),updateTime.date())"; then
    format-echo "ERROR" "Failed to list Docker images"
    return 1
  fi
  
  return 0
}

# Function to delete Docker image
delete_docker_image() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local image="$4"
  local tag="${5:-latest}"
  
  format-echo "INFO" "Deleting Docker image: $image:$tag"
  
  local registry_url
  registry_url=$(get_docker_image_url "$image" "$tag")
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete Docker image: $registry_url"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the Docker image '$registry_url'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud artifacts docker images delete "$registry_url" --quiet; then
    format-echo "ERROR" "Failed to delete Docker image"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Docker image: $registry_url"
  return 0
}

#=====================================================================
# VULNERABILITY SCANNING
#=====================================================================
# Function to scan for vulnerabilities
scan_vulnerabilities() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local package="$4"
  
  format-echo "INFO" "Scanning package for vulnerabilities: $package"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would scan package for vulnerabilities: $package"
    return 0
  fi
  
  local package_full_name
  package_full_name=$(get_package_full_name)
  
  if ! gcloud beta container analysis notes list \
    --project="$project" \
    --filter="kind:VULNERABILITY" \
    --format="table(name,kind,vulnerability.severity)"; then
    format-echo "ERROR" "Failed to scan for vulnerabilities"
    return 1
  fi
  
  format-echo "SUCCESS" "Vulnerability scan completed"
  return 0
}

#=====================================================================
# IAM MANAGEMENT
#=====================================================================
# Function to add IAM policy binding
add_iam_binding() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local member="$4"
  local role="$5"
  
  format-echo "INFO" "Adding IAM policy binding"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would add IAM binding:"
    format-echo "INFO" "  Member: $member"
    format-echo "INFO" "  Role: $role"
    return 0
  fi
  
  if ! gcloud artifacts repositories add-iam-policy-binding "$repository" \
    --project="$project" \
    --location="$location" \
    --member="$member" \
    --role="$role"; then
    format-echo "ERROR" "Failed to add IAM policy binding"
    return 1
  fi
  
  format-echo "SUCCESS" "Added IAM policy binding"
  return 0
}

# Function to remove IAM policy binding
remove_iam_binding() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local member="$4"
  local role="$5"
  
  format-echo "INFO" "Removing IAM policy binding"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would remove IAM binding:"
    format-echo "INFO" "  Member: $member"
    format-echo "INFO" "  Role: $role"
    return 0
  fi
  
  if ! gcloud artifacts repositories remove-iam-policy-binding "$repository" \
    --project="$project" \
    --location="$location" \
    --member="$member" \
    --role="$role"; then
    format-echo "ERROR" "Failed to remove IAM policy binding"
    return 1
  fi
  
  format-echo "SUCCESS" "Removed IAM policy binding"
  return 0
}

# Function to get IAM policy
get_iam_policy() {
  local project="$1"
  local location="$2"
  local repository="$3"
  
  format-echo "INFO" "Getting IAM policy for repository: $repository"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get IAM policy"
    return 0
  fi
  
  if ! gcloud artifacts repositories get-iam-policy "$repository" \
    --project="$project" \
    --location="$location"; then
    format-echo "ERROR" "Failed to get IAM policy"
    return 1
  fi
  
  return 0
}

#=====================================================================
# CLEANUP OPERATIONS
#=====================================================================
# Function to set cleanup policy
set_cleanup_policy() {
  local project="$1"
  local location="$2"
  local repository="$3"
  local days="$4"
  
  format-echo "INFO" "Setting cleanup policy: keep versions for $days days"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set cleanup policy to $days days"
    return 0
  fi
  
  # Create cleanup policy configuration
  local policy_config
  policy_config=$(cat << EOF
{
  "rules": [
    {
      "name": "delete-old-versions",
      "action": {
        "type": "Delete"
      },
      "condition": {
        "olderThan": "${days}d"
      }
    }
  ]
}
EOF
)
  
  if ! echo "$policy_config" | gcloud artifacts repositories update "$repository" \
    --project="$project" \
    --location="$location" \
    --cleanup-policy-file=-; then
    format-echo "ERROR" "Failed to set cleanup policy"
    return 1
  fi
  
  format-echo "SUCCESS" "Set cleanup policy: keep versions for $days days"
  return 0
}

# Function to delete untagged images
delete_untagged_images() {
  local project="$1"
  local location="$2"
  local repository="$3"
  
  format-echo "INFO" "Deleting untagged Docker images"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete untagged images"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete all untagged images in repository '$repository'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  # List and delete untagged images
  local untagged_images
  untagged_images=$(gcloud artifacts docker images list \
    "$location-docker.pkg.dev/$project/$repository" \
    --filter="tags:*" \
    --format="value(package)@value(version)" 2>/dev/null || true)
  
  if [ -z "$untagged_images" ]; then
    format-echo "INFO" "No untagged images found"
    return 0
  fi
  
  local count=0
  while IFS= read -r image; do
    if [ -n "$image" ]; then
      if gcloud artifacts docker images delete "$location-docker.pkg.dev/$project/$repository/$image" --quiet; then
        ((count++))
      fi
    fi
  done <<< "$untagged_images"
  
  format-echo "SUCCESS" "Deleted $count untagged images"
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
  
  print_with_separator "GCP Artifact Registry Manager Script"
  format-echo "INFO" "Starting GCP Artifact Registry Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Artifact Registry Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Artifact Registry Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Artifact Registry Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-repo)
      if [ -z "$REPOSITORY" ]; then
        format-echo "ERROR" "Repository name is required for creating repository"
        exit 1
      fi
      ;;
    delete-repo|describe-repo|list-packages|get-iam-policy|set-cleanup-policy|delete-untagged|list-docker-images)
      if [ -z "$REPOSITORY" ]; then
        format-echo "ERROR" "Repository name is required for action: $ACTION"
        exit 1
      fi
      ;;
    delete-package|list-versions|scan-vulnerabilities)
      if [ -z "$REPOSITORY" ] || [ -z "$PACKAGE" ]; then
        format-echo "ERROR" "Repository and package names are required for action: $ACTION"
        exit 1
      fi
      ;;
    delete-version)
      if [ -z "$REPOSITORY" ] || [ -z "$PACKAGE" ] || [ -z "$VERSION" ]; then
        format-echo "ERROR" "Repository, package, and version are required for action: $ACTION"
        exit 1
      fi
      ;;
    push-docker|pull-docker|delete-docker-image)
      if [ -z "$REPOSITORY" ] || [ -z "$DOCKER_IMAGE" ]; then
        format-echo "ERROR" "Repository and Docker image names are required for action: $ACTION"
        exit 1
      fi
      ;;
    add-iam-binding|remove-iam-binding)
      if [ -z "$REPOSITORY" ] || [ -z "$MEMBER" ] || [ -z "$ROLE" ]; then
        format-echo "ERROR" "Repository, member, and role are required for IAM binding actions"
        exit 1
      fi
      ;;
    list-repos|configure-docker|print-docker-login)
      # No additional requirements
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-repo, delete-repo, push-docker, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-repo)
      if create_repository "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$FORMAT"; then
        format-echo "SUCCESS" "Repository creation completed successfully"
      else
        format-echo "ERROR" "Failed to create repository"
        exit 1
      fi
      ;;
    delete-repo)
      if delete_repository "$PROJECT_ID" "$LOCATION" "$REPOSITORY"; then
        format-echo "SUCCESS" "Repository deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete repository"
        exit 1
      fi
      ;;
    list-repos)
      if list_repositories "$PROJECT_ID" "$LOCATION"; then
        format-echo "SUCCESS" "Listed repositories successfully"
      else
        format-echo "ERROR" "Failed to list repositories"
        exit 1
      fi
      ;;
    describe-repo)
      if describe_repository "$PROJECT_ID" "$LOCATION" "$REPOSITORY"; then
        format-echo "SUCCESS" "Described repository successfully"
      else
        format-echo "ERROR" "Failed to describe repository"
        exit 1
      fi
      ;;
    list-packages)
      if list_packages "$PROJECT_ID" "$LOCATION" "$REPOSITORY"; then
        format-echo "SUCCESS" "Listed packages successfully"
      else
        format-echo "ERROR" "Failed to list packages"
        exit 1
      fi
      ;;
    delete-package)
      if delete_package "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$PACKAGE"; then
        format-echo "SUCCESS" "Package deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete package"
        exit 1
      fi
      ;;
    list-versions)
      if list_versions "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$PACKAGE"; then
        format-echo "SUCCESS" "Listed package versions successfully"
      else
        format-echo "ERROR" "Failed to list package versions"
        exit 1
      fi
      ;;
    delete-version)
      if delete_version "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$PACKAGE" "$VERSION"; then
        format-echo "SUCCESS" "Package version deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete package version"
        exit 1
      fi
      ;;
    push-docker)
      if push_docker_image "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$DOCKER_IMAGE" "$TAG"; then
        format-echo "SUCCESS" "Docker image push completed successfully"
      else
        format-echo "ERROR" "Failed to push Docker image"
        exit 1
      fi
      ;;
    pull-docker)
      if pull_docker_image "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$DOCKER_IMAGE" "$TAG"; then
        format-echo "SUCCESS" "Docker image pull completed successfully"
      else
        format-echo "ERROR" "Failed to pull Docker image"
        exit 1
      fi
      ;;
    list-docker-images)
      if list_docker_images "$PROJECT_ID" "$LOCATION" "$REPOSITORY"; then
        format-echo "SUCCESS" "Listed Docker images successfully"
      else
        format-echo "ERROR" "Failed to list Docker images"
        exit 1
      fi
      ;;
    delete-docker-image)
      if delete_docker_image "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$DOCKER_IMAGE" "$TAG"; then
        format-echo "SUCCESS" "Docker image deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete Docker image"
        exit 1
      fi
      ;;
    scan-vulnerabilities)
      if scan_vulnerabilities "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$PACKAGE"; then
        format-echo "SUCCESS" "Vulnerability scan completed successfully"
      else
        format-echo "ERROR" "Failed to scan for vulnerabilities"
        exit 1
      fi
      ;;
    add-iam-binding)
      if add_iam_binding "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$MEMBER" "$ROLE"; then
        format-echo "SUCCESS" "IAM policy binding added successfully"
      else
        format-echo "ERROR" "Failed to add IAM policy binding"
        exit 1
      fi
      ;;
    remove-iam-binding)
      if remove_iam_binding "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$MEMBER" "$ROLE"; then
        format-echo "SUCCESS" "IAM policy binding removed successfully"
      else
        format-echo "ERROR" "Failed to remove IAM policy binding"
        exit 1
      fi
      ;;
    get-iam-policy)
      if get_iam_policy "$PROJECT_ID" "$LOCATION" "$REPOSITORY"; then
        format-echo "SUCCESS" "Retrieved IAM policy successfully"
      else
        format-echo "ERROR" "Failed to get IAM policy"
        exit 1
      fi
      ;;
    set-cleanup-policy)
      if set_cleanup_policy "$PROJECT_ID" "$LOCATION" "$REPOSITORY" "$CLEANUP_DAYS"; then
        format-echo "SUCCESS" "Cleanup policy set successfully"
      else
        format-echo "ERROR" "Failed to set cleanup policy"
        exit 1
      fi
      ;;
    delete-untagged)
      if delete_untagged_images "$PROJECT_ID" "$LOCATION" "$REPOSITORY"; then
        format-echo "SUCCESS" "Untagged images deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete untagged images"
        exit 1
      fi
      ;;
    configure-docker)
      if configure_docker_auth "$PROJECT_ID" "$LOCATION"; then
        format-echo "SUCCESS" "Docker authentication configured successfully"
      else
        format-echo "ERROR" "Failed to configure Docker authentication"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Artifact Registry Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
