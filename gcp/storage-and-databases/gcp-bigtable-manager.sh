#!/usr/bin/env bash
# gcp-bigtable-manager.sh
# Script to manage Google Cloud Bigtable resources

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
CLUSTER_ID=""
TABLE_ID=""
BACKUP_ID=""
ZONE=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Bigtable Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Bigtable (NoSQL wide-column database) resources."
  echo "  Provides comprehensive management capabilities for Bigtable instances, clusters, and tables."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-i, --instance INSTANCE_ID\033[0m  Set Bigtable instance ID"
  echo -e "  \033[1;33m-c, --cluster CLUSTER_ID\033[0m    Set cluster ID"
  echo -e "  \033[1;33m-t, --table TABLE_ID\033[0m        Set table ID"
  echo -e "  \033[1;33m-b, --backup BACKUP_ID\033[0m      Set backup ID"
  echo -e "  \033[1;33m-z, --zone ZONE\033[0m             Set zone for cluster"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate-instance\033[0m             Create new Bigtable instance"
  echo -e "  \033[1;36mlist-instances\033[0m              List Bigtable instances"
  echo -e "  \033[1;36mget-instance\033[0m                Get instance details"
  echo -e "  \033[1;36mupdate-instance\033[0m             Update instance configuration"
  echo -e "  \033[1;36mdelete-instance\033[0m             Delete Bigtable instance"
  echo -e "  \033[1;36mcreate-cluster\033[0m              Create new cluster"
  echo -e "  \033[1;36mlist-clusters\033[0m               List clusters in instance"
  echo -e "  \033[1;36mget-cluster\033[0m                 Get cluster details"
  echo -e "  \033[1;36mupdate-cluster\033[0m              Update cluster configuration"
  echo -e "  \033[1;36mdelete-cluster\033[0m              Delete cluster"
  echo -e "  \033[1;36mcreate-table\033[0m                Create new table"
  echo -e "  \033[1;36mlist-tables\033[0m                 List tables in instance"
  echo -e "  \033[1;36mget-table\033[0m                   Get table details"
  echo -e "  \033[1;36mdelete-table\033[0m                Delete table"
  echo -e "  \033[1;36mcreate-backup\033[0m               Create table backup"
  echo -e "  \033[1;36mlist-backups\033[0m                List backups"
  echo -e "  \033[1;36mrestore-backup\033[0m              Restore table from backup"
  echo -e "  \033[1;36mdelete-backup\033[0m               Delete backup"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project list-instances"
  echo "  $0 --project my-project --instance my-instance create-instance"
  echo "  $0 -p my-project -i my-instance -c my-cluster -z us-central1-a create-cluster"
  echo "  $0 -p my-project -i my-instance -t my-table create-table"
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
      -c|--cluster)
        if [[ -n "${2:-}" ]]; then
          CLUSTER_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --cluster"
          usage
        fi
        ;;
      -t|--table)
        if [[ -n "${2:-}" ]]; then
          TABLE_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --table"
          usage
        fi
        ;;
      -b|--backup)
        if [[ -n "${2:-}" ]]; then
          BACKUP_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --backup"
          usage
        fi
        ;;
      -z|--zone)
        if [[ -n "${2:-}" ]]; then
          ZONE="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --zone"
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
    "bigtable.googleapis.com"
    "bigtableadmin.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# BIGTABLE INSTANCE OPERATIONS
#=====================================================================
create_instance() {
  format-echo "INFO" "Creating Bigtable instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required for create operation"
    exit 1
  fi
  
  gcloud bigtable instances create "$INSTANCE_ID" \
    --display-name="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Bigtable instance created successfully"
}

list_instances() {
  format-echo "INFO" "Listing Bigtable instances..."
  
  print_with_separator "Bigtable Instances"
  gcloud bigtable instances list --project="$PROJECT_ID"
  print_with_separator "End of Bigtable Instances"
}

get_instance() {
  format-echo "INFO" "Getting Bigtable instance details..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  print_with_separator "Bigtable Instance: $INSTANCE_ID"
  gcloud bigtable instances describe "$INSTANCE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Bigtable Instance Details"
}

update_instance() {
  format-echo "INFO" "Updating Bigtable instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  gcloud bigtable instances update "$INSTANCE_ID" \
    --display-name="$INSTANCE_ID-updated" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Bigtable instance updated successfully"
}

delete_instance() {
  format-echo "INFO" "Deleting Bigtable instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the instance and all its data"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud bigtable instances delete "$INSTANCE_ID" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Bigtable instance deleted successfully"
}

#=====================================================================
# BIGTABLE CLUSTER OPERATIONS
#=====================================================================
create_cluster() {
  format-echo "INFO" "Creating Bigtable cluster..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$CLUSTER_ID" ]]; then
    format-echo "ERROR" "Instance ID and Cluster ID are required"
    exit 1
  fi
  
  if [[ -z "$ZONE" ]]; then
    ZONE="us-central1-a"
    format-echo "INFO" "Using default zone: $ZONE"
  fi
  
  gcloud bigtable clusters create "$CLUSTER_ID" \
    --instance="$INSTANCE_ID" \
    --zone="$ZONE" \
    --num-nodes=1 \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Bigtable cluster created successfully"
}

list_clusters() {
  format-echo "INFO" "Listing Bigtable clusters..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  print_with_separator "Bigtable Clusters in $INSTANCE_ID"
  gcloud bigtable clusters list --instances="$INSTANCE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Bigtable Clusters"
}

get_cluster() {
  format-echo "INFO" "Getting Bigtable cluster details..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$CLUSTER_ID" ]]; then
    format-echo "ERROR" "Instance ID and Cluster ID are required"
    exit 1
  fi
  
  print_with_separator "Bigtable Cluster: $CLUSTER_ID"
  gcloud bigtable clusters describe "$CLUSTER_ID" \
    --instance="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  print_with_separator "End of Bigtable Cluster Details"
}

update_cluster() {
  format-echo "INFO" "Updating Bigtable cluster..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$CLUSTER_ID" ]]; then
    format-echo "ERROR" "Instance ID and Cluster ID are required"
    exit 1
  fi
  
  gcloud bigtable clusters update "$CLUSTER_ID" \
    --instance="$INSTANCE_ID" \
    --num-nodes=2 \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Bigtable cluster updated successfully"
}

delete_cluster() {
  format-echo "INFO" "Deleting Bigtable cluster..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$CLUSTER_ID" ]]; then
    format-echo "ERROR" "Instance ID and Cluster ID are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the cluster"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud bigtable clusters delete "$CLUSTER_ID" \
    --instance="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Bigtable cluster deleted successfully"
}

#=====================================================================
# BIGTABLE TABLE OPERATIONS
#=====================================================================
create_table() {
  format-echo "INFO" "Creating Bigtable table..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$TABLE_ID" ]]; then
    format-echo "ERROR" "Instance ID and Table ID are required"
    exit 1
  fi
  
  # Check if cbt command is available
  if ! command -v cbt &> /dev/null; then
    format-echo "ERROR" "cbt command not found. Please install Cloud Bigtable CLI tool"
    format-echo "INFO" "Install with: gcloud components install cbt"
    exit 1
  fi
  
  cbt -project="$PROJECT_ID" -instance="$INSTANCE_ID" createtable "$TABLE_ID"
  cbt -project="$PROJECT_ID" -instance="$INSTANCE_ID" createfamily "$TABLE_ID" cf1
  
  format-echo "SUCCESS" "Bigtable table created successfully"
}

list_tables() {
  format-echo "INFO" "Listing Bigtable tables..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  # Check if cbt command is available
  if ! command -v cbt &> /dev/null; then
    format-echo "ERROR" "cbt command not found. Please install Cloud Bigtable CLI tool"
    format-echo "INFO" "Install with: gcloud components install cbt"
    exit 1
  fi
  
  print_with_separator "Bigtable Tables in $INSTANCE_ID"
  cbt -project="$PROJECT_ID" -instance="$INSTANCE_ID" ls
  print_with_separator "End of Bigtable Tables"
}

get_table() {
  format-echo "INFO" "Getting Bigtable table details..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$TABLE_ID" ]]; then
    format-echo "ERROR" "Instance ID and Table ID are required"
    exit 1
  fi
  
  # Check if cbt command is available
  if ! command -v cbt &> /dev/null; then
    format-echo "ERROR" "cbt command not found. Please install Cloud Bigtable CLI tool"
    format-echo "INFO" "Install with: gcloud components install cbt"
    exit 1
  fi
  
  print_with_separator "Bigtable Table: $TABLE_ID"
  cbt -project="$PROJECT_ID" -instance="$INSTANCE_ID" ls "$TABLE_ID"
  print_with_separator "End of Bigtable Table Details"
}

delete_table() {
  format-echo "INFO" "Deleting Bigtable table..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$TABLE_ID" ]]; then
    format-echo "ERROR" "Instance ID and Table ID are required"
    exit 1
  fi
  
  # Check if cbt command is available
  if ! command -v cbt &> /dev/null; then
    format-echo "ERROR" "cbt command not found. Please install Cloud Bigtable CLI tool"
    format-echo "INFO" "Install with: gcloud components install cbt"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the table and all its data"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  cbt -project="$PROJECT_ID" -instance="$INSTANCE_ID" deletetable "$TABLE_ID"
  format-echo "SUCCESS" "Bigtable table deleted successfully"
}

#=====================================================================
# BIGTABLE BACKUP OPERATIONS
#=====================================================================
create_backup() {
  format-echo "INFO" "Creating Bigtable table backup..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$CLUSTER_ID" ]] || [[ -z "$TABLE_ID" ]] || [[ -z "$BACKUP_ID" ]]; then
    format-echo "ERROR" "Instance ID, Cluster ID, Table ID, and Backup ID are required"
    exit 1
  fi
  
  local expire_time=$(date -d "+30 days" -Iseconds)
  
  gcloud bigtable backups create "$BACKUP_ID" \
    --source-table="$TABLE_ID" \
    --source-instance="$INSTANCE_ID" \
    --cluster="$CLUSTER_ID" \
    --expire-time="$expire_time" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Bigtable backup created successfully"
}

list_backups() {
  format-echo "INFO" "Listing Bigtable backups..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$CLUSTER_ID" ]]; then
    format-echo "ERROR" "Instance ID and Cluster ID are required"
    exit 1
  fi
  
  print_with_separator "Bigtable Backups in $CLUSTER_ID"
  gcloud bigtable backups list \
    --instance="$INSTANCE_ID" \
    --cluster="$CLUSTER_ID" \
    --project="$PROJECT_ID"
  print_with_separator "End of Bigtable Backups"
}

restore_backup() {
  format-echo "INFO" "Restoring Bigtable table from backup..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$CLUSTER_ID" ]] || [[ -z "$TABLE_ID" ]] || [[ -z "$BACKUP_ID" ]]; then
    format-echo "ERROR" "Instance ID, Cluster ID, Table ID, and Backup ID are required"
    exit 1
  fi
  
  local new_table_id="${TABLE_ID}-restored-$(date +%Y%m%d%H%M%S)"
  
  gcloud bigtable backups restore "$BACKUP_ID" \
    --source-instance="$INSTANCE_ID" \
    --source-cluster="$CLUSTER_ID" \
    --destination-table="$new_table_id" \
    --destination-instance="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Table restored as $new_table_id"
}

delete_backup() {
  format-echo "INFO" "Deleting Bigtable backup..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$CLUSTER_ID" ]] || [[ -z "$BACKUP_ID" ]]; then
    format-echo "ERROR" "Instance ID, Cluster ID, and Backup ID are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the backup"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud bigtable backups delete "$BACKUP_ID" \
    --instance="$INSTANCE_ID" \
    --cluster="$CLUSTER_ID" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Bigtable backup deleted successfully"
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
    create-cluster)
      create_cluster
      ;;
    list-clusters)
      list_clusters
      ;;
    get-cluster)
      get_cluster
      ;;
    update-cluster)
      update_cluster
      ;;
    delete-cluster)
      delete_cluster
      ;;
    create-table)
      create_table
      ;;
    list-tables)
      list_tables
      ;;
    get-table)
      get_table
      ;;
    delete-table)
      delete_table
      ;;
    create-backup)
      create_backup
      ;;
    list-backups)
      list_backups
      ;;
    restore-backup)
      restore_backup
      ;;
    delete-backup)
      delete_backup
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
  
  print_with_separator "GCP Cloud Bigtable Manager"
  format-echo "INFO" "Starting Bigtable management operations..."
  
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
  format-echo "SUCCESS" "Bigtable management operation completed successfully."
  print_with_separator "End of GCP Cloud Bigtable Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?