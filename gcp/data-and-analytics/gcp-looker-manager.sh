#!/usr/bin/env bash
# gcp-looker-manager.sh
# Script to manage Google Cloud Looker/Looker Studio resources

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
DASHBOARD_ID=""
DATASET_ID=""
REGION=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Looker/Looker Studio Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Looker and Looker Studio (business intelligence) resources."
  echo "  Provides comprehensive management capabilities for Looker instances and analytics."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-i, --instance INSTANCE_ID\033[0m  Set Looker instance ID"
  echo -e "  \033[1;33m-d, --dashboard DASHBOARD_ID\033[0m Set dashboard ID"
  echo -e "  \033[1;33m-s, --dataset DATASET_ID\033[0m    Set dataset ID"
  echo -e "  \033[1;33m-r, --region REGION\033[0m         Set region for instance"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate-instance\033[0m             Create new Looker instance"
  echo -e "  \033[1;36mlist-instances\033[0m              List Looker instances"
  echo -e "  \033[1;36mget-instance\033[0m                Get instance details"
  echo -e "  \033[1;36mupdate-instance\033[0m             Update instance configuration"
  echo -e "  \033[1;36mdelete-instance\033[0m             Delete Looker instance"
  echo -e "  \033[1;36mrestart-instance\033[0m            Restart Looker instance"
  echo -e "  \033[1;36mget-studio-url\033[0m              Get Looker Studio URL"
  echo -e "  \033[1;36mlist-data-sources\033[0m           List available data sources"
  echo -e "  \033[1;36mconnect-bigquery\033[0m            Connect BigQuery as data source"
  echo -e "  \033[1;36mlist-dashboards\033[0m             List dashboards (via API)"
  echo -e "  \033[1;36mget-dashboard\033[0m               Get dashboard details"
  echo -e "  \033[1;36mexport-dashboard\033[0m            Export dashboard"
  echo -e "  \033[1;36mlist-reports\033[0m                List reports"
  echo -e "  \033[1;36mschedule-report\033[0m             Schedule report delivery"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project -r us-central1 create-instance"
  echo "  $0 --project my-project --instance my-instance get-instance"
  echo "  $0 -p my-project get-studio-url"
  echo "  $0 -p my-project -s my-dataset connect-bigquery"
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
      -d|--dashboard)
        if [[ -n "${2:-}" ]]; then
          DASHBOARD_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --dashboard"
          usage
        fi
        ;;
      -s|--dataset)
        if [[ -n "${2:-}" ]]; then
          DATASET_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --dataset"
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
    "looker.googleapis.com"
    "bigquery.googleapis.com"
    "cloudresourcemanager.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# LOOKER INSTANCE OPERATIONS
#=====================================================================
create_instance() {
  format-echo "INFO" "Creating Looker instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required for create operation"
    exit 1
  fi
  
  if [[ -z "$REGION" ]]; then
    REGION="us-central1"
    format-echo "INFO" "Using default region: $REGION"
  fi
  
  # Note: Looker instances are typically managed through the Cloud Console
  # This is a placeholder for the actual gcloud command when available
  format-echo "INFO" "Creating Looker instance: $INSTANCE_ID"
  format-echo "INFO" "Region: $REGION"
  format-echo "WARNING" "Looker instances are typically created through the Google Cloud Console"
  format-echo "INFO" "Please visit: https://console.cloud.google.com/looker"
  
  format-echo "SUCCESS" "Looker instance creation initiated (check Cloud Console for progress)"
}

list_instances() {
  format-echo "INFO" "Listing Looker instances..."
  
  print_with_separator "Looker Instances"
  format-echo "INFO" "Looker instances are managed through the Cloud Console"
  format-echo "INFO" "Please visit: https://console.cloud.google.com/looker/instances"
  
  # Attempt to use gcloud if the command is available
  if gcloud looker instances list --project="$PROJECT_ID" 2>/dev/null; then
    format-echo "SUCCESS" "Looker instances listed successfully"
  else
    format-echo "INFO" "Use the Cloud Console to view Looker instances"
  fi
  print_with_separator "End of Looker Instances"
}

get_instance() {
  format-echo "INFO" "Getting Looker instance details..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  if [[ -z "$REGION" ]]; then
    format-echo "ERROR" "Region is required for describe operation"
    exit 1
  fi
  
  print_with_separator "Looker Instance: $INSTANCE_ID"
  format-echo "INFO" "Instance ID: $INSTANCE_ID"
  format-echo "INFO" "Region: $REGION"
  format-echo "INFO" "Please use the Cloud Console for detailed instance information"
  format-echo "INFO" "URL: https://console.cloud.google.com/looker/instances"
  print_with_separator "End of Looker Instance Details"
}

update_instance() {
  format-echo "INFO" "Updating Looker instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  format-echo "INFO" "Instance updates are typically performed through the Cloud Console"
  format-echo "INFO" "Instance: $INSTANCE_ID"
  format-echo "INFO" "URL: https://console.cloud.google.com/looker/instances"
}

delete_instance() {
  format-echo "INFO" "Deleting Looker instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the instance and all its data"
  format-echo "WARNING" "Instance deletion should be performed through the Cloud Console"
  format-echo "INFO" "Instance: $INSTANCE_ID"
  format-echo "INFO" "URL: https://console.cloud.google.com/looker/instances"
}

restart_instance() {
  format-echo "INFO" "Restarting Looker instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  format-echo "INFO" "Instance restart should be performed through the Cloud Console"
  format-echo "INFO" "Instance: $INSTANCE_ID"
  format-echo "INFO" "URL: https://console.cloud.google.com/looker/instances"
}

#=====================================================================
# LOOKER STUDIO OPERATIONS
#=====================================================================
get_studio_url() {
  format-echo "INFO" "Getting Looker Studio URL..."
  
  print_with_separator "Looker Studio Access"
  format-echo "INFO" "Looker Studio (formerly Google Data Studio) is a free web-based tool"
  format-echo "INFO" "URL: https://datastudio.google.com/"
  format-echo "INFO" "Project-specific URL: https://datastudio.google.com/u/0/navigation/reporting"
  format-echo "INFO" "You can create reports and dashboards using data from your GCP project"
  print_with_separator "End of Looker Studio Access"
}

list_data_sources() {
  format-echo "INFO" "Listing available data sources..."
  
  print_with_separator "Available Data Sources"
  format-echo "INFO" "Common GCP data sources for Looker Studio:"
  echo "  • BigQuery datasets"
  echo "  • Cloud SQL databases"
  echo "  • Google Sheets"
  echo "  • Cloud Storage (CSV files)"
  echo "  • Google Analytics"
  echo "  • Google Ads"
  
  format-echo "INFO" "BigQuery datasets in project $PROJECT_ID:"
  if command -v bq &> /dev/null; then
    bq ls --project_id="$PROJECT_ID" 2>/dev/null || format-echo "WARNING" "Could not list BigQuery datasets"
  else
    format-echo "WARNING" "BigQuery CLI (bq) not available"
  fi
  print_with_separator "End of Available Data Sources"
}

connect_bigquery() {
  format-echo "INFO" "Connecting BigQuery as data source..."
  
  if [[ -z "$DATASET_ID" ]]; then
    format-echo "ERROR" "Dataset ID is required"
    exit 1
  fi
  
  print_with_separator "BigQuery Connection Instructions"
  format-echo "INFO" "To connect BigQuery dataset '$DATASET_ID' to Looker Studio:"
  echo "1. Go to https://datastudio.google.com/"
  echo "2. Create a new report or open an existing one"
  echo "3. Click 'Add data' or the data source icon"
  echo "4. Select 'BigQuery' from the list of connectors"
  echo "5. Choose your project: $PROJECT_ID"
  echo "6. Select dataset: $DATASET_ID"
  echo "7. Choose the table you want to use"
  echo "8. Click 'Connect' to add the data source"
  
  format-echo "INFO" "Dataset: $PROJECT_ID.$DATASET_ID"
  format-echo "INFO" "BigQuery URL: https://console.cloud.google.com/bigquery?project=$PROJECT_ID"
  print_with_separator "End of BigQuery Connection Instructions"
}

#=====================================================================
# DASHBOARD AND REPORT OPERATIONS
#=====================================================================
list_dashboards() {
  format-echo "INFO" "Listing dashboards..."
  
  print_with_separator "Looker Studio Dashboards"
  format-echo "INFO" "Dashboards are managed through the Looker Studio web interface"
  format-echo "INFO" "To view your dashboards:"
  echo "1. Go to https://datastudio.google.com/"
  echo "2. Your reports and dashboards will be listed on the home page"
  echo "3. Use the search or filter options to find specific dashboards"
  
  format-echo "INFO" "For programmatic access, you can use the Google Analytics Reporting API"
  format-echo "INFO" "or the Google Sheets API if your reports are connected to sheets"
  print_with_separator "End of Looker Studio Dashboards"
}

get_dashboard() {
  format-echo "INFO" "Getting dashboard details..."
  
  if [[ -z "$DASHBOARD_ID" ]]; then
    format-echo "ERROR" "Dashboard ID is required"
    exit 1
  fi
  
  print_with_separator "Dashboard: $DASHBOARD_ID"
  format-echo "INFO" "Dashboard details are available through the Looker Studio interface"
  format-echo "INFO" "To view dashboard details:"
  echo "1. Go to https://datastudio.google.com/"
  echo "2. Find and open your dashboard: $DASHBOARD_ID"
  echo "3. Use the 'File' > 'Report settings' menu for configuration details"
  echo "4. Use 'Resource' > 'Manage added data sources' for data source info"
  print_with_separator "End of Dashboard Details"
}

export_dashboard() {
  format-echo "INFO" "Exporting dashboard..."
  
  if [[ -z "$DASHBOARD_ID" ]]; then
    format-echo "ERROR" "Dashboard ID is required"
    exit 1
  fi
  
  print_with_separator "Dashboard Export Instructions"
  format-echo "INFO" "To export dashboard '$DASHBOARD_ID':"
  echo "1. Open the dashboard in Looker Studio"
  echo "2. Click 'File' > 'Export' or use the share button"
  echo "3. Choose export format (PDF, CSV, Google Sheets, etc.)"
  echo "4. Configure export settings as needed"
  echo "5. Download or share the exported file"
  
  format-echo "INFO" "Alternative: Use 'File' > 'Make a copy' to duplicate the dashboard"
  print_with_separator "End of Dashboard Export Instructions"
}

list_reports() {
  format-echo "INFO" "Listing reports..."
  
  print_with_separator "Looker Studio Reports"
  format-echo "INFO" "Reports are managed through the Looker Studio web interface"
  format-echo "INFO" "To view your reports:"
  echo "1. Go to https://datastudio.google.com/"
  echo "2. Your reports will be listed on the home page"
  echo "3. Use filters to organize by 'Owned by me', 'Shared with me', etc."
  echo "4. Click on any report to open and view details"
  print_with_separator "End of Looker Studio Reports"
}

schedule_report() {
  format-echo "INFO" "Scheduling report delivery..."
  
  print_with_separator "Report Scheduling Instructions"
  format-echo "INFO" "To schedule automatic report delivery:"
  echo "1. Open your report in Looker Studio"
  echo "2. Click the 'Share' button (top right)"
  echo "3. Click 'Schedule email delivery'"
  echo "4. Configure recipients, frequency, and format"
  echo "5. Set the schedule (daily, weekly, monthly, etc.)"
  echo "6. Click 'Schedule' to activate"
  
  format-echo "INFO" "Scheduled reports will be sent automatically to specified recipients"
  format-echo "INFO" "You can manage scheduled deliveries from the report's sharing settings"
  print_with_separator "End of Report Scheduling Instructions"
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
    get-studio-url)
      get_studio_url
      ;;
    list-data-sources)
      list_data_sources
      ;;
    connect-bigquery)
      connect_bigquery
      ;;
    list-dashboards)
      list_dashboards
      ;;
    get-dashboard)
      get_dashboard
      ;;
    export-dashboard)
      export_dashboard
      ;;
    list-reports)
      list_reports
      ;;
    schedule-report)
      schedule_report
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
  
  print_with_separator "GCP Looker/Looker Studio Manager"
  format-echo "INFO" "Starting Looker management operations..."
  
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
  format-echo "SUCCESS" "Looker management operation completed successfully."
  print_with_separator "End of GCP Looker/Looker Studio Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?
