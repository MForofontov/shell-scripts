#!/usr/bin/env bash
# gcp-spanner-manager.sh
# Script to manage Google Cloud Spanner resources

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
DATABASE_ID=""
BACKUP_ID=""
CONFIG_ID=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Spanner Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Spanner (globally distributed database) resources."
  echo "  Provides comprehensive management capabilities for Spanner instances and databases."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-i, --instance INSTANCE_ID\033[0m  Set Spanner instance ID"
  echo -e "  \033[1;33m-d, --database DATABASE_ID\033[0m  Set Spanner database ID"
  echo -e "  \033[1;33m-b, --backup BACKUP_ID\033[0m      Set backup ID"
  echo -e "  \033[1;33m-c, --config CONFIG_ID\033[0m      Set instance configuration"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mlist-configs\033[0m                List available instance configurations"
  echo -e "  \033[1;36mcreate-instance\033[0m             Create new Spanner instance"
  echo -e "  \033[1;36mlist-instances\033[0m              List Spanner instances"
  echo -e "  \033[1;36mget-instance\033[0m                Get instance details"
  echo -e "  \033[1;36mupdate-instance\033[0m             Update instance configuration"
  echo -e "  \033[1;36mdelete-instance\033[0m             Delete Spanner instance"
  echo -e "  \033[1;36mcreate-database\033[0m             Create new database"
  echo -e "  \033[1;36mlist-databases\033[0m              List databases in instance"
  echo -e "  \033[1;36mget-database\033[0m                Get database details"
  echo -e "  \033[1;36mdelete-database\033[0m             Delete database"
  echo -e "  \033[1;36mcreate-backup\033[0m               Create database backup"
  echo -e "  \033[1;36mlist-backups\033[0m                List backups"
  echo -e "  \033[1;36mrestore-backup\033[0m              Restore database from backup"
  echo -e "  \033[1;36mdelete-backup\033[0m               Delete backup"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project list-configs"
  echo "  $0 --project my-project --instance my-instance create-instance"
  echo "  $0 -p my-project -i my-instance -d my-db create-database"
  echo "  $0 -p my-project -i my-instance -d my-db -b backup1 create-backup"
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
      -d|--database)
        if [[ -n "${2:-}" ]]; then
          DATABASE_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --database"
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
      -c|--config)
        if [[ -n "${2:-}" ]]; then
          CONFIG_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --config"
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
    "spanner.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# SPANNER INSTANCE OPERATIONS
#=====================================================================
list_configs() {
  format-echo "INFO" "Listing Spanner instance configurations..."
  
  print_with_separator "Spanner Instance Configurations"
  gcloud spanner instance-configs list --project="$PROJECT_ID"
  print_with_separator "End of Spanner Instance Configurations"
}

create_instance() {
  format-echo "INFO" "Creating Spanner instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required for create operation"
    exit 1
  fi
  
  if [[ -z "$CONFIG_ID" ]]; then
    CONFIG_ID="regional-us-central1"
    format-echo "INFO" "Using default config: $CONFIG_ID"
  fi
  
  gcloud spanner instances create "$INSTANCE_ID" \
    --config="$CONFIG_ID" \
    --description="Spanner instance created by script" \
    --nodes=1 \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Spanner instance created successfully"
}

list_instances() {
  format-echo "INFO" "Listing Spanner instances..."
  
  print_with_separator "Spanner Instances"
  gcloud spanner instances list --project="$PROJECT_ID"
  print_with_separator "End of Spanner Instances"
}

get_instance() {
  format-echo "INFO" "Getting Spanner instance details..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  print_with_separator "Spanner Instance: $INSTANCE_ID"
  gcloud spanner instances describe "$INSTANCE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Spanner Instance Details"
}

update_instance() {
  format-echo "INFO" "Updating Spanner instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  gcloud spanner instances update "$INSTANCE_ID" \
    --nodes=2 \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Spanner instance updated successfully"
}

delete_instance() {
  format-echo "INFO" "Deleting Spanner instance..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the instance and all its databases"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud spanner instances delete "$INSTANCE_ID" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Spanner instance deleted successfully"
}

#=====================================================================
# SPANNER DATABASE OPERATIONS
#=====================================================================
create_database() {
  format-echo "INFO" "Creating Spanner database..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$DATABASE_ID" ]]; then
    format-echo "ERROR" "Instance ID and Database ID are required"
    exit 1
  fi
  
  gcloud spanner databases create "$DATABASE_ID" \
    --instance="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Spanner database created successfully"
}

list_databases() {
  format-echo "INFO" "Listing Spanner databases..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  print_with_separator "Spanner Databases in $INSTANCE_ID"
  gcloud spanner databases list --instance="$INSTANCE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Spanner Databases"
}

get_database() {
  format-echo "INFO" "Getting Spanner database details..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$DATABASE_ID" ]]; then
    format-echo "ERROR" "Instance ID and Database ID are required"
    exit 1
  fi
  
  print_with_separator "Spanner Database: $DATABASE_ID"
  gcloud spanner databases describe "$DATABASE_ID" \
    --instance="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  print_with_separator "End of Spanner Database Details"
}

delete_database() {
  format-echo "INFO" "Deleting Spanner database..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$DATABASE_ID" ]]; then
    format-echo "ERROR" "Instance ID and Database ID are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the database and all its data"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud spanner databases delete "$DATABASE_ID" \
    --instance="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Spanner database deleted successfully"
}

#=====================================================================
# SPANNER BACKUP OPERATIONS
#=====================================================================
create_backup() {
  format-echo "INFO" "Creating Spanner database backup..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$DATABASE_ID" ]] || [[ -z "$BACKUP_ID" ]]; then
    format-echo "ERROR" "Instance ID, Database ID, and Backup ID are required"
    exit 1
  fi
  
  local expire_time=$(date -d "+30 days" -Iseconds)
  
  gcloud spanner backups create "$BACKUP_ID" \
    --database="$DATABASE_ID" \
    --instance="$INSTANCE_ID" \
    --expire-time="$expire_time" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Spanner backup created successfully"
}

list_backups() {
  format-echo "INFO" "Listing Spanner backups..."
  
  if [[ -z "$INSTANCE_ID" ]]; then
    format-echo "ERROR" "Instance ID is required"
    exit 1
  fi
  
  print_with_separator "Spanner Backups in $INSTANCE_ID"
  gcloud spanner backups list --instance="$INSTANCE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Spanner Backups"
}

restore_backup() {
  format-echo "INFO" "Restoring Spanner database from backup..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$DATABASE_ID" ]] || [[ -z "$BACKUP_ID" ]]; then
    format-echo "ERROR" "Instance ID, Database ID, and Backup ID are required"
    exit 1
  fi
  
  local new_db_id="${DATABASE_ID}-restored-$(date +%Y%m%d%H%M%S)"
  
  gcloud spanner databases restore "$new_db_id" \
    --source-backup="$BACKUP_ID" \
    --source-instance="$INSTANCE_ID" \
    --target-instance="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Database restored as $new_db_id"
}

delete_backup() {
  format-echo "INFO" "Deleting Spanner backup..."
  
  if [[ -z "$INSTANCE_ID" ]] || [[ -z "$BACKUP_ID" ]]; then
    format-echo "ERROR" "Instance ID and Backup ID are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the backup"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud spanner backups delete "$BACKUP_ID" \
    --instance="$INSTANCE_ID" \
    --project="$PROJECT_ID"
  
  format-echo "SUCCESS" "Spanner backup deleted successfully"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    list-configs)
      list_configs
      ;;
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
    create-database)
      create_database
      ;;
    list-databases)
      list_databases
      ;;
    get-database)
      get_database
      ;;
    delete-database)
      delete_database
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
  
  print_with_separator "GCP Cloud Spanner Manager"
  format-echo "INFO" "Starting Spanner management operations..."
  
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
  format-echo "SUCCESS" "Spanner management operation completed successfully."
  print_with_separator "End of GCP Cloud Spanner Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?