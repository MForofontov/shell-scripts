#!/usr/bin/env bash
# gcp-bigquery-manager.sh
# Script to manage GCP BigQuery datasets, tables, jobs, and data operations.

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
DATASET_ID=""
TABLE_ID=""
JOB_ID=""
VIEW_ID=""
ROUTINE_ID=""
LOCATION="US"
DESCRIPTION=""
EXPIRATION_TIME=""
LABELS=""
SOURCE_FORMAT="CSV"
DESTINATION_FORMAT="CSV"
SOURCE_FILE=""
SOURCE_URI=""
DESTINATION_TABLE=""
DESTINATION_URI=""
SCHEMA_FILE=""
SCHEMA=""
QUERY=""
QUERY_FILE=""
USE_LEGACY_SQL=false
DRY_RUN_QUERY=false
MAX_RESULTS="100"
TIMEOUT="600"
WRITE_DISPOSITION="WRITE_TRUNCATE"
CREATE_DISPOSITION="CREATE_IF_NEEDED"
FIELD_DELIMITER=","
SKIP_LEADING_ROWS="0"
ALLOW_JAGGED_ROWS=false
ALLOW_QUOTED_NEWLINES=false
IGNORE_UNKNOWN_VALUES=false
COMPRESSION="NONE"
ENCODING="UTF-8"
CLUSTERING_FIELDS=""
PARTITION_FIELD=""
PARTITION_TYPE="DAY"
REQUIRE_PARTITION_FILTER=false
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP BigQuery Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP BigQuery datasets, tables, jobs, and data operations."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-dataset\033[0m           Create a BigQuery dataset"
  echo -e "  \033[1;33mdelete-dataset\033[0m           Delete a BigQuery dataset"
  echo -e "  \033[1;33mlist-datasets\033[0m            List all datasets"
  echo -e "  \033[1;33mget-dataset\033[0m              Get dataset details"
  echo -e "  \033[1;33mcreate-table\033[0m             Create a BigQuery table"
  echo -e "  \033[1;33mdelete-table\033[0m             Delete a BigQuery table"
  echo -e "  \033[1;33mlist-tables\033[0m              List tables in dataset"
  echo -e "  \033[1;33mget-table\033[0m                Get table details"
  echo -e "  \033[1;33mquery-table\033[0m              Query table data"
  echo -e "  \033[1;33mload-data\033[0m                Load data into table"
  echo -e "  \033[1;33mexport-data\033[0m              Export table data"
  echo -e "  \033[1;33mcopy-table\033[0m               Copy table data"
  echo -e "  \033[1;33mcreate-view\033[0m              Create a view"
  echo -e "  \033[1;33mdelete-view\033[0m              Delete a view"
  echo -e "  \033[1;33mlist-views\033[0m               List views in dataset"
  echo -e "  \033[1;33mcreate-routine\033[0m           Create a routine (function/procedure)"
  echo -e "  \033[1;33mdelete-routine\033[0m           Delete a routine"
  echo -e "  \033[1;33mlist-routines\033[0m            List routines in dataset"
  echo -e "  \033[1;33mlist-jobs\033[0m                List BigQuery jobs"
  echo -e "  \033[1;33mget-job\033[0m                  Get job details"
  echo -e "  \033[1;33mcancel-job\033[0m               Cancel a running job"
  echo -e "  \033[1;33mshow-schema\033[0m              Show table schema"
  echo -e "  \033[1;33mupdate-schema\033[0m            Update table schema"
  echo -e "  \033[1;33mget-pricing\033[0m              Get BigQuery pricing information"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--dataset <dataset-id>\033[0m           (Required for dataset/table actions) Dataset ID"
  echo -e "  \033[1;33m--table <table-id>\033[0m               (Required for table actions) Table ID"
  echo -e "  \033[1;33m--job <job-id>\033[0m                   (Required for job actions) Job ID"
  echo -e "  \033[1;33m--view <view-id>\033[0m                 (Required for view actions) View ID"
  echo -e "  \033[1;33m--routine <routine-id>\033[0m           (Required for routine actions) Routine ID"
  echo -e "  \033[1;33m--location <location>\033[0m            (Optional) Dataset location (default: US)"
  echo -e "  \033[1;33m--description <description>\033[0m      (Optional) Resource description"
  echo -e "  \033[1;33m--expiration <time>\033[0m              (Optional) Expiration time (e.g., 3600s, 1h, 1d)"
  echo -e "  \033[1;33m--labels <labels>\033[0m                (Optional) Labels (key=value,key2=value2)"
  echo -e "  \033[1;33m--source-format <format>\033[0m         (Optional) Source format: CSV, JSON, AVRO, PARQUET (default: CSV)"
  echo -e "  \033[1;33m--destination-format <format>\033[0m    (Optional) Destination format (default: CSV)"
  echo -e "  \033[1;33m--source-file <file>\033[0m             (Optional) Local source file path"
  echo -e "  \033[1;33m--source-uri <uri>\033[0m               (Optional) GCS source URI"
  echo -e "  \033[1;33m--destination-table <table>\033[0m      (Optional) Destination table (project:dataset.table)"
  echo -e "  \033[1;33m--destination-uri <uri>\033[0m          (Optional) GCS destination URI"
  echo -e "  \033[1;33m--schema-file <file>\033[0m             (Optional) Schema definition file (JSON)"
  echo -e "  \033[1;33m--schema <schema>\033[0m                (Optional) Schema definition string"
  echo -e "  \033[1;33m--query <sql>\033[0m                    (Optional) SQL query string"
  echo -e "  \033[1;33m--query-file <file>\033[0m              (Optional) SQL query file"
  echo -e "  \033[1;33m--use-legacy-sql\033[0m                 (Optional) Use legacy SQL syntax"
  echo -e "  \033[1;33m--dry-run-query\033[0m                  (Optional) Validate query without running"
  echo -e "  \033[1;33m--max-results <count>\033[0m            (Optional) Max results to return (default: 100)"
  echo -e "  \033[1;33m--timeout <seconds>\033[0m              (Optional) Query timeout (default: 600)"
  echo -e "  \033[1;33m--write-disposition <mode>\033[0m       (Optional) Write mode: WRITE_TRUNCATE, WRITE_APPEND, WRITE_EMPTY"
  echo -e "  \033[1;33m--field-delimiter <delimiter>\033[0m    (Optional) Field delimiter for CSV (default: ,)"
  echo -e "  \033[1;33m--skip-leading-rows <count>\033[0m      (Optional) Skip leading rows (default: 0)"
  echo -e "  \033[1;33m--clustering-fields <fields>\033[0m     (Optional) Clustering fields (comma-separated)"
  echo -e "  \033[1;33m--partition-field <field>\033[0m        (Optional) Partition field"
  echo -e "  \033[1;33m--partition-type <type>\033[0m          (Optional) Partition type: DAY, HOUR, MONTH, YEAR"
  echo -e "  \033[1;33m--require-partition-filter\033[0m       (Optional) Require partition filter in queries"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-datasets --project my-project"
  echo "  $0 create-dataset --project my-project --dataset analytics --location EU --description 'Analytics data'"
  echo "  $0 create-table --project my-project --dataset analytics --table users --schema-file schema.json"
  echo "  $0 query-table --project my-project --query 'SELECT * FROM analytics.users LIMIT 10'"
  echo "  $0 load-data --project my-project --dataset analytics --table users --source-file data.csv"
  echo "  $0 export-data --project my-project --dataset analytics --table users --destination-uri gs://bucket/export/"
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
      --dataset)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No dataset ID provided after --dataset."
          usage
        fi
        DATASET_ID="$2"
        shift 2
        ;;
      --table)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No table ID provided after --table."
          usage
        fi
        TABLE_ID="$2"
        shift 2
        ;;
      --job)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No job ID provided after --job."
          usage
        fi
        JOB_ID="$2"
        shift 2
        ;;
      --view)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No view ID provided after --view."
          usage
        fi
        VIEW_ID="$2"
        shift 2
        ;;
      --routine)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No routine ID provided after --routine."
          usage
        fi
        ROUTINE_ID="$2"
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
      --description)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No description provided after --description."
          usage
        fi
        DESCRIPTION="$2"
        shift 2
        ;;
      --expiration)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No expiration time provided after --expiration."
          usage
        fi
        EXPIRATION_TIME="$2"
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
      --source-format)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source format provided after --source-format."
          usage
        fi
        SOURCE_FORMAT="$2"
        shift 2
        ;;
      --destination-format)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No destination format provided after --destination-format."
          usage
        fi
        DESTINATION_FORMAT="$2"
        shift 2
        ;;
      --source-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source file provided after --source-file."
          usage
        fi
        SOURCE_FILE="$2"
        shift 2
        ;;
      --source-uri)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source URI provided after --source-uri."
          usage
        fi
        SOURCE_URI="$2"
        shift 2
        ;;
      --destination-table)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No destination table provided after --destination-table."
          usage
        fi
        DESTINATION_TABLE="$2"
        shift 2
        ;;
      --destination-uri)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No destination URI provided after --destination-uri."
          usage
        fi
        DESTINATION_URI="$2"
        shift 2
        ;;
      --schema-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No schema file provided after --schema-file."
          usage
        fi
        SCHEMA_FILE="$2"
        shift 2
        ;;
      --schema)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No schema provided after --schema."
          usage
        fi
        SCHEMA="$2"
        shift 2
        ;;
      --query)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No query provided after --query."
          usage
        fi
        QUERY="$2"
        shift 2
        ;;
      --query-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No query file provided after --query-file."
          usage
        fi
        QUERY_FILE="$2"
        shift 2
        ;;
      --use-legacy-sql)
        USE_LEGACY_SQL=true
        shift
        ;;
      --dry-run-query)
        DRY_RUN_QUERY=true
        shift
        ;;
      --max-results)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max results provided after --max-results."
          usage
        fi
        MAX_RESULTS="$2"
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
      --write-disposition)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No write disposition provided after --write-disposition."
          usage
        fi
        WRITE_DISPOSITION="$2"
        shift 2
        ;;
      --field-delimiter)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No field delimiter provided after --field-delimiter."
          usage
        fi
        FIELD_DELIMITER="$2"
        shift 2
        ;;
      --skip-leading-rows)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No skip leading rows count provided after --skip-leading-rows."
          usage
        fi
        SKIP_LEADING_ROWS="$2"
        shift 2
        ;;
      --clustering-fields)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No clustering fields provided after --clustering-fields."
          usage
        fi
        CLUSTERING_FIELDS="$2"
        shift 2
        ;;
      --partition-field)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No partition field provided after --partition-field."
          usage
        fi
        PARTITION_FIELD="$2"
        shift 2
        ;;
      --partition-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No partition type provided after --partition-type."
          usage
        fi
        PARTITION_TYPE="$2"
        shift 2
        ;;
      --require-partition-filter)
        REQUIRE_PARTITION_FILTER=true
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
  if ! command_exists bq; then
    format-echo "ERROR" "bq CLI is required but not installed."
    format-echo "INFO" "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  
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

# Function to validate files
validate_files() {
  if [ -n "$SCHEMA_FILE" ] && [ ! -f "$SCHEMA_FILE" ]; then
    format-echo "ERROR" "Schema file not found: $SCHEMA_FILE"
    return 1
  fi
  
  if [ -n "$QUERY_FILE" ] && [ ! -f "$QUERY_FILE" ]; then
    format-echo "ERROR" "Query file not found: $QUERY_FILE"
    return 1
  fi
  
  if [ -n "$SOURCE_FILE" ] && [ ! -f "$SOURCE_FILE" ]; then
    format-echo "ERROR" "Source file not found: $SOURCE_FILE"
    return 1
  fi
  
  return 0
}

#=====================================================================
# DATASET MANAGEMENT
#=====================================================================
# Function to create dataset
create_dataset() {
  local project="$1"
  local dataset="$2"
  
  format-echo "INFO" "Creating BigQuery dataset: $dataset"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create dataset:"
    format-echo "INFO" "  Name: $dataset"
    format-echo "INFO" "  Location: $LOCATION"
    [ -n "$DESCRIPTION" ] && format-echo "INFO" "  Description: $DESCRIPTION"
    return 0
  fi
  
  local create_cmd="bq mk"
  create_cmd+=" --project_id=$project"
  create_cmd+=" --location=$LOCATION"
  
  if [ -n "$DESCRIPTION" ]; then
    create_cmd+=" --description='$DESCRIPTION'"
  fi
  
  if [ -n "$EXPIRATION_TIME" ]; then
    create_cmd+=" --default_table_expiration=$EXPIRATION_TIME"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --label=$LABELS"
  fi
  
  create_cmd+=" --dataset $dataset"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create dataset: $dataset"
    return 1
  fi
  
  format-echo "SUCCESS" "Created BigQuery dataset: $dataset"
  return 0
}

# Function to delete dataset
delete_dataset() {
  local project="$1"
  local dataset="$2"
  
  format-echo "INFO" "Deleting BigQuery dataset: $dataset"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete dataset: $dataset"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will delete the dataset '$dataset' and all its tables."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! bq rm -r -f --project_id="$project" "$dataset"; then
    format-echo "ERROR" "Failed to delete dataset: $dataset"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted BigQuery dataset: $dataset"
  return 0
}

# Function to list datasets
list_datasets() {
  local project="$1"
  
  format-echo "INFO" "Listing BigQuery datasets"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list datasets"
    return 0
  fi
  
  if ! bq ls --project_id="$project" --max_results="$MAX_RESULTS"; then
    format-echo "ERROR" "Failed to list datasets"
    return 1
  fi
  
  return 0
}

# Function to get dataset details
get_dataset() {
  local project="$1"
  local dataset="$2"
  
  format-echo "INFO" "Getting details for dataset: $dataset"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get dataset details: $dataset"
    return 0
  fi
  
  if ! bq show --project_id="$project" "$dataset"; then
    format-echo "ERROR" "Failed to get dataset details: $dataset"
    return 1
  fi
  
  return 0
}

#=====================================================================
# TABLE MANAGEMENT
#=====================================================================
# Function to create table
create_table() {
  local project="$1"
  local dataset="$2"
  local table="$3"
  
  format-echo "INFO" "Creating BigQuery table: $table"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create table:"
    format-echo "INFO" "  Dataset: $dataset"
    format-echo "INFO" "  Table: $table"
    [ -n "$SCHEMA_FILE" ] && format-echo "INFO" "  Schema file: $SCHEMA_FILE"
    return 0
  fi
  
  local create_cmd="bq mk"
  create_cmd+=" --project_id=$project"
  create_cmd+=" --table"
  
  if [ -n "$DESCRIPTION" ]; then
    create_cmd+=" --description='$DESCRIPTION'"
  fi
  
  if [ -n "$EXPIRATION_TIME" ]; then
    create_cmd+=" --expiration=$EXPIRATION_TIME"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --label=$LABELS"
  fi
  
  if [ -n "$SCHEMA_FILE" ]; then
    create_cmd+=" --schema=$SCHEMA_FILE"
  elif [ -n "$SCHEMA" ]; then
    create_cmd+=" --schema='$SCHEMA'"
  fi
  
  # Partitioning
  if [ -n "$PARTITION_FIELD" ]; then
    case "$PARTITION_TYPE" in
      DAY|HOUR|MONTH|YEAR)
        create_cmd+=" --time_partitioning_field=$PARTITION_FIELD"
        create_cmd+=" --time_partitioning_type=$PARTITION_TYPE"
        ;;
    esac
    
    if [ "$REQUIRE_PARTITION_FILTER" = true ]; then
      create_cmd+=" --require_partition_filter"
    fi
  fi
  
  # Clustering
  if [ -n "$CLUSTERING_FIELDS" ]; then
    create_cmd+=" --clustering_fields=$CLUSTERING_FIELDS"
  fi
  
  create_cmd+=" $dataset.$table"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create table: $table"
    return 1
  fi
  
  format-echo "SUCCESS" "Created BigQuery table: $table"
  return 0
}

# Function to query table
query_table() {
  local project="$1"
  local query_sql="$2"
  
  format-echo "INFO" "Executing BigQuery query"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would execute query:"
    format-echo "INFO" "  SQL: $query_sql"
    return 0
  fi
  
  local query_cmd="bq query"
  query_cmd+=" --project_id=$project"
  query_cmd+=" --max_rows=$MAX_RESULTS"
  query_cmd+=" --job_timeout=${TIMEOUT}s"
  
  if [ "$USE_LEGACY_SQL" = true ]; then
    query_cmd+=" --use_legacy_sql"
  else
    query_cmd+=" --nouse_legacy_sql"
  fi
  
  if [ "$DRY_RUN_QUERY" = true ]; then
    query_cmd+=" --dry_run"
  fi
  
  if [ -n "$DESTINATION_TABLE" ]; then
    query_cmd+=" --destination_table=$DESTINATION_TABLE"
    query_cmd+=" --replace"
  fi
  
  query_cmd+=" '$query_sql'"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $query_cmd"
  fi
  
  if ! eval "$query_cmd"; then
    format-echo "ERROR" "Failed to execute query"
    return 1
  fi
  
  if [ "$DRY_RUN_QUERY" = true ]; then
    format-echo "SUCCESS" "Query validation completed"
  else
    format-echo "SUCCESS" "Query executed successfully"
  fi
  return 0
}

# Function to load data
load_data() {
  local project="$1"
  local dataset="$2"
  local table="$3"
  local source="$4"
  
  format-echo "INFO" "Loading data into table: $dataset.$table"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would load data:"
    format-echo "INFO" "  Source: $source"
    format-echo "INFO" "  Destination: $dataset.$table"
    format-echo "INFO" "  Format: $SOURCE_FORMAT"
    return 0
  fi
  
  local load_cmd="bq load"
  load_cmd+=" --project_id=$project"
  load_cmd+=" --source_format=$SOURCE_FORMAT"
  load_cmd+=" --$WRITE_DISPOSITION"
  
  if [ "$SOURCE_FORMAT" = "CSV" ]; then
    load_cmd+=" --field_delimiter='$FIELD_DELIMITER'"
    load_cmd+=" --skip_leading_rows=$SKIP_LEADING_ROWS"
    
    if [ "$ALLOW_JAGGED_ROWS" = true ]; then
      load_cmd+=" --allow_jagged_rows"
    fi
    
    if [ "$ALLOW_QUOTED_NEWLINES" = true ]; then
      load_cmd+=" --allow_quoted_newlines"
    fi
  fi
  
  if [ "$IGNORE_UNKNOWN_VALUES" = true ]; then
    load_cmd+=" --ignore_unknown_values"
  fi
  
  if [ -n "$SCHEMA_FILE" ]; then
    load_cmd+=" --schema=$SCHEMA_FILE"
  elif [ -n "$SCHEMA" ]; then
    load_cmd+=" --schema='$SCHEMA'"
  else
    load_cmd+=" --autodetect"
  fi
  
  load_cmd+=" $dataset.$table"
  load_cmd+=" '$source'"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $load_cmd"
  fi
  
  if ! eval "$load_cmd"; then
    format-echo "ERROR" "Failed to load data into table: $table"
    return 1
  fi
  
  format-echo "SUCCESS" "Loaded data into table: $dataset.$table"
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
  
  print_with_separator "GCP BigQuery Manager Script"
  format-echo "INFO" "Starting GCP BigQuery Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP BigQuery Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP BigQuery Manager Script"
    exit 1
  fi
  
  # Validate files
  if ! validate_files; then
    print_with_separator "End of GCP BigQuery Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP BigQuery Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-dataset|delete-dataset|get-dataset|list-tables|list-views|list-routines)
      if [ -z "$DATASET_ID" ]; then
        format-echo "ERROR" "Dataset ID is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-table|delete-table|get-table|show-schema|update-schema|load-data)
      if [ -z "$DATASET_ID" ] || [ -z "$TABLE_ID" ]; then
        format-echo "ERROR" "Dataset ID and table ID are required for action: $ACTION"
        exit 1
      fi
      ;;
    query-table)
      if [ -z "$QUERY" ] && [ -z "$QUERY_FILE" ]; then
        format-echo "ERROR" "Query string or query file is required for action: $ACTION"
        exit 1
      fi
      ;;
    list-datasets|list-jobs|get-pricing)
      # No additional requirements for these actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-dataset, delete-dataset, list-datasets, get-dataset, create-table, delete-table, list-tables, get-table, query-table, load-data, export-data, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-dataset)
      if create_dataset "$PROJECT_ID" "$DATASET_ID"; then
        format-echo "SUCCESS" "Dataset creation completed successfully"
      else
        format-echo "ERROR" "Failed to create dataset"
        exit 1
      fi
      ;;
    delete-dataset)
      if delete_dataset "$PROJECT_ID" "$DATASET_ID"; then
        format-echo "SUCCESS" "Dataset deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete dataset"
        exit 1
      fi
      ;;
    list-datasets)
      if list_datasets "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed datasets successfully"
      else
        format-echo "ERROR" "Failed to list datasets"
        exit 1
      fi
      ;;
    get-dataset)
      if get_dataset "$PROJECT_ID" "$DATASET_ID"; then
        format-echo "SUCCESS" "Retrieved dataset details successfully"
      else
        format-echo "ERROR" "Failed to get dataset details"
        exit 1
      fi
      ;;
    create-table)
      if create_table "$PROJECT_ID" "$DATASET_ID" "$TABLE_ID"; then
        format-echo "SUCCESS" "Table creation completed successfully"
      else
        format-echo "ERROR" "Failed to create table"
        exit 1
      fi
      ;;
    query-table)
      local query_sql="$QUERY"
      if [ -n "$QUERY_FILE" ]; then
        query_sql=$(cat "$QUERY_FILE")
      fi
      if query_table "$PROJECT_ID" "$query_sql"; then
        format-echo "SUCCESS" "Query execution completed successfully"
      else
        format-echo "ERROR" "Failed to execute query"
        exit 1
      fi
      ;;
    load-data)
      local source="$SOURCE_FILE"
      if [ -n "$SOURCE_URI" ]; then
        source="$SOURCE_URI"
      fi
      if load_data "$PROJECT_ID" "$DATASET_ID" "$TABLE_ID" "$source"; then
        format-echo "SUCCESS" "Data loading completed successfully"
      else
        format-echo "ERROR" "Failed to load data"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP BigQuery Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
