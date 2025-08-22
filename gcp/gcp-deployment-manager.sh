#!/usr/bin/env bash
# gcp-deployment-manager.sh
# Script to manage GCP Deployment Manager templates and deployments.

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
DEPLOYMENT_NAME=""
TEMPLATE_FILE=""
CONFIG_FILE=""
PROPERTIES_FILE=""
DESCRIPTION=""
LABELS=""
PREVIEW_MODE=false
UPDATE_MODE=false
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Deployment Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Deployment Manager templates and deployments."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-deployment\033[0m    Create a new deployment"
  echo -e "  \033[1;33mupdate-deployment\033[0m    Update an existing deployment"
  echo -e "  \033[1;33mdelete-deployment\033[0m    Delete a deployment"
  echo -e "  \033[1;33mpreview-deployment\033[0m   Preview deployment changes"
  echo -e "  \033[1;33mlist-deployments\033[0m     List all deployments"
  echo -e "  \033[1;33mget-deployment\033[0m       Get deployment details"
  echo -e "  \033[1;33mlist-resources\033[0m       List resources in a deployment"
  echo -e "  \033[1;33mget-manifest\033[0m         Get deployment manifest"
  echo -e "  \033[1;33mvalidate-template\033[0m    Validate a deployment template"
  echo -e "  \033[1;33mstop-deployment\033[0m      Stop a running deployment"
  echo -e "  \033[1;33mexport-template\033[0m      Export existing resources as template"
  echo -e "  \033[1;33mgenerate-config\033[0m      Generate configuration file template"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--deployment <name>\033[0m          (Required for most actions) Deployment name"
  echo -e "  \033[1;33m--template <file>\033[0m            (Optional) Template file path"
  echo -e "  \033[1;33m--config <file>\033[0m              (Optional) Configuration file path"
  echo -e "  \033[1;33m--properties <file>\033[0m          (Optional) Properties file path"
  echo -e "  \033[1;33m--description <text>\033[0m         (Optional) Deployment description"
  echo -e "  \033[1;33m--labels <key=value>\033[0m         (Optional) Labels in key=value format (comma-separated)"
  echo -e "  \033[1;33m--preview\033[0m                    (Optional) Preview mode - show changes without applying"
  echo -e "  \033[1;33m--update\033[0m                     (Optional) Update existing deployment"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-deployments --project my-project"
  echo "  $0 create-deployment --project my-project --deployment my-app --config deployment.yaml"
  echo "  $0 preview-deployment --project my-project --deployment my-app --config new-config.yaml"
  echo "  $0 update-deployment --project my-project --deployment my-app --config updated-config.yaml"
  echo "  $0 validate-template --template my-template.jinja"
  echo "  $0 delete-deployment --project my-project --deployment my-app --force"
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
      --deployment)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No deployment name provided after --deployment."
          usage
        fi
        DEPLOYMENT_NAME="$2"
        shift 2
        ;;
      --template)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No template file provided after --template."
          usage
        fi
        TEMPLATE_FILE="$2"
        shift 2
        ;;
      --config)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No config file provided after --config."
          usage
        fi
        CONFIG_FILE="$2"
        shift 2
        ;;
      --properties)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No properties file provided after --properties."
          usage
        fi
        PROPERTIES_FILE="$2"
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
      --preview)
        PREVIEW_MODE=true
        shift
        ;;
      --update)
        UPDATE_MODE=true
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

# Function to validate file exists
validate_file() {
  local file="$1"
  local description="$2"
  
  if [ -n "$file" ] && [ ! -f "$file" ]; then
    format-echo "ERROR" "$description file not found: $file"
    return 1
  fi
  return 0
}

#=====================================================================
# DEPLOYMENT MANAGEMENT FUNCTIONS
#=====================================================================
# Function to create deployment
create_deployment() {
  local project="$1"
  local deployment="$2"
  
  format-echo "INFO" "Creating deployment: $deployment"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create deployment:"
    format-echo "INFO" "  Name: $deployment"
    [ -n "$CONFIG_FILE" ] && format-echo "INFO" "  Config: $CONFIG_FILE"
    [ -n "$TEMPLATE_FILE" ] && format-echo "INFO" "  Template: $TEMPLATE_FILE"
    [ -n "$DESCRIPTION" ] && format-echo "INFO" "  Description: $DESCRIPTION"
    return 0
  fi
  
  # Build deployment create command
  local deploy_cmd="gcloud deployment-manager deployments create $deployment"
  deploy_cmd+=" --project=$project"
  
  if [ -n "$CONFIG_FILE" ]; then
    deploy_cmd+=" --config=$CONFIG_FILE"
  elif [ -n "$TEMPLATE_FILE" ]; then
    deploy_cmd+=" --template=$TEMPLATE_FILE"
  else
    format-echo "ERROR" "Either --config or --template must be provided"
    return 1
  fi
  
  if [ -n "$DESCRIPTION" ]; then
    deploy_cmd+=" --description=\"$DESCRIPTION\""
  fi
  
  if [ -n "$LABELS" ]; then
    deploy_cmd+=" --labels=$LABELS"
  fi
  
  if [ -n "$PROPERTIES_FILE" ]; then
    deploy_cmd+=" --properties=$PROPERTIES_FILE"
  fi
  
  if [ "$PREVIEW_MODE" = true ]; then
    deploy_cmd+=" --preview"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $deploy_cmd"
  fi
  
  if ! eval "$deploy_cmd"; then
    format-echo "ERROR" "Failed to create deployment: $deployment"
    return 1
  fi
  
  if [ "$PREVIEW_MODE" = true ]; then
    format-echo "SUCCESS" "Preview completed for deployment: $deployment"
  else
    format-echo "SUCCESS" "Created deployment: $deployment"
  fi
  return 0
}

# Function to update deployment
update_deployment() {
  local project="$1"
  local deployment="$2"
  
  format-echo "INFO" "Updating deployment: $deployment"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would update deployment: $deployment"
    return 0
  fi
  
  # Build deployment update command
  local update_cmd="gcloud deployment-manager deployments update $deployment"
  update_cmd+=" --project=$project"
  
  if [ -n "$CONFIG_FILE" ]; then
    update_cmd+=" --config=$CONFIG_FILE"
  elif [ -n "$TEMPLATE_FILE" ]; then
    update_cmd+=" --template=$TEMPLATE_FILE"
  else
    format-echo "ERROR" "Either --config or --template must be provided for update"
    return 1
  fi
  
  if [ -n "$DESCRIPTION" ]; then
    update_cmd+=" --description=\"$DESCRIPTION\""
  fi
  
  if [ -n "$PROPERTIES_FILE" ]; then
    update_cmd+=" --properties=$PROPERTIES_FILE"
  fi
  
  if [ "$PREVIEW_MODE" = true ]; then
    update_cmd+=" --preview"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $update_cmd"
  fi
  
  if ! eval "$update_cmd"; then
    format-echo "ERROR" "Failed to update deployment: $deployment"
    return 1
  fi
  
  if [ "$PREVIEW_MODE" = true ]; then
    format-echo "SUCCESS" "Preview completed for deployment update: $deployment"
  else
    format-echo "SUCCESS" "Updated deployment: $deployment"
  fi
  return 0
}

# Function to delete deployment
delete_deployment() {
  local project="$1"
  local deployment="$2"
  
  # Confirmation unless forced
  if [ "$FORCE" = false ]; then
    echo
    format-echo "WARNING" "This will permanently delete deployment: $deployment"
    format-echo "WARNING" "All resources created by this deployment will be deleted!"
    echo
    read -p "Are you sure you want to delete this deployment? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      format-echo "INFO" "Deployment deletion cancelled"
      return 0
    fi
  fi
  
  format-echo "INFO" "Deleting deployment: $deployment"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete deployment: $deployment"
    return 0
  fi
  
  if ! gcloud deployment-manager deployments delete "$deployment" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete deployment: $deployment"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted deployment: $deployment"
  return 0
}

# Function to list deployments
list_deployments() {
  local project="$1"
  
  format-echo "INFO" "Listing deployments in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list deployments"
    return 0
  fi
  
  if ! gcloud deployment-manager deployments list \
    --project="$project" \
    --format="table(name,description,insertTime,operation.operationType,operation.status)"; then
    format-echo "ERROR" "Failed to list deployments"
    return 1
  fi
  
  return 0
}

# Function to get deployment details
get_deployment() {
  local project="$1"
  local deployment="$2"
  
  format-echo "INFO" "Getting details for deployment: $deployment"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get deployment details: $deployment"
    return 0
  fi
  
  if ! gcloud deployment-manager deployments describe "$deployment" \
    --project="$project"; then
    format-echo "ERROR" "Failed to get deployment details: $deployment"
    return 1
  fi
  
  return 0
}

# Function to list resources in deployment
list_resources() {
  local project="$1"
  local deployment="$2"
  
  format-echo "INFO" "Listing resources in deployment: $deployment"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list resources for deployment: $deployment"
    return 0
  fi
  
  if ! gcloud deployment-manager resources list \
    --deployment="$deployment" \
    --project="$project" \
    --format="table(name,type,update.state,update.intent)"; then
    format-echo "ERROR" "Failed to list resources for deployment: $deployment"
    return 1
  fi
  
  return 0
}

# Function to get deployment manifest
get_manifest() {
  local project="$1"
  local deployment="$2"
  
  format-echo "INFO" "Getting manifest for deployment: $deployment"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get manifest for deployment: $deployment"
    return 0
  fi
  
  # Get the latest manifest
  local manifest_id
  if ! manifest_id=$(gcloud deployment-manager manifests list \
    --deployment="$deployment" \
    --project="$project" \
    --format="value(name)" \
    --sort-by="~insertTime" \
    --limit=1 2>/dev/null); then
    format-echo "ERROR" "Failed to get manifest list for deployment: $deployment"
    return 1
  fi
  
  if [ -z "$manifest_id" ]; then
    format-echo "ERROR" "No manifest found for deployment: $deployment"
    return 1
  fi
  
  if ! gcloud deployment-manager manifests describe "$manifest_id" \
    --deployment="$deployment" \
    --project="$project"; then
    format-echo "ERROR" "Failed to get manifest details"
    return 1
  fi
  
  return 0
}

# Function to validate template
validate_template() {
  local template="$1"
  
  format-echo "INFO" "Validating template: $template"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would validate template: $template"
    return 0
  fi
  
  if [ ! -f "$template" ]; then
    format-echo "ERROR" "Template file not found: $template"
    return 1
  fi
  
  # Basic syntax validation for YAML/JSON
  local extension="${template##*.}"
  case "$extension" in
    yaml|yml)
      if command_exists python3; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$template'))" 2>/dev/null; then
          format-echo "ERROR" "Invalid YAML syntax in template: $template"
          return 1
        fi
      else
        format-echo "WARNING" "Python3 not available for YAML validation"
      fi
      ;;
    json)
      if command_exists python3; then
        if ! python3 -c "import json; json.load(open('$template'))" 2>/dev/null; then
          format-echo "ERROR" "Invalid JSON syntax in template: $template"
          return 1
        fi
      elif command_exists jq; then
        if ! jq empty "$template" >/dev/null 2>&1; then
          format-echo "ERROR" "Invalid JSON syntax in template: $template"
          return 1
        fi
      else
        format-echo "WARNING" "No JSON validator available"
      fi
      ;;
    jinja|jinja2)
      format-echo "INFO" "Jinja template detected, basic validation only"
      ;;
    *)
      format-echo "WARNING" "Unknown template format: $extension"
      ;;
  esac
  
  format-echo "SUCCESS" "Template validation passed: $template"
  return 0
}

# Function to stop deployment
stop_deployment() {
  local project="$1"
  local deployment="$2"
  
  format-echo "INFO" "Stopping deployment: $deployment"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would stop deployment: $deployment"
    return 0
  fi
  
  if ! gcloud deployment-manager deployments stop "$deployment" \
    --project="$project"; then
    format-echo "ERROR" "Failed to stop deployment: $deployment"
    return 1
  fi
  
  format-echo "SUCCESS" "Stopped deployment: $deployment"
  return 0
}

# Function to generate config template
generate_config() {
  local config_file="${CONFIG_FILE:-deployment-config.yaml}"
  
  format-echo "INFO" "Generating configuration template: $config_file"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would generate config template: $config_file"
    return 0
  fi
  
  cat > "$config_file" << 'EOF'
# Deployment Manager Configuration Template
# Edit this file to match your deployment requirements

imports:
- path: templates/vm-template.jinja
  name: vm-template.jinja

resources:
# Example: Virtual Machine Instance
- name: my-vm-instance
  type: vm-template.jinja
  properties:
    zone: us-central1-a
    machineType: f1-micro
    diskImage: projects/debian-cloud/global/images/family/debian-11
    networkName: default
    
# Example: Cloud Storage Bucket
- name: my-storage-bucket
  type: storage.v1.bucket
  properties:
    location: US
    storageClass: STANDARD
    
# Example: Cloud SQL Instance
- name: my-sql-instance
  type: sqladmin.v1beta4.instance
  properties:
    region: us-central1
    databaseVersion: MYSQL_8_0
    settings:
      tier: db-f1-micro
      dataDiskSizeGb: 10
      dataDiskType: PD_SSD

outputs:
- name: vm-instance-ip
  value: $(ref.my-vm-instance.networkInterfaces[0].accessConfigs[0].natIP)
- name: bucket-name
  value: $(ref.my-storage-bucket.name)
- name: sql-connection-name
  value: $(ref.my-sql-instance.connectionName)
EOF
  
  format-echo "SUCCESS" "Generated configuration template: $config_file"
  format-echo "INFO" "Edit the configuration file and use it with: $0 create-deployment --config $config_file"
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
  
  print_with_separator "GCP Deployment Manager Script"
  format-echo "INFO" "Starting GCP Deployment Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Deployment Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Deployment Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Deployment Manager Script"
    exit 1
  fi
  
  # Validate files exist
  if ! validate_file "$CONFIG_FILE" "Configuration"; then
    exit 1
  fi
  
  if ! validate_file "$TEMPLATE_FILE" "Template"; then
    exit 1
  fi
  
  if ! validate_file "$PROPERTIES_FILE" "Properties"; then
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-deployment|update-deployment|delete-deployment|get-deployment|list-resources|get-manifest|stop-deployment)
      if [ -z "$DEPLOYMENT_NAME" ]; then
        format-echo "ERROR" "Deployment name is required for action: $ACTION"
        exit 1
      fi
      ;;
    preview-deployment)
      if [ -z "$DEPLOYMENT_NAME" ]; then
        format-echo "ERROR" "Deployment name is required for action: $ACTION"
        exit 1
      fi
      PREVIEW_MODE=true
      ;;
    validate-template)
      if [ -z "$TEMPLATE_FILE" ]; then
        format-echo "ERROR" "Template file is required for validation"
        exit 1
      fi
      ;;
    list-deployments|generate-config)
      # No additional requirements
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-deployment, update-deployment, delete-deployment, preview-deployment, list-deployments, get-deployment, list-resources, get-manifest, validate-template, stop-deployment, generate-config"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-deployment)
      if create_deployment "$PROJECT_ID" "$DEPLOYMENT_NAME"; then
        format-echo "SUCCESS" "Deployment creation completed successfully"
      else
        format-echo "ERROR" "Failed to create deployment"
        exit 1
      fi
      ;;
    update-deployment|preview-deployment)
      if update_deployment "$PROJECT_ID" "$DEPLOYMENT_NAME"; then
        if [ "$PREVIEW_MODE" = true ]; then
          format-echo "SUCCESS" "Deployment preview completed successfully"
        else
          format-echo "SUCCESS" "Deployment update completed successfully"
        fi
      else
        if [ "$PREVIEW_MODE" = true ]; then
          format-echo "ERROR" "Failed to preview deployment"
        else
          format-echo "ERROR" "Failed to update deployment"
        fi
        exit 1
      fi
      ;;
    delete-deployment)
      if delete_deployment "$PROJECT_ID" "$DEPLOYMENT_NAME"; then
        format-echo "SUCCESS" "Deployment deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete deployment"
        exit 1
      fi
      ;;
    list-deployments)
      if list_deployments "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed deployments successfully"
      else
        format-echo "ERROR" "Failed to list deployments"
        exit 1
      fi
      ;;
    get-deployment)
      if get_deployment "$PROJECT_ID" "$DEPLOYMENT_NAME"; then
        format-echo "SUCCESS" "Retrieved deployment details successfully"
      else
        format-echo "ERROR" "Failed to get deployment details"
        exit 1
      fi
      ;;
    list-resources)
      if list_resources "$PROJECT_ID" "$DEPLOYMENT_NAME"; then
        format-echo "SUCCESS" "Listed deployment resources successfully"
      else
        format-echo "ERROR" "Failed to list deployment resources"
        exit 1
      fi
      ;;
    get-manifest)
      if get_manifest "$PROJECT_ID" "$DEPLOYMENT_NAME"; then
        format-echo "SUCCESS" "Retrieved deployment manifest successfully"
      else
        format-echo "ERROR" "Failed to get deployment manifest"
        exit 1
      fi
      ;;
    validate-template)
      if validate_template "$TEMPLATE_FILE"; then
        format-echo "SUCCESS" "Template validation completed successfully"
      else
        format-echo "ERROR" "Template validation failed"
        exit 1
      fi
      ;;
    stop-deployment)
      if stop_deployment "$PROJECT_ID" "$DEPLOYMENT_NAME"; then
        format-echo "SUCCESS" "Deployment stop completed successfully"
      else
        format-echo "ERROR" "Failed to stop deployment"
        exit 1
      fi
      ;;
    generate-config)
      if generate_config; then
        format-echo "SUCCESS" "Configuration template generation completed successfully"
      else
        format-echo "ERROR" "Failed to generate configuration template"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Deployment Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
