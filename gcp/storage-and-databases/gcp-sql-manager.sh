#!/usr/bin/env bash
# gcp-sql-manager.sh
# Script to manage GCP Cloud SQL instances, databases, and users.

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
INSTANCE_NAME=""
DATABASE_NAME=""
USER_NAME=""
PASSWORD=""
DATABASE_VERSION="MYSQL_8_0"
TIER="db-f1-micro"
REGION="us-central1"
ZONE=""
STORAGE_SIZE="10"
STORAGE_TYPE="SSD"
BACKUP_ENABLED=true
BINARY_LOG_ENABLED=false
MAINTENANCE_WINDOW_DAY="7"
MAINTENANCE_WINDOW_HOUR="2"
AUTHORIZED_NETWORKS=""
SSL_MODE="REQUIRED"
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud SQL Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Cloud SQL instances, databases, and users."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-instance\033[0m   Create a new Cloud SQL instance"
  echo -e "  \033[1;33mdelete-instance\033[0m   Delete a Cloud SQL instance"
  echo -e "  \033[1;33mstart-instance\033[0m    Start a Cloud SQL instance"
  echo -e "  \033[1;33mstop-instance\033[0m     Stop a Cloud SQL instance"
  echo -e "  \033[1;33mrestart-instance\033[0m  Restart a Cloud SQL instance"
  echo -e "  \033[1;33mcreate-database\033[0m   Create a database in an instance"
  echo -e "  \033[1;33mdelete-database\033[0m   Delete a database from an instance"
  echo -e "  \033[1;33mcreate-user\033[0m       Create a database user"
  echo -e "  \033[1;33mdelete-user\033[0m       Delete a database user"
  echo -e "  \033[1;33mlist-instances\033[0m    List all Cloud SQL instances"
  echo -e "  \033[1;33mlist-databases\033[0m    List databases in an instance"
  echo -e "  \033[1;33mlist-users\033[0m        List users in an instance"
  echo -e "  \033[1;33minstance-info\033[0m     Show detailed instance information"
  echo -e "  \033[1;33mbackup-instance\033[0m   Create a backup of an instance"
  echo -e "  \033[1;33mlist-backups\033[0m      List backups for an instance"
  echo -e "  \033[1;33mrestore-backup\033[0m    Restore from a backup"
  echo -e "  \033[1;33mupdate-instance\033[0m   Update instance configuration"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--instance <name>\033[0m            (Required for most actions) Instance name"
  echo -e "  \033[1;33m--database <name>\033[0m            (Required for database actions) Database name"
  echo -e "  \033[1;33m--user <name>\033[0m                (Required for user actions) User name"
  echo -e "  \033[1;33m--password <password>\033[0m        (Required for user creation) User password"
  echo -e "  \033[1;33m--version <version>\033[0m          (Optional) Database version (default: MYSQL_8_0)"
  echo -e "  \033[1;33m--tier <tier>\033[0m                (Optional) Machine tier (default: db-f1-micro)"
  echo -e "  \033[1;33m--region <region>\033[0m            (Optional) Region (default: us-central1)"
  echo -e "  \033[1;33m--zone <zone>\033[0m                (Optional) Zone for instance"
  echo -e "  \033[1;33m--storage-size <gb>\033[0m          (Optional) Storage size in GB (default: 10)"
  echo -e "  \033[1;33m--storage-type <type>\033[0m        (Optional) Storage type: SSD, HDD (default: SSD)"
  echo -e "  \033[1;33m--backup-enabled\033[0m             (Optional) Enable automated backups (default: true)"
  echo -e "  \033[1;33m--binary-log-enabled\033[0m         (Optional) Enable binary logging (default: false)"
  echo -e "  \033[1;33m--maintenance-day <day>\033[0m      (Optional) Maintenance window day 1-7 (default: 7)"
  echo -e "  \033[1;33m--maintenance-hour <hour>\033[0m    (Optional) Maintenance window hour 0-23 (default: 2)"
  echo -e "  \033[1;33m--authorized-networks <ips>\033[0m  (Optional) Authorized networks (comma-separated)"
  echo -e "  \033[1;33m--ssl-mode <mode>\033[0m            (Optional) SSL mode: REQUIRED, OPTIONAL (default: REQUIRED)"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-instances --project my-project"
  echo "  $0 create-instance --project my-project --instance my-db --version MYSQL_8_0 --tier db-n1-standard-1"
  echo "  $0 create-database --project my-project --instance my-db --database myapp"
  echo "  $0 create-user --project my-project --instance my-db --user appuser --password 'secure-password'"
  echo "  $0 backup-instance --project my-project --instance my-db"
  echo "  $0 delete-instance --project my-project --instance my-db --force"
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
      --instance)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No instance name provided after --instance."
          usage
        fi
        INSTANCE_NAME="$2"
        shift 2
        ;;
      --database)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No database name provided after --database."
          usage
        fi
        DATABASE_NAME="$2"
        shift 2
        ;;
      --user)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No user name provided after --user."
          usage
        fi
        USER_NAME="$2"
        shift 2
        ;;
      --password)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No password provided after --password."
          usage
        fi
        PASSWORD="$2"
        shift 2
        ;;
      --version)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No database version provided after --version."
          usage
        fi
        DATABASE_VERSION="$2"
        shift 2
        ;;
      --tier)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No tier provided after --tier."
          usage
        fi
        TIER="$2"
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
      --zone)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No zone provided after --zone."
          usage
        fi
        ZONE="$2"
        shift 2
        ;;
      --storage-size)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No storage size provided after --storage-size."
          usage
        fi
        STORAGE_SIZE="$2"
        shift 2
        ;;
      --storage-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No storage type provided after --storage-type."
          usage
        fi
        STORAGE_TYPE="$2"
        shift 2
        ;;
      --backup-enabled)
        BACKUP_ENABLED=true
        shift
        ;;
      --binary-log-enabled)
        BINARY_LOG_ENABLED=true
        shift
        ;;
      --maintenance-day)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No maintenance day provided after --maintenance-day."
          usage
        fi
        MAINTENANCE_WINDOW_DAY="$2"
        shift 2
        ;;
      --maintenance-hour)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No maintenance hour provided after --maintenance-hour."
          usage
        fi
        MAINTENANCE_WINDOW_HOUR="$2"
        shift 2
        ;;
      --authorized-networks)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No authorized networks provided after --authorized-networks."
          usage
        fi
        AUTHORIZED_NETWORKS="$2"
        shift 2
        ;;
      --ssl-mode)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No SSL mode provided after --ssl-mode."
          usage
        fi
        SSL_MODE="$2"
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
# INSTANCE MANAGEMENT FUNCTIONS
#=====================================================================
# Function to create instance
create_instance() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Creating Cloud SQL instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create instance:"
    format-echo "INFO" "  Name: $instance"
    format-echo "INFO" "  Version: $DATABASE_VERSION"
    format-echo "INFO" "  Tier: $TIER"
    format-echo "INFO" "  Region: $REGION"
    [ -n "$ZONE" ] && format-echo "INFO" "  Zone: $ZONE"
    format-echo "INFO" "  Storage: ${STORAGE_SIZE}GB ($STORAGE_TYPE)"
    return 0
  fi
  
  # Build create command
  local create_cmd="gcloud sql instances create $instance"
  create_cmd+=" --project=$project"
  create_cmd+=" --database-version=$DATABASE_VERSION"
  create_cmd+=" --tier=$TIER"
  create_cmd+=" --region=$REGION"
  create_cmd+=" --storage-size=$STORAGE_SIZE"
  create_cmd+=" --storage-type=$STORAGE_TYPE"
  
  if [ -n "$ZONE" ]; then
    create_cmd+=" --gce-zone=$ZONE"
  fi
  
  if [ "$BACKUP_ENABLED" = true ]; then
    create_cmd+=" --backup"
    create_cmd+=" --backup-start-time=03:00"
  fi
  
  if [ "$BINARY_LOG_ENABLED" = true ]; then
    create_cmd+=" --enable-bin-log"
  fi
  
  create_cmd+=" --maintenance-window-day=$MAINTENANCE_WINDOW_DAY"
  create_cmd+=" --maintenance-window-hour=$MAINTENANCE_WINDOW_HOUR"
  
  if [ -n "$AUTHORIZED_NETWORKS" ]; then
    create_cmd+=" --authorized-networks=$AUTHORIZED_NETWORKS"
  fi
  
  create_cmd+=" --require-ssl"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Created Cloud SQL instance: $instance"
  return 0
}

# Function to delete instance
delete_instance() {
  local project="$1"
  local instance="$2"
  
  # Confirmation unless forced
  if [ "$FORCE" = false ]; then
    echo
    format-echo "WARNING" "This will permanently delete Cloud SQL instance: $instance"
    format-echo "WARNING" "All databases and data will be lost!"
    echo
    read -p "Are you sure you want to delete this instance? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      format-echo "INFO" "Instance deletion cancelled"
      return 0
    fi
  fi
  
  format-echo "INFO" "Deleting Cloud SQL instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete instance: $instance"
    return 0
  fi
  
  if ! gcloud sql instances delete "$instance" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Cloud SQL instance: $instance"
  return 0
}

# Function to start instance
start_instance() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Starting Cloud SQL instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would start instance: $instance"
    return 0
  fi
  
  if ! gcloud sql instances patch "$instance" \
    --project="$project" \
    --activation-policy=ALWAYS; then
    format-echo "ERROR" "Failed to start instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Started Cloud SQL instance: $instance"
  return 0
}

# Function to stop instance
stop_instance() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Stopping Cloud SQL instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would stop instance: $instance"
    return 0
  fi
  
  if ! gcloud sql instances patch "$instance" \
    --project="$project" \
    --activation-policy=NEVER; then
    format-echo "ERROR" "Failed to stop instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Stopped Cloud SQL instance: $instance"
  return 0
}

# Function to restart instance
restart_instance() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Restarting Cloud SQL instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would restart instance: $instance"
    return 0
  fi
  
  if ! gcloud sql instances restart "$instance" \
    --project="$project"; then
    format-echo "ERROR" "Failed to restart instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Restarted Cloud SQL instance: $instance"
  return 0
}

# Function to list instances
list_instances() {
  local project="$1"
  
  format-echo "INFO" "Listing Cloud SQL instances in project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list instances"
    return 0
  fi
  
  if ! gcloud sql instances list \
    --project="$project" \
    --format="table(name,databaseVersion,locationId,tier,ipAddresses.ipAddress,state)"; then
    format-echo "ERROR" "Failed to list instances"
    return 1
  fi
  
  return 0
}

# Function to show instance information
show_instance_info() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Getting information for instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would show info for instance: $instance"
    return 0
  fi
  
  if ! gcloud sql instances describe "$instance" \
    --project="$project"; then
    format-echo "ERROR" "Failed to get instance information"
    return 1
  fi
  
  return 0
}

#=====================================================================
# DATABASE MANAGEMENT FUNCTIONS
#=====================================================================
# Function to create database
create_database() {
  local project="$1"
  local instance="$2"
  local database="$3"
  
  format-echo "INFO" "Creating database: $database in instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create database: $database"
    return 0
  fi
  
  if ! gcloud sql databases create "$database" \
    --instance="$instance" \
    --project="$project"; then
    format-echo "ERROR" "Failed to create database: $database"
    return 1
  fi
  
  format-echo "SUCCESS" "Created database: $database"
  return 0
}

# Function to delete database
delete_database() {
  local project="$1"
  local instance="$2"
  local database="$3"
  
  format-echo "INFO" "Deleting database: $database from instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete database: $database"
    return 0
  fi
  
  if ! gcloud sql databases delete "$database" \
    --instance="$instance" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete database: $database"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted database: $database"
  return 0
}

# Function to list databases
list_databases() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Listing databases in instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list databases for instance: $instance"
    return 0
  fi
  
  if ! gcloud sql databases list \
    --instance="$instance" \
    --project="$project" \
    --format="table(name,charset,collation)"; then
    format-echo "ERROR" "Failed to list databases"
    return 1
  fi
  
  return 0
}

#=====================================================================
# USER MANAGEMENT FUNCTIONS
#=====================================================================
# Function to create user
create_user() {
  local project="$1"
  local instance="$2"
  local user="$3"
  local password="$4"
  
  format-echo "INFO" "Creating user: $user in instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create user: $user"
    return 0
  fi
  
  if ! gcloud sql users create "$user" \
    --instance="$instance" \
    --project="$project" \
    --password="$password"; then
    format-echo "ERROR" "Failed to create user: $user"
    return 1
  fi
  
  format-echo "SUCCESS" "Created user: $user"
  return 0
}

# Function to delete user
delete_user() {
  local project="$1"
  local instance="$2"
  local user="$3"
  
  format-echo "INFO" "Deleting user: $user from instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete user: $user"
    return 0
  fi
  
  if ! gcloud sql users delete "$user" \
    --instance="$instance" \
    --project="$project" \
    --quiet; then
    format-echo "ERROR" "Failed to delete user: $user"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted user: $user"
  return 0
}

# Function to list users
list_users() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Listing users in instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list users for instance: $instance"
    return 0
  fi
  
  if ! gcloud sql users list \
    --instance="$instance" \
    --project="$project" \
    --format="table(name,host)"; then
    format-echo "ERROR" "Failed to list users"
    return 1
  fi
  
  return 0
}

#=====================================================================
# BACKUP MANAGEMENT FUNCTIONS
#=====================================================================
# Function to create backup
backup_instance() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Creating backup for instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create backup for instance: $instance"
    return 0
  fi
  
  if ! gcloud sql backups create \
    --instance="$instance" \
    --project="$project"; then
    format-echo "ERROR" "Failed to create backup for instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Created backup for instance: $instance"
  return 0
}

# Function to list backups
list_backups() {
  local project="$1"
  local instance="$2"
  
  format-echo "INFO" "Listing backups for instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list backups for instance: $instance"
    return 0
  fi
  
  if ! gcloud sql backups list \
    --instance="$instance" \
    --project="$project" \
    --format="table(id,windowStartTime,type,status)"; then
    format-echo "ERROR" "Failed to list backups"
    return 1
  fi
  
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
  
  print_with_separator "GCP Cloud SQL Manager Script"
  format-echo "INFO" "Starting GCP Cloud SQL Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Cloud SQL Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Cloud SQL Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Cloud SQL Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-instance|delete-instance|start-instance|stop-instance|restart-instance|instance-info|backup-instance|list-backups|list-databases|list-users|update-instance)
      if [ -z "$INSTANCE_NAME" ]; then
        format-echo "ERROR" "Instance name is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-database|delete-database)
      if [ -z "$INSTANCE_NAME" ] || [ -z "$DATABASE_NAME" ]; then
        format-echo "ERROR" "Instance and database names are required for action: $ACTION"
        exit 1
      fi
      ;;
    create-user|delete-user)
      if [ -z "$INSTANCE_NAME" ] || [ -z "$USER_NAME" ]; then
        format-echo "ERROR" "Instance and user names are required for action: $ACTION"
        exit 1
      fi
      if [[ "$ACTION" == "create-user" && -z "$PASSWORD" ]]; then
        format-echo "ERROR" "Password is required for creating user"
        exit 1
      fi
      ;;
    list-instances)
      # No additional requirements for list actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-instance, delete-instance, start-instance, stop-instance, restart-instance, create-database, delete-database, create-user, delete-user, list-instances, list-databases, list-users, instance-info, backup-instance, list-backups"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-instance)
      if create_instance "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Instance creation completed successfully"
      else
        format-echo "ERROR" "Failed to create instance"
        exit 1
      fi
      ;;
    delete-instance)
      if delete_instance "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Instance deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete instance"
        exit 1
      fi
      ;;
    start-instance)
      if start_instance "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Instance start completed successfully"
      else
        format-echo "ERROR" "Failed to start instance"
        exit 1
      fi
      ;;
    stop-instance)
      if stop_instance "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Instance stop completed successfully"
      else
        format-echo "ERROR" "Failed to stop instance"
        exit 1
      fi
      ;;
    restart-instance)
      if restart_instance "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Instance restart completed successfully"
      else
        format-echo "ERROR" "Failed to restart instance"
        exit 1
      fi
      ;;
    create-database)
      if create_database "$PROJECT_ID" "$INSTANCE_NAME" "$DATABASE_NAME"; then
        format-echo "SUCCESS" "Database creation completed successfully"
      else
        format-echo "ERROR" "Failed to create database"
        exit 1
      fi
      ;;
    delete-database)
      if delete_database "$PROJECT_ID" "$INSTANCE_NAME" "$DATABASE_NAME"; then
        format-echo "SUCCESS" "Database deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete database"
        exit 1
      fi
      ;;
    create-user)
      if create_user "$PROJECT_ID" "$INSTANCE_NAME" "$USER_NAME" "$PASSWORD"; then
        format-echo "SUCCESS" "User creation completed successfully"
      else
        format-echo "ERROR" "Failed to create user"
        exit 1
      fi
      ;;
    delete-user)
      if delete_user "$PROJECT_ID" "$INSTANCE_NAME" "$USER_NAME"; then
        format-echo "SUCCESS" "User deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete user"
        exit 1
      fi
      ;;
    list-instances)
      if list_instances "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed instances successfully"
      else
        format-echo "ERROR" "Failed to list instances"
        exit 1
      fi
      ;;
    list-databases)
      if list_databases "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Listed databases successfully"
      else
        format-echo "ERROR" "Failed to list databases"
        exit 1
      fi
      ;;
    list-users)
      if list_users "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Listed users successfully"
      else
        format-echo "ERROR" "Failed to list users"
        exit 1
      fi
      ;;
    instance-info)
      if show_instance_info "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Retrieved instance information successfully"
      else
        format-echo "ERROR" "Failed to get instance information"
        exit 1
      fi
      ;;
    backup-instance)
      if backup_instance "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Backup creation completed successfully"
      else
        format-echo "ERROR" "Failed to create backup"
        exit 1
      fi
      ;;
    list-backups)
      if list_backups "$PROJECT_ID" "$INSTANCE_NAME"; then
        format-echo "SUCCESS" "Listed backups successfully"
      else
        format-echo "ERROR" "Failed to list backups"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Cloud SQL Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
