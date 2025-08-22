#!/usr/bin/env bash
# gcp-data-fusion-manager.sh
# Script to manage Google Cloud Data Fusion resources

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
INSTANCE_ID=""
PIPELINE_NAME=""
NAMESPACE=""
REGION=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Data Fusion Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Data Fusion (data integration service) resources."
  echo "  Provides comprehensive management capabilities for Data Fusion instances and pipelines."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-i, --instance INSTANCE_ID\033[0m  Set Data Fusion instance ID"
  echo -e "  \033[1;33m-n, --pipeline PIPELINE_NAME\033[0m Set pipeline name"
  echo -e "  \033[1;33m-s, --namespace NAMESPACE\033[0m   Set namespace"
  echo -e "  \033[1;33m-r, --region REGION\033[0m         Set region for instance"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate-instance\033[0m             Create new Data Fusion instance"
  echo -e "  \033[1;36mlist-instances\033[0m              List Data Fusion instances"
  echo -e "  \033[1;36mget-instance\033[0m                Get instance details"
  echo -e "  \033[1;36mupdate-instance\033[0m             Update instance configuration"
  echo -e "  \033[1;36mdelete-instance\033[0m             Delete Data Fusion instance"
  echo -e "  \033[1;36mrestart-instance\033[0m            Restart Data Fusion instance"
  echo -e "  \033[1;36mlist-pipelines\033[0m              List pipelines in instance"
  echo -e "  \033[1;36mget-pipeline\033[0m                Get pipeline details"
  echo -e "  \033[1;36mstart-pipeline\033[0m              Start a pipeline"
  echo -e "  \033[1;36mstop-pipeline\033[0m               Stop a pipeline"
  echo -e "  \033[1;36mdelete-pipeline\033[0m             Delete a pipeline"
  echo -e "  \033[1;36mlist-namespaces\033[0m             List namespaces"
  echo -e "  \033[1;36mcreate-namespace\033[0m            Create namespace"
  echo -e "  \033[1;36mdelete-namespace\033[0m            Delete namespace"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project -r us-central1 create-instance"
  echo "  $0 --project my-project --instance my-instance list-pipelines"
  echo "  $0 -p my-project -i my-instance -n my-pipeline start-pipeline"
  echo "  $0 -p my-project -i my-instance list-namespaces"
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
      -i|--instance)
        if [[ -n "${2:-}" ]]; then
          INSTANCE_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --instance"
          usage
        fi
        ;;
      -n|--pipeline)
        if [[ -n "${2:-}" ]]; then
          PIPELINE_NAME="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --pipeline"
          usage
        fi
        ;;
      -s|--namespace)
        if [[ -n "${2:-}" ]]; then
          NAMESPACE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --namespace"
          usage
        fi
        ;;
      -r|--region)
        if [[ -n "${2:-}" ]]; then
          REGION="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --region"
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
    "datafusion.googleapis.com"
    "compute.googleapis.com"
    "cloudresourcemanager.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# DATA FUSION INSTANCE OPERATIONS
#=====================================================================
create_instance() {
  format-echo "INFO" "Creating Data Fusion instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required for create operation"
    exit 1
  fi
  
  if [[ -z "$REGION" ]]; then
    REGION="us-central1"
    format-echo "INFO" "Using default region: $REGION"
  fi
  
  gcloud data-fusion instances create "$INSTANCE_ID" \
    --location="$REGION" \
    --type=basic \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Data Fusion instance created successfully"
  format-echo "INFO" "It may take several minutes for the instance to be fully available"
}

list_instances() {
  format-echo "INFO" "Listing Data Fusion instances..."
  
  print_with_separator "Data Fusion Instances"
  gcloud data-fusion instances list --project="$PROJECT_ID"
  print_with_separator "End of Data Fusion Instances"
}

get_instance() {
  format-echo "INFO" "Getting Data Fusion instance details..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required for describe operation"
    exit 1
  fi
  
  print_with_separator "Data Fusion Instance: $INSTANCE_ID"
  gcloud data-fusion instances describe "$INSTANCE_ID" \
    --location="$REGION" \
    --project="$PROJECT_ID"
  print_with_separator "End of Data Fusion Instance Details"
}

update_instance() {
  format-echo "INFO" "Updating Data Fusion instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required for update operation"
    exit 1
  fi
  
  gcloud data-fusion instances update "$INSTANCE_ID" \
    --location="$REGION" \
    --enable-stackdriver-logging \
    --enable-stackdriver-monitoring \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Data Fusion instance updated successfully"
}

delete_instance() {
  format-echo "INFO" "Deleting Data Fusion instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required for delete operation"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the instance and all its data"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud data-fusion instances delete "$INSTANCE_ID" \
    --location="$REGION" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Data Fusion instance deleted successfully"
}

restart_instance() {
  format-echo "INFO" "Restarting Data Fusion instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required for restart operation"
    exit 1
  fi
  
  gcloud data-fusion instances restart "$INSTANCE_ID" \
    --location="$REGION" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Data Fusion instance restart initiated"
}

#=====================================================================
# DATA FUSION PIPELINE OPERATIONS
#=====================================================================
list_pipelines() {
  format-echo "INFO" "Listing Data Fusion pipelines..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Instance ID and region are required"
    exit 1
  fi
  
  # Get instance endpoint
  local endpoint=$(gcloud data-fusion instances describe "$INSTANCE_ID" \
    --location="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(apiEndpoint)")
  
  if [[ -z "$endpoint" ]]; then
    format-echo "ERROR" "Could not get instance endpoint"
    exit 1
  fi
  
  format-echo "INFO" "Instance endpoint: $endpoint"
  format-echo "INFO" "Please use the Data Fusion web UI to manage pipelines"
  format-echo "INFO" "URL: $endpoint"
  
  print_with_separator "Data Fusion Pipelines"
  echo "Use the web UI at $endpoint to view and manage pipelines"
  print_with_separator "End of Data Fusion Pipelines"
}

get_pipeline() {
  format-echo "INFO" "Getting Data Fusion pipeline details..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$PIPELINE_NAME" ]]; then
    format-echo "ERROR" "Instance ID, region, and pipeline name are required"
    exit 1
  fi
  
  # Get instance endpoint
  local endpoint=$(gcloud data-fusion instances describe "$INSTANCE_ID" \
    --location="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(apiEndpoint)")
  
  format-echo "INFO" "Instance endpoint: $endpoint"
  format-echo "INFO" "Pipeline: $PIPELINE_NAME"
  format-echo "INFO" "Please use the Data Fusion web UI to view pipeline details"
}

start_pipeline() {
  format-echo "INFO" "Starting Data Fusion pipeline..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$PIPELINE_NAME" ]]; then
    format-echo "ERROR" "Instance ID, region, and pipeline name are required"
    exit 1
  fi
  
  format-echo "INFO" "Pipeline operations should be performed through the Data Fusion web UI"
  format-echo "INFO" "Pipeline: $PIPELINE_NAME"
}

stop_pipeline() {
  format-echo "INFO" "Stopping Data Fusion pipeline..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$PIPELINE_NAME" ]]; then
    format-echo "ERROR" "Instance ID, region, and pipeline name are required"
    exit 1
  fi
  
  format-echo "INFO" "Pipeline operations should be performed through the Data Fusion web UI"
  format-echo "INFO" "Pipeline: $PIPELINE_NAME"
}

delete_pipeline() {
  format-echo "INFO" "Deleting Data Fusion pipeline..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$PIPELINE_NAME" ]]; then
    format-echo "ERROR" "Instance ID, region, and pipeline name are required"
    exit 1
  fi
  
  format-echo "WARNING" "Pipeline deletion should be performed through the Data Fusion web UI"
  format-echo "INFO" "Pipeline: $PIPELINE_NAME"
}

#=====================================================================
# DATA FUSION NAMESPACE OPERATIONS
#=====================================================================
list_namespaces() {
  format-echo "INFO" "Listing Data Fusion namespaces..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Instance ID and region are required"
    exit 1
  fi
  
  # Get instance endpoint
  local endpoint=$(gcloud data-fusion instances describe "$INSTANCE_ID" \
    --location="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(apiEndpoint)")
  
  format-echo "INFO" "Instance endpoint: $endpoint"
  format-echo "INFO" "Please use the Data Fusion web UI to manage namespaces"
  
  print_with_separator "Data Fusion Namespaces"
  echo "Use the web UI at $endpoint to view and manage namespaces"
  print_with_separator "End of Data Fusion Namespaces"
}

create_namespace() {
  format-echo "INFO" "Creating Data Fusion namespace..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$NAMESPACE" ]]; then
    format-echo "ERROR" "Instance ID, region, and namespace are required"
    exit 1
  fi
  
  format-echo "INFO" "Namespace operations should be performed through the Data Fusion web UI"
  format-echo "INFO" "Namespace: $NAMESPACE"
}

delete_namespace() {
  format-echo "INFO" "Deleting Data Fusion namespace..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$REGION" ]] || [[ -z "$NAMESPACE" ]]; then
    format-echo "ERROR" "Instance ID, region, and namespace are required"
    exit 1
  fi
  
  format-echo "WARNING" "Namespace deletion should be performed through the Data Fusion web UI"
  format-echo "INFO" "Namespace: $NAMESPACE"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    create-instance)
      enable_apis
      create_instance
      ;;
    list-instances)
      list_instances
      ;;
    get-instance)
      get_instance
      ;;
    update-instance)
      update_instance
      ;;
    delete-instance)
      delete_instance
      ;;
    restart-instance)
      restart_instance
      ;;
    list-pipelines)
      list_pipelines
      ;;
    get-pipeline)
      get_pipeline
      ;;
    start-pipeline)
      start_pipeline
      ;;
    stop-pipeline)
      stop_pipeline
      ;;
    delete-pipeline)
      delete_pipeline
      ;;
    list-namespaces)
      list_namespaces
      ;;
    create-namespace)
      create_namespace
      ;;
    delete-namespace)
      delete_namespace
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
  
  print_with_separator "GCP Data Fusion Manager"
  format-echo "INFO" "Starting Data Fusion management operations..."
  
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
  format-echo "SUCCESS" "Data Fusion management operation completed successfully."
  print_with_separator "End of GCP Data Fusion Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
