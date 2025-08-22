#!/usr/bin/env bash
# gcp-compute-manager.sh
# Script to manage GCP Compute Engine instances - create, delete, start, stop, and monitor instances.

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
ZONE="us-central1-a"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
BOOT_DISK_SIZE="20GB"
BOOT_DISK_TYPE="pd-standard"
NETWORK="default"
SUBNET=""
TAGS=""
LABELS=""
METADATA=""
STARTUP_SCRIPT=""
PREEMPTIBLE=false
SPOT=false
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Compute Engine Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Compute Engine instances - create, delete, start, stop, and monitor."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate\033[0m         Create a new instance"
  echo -e "  \033[1;33mdelete\033[0m         Delete an existing instance"
  echo -e "  \033[1;33mstart\033[0m          Start a stopped instance"
  echo -e "  \033[1;33mstop\033[0m           Stop a running instance"
  echo -e "  \033[1;33mrestart\033[0m        Restart an instance"
  echo -e "  \033[1;33mlist\033[0m           List all instances in project/zone"
  echo -e "  \033[1;33minfo\033[0m           Show detailed instance information"
  echo -e "  \033[1;33mssh\033[0m            SSH into an instance"
  echo -e "  \033[1;33mlogs\033[0m           View instance serial console logs"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--instance <name>\033[0m            (Required for most actions) Instance name"
  echo -e "  \033[1;33m--zone <zone>\033[0m                (Optional) Zone (default: us-central1-a)"
  echo -e "  \033[1;33m--machine-type <type>\033[0m        (Optional) Machine type (default: e2-medium)"
  echo -e "  \033[1;33m--image-family <family>\033[0m      (Optional) Image family (default: ubuntu-2004-lts)"
  echo -e "  \033[1;33m--image-project <project>\033[0m    (Optional) Image project (default: ubuntu-os-cloud)"
  echo -e "  \033[1;33m--boot-disk-size <size>\033[0m      (Optional) Boot disk size (default: 20GB)"
  echo -e "  \033[1;33m--boot-disk-type <type>\033[0m      (Optional) Boot disk type (default: pd-standard)"
  echo -e "  \033[1;33m--network <network>\033[0m          (Optional) Network (default: default)"
  echo -e "  \033[1;33m--subnet <subnet>\033[0m            (Optional) Subnet"
  echo -e "  \033[1;33m--tags <tag1,tag2,...>\033[0m       (Optional) Network tags"
  echo -e "  \033[1;33m--labels <key=value,...>\033[0m     (Optional) Instance labels"
  echo -e "  \033[1;33m--metadata <key=value,...>\033[0m   (Optional) Instance metadata"
  echo -e "  \033[1;33m--startup-script <file>\033[0m      (Optional) Startup script file"
  echo -e "  \033[1;33m--preemptible\033[0m                (Optional) Create preemptible instance"
  echo -e "  \033[1;33m--spot\033[0m                       (Optional) Create spot instance"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force action without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mCommon Machine Types:\033[0m"
  echo "  e2-micro, e2-small, e2-medium, e2-standard-2, e2-standard-4"
  echo "  n1-standard-1, n1-standard-2, n1-standard-4"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list --project my-project --zone us-central1-a"
  echo "  $0 create --project my-project --instance web-server --machine-type e2-standard-2"
  echo "  $0 info --project my-project --instance web-server --zone us-central1-a"
  echo "  $0 ssh --project my-project --instance web-server --zone us-central1-a"
  echo "  $0 delete --project my-project --instance web-server --zone us-central1-a --force"
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
      --zone)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No zone provided after --zone."
          usage
        fi
        ZONE="$2"
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
      --image-family)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No image family provided after --image-family."
          usage
        fi
        IMAGE_FAMILY="$2"
        shift 2
        ;;
      --image-project)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No image project provided after --image-project."
          usage
        fi
        IMAGE_PROJECT="$2"
        shift 2
        ;;
      --boot-disk-size)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No boot disk size provided after --boot-disk-size."
          usage
        fi
        BOOT_DISK_SIZE="$2"
        shift 2
        ;;
      --boot-disk-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No boot disk type provided after --boot-disk-type."
          usage
        fi
        BOOT_DISK_TYPE="$2"
        shift 2
        ;;
      --network)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No network provided after --network."
          usage
        fi
        NETWORK="$2"
        shift 2
        ;;
      --subnet)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No subnet provided after --subnet."
          usage
        fi
        SUBNET="$2"
        shift 2
        ;;
      --tags)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No tags provided after --tags."
          usage
        fi
        TAGS="$2"
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
      --metadata)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No metadata provided after --metadata."
          usage
        fi
        METADATA="$2"
        shift 2
        ;;
      --startup-script)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No startup script file provided after --startup-script."
          usage
        fi
        STARTUP_SCRIPT="$2"
        shift 2
        ;;
      --preemptible)
        PREEMPTIBLE=true
        shift
        ;;
      --spot)
        SPOT=true
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

#=====================================================================
# ACTION FUNCTIONS
#=====================================================================
# Function to list instances
list_instances() {
  local project="$1"
  local zone="$2"
  
  format-echo "INFO" "Listing instances in project: $project, zone: $zone"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list instances in $project/$zone"
    return 0
  fi
  
  if ! gcloud compute instances list --project="$project" --zones="$zone" \
    --format="table(name,status,machineType.basename(),internalIP,externalIP)"; then
    format-echo "ERROR" "Failed to list instances"
    return 1
  fi
  
  return 0
}

# Function to show instance information
show_instance_info() {
  local project="$1"
  local instance="$2"
  local zone="$3"
  
  format-echo "INFO" "Getting information for instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would show info for instance: $instance"
    return 0
  fi
  
  if ! gcloud compute instances describe "$instance" --project="$project" --zone="$zone"; then
    format-echo "ERROR" "Failed to get instance information"
    return 1
  fi
  
  return 0
}

# Function to create instance
create_instance() {
  local project="$1"
  local instance="$2"
  local zone="$3"
  
  format-echo "INFO" "Creating instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create instance:"
    format-echo "INFO" "  Name: $instance"
    format-echo "INFO" "  Project: $project"
    format-echo "INFO" "  Zone: $zone"
    format-echo "INFO" "  Machine Type: $MACHINE_TYPE"
    format-echo "INFO" "  Image: $IMAGE_PROJECT/$IMAGE_FAMILY"
    format-echo "INFO" "  Boot Disk: $BOOT_DISK_SIZE ($BOOT_DISK_TYPE)"
    format-echo "INFO" "  Network: $NETWORK"
    [ -n "$SUBNET" ] && format-echo "INFO" "  Subnet: $SUBNET"
    [ -n "$TAGS" ] && format-echo "INFO" "  Tags: $TAGS"
    [ -n "$LABELS" ] && format-echo "INFO" "  Labels: $LABELS"
    [ "$PREEMPTIBLE" = true ] && format-echo "INFO" "  Preemptible: true"
    [ "$SPOT" = true ] && format-echo "INFO" "  Spot: true"
    return 0
  fi
  
  # Build create command
  local create_cmd="gcloud compute instances create $instance"
  create_cmd+=" --project=$project"
  create_cmd+=" --zone=$zone"
  create_cmd+=" --machine-type=$MACHINE_TYPE"
  create_cmd+=" --image-family=$IMAGE_FAMILY"
  create_cmd+=" --image-project=$IMAGE_PROJECT"
  create_cmd+=" --boot-disk-size=$BOOT_DISK_SIZE"
  create_cmd+=" --boot-disk-type=$BOOT_DISK_TYPE"
  create_cmd+=" --network=$NETWORK"
  
  if [ -n "$SUBNET" ]; then
    create_cmd+=" --subnet=$SUBNET"
  fi
  
  if [ -n "$TAGS" ]; then
    create_cmd+=" --tags=$TAGS"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --labels=$LABELS"
  fi
  
  if [ -n "$METADATA" ]; then
    create_cmd+=" --metadata=$METADATA"
  fi
  
  if [ -n "$STARTUP_SCRIPT" ]; then
    if [ ! -f "$STARTUP_SCRIPT" ]; then
      format-echo "ERROR" "Startup script file not found: $STARTUP_SCRIPT"
      return 1
    fi
    create_cmd+=" --metadata-from-file=startup-script=$STARTUP_SCRIPT"
  fi
  
  if [ "$PREEMPTIBLE" = true ]; then
    create_cmd+=" --preemptible"
  fi
  
  if [ "$SPOT" = true ]; then
    create_cmd+=" --provisioning-model=SPOT"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Created instance: $instance"
  return 0
}

# Function to delete instance
delete_instance() {
  local project="$1"
  local instance="$2"
  local zone="$3"
  
  # Confirmation unless forced
  if [ "$FORCE" = false ]; then
    echo
    format-echo "WARNING" "This will permanently delete instance: $instance"
    format-echo "WARNING" "All data on the instance will be lost!"
    echo
    read -p "Are you sure you want to delete this instance? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
      format-echo "INFO" "Instance deletion cancelled"
      return 0
    fi
  fi
  
  format-echo "INFO" "Deleting instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete instance: $instance"
    return 0
  fi
  
  if ! gcloud compute instances delete "$instance" --project="$project" --zone="$zone" --quiet; then
    format-echo "ERROR" "Failed to delete instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted instance: $instance"
  return 0
}

# Function to start instance
start_instance() {
  local project="$1"
  local instance="$2"
  local zone="$3"
  
  format-echo "INFO" "Starting instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would start instance: $instance"
    return 0
  fi
  
  if ! gcloud compute instances start "$instance" --project="$project" --zone="$zone"; then
    format-echo "ERROR" "Failed to start instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Started instance: $instance"
  return 0
}

# Function to stop instance
stop_instance() {
  local project="$1"
  local instance="$2"
  local zone="$3"
  
  format-echo "INFO" "Stopping instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would stop instance: $instance"
    return 0
  fi
  
  if ! gcloud compute instances stop "$instance" --project="$project" --zone="$zone"; then
    format-echo "ERROR" "Failed to stop instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Stopped instance: $instance"
  return 0
}

# Function to restart instance
restart_instance() {
  local project="$1"
  local instance="$2"
  local zone="$3"
  
  format-echo "INFO" "Restarting instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would restart instance: $instance"
    return 0
  fi
  
  if ! gcloud compute instances reset "$instance" --project="$project" --zone="$zone"; then
    format-echo "ERROR" "Failed to restart instance: $instance"
    return 1
  fi
  
  format-echo "SUCCESS" "Restarted instance: $instance"
  return 0
}

# Function to SSH into instance
ssh_instance() {
  local project="$1"
  local instance="$2"
  local zone="$3"
  
  format-echo "INFO" "Connecting to instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would SSH to instance: $instance"
    return 0
  fi
  
  if ! gcloud compute ssh "$instance" --project="$project" --zone="$zone"; then
    format-echo "ERROR" "Failed to connect to instance: $instance"
    return 1
  fi
  
  return 0
}

# Function to view instance logs
view_logs() {
  local project="$1"
  local instance="$2"
  local zone="$3"
  
  format-echo "INFO" "Viewing logs for instance: $instance"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would view logs for instance: $instance"
    return 0
  fi
  
  if ! gcloud compute instances get-serial-port-output "$instance" --project="$project" --zone="$zone"; then
    format-echo "ERROR" "Failed to get logs for instance: $instance"
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
  
  print_with_separator "GCP Compute Engine Manager Script"
  format-echo "INFO" "Starting GCP Compute Engine Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Compute Engine Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Compute Engine Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Compute Engine Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create|delete|start|stop|restart|info|ssh|logs)
      if [ -z "$INSTANCE_NAME" ]; then
        format-echo "ERROR" "Instance name is required for action: $ACTION"
        print_with_separator "End of GCP Compute Engine Manager Script"
        exit 1
      fi
      ;;
    list)
      # No instance name required for list
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create, delete, start, stop, restart, list, info, ssh, logs"
      print_with_separator "End of GCP Compute Engine Manager Script"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    list)
      if list_instances "$PROJECT_ID" "$ZONE"; then
        format-echo "SUCCESS" "Listed instances successfully"
      else
        format-echo "ERROR" "Failed to list instances"
        exit 1
      fi
      ;;
    info)
      if show_instance_info "$PROJECT_ID" "$INSTANCE_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Retrieved instance information successfully"
      else
        format-echo "ERROR" "Failed to get instance information"
        exit 1
      fi
      ;;
    create)
      if create_instance "$PROJECT_ID" "$INSTANCE_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Instance management completed successfully"
      else
        format-echo "ERROR" "Failed to create instance"
        exit 1
      fi
      ;;
    delete)
      if delete_instance "$PROJECT_ID" "$INSTANCE_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Instance management completed successfully"
      else
        format-echo "ERROR" "Failed to delete instance"
        exit 1
      fi
      ;;
    start)
      if start_instance "$PROJECT_ID" "$INSTANCE_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Instance started successfully"
      else
        format-echo "ERROR" "Failed to start instance"
        exit 1
      fi
      ;;
    stop)
      if stop_instance "$PROJECT_ID" "$INSTANCE_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Instance stopped successfully"
      else
        format-echo "ERROR" "Failed to stop instance"
        exit 1
      fi
      ;;
    restart)
      if restart_instance "$PROJECT_ID" "$INSTANCE_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Instance restarted successfully"
      else
        format-echo "ERROR" "Failed to restart instance"
        exit 1
      fi
      ;;
    ssh)
      ssh_instance "$PROJECT_ID" "$INSTANCE_NAME" "$ZONE"
      ;;
    logs)
      if view_logs "$PROJECT_ID" "$INSTANCE_NAME" "$ZONE"; then
        format-echo "SUCCESS" "Retrieved instance logs successfully"
      else
        format-echo "ERROR" "Failed to get instance logs"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Compute Engine Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
