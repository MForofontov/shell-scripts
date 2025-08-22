#!/usr/bin/env bash
# gcp-dataproc-manager.sh
# Script to manage GCP Dataproc clusters, jobs, and big data processing workflows.

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
CLUSTER_NAME=""
JOB_NAME=""
JOB_ID=""
REGION="us-central1"
ZONE="us-central1-a"
SUBNET=""
NETWORK=""
MACHINE_TYPE="e2-standard-4"
PREEMPTIBLE_WORKERS="0"
NUM_WORKERS="2"
NUM_PREEMPTIBLE_WORKERS="0"
BOOT_DISK_SIZE="100GB"
BOOT_DISK_TYPE="pd-standard"
NUM_LOCAL_SSDS="0"
IMAGE_VERSION=""
INITIALIZATION_ACTIONS=""
METADATA=""
SERVICE_ACCOUNT=""
SCOPES=""
TAGS=""
LABELS=""
PROPERTIES=""
MAX_IDLE_TIME=""
SPARK_JOB_FILE=""
SPARK_MAIN_CLASS=""
SPARK_ARGS=""
PYSPARK_JOB_FILE=""
HIVE_JOB_FILE=""
PIG_JOB_FILE=""
HADOOP_JOB_FILE=""
HADOOP_MAIN_CLASS=""
SPARK_SQL_JOB_FILE=""
JAR_FILES=""
FILE_URIS=""
ARCHIVE_URIS=""
DRIVER_LOG_LEVELS=""
ENABLE_AUTOSCALING=false
MAX_WORKERS_AUTOSCALE="10"
MIN_WORKERS_AUTOSCALE="2"
ENABLE_PREEMPTIBLE_SECONDARY=false
ENABLE_IP_ALIAS=false
CLUSTER_VERSION=""
OPTIONAL_COMPONENTS=""
ENABLE_STACKDRIVER_LOGGING=true
ENABLE_STACKDRIVER_MONITORING=true
KERBEROS_CONFIG=""
ENCRYPTION_CONFIG=""
PLACEMENT_GROUP=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Dataproc Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Dataproc clusters, jobs, and big data processing workflows."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-cluster\033[0m           Create a Dataproc cluster"
  echo -e "  \033[1;33mdelete-cluster\033[0m           Delete a Dataproc cluster"
  echo -e "  \033[1;33mlist-clusters\033[0m            List Dataproc clusters"
  echo -e "  \033[1;33mget-cluster\033[0m              Get cluster details"
  echo -e "  \033[1;33mupdate-cluster\033[0m           Update cluster configuration"
  echo -e "  \033[1;33mstart-cluster\033[0m            Start a stopped cluster"
  echo -e "  \033[1;33mstop-cluster\033[0m             Stop a running cluster"
  echo -e "  \033[1;33msubmit-spark-job\033[0m         Submit a Spark job"
  echo -e "  \033[1;33msubmit-pyspark-job\033[0m       Submit a PySpark job"
  echo -e "  \033[1;33msubmit-hive-job\033[0m          Submit a Hive job"
  echo -e "  \033[1;33msubmit-pig-job\033[0m           Submit a Pig job"
  echo -e "  \033[1;33msubmit-hadoop-job\033[0m        Submit a Hadoop job"
  echo -e "  \033[1;33msubmit-spark-sql-job\033[0m     Submit a Spark SQL job"
  echo -e "  \033[1;33mlist-jobs\033[0m                List cluster jobs"
  echo -e "  \033[1;33mget-job\033[0m                  Get job details"
  echo -e "  \033[1;33mcancel-job\033[0m               Cancel a running job"
  echo -e "  \033[1;33mget-job-logs\033[0m             Get job logs"
  echo -e "  \033[1;33mcreate-autoscaling-policy\033[0m Create autoscaling policy"
  echo -e "  \033[1;33mlist-autoscaling-policies\033[0m List autoscaling policies"
  echo -e "  \033[1;33mdelete-autoscaling-policy\033[0m Delete autoscaling policy"
  echo -e "  \033[1;33mgenerate-sample-job\033[0m      Generate sample job files"
  echo -e "  \033[1;33minstall-conda\033[0m            Install Conda on cluster"
  echo -e "  \033[1;33minstall-jupyter\033[0m          Install Jupyter on cluster"
  echo -e "  \033[1;33msetup-gpu-cluster\033[0m        Setup GPU-enabled cluster"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--cluster-name <name>\033[0m            (Required for cluster actions) Cluster name"
  echo -e "  \033[1;33m--job-name <name>\033[0m                (Required for job actions) Job name"
  echo -e "  \033[1;33m--job-id <id>\033[0m                    (Required for job actions) Job ID"
  echo -e "  \033[1;33m--region <region>\033[0m                (Optional) Region (default: us-central1)"
  echo -e "  \033[1;33m--zone <zone>\033[0m                    (Optional) Zone (default: us-central1-a)"
  echo -e "  \033[1;33m--network <network>\033[0m              (Optional) Network name"
  echo -e "  \033[1;33m--subnet <subnet>\033[0m                (Optional) Subnet name"
  echo -e "  \033[1;33m--machine-type <type>\033[0m            (Optional) Machine type (default: e2-standard-4)"
  echo -e "  \033[1;33m--num-workers <count>\033[0m            (Optional) Number of workers (default: 2)"
  echo -e "  \033[1;33m--num-preemptible-workers <count>\033[0m (Optional) Number of preemptible workers"
  echo -e "  \033[1;33m--boot-disk-size <size>\033[0m          (Optional) Boot disk size (default: 100GB)"
  echo -e "  \033[1;33m--boot-disk-type <type>\033[0m          (Optional) Boot disk type (default: pd-standard)"
  echo -e "  \033[1;33m--num-local-ssds <count>\033[0m         (Optional) Number of local SSDs"
  echo -e "  \033[1;33m--image-version <version>\033[0m        (Optional) Dataproc image version"
  echo -e "  \033[1;33m--initialization-actions <uri>\033[0m   (Optional) Initialization actions script"
  echo -e "  \033[1;33m--metadata <key=value>\033[0m           (Optional) Metadata (key=value,key2=value2)"
  echo -e "  \033[1;33m--service-account <email>\033[0m        (Optional) Service account email"
  echo -e "  \033[1;33m--scopes <scopes>\033[0m                (Optional) OAuth scopes"
  echo -e "  \033[1;33m--tags <tags>\033[0m                    (Optional) Network tags"
  echo -e "  \033[1;33m--labels <labels>\033[0m                (Optional) Labels (key=value,key2=value2)"
  echo -e "  \033[1;33m--properties <props>\033[0m             (Optional) Cluster properties"
  echo -e "  \033[1;33m--max-idle-time <time>\033[0m           (Optional) Max idle time before deletion"
  echo -e "  \033[1;33m--spark-job-file <file>\033[0m          (Required for Spark jobs) Spark job file"
  echo -e "  \033[1;33m--spark-main-class <class>\033[0m       (Optional) Spark main class"
  echo -e "  \033[1;33m--spark-args <args>\033[0m              (Optional) Spark job arguments"
  echo -e "  \033[1;33m--pyspark-job-file <file>\033[0m        (Required for PySpark jobs) PySpark job file"
  echo -e "  \033[1;33m--hive-job-file <file>\033[0m           (Required for Hive jobs) Hive job file"
  echo -e "  \033[1;33m--pig-job-file <file>\033[0m            (Required for Pig jobs) Pig job file"
  echo -e "  \033[1;33m--hadoop-job-file <file>\033[0m         (Required for Hadoop jobs) Hadoop job file"
  echo -e "  \033[1;33m--hadoop-main-class <class>\033[0m      (Required for Hadoop jobs) Hadoop main class"
  echo -e "  \033[1;33m--spark-sql-job-file <file>\033[0m      (Required for Spark SQL jobs) Spark SQL file"
  echo -e "  \033[1;33m--jar-files <files>\033[0m              (Optional) JAR files (comma-separated)"
  echo -e "  \033[1;33m--file-uris <uris>\033[0m               (Optional) File URIs (comma-separated)"
  echo -e "  \033[1;33m--archive-uris <uris>\033[0m            (Optional) Archive URIs (comma-separated)"
  echo -e "  \033[1;33m--enable-autoscaling\033[0m             (Optional) Enable cluster autoscaling"
  echo -e "  \033[1;33m--max-workers-autoscale <count>\033[0m  (Optional) Max workers for autoscaling"
  echo -e "  \033[1;33m--min-workers-autoscale <count>\033[0m  (Optional) Min workers for autoscaling"
  echo -e "  \033[1;33m--enable-preemptible-secondary\033[0m   (Optional) Enable preemptible secondary workers"
  echo -e "  \033[1;33m--enable-ip-alias\033[0m                (Optional) Enable IP alias"
  echo -e "  \033[1;33m--optional-components <components>\033[0m (Optional) Optional components (JUPYTER,ZEPPELIN)"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 create-cluster --project my-project --cluster-name my-cluster --region us-central1"
  echo "  $0 submit-spark-job --project my-project --cluster-name my-cluster --job-name spark-job --spark-job-file gs://bucket/job.jar"
  echo "  $0 submit-pyspark-job --project my-project --cluster-name my-cluster --job-name pyspark-job --pyspark-job-file gs://bucket/job.py"
  echo "  $0 list-clusters --project my-project --region us-central1"
  echo "  $0 delete-cluster --project my-project --cluster-name my-cluster --region us-central1"
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
      --cluster-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No cluster name provided after --cluster-name."
          usage
        fi
        CLUSTER_NAME="$2"
        shift 2
        ;;
      --job-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No job name provided after --job-name."
          usage
        fi
        JOB_NAME="$2"
        shift 2
        ;;
      --job-id)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No job ID provided after --job-id."
          usage
        fi
        JOB_ID="$2"
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
      --machine-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No machine type provided after --machine-type."
          usage
        fi
        MACHINE_TYPE="$2"
        shift 2
        ;;
      --num-workers)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No number of workers provided after --num-workers."
          usage
        fi
        NUM_WORKERS="$2"
        shift 2
        ;;
      --num-preemptible-workers)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No number of preemptible workers provided after --num-preemptible-workers."
          usage
        fi
        NUM_PREEMPTIBLE_WORKERS="$2"
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
      --num-local-ssds)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No number of local SSDs provided after --num-local-ssds."
          usage
        fi
        NUM_LOCAL_SSDS="$2"
        shift 2
        ;;
      --image-version)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No image version provided after --image-version."
          usage
        fi
        IMAGE_VERSION="$2"
        shift 2
        ;;
      --initialization-actions)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No initialization actions provided after --initialization-actions."
          usage
        fi
        INITIALIZATION_ACTIONS="$2"
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
      --service-account)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No service account provided after --service-account."
          usage
        fi
        SERVICE_ACCOUNT="$2"
        shift 2
        ;;
      --scopes)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No scopes provided after --scopes."
          usage
        fi
        SCOPES="$2"
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
      --properties)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No properties provided after --properties."
          usage
        fi
        PROPERTIES="$2"
        shift 2
        ;;
      --max-idle-time)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max idle time provided after --max-idle-time."
          usage
        fi
        MAX_IDLE_TIME="$2"
        shift 2
        ;;
      --spark-job-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Spark job file provided after --spark-job-file."
          usage
        fi
        SPARK_JOB_FILE="$2"
        shift 2
        ;;
      --spark-main-class)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Spark main class provided after --spark-main-class."
          usage
        fi
        SPARK_MAIN_CLASS="$2"
        shift 2
        ;;
      --spark-args)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Spark args provided after --spark-args."
          usage
        fi
        SPARK_ARGS="$2"
        shift 2
        ;;
      --pyspark-job-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No PySpark job file provided after --pyspark-job-file."
          usage
        fi
        PYSPARK_JOB_FILE="$2"
        shift 2
        ;;
      --hive-job-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Hive job file provided after --hive-job-file."
          usage
        fi
        HIVE_JOB_FILE="$2"
        shift 2
        ;;
      --pig-job-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Pig job file provided after --pig-job-file."
          usage
        fi
        PIG_JOB_FILE="$2"
        shift 2
        ;;
      --hadoop-job-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Hadoop job file provided after --hadoop-job-file."
          usage
        fi
        HADOOP_JOB_FILE="$2"
        shift 2
        ;;
      --hadoop-main-class)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Hadoop main class provided after --hadoop-main-class."
          usage
        fi
        HADOOP_MAIN_CLASS="$2"
        shift 2
        ;;
      --spark-sql-job-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Spark SQL job file provided after --spark-sql-job-file."
          usage
        fi
        SPARK_SQL_JOB_FILE="$2"
        shift 2
        ;;
      --jar-files)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No JAR files provided after --jar-files."
          usage
        fi
        JAR_FILES="$2"
        shift 2
        ;;
      --file-uris)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No file URIs provided after --file-uris."
          usage
        fi
        FILE_URIS="$2"
        shift 2
        ;;
      --archive-uris)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No archive URIs provided after --archive-uris."
          usage
        fi
        ARCHIVE_URIS="$2"
        shift 2
        ;;
      --max-workers-autoscale)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max workers for autoscaling provided after --max-workers-autoscale."
          usage
        fi
        MAX_WORKERS_AUTOSCALE="$2"
        shift 2
        ;;
      --min-workers-autoscale)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No min workers for autoscaling provided after --min-workers-autoscale."
          usage
        fi
        MIN_WORKERS_AUTOSCALE="$2"
        shift 2
        ;;
      --optional-components)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No optional components provided after --optional-components."
          usage
        fi
        OPTIONAL_COMPONENTS="$2"
        shift 2
        ;;
      --enable-autoscaling)
        ENABLE_AUTOSCALING=true
        shift
        ;;
      --enable-preemptible-secondary)
        ENABLE_PREEMPTIBLE_SECONDARY=true
        shift
        ;;
      --enable-ip-alias)
        ENABLE_IP_ALIAS=true
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
# CLUSTER MANAGEMENT
#=====================================================================
# Function to create cluster
create_cluster() {
  local project="$1"
  local cluster_name="$2"
  
  format-echo "INFO" "Creating Dataproc cluster: $cluster_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create cluster:"
    format-echo "INFO" "  Name: $cluster_name"
    format-echo "INFO" "  Region: $REGION"
    format-echo "INFO" "  Zone: $ZONE"
    format-echo "INFO" "  Machine type: $MACHINE_TYPE"
    format-echo "INFO" "  Workers: $NUM_WORKERS"
    return 0
  fi
  
  local create_cmd="gcloud dataproc clusters create $cluster_name"
  create_cmd+=" --project=$project"
  create_cmd+=" --region=$REGION"
  create_cmd+=" --zone=$ZONE"
  create_cmd+=" --master-machine-type=$MACHINE_TYPE"
  create_cmd+=" --worker-machine-type=$MACHINE_TYPE"
  create_cmd+=" --num-workers=$NUM_WORKERS"
  create_cmd+=" --master-boot-disk-size=$BOOT_DISK_SIZE"
  create_cmd+=" --worker-boot-disk-size=$BOOT_DISK_SIZE"
  create_cmd+=" --master-boot-disk-type=$BOOT_DISK_TYPE"
  create_cmd+=" --worker-boot-disk-type=$BOOT_DISK_TYPE"
  
  # Add preemptible workers if specified
  if [ "$NUM_PREEMPTIBLE_WORKERS" -gt 0 ]; then
    create_cmd+=" --num-preemptible-workers=$NUM_PREEMPTIBLE_WORKERS"
    create_cmd+=" --preemptible-worker-boot-disk-size=$BOOT_DISK_SIZE"
  fi
  
  # Add local SSDs if specified
  if [ "$NUM_LOCAL_SSDS" -gt 0 ]; then
    create_cmd+=" --num-master-local-ssds=$NUM_LOCAL_SSDS"
    create_cmd+=" --num-worker-local-ssds=$NUM_LOCAL_SSDS"
  fi
  
  # Network configuration
  if [ -n "$NETWORK" ]; then
    create_cmd+=" --network=$NETWORK"
  fi
  
  if [ -n "$SUBNET" ]; then
    create_cmd+=" --subnet=$SUBNET"
  fi
  
  if [ "$ENABLE_IP_ALIAS" = true ]; then
    create_cmd+=" --enable-ip-alias"
  fi
  
  # Image version
  if [ -n "$IMAGE_VERSION" ]; then
    create_cmd+=" --image-version=$IMAGE_VERSION"
  fi
  
  # Initialization actions
  if [ -n "$INITIALIZATION_ACTIONS" ]; then
    create_cmd+=" --initialization-actions=$INITIALIZATION_ACTIONS"
  fi
  
  # Metadata
  if [ -n "$METADATA" ]; then
    create_cmd+=" --metadata=$METADATA"
  fi
  
  # Service account and scopes
  if [ -n "$SERVICE_ACCOUNT" ]; then
    create_cmd+=" --service-account=$SERVICE_ACCOUNT"
  fi
  
  if [ -n "$SCOPES" ]; then
    create_cmd+=" --scopes=$SCOPES"
  fi
  
  # Tags and labels
  if [ -n "$TAGS" ]; then
    create_cmd+=" --tags=$TAGS"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --labels=$LABELS"
  fi
  
  # Properties
  if [ -n "$PROPERTIES" ]; then
    create_cmd+=" --properties=$PROPERTIES"
  fi
  
  # Max idle time
  if [ -n "$MAX_IDLE_TIME" ]; then
    create_cmd+=" --max-idle=$MAX_IDLE_TIME"
  fi
  
  # Autoscaling
  if [ "$ENABLE_AUTOSCALING" = true ]; then
    create_cmd+=" --enable-autoscaling"
    create_cmd+=" --max-workers=$MAX_WORKERS_AUTOSCALE"
    create_cmd+=" --secondary-worker-type=preemptible"
  fi
  
  # Optional components
  if [ -n "$OPTIONAL_COMPONENTS" ]; then
    create_cmd+=" --optional-components=$OPTIONAL_COMPONENTS"
  fi
  
  # Stackdriver integration
  if [ "$ENABLE_STACKDRIVER_LOGGING" = true ]; then
    create_cmd+=" --enable-cloud-sql-hive-metastore"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create cluster: $cluster_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created Dataproc cluster: $cluster_name"
  return 0
}

# Function to delete cluster
delete_cluster() {
  local project="$1"
  local cluster_name="$2"
  
  format-echo "INFO" "Deleting Dataproc cluster: $cluster_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete cluster: $cluster_name"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will permanently delete the cluster '$cluster_name'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud dataproc clusters delete "$cluster_name" \
    --project="$project" \
    --region="$REGION" \
    --quiet; then
    format-echo "ERROR" "Failed to delete cluster: $cluster_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Dataproc cluster: $cluster_name"
  return 0
}

# Function to list clusters
list_clusters() {
  local project="$1"
  
  format-echo "INFO" "Listing Dataproc clusters"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list clusters"
    return 0
  fi
  
  if ! gcloud dataproc clusters list \
    --project="$project" \
    --region="$REGION" \
    --format="table(clusterName,status.state,config.numInstances,config.masterConfig.machineTypeUri.basename(),config.workerConfig.machineTypeUri.basename())"; then
    format-echo "ERROR" "Failed to list clusters"
    return 1
  fi
  
  return 0
}

# Function to get cluster details
get_cluster() {
  local project="$1"
  local cluster_name="$2"
  
  format-echo "INFO" "Getting details for cluster: $cluster_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get cluster details: $cluster_name"
    return 0
  fi
  
  if ! gcloud dataproc clusters describe "$cluster_name" \
    --project="$project" \
    --region="$REGION"; then
    format-echo "ERROR" "Failed to get cluster details: $cluster_name"
    return 1
  fi
  
  return 0
}

#=====================================================================
# JOB MANAGEMENT
#=====================================================================
# Function to submit Spark job
submit_spark_job() {
  local project="$1"
  local cluster_name="$2"
  local job_name="$3"
  local spark_job_file="$4"
  
  format-echo "INFO" "Submitting Spark job: $job_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would submit Spark job:"
    format-echo "INFO" "  Job name: $job_name"
    format-echo "INFO" "  Cluster: $cluster_name"
    format-echo "INFO" "  Job file: $spark_job_file"
    return 0
  fi
  
  local submit_cmd="gcloud dataproc jobs submit spark"
  submit_cmd+=" --cluster=$cluster_name"
  submit_cmd+=" --project=$project"
  submit_cmd+=" --region=$REGION"
  submit_cmd+=" --jar=$spark_job_file"
  
  if [ -n "$SPARK_MAIN_CLASS" ]; then
    submit_cmd+=" --class=$SPARK_MAIN_CLASS"
  fi
  
  if [ -n "$SPARK_ARGS" ]; then
    submit_cmd+=" -- $SPARK_ARGS"
  fi
  
  if [ -n "$JAR_FILES" ]; then
    submit_cmd+=" --jars=$JAR_FILES"
  fi
  
  if [ -n "$FILE_URIS" ]; then
    submit_cmd+=" --files=$FILE_URIS"
  fi
  
  if [ -n "$ARCHIVE_URIS" ]; then
    submit_cmd+=" --archives=$ARCHIVE_URIS"
  fi
  
  if [ -n "$PROPERTIES" ]; then
    submit_cmd+=" --properties=$PROPERTIES"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $submit_cmd"
  fi
  
  if ! eval "$submit_cmd"; then
    format-echo "ERROR" "Failed to submit Spark job: $job_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Submitted Spark job: $job_name"
  return 0
}

# Function to submit PySpark job
submit_pyspark_job() {
  local project="$1"
  local cluster_name="$2"
  local job_name="$3"
  local pyspark_job_file="$4"
  
  format-echo "INFO" "Submitting PySpark job: $job_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would submit PySpark job:"
    format-echo "INFO" "  Job name: $job_name"
    format-echo "INFO" "  Cluster: $cluster_name"
    format-echo "INFO" "  Job file: $pyspark_job_file"
    return 0
  fi
  
  local submit_cmd="gcloud dataproc jobs submit pyspark"
  submit_cmd+=" --cluster=$cluster_name"
  submit_cmd+=" --project=$project"
  submit_cmd+=" --region=$REGION"
  submit_cmd+=" $pyspark_job_file"
  
  if [ -n "$SPARK_ARGS" ]; then
    submit_cmd+=" -- $SPARK_ARGS"
  fi
  
  if [ -n "$JAR_FILES" ]; then
    submit_cmd+=" --jars=$JAR_FILES"
  fi
  
  if [ -n "$FILE_URIS" ]; then
    submit_cmd+=" --files=$FILE_URIS"
  fi
  
  if [ -n "$ARCHIVE_URIS" ]; then
    submit_cmd+=" --archives=$ARCHIVE_URIS"
  fi
  
  if [ -n "$PROPERTIES" ]; then
    submit_cmd+=" --properties=$PROPERTIES"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $submit_cmd"
  fi
  
  if ! eval "$submit_cmd"; then
    format-echo "ERROR" "Failed to submit PySpark job: $job_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Submitted PySpark job: $job_name"
  return 0
}

# Function to list jobs
list_jobs() {
  local project="$1"
  local cluster_name="$2"
  
  format-echo "INFO" "Listing jobs for cluster: $cluster_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list jobs for cluster: $cluster_name"
    return 0
  fi
  
  local list_cmd="gcloud dataproc jobs list"
  list_cmd+=" --project=$project"
  list_cmd+=" --region=$REGION"
  list_cmd+=" --format=table(jobUuid,status.state,jobType,placement.clusterName)"
  
  if [ -n "$cluster_name" ]; then
    list_cmd+=" --cluster=$cluster_name"
  fi
  
  if ! eval "$list_cmd"; then
    format-echo "ERROR" "Failed to list jobs"
    return 1
  fi
  
  return 0
}

# Function to generate sample job files
generate_sample_job() {
  local job_type="${1:-spark}"
  
  format-echo "INFO" "Generating sample $job_type job files"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would generate sample $job_type job"
    return 0
  fi
  
  local job_dir="./dataproc-$job_type-job"
  mkdir -p "$job_dir"
  
  case "$job_type" in
    spark)
      # Generate Scala Spark job
      cat > "$job_dir/WordCount.scala" << 'EOF'
import org.apache.spark.sql.SparkSession

object WordCount {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("Word Count")
      .getOrCreate()
    
    import spark.implicits._
    
    val inputPath = if (args.length > 0) args(0) else "gs://dataproc-examples/shakespeare/hamlet.txt"
    val outputPath = if (args.length > 1) args(1) else "gs://your-bucket/wordcount-output"
    
    val textFile = spark.read.textFile(inputPath)
    val counts = textFile.flatMap(line => line.split(" "))
                        .groupByKey(identity)
                        .count()
    
    counts.write.mode("overwrite").text(outputPath)
    
    spark.stop()
  }
}
EOF
      
      # Generate build.sbt
      cat > "$job_dir/build.sbt" << 'EOF'
name := "WordCount"
version := "1.0"
scalaVersion := "2.12.15"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % "3.3.0" % "provided",
  "org.apache.spark" %% "spark-sql" % "3.3.0" % "provided"
)

assemblyMergeStrategy in assembly := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first
}
EOF
      ;;
    pyspark)
      # Generate PySpark job
      cat > "$job_dir/wordcount.py" << 'EOF'
#!/usr/bin/env python3

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, split, col

def main():
    # Create Spark session
    spark = SparkSession.builder \
        .appName("WordCount") \
        .getOrCreate()
    
    # Get input and output paths
    input_path = sys.argv[1] if len(sys.argv) > 1 else "gs://dataproc-examples/shakespeare/hamlet.txt"
    output_path = sys.argv[2] if len(sys.argv) > 2 else "gs://your-bucket/wordcount-output"
    
    # Read text file
    df = spark.read.text(input_path)
    
    # Split lines into words and count
    words = df.select(explode(split(col("value"), " ")).alias("word"))
    word_counts = words.groupBy("word").count().orderBy("count", ascending=False)
    
    # Write results
    word_counts.write.mode("overwrite").csv(output_path, header=True)
    
    # Stop Spark session
    spark.stop()

if __name__ == "__main__":
    main()
EOF
      ;;
    hive)
      # Generate Hive job
      cat > "$job_dir/word_count.hql" << 'EOF'
-- Word count example in Hive
CREATE TABLE IF NOT EXISTS word_count_input (
    line STRING
)
STORED AS TEXTFILE
LOCATION 'gs://dataproc-examples/shakespeare/';

CREATE TABLE IF NOT EXISTS word_count_output (
    word STRING,
    count INT
)
STORED AS TEXTFILE
LOCATION 'gs://your-bucket/hive-wordcount-output/';

INSERT OVERWRITE TABLE word_count_output
SELECT word, COUNT(1) as count
FROM (
    SELECT explode(split(line, ' ')) as word
    FROM word_count_input
    WHERE line IS NOT NULL
) words
WHERE word != ''
GROUP BY word
ORDER BY count DESC;
EOF
      ;;
  esac
  
  # Generate submit script
  cat > "$job_dir/submit.sh" << EOF
#!/bin/bash
# Submit script for $job_type job

set -e

PROJECT_ID="\${PROJECT_ID:-your-project-id}"
CLUSTER_NAME="\${CLUSTER_NAME:-your-cluster}"
REGION="\${REGION:-us-central1}"

echo "Submitting $job_type job to cluster \$CLUSTER_NAME in project \$PROJECT_ID"

case "$job_type" in
  spark)
    # Build JAR first
    sbt assembly
    
    # Submit Spark job
    gcloud dataproc jobs submit spark \\
      --cluster=\$CLUSTER_NAME \\
      --project=\$PROJECT_ID \\
      --region=\$REGION \\
      --jar=target/scala-2.12/wordcount-assembly-1.0.jar \\
      --class=WordCount \\
      -- gs://dataproc-examples/shakespeare/hamlet.txt gs://your-bucket/spark-output
    ;;
  pyspark)
    # Submit PySpark job
    gcloud dataproc jobs submit pyspark \\
      --cluster=\$CLUSTER_NAME \\
      --project=\$PROJECT_ID \\
      --region=\$REGION \\
      wordcount.py \\
      -- gs://dataproc-examples/shakespeare/hamlet.txt gs://your-bucket/pyspark-output
    ;;
  hive)
    # Submit Hive job
    gcloud dataproc jobs submit hive \\
      --cluster=\$CLUSTER_NAME \\
      --project=\$PROJECT_ID \\
      --region=\$REGION \\
      --file=word_count.hql
    ;;
esac

echo "$job_type job submitted successfully!"
EOF
  
  chmod +x "$job_dir/submit.sh"
  
  format-echo "SUCCESS" "Generated sample $job_type job in: $job_dir"
  format-echo "INFO" "Edit the submit.sh script with your project details and run it to submit the job"
  
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
  
  print_with_separator "GCP Dataproc Manager Script"
  format-echo "INFO" "Starting GCP Dataproc Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Dataproc Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Dataproc Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Dataproc Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-cluster|delete-cluster|get-cluster|update-cluster|start-cluster|stop-cluster)
      if [ -z "$CLUSTER_NAME" ]; then
        format-echo "ERROR" "Cluster name is required for action: $ACTION"
        exit 1
      fi
      ;;
    submit-spark-job)
      if [ -z "$CLUSTER_NAME" ] || [ -z "$JOB_NAME" ] || [ -z "$SPARK_JOB_FILE" ]; then
        format-echo "ERROR" "Cluster name, job name, and Spark job file are required for action: $ACTION"
        exit 1
      fi
      ;;
    submit-pyspark-job)
      if [ -z "$CLUSTER_NAME" ] || [ -z "$JOB_NAME" ] || [ -z "$PYSPARK_JOB_FILE" ]; then
        format-echo "ERROR" "Cluster name, job name, and PySpark job file are required for action: $ACTION"
        exit 1
      fi
      ;;
    list-jobs|list-clusters|generate-sample-job)
      # No additional requirements for these actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-cluster, delete-cluster, list-clusters, submit-spark-job, submit-pyspark-job, list-jobs, generate-sample-job, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-cluster)
      if create_cluster "$PROJECT_ID" "$CLUSTER_NAME"; then
        format-echo "SUCCESS" "Cluster creation completed successfully"
      else
        format-echo "ERROR" "Failed to create cluster"
        exit 1
      fi
      ;;
    delete-cluster)
      if delete_cluster "$PROJECT_ID" "$CLUSTER_NAME"; then
        format-echo "SUCCESS" "Cluster deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete cluster"
        exit 1
      fi
      ;;
    list-clusters)
      if list_clusters "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed clusters successfully"
      else
        format-echo "ERROR" "Failed to list clusters"
        exit 1
      fi
      ;;
    get-cluster)
      if get_cluster "$PROJECT_ID" "$CLUSTER_NAME"; then
        format-echo "SUCCESS" "Retrieved cluster details successfully"
      else
        format-echo "ERROR" "Failed to get cluster details"
        exit 1
      fi
      ;;
    submit-spark-job)
      if submit_spark_job "$PROJECT_ID" "$CLUSTER_NAME" "$JOB_NAME" "$SPARK_JOB_FILE"; then
        format-echo "SUCCESS" "Spark job submission completed successfully"
      else
        format-echo "ERROR" "Failed to submit Spark job"
        exit 1
      fi
      ;;
    submit-pyspark-job)
      if submit_pyspark_job "$PROJECT_ID" "$CLUSTER_NAME" "$JOB_NAME" "$PYSPARK_JOB_FILE"; then
        format-echo "SUCCESS" "PySpark job submission completed successfully"
      else
        format-echo "ERROR" "Failed to submit PySpark job"
        exit 1
      fi
      ;;
    list-jobs)
      if list_jobs "$PROJECT_ID" "$CLUSTER_NAME"; then
        format-echo "SUCCESS" "Listed jobs successfully"
      else
        format-echo "ERROR" "Failed to list jobs"
        exit 1
      fi
      ;;
    generate-sample-job)
      job_type="${TEMPLATE_TYPE:-spark}"
      if generate_sample_job "$job_type"; then
        format-echo "SUCCESS" "Sample job generation completed successfully"
      else
        format-echo "ERROR" "Failed to generate sample job"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Dataproc Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
