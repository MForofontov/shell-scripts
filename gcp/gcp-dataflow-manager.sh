#!/usr/bin/env bash
# gcp-dataflow-manager.sh
# Script to manage GCP Dataflow jobs, pipelines, and streaming analytics.

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
JOB_NAME=""
JOB_ID=""
TEMPLATE_NAME=""
PIPELINE_FILE=""
REGION="us-central1"
ZONE="us-central1-a"
WORKER_MACHINE_TYPE="n1-standard-1"
MAX_WORKERS="10"
NUM_WORKERS="1"
DISK_SIZE_GB="20"
NETWORK=""
SUBNETWORK=""
USE_PUBLIC_IPS=true
STAGING_LOCATION=""
TEMP_LOCATION=""
INPUT_TOPIC=""
INPUT_SUBSCRIPTION=""
OUTPUT_TOPIC=""
OUTPUT_TABLE=""
INPUT_FILE=""
OUTPUT_FILE=""
WINDOW_SIZE="60s"
TEMPLATE_TYPE="batch"
SERVICE_ACCOUNT=""
LABELS=""
PARAMETERS=""
ENABLE_STREAMING_ENGINE=false
ENABLE_SHUFFLE_SERVICE=false
USE_DATAFLOW_PRIME=false
STREAMING=false
UPDATE=false
DRAIN=false
CANCEL=false
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Dataflow Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Dataflow jobs, pipelines, and streaming analytics."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mcreate-job\033[0m               Create and run a Dataflow job"
  echo -e "  \033[1;33mupdate-job\033[0m               Update a running Dataflow job"
  echo -e "  \033[1;33mcancel-job\033[0m               Cancel a Dataflow job"
  echo -e "  \033[1;33mdrain-job\033[0m                Drain a streaming Dataflow job"
  echo -e "  \033[1;33mlist-jobs\033[0m                List Dataflow jobs"
  echo -e "  \033[1;33mget-job\033[0m                  Get job details"
  echo -e "  \033[1;33mget-job-logs\033[0m             Get job logs"
  echo -e "  \033[1;33mget-job-metrics\033[0m          Get job metrics"
  echo -e "  \033[1;33mcreate-template\033[0m          Create a Dataflow template"
  echo -e "  \033[1;33mrun-template\033[0m             Run a job from template"
  echo -e "  \033[1;33mlist-templates\033[0m           List available templates"
  echo -e "  \033[1;33mget-template\033[0m             Get template details"
  echo -e "  \033[1;33mcreate-flex-template\033[0m     Create a Flex template"
  echo -e "  \033[1;33mrun-flex-template\033[0m        Run a job from Flex template"
  echo -e "  \033[1;33mgenerate-pipeline\033[0m        Generate sample pipeline code"
  echo -e "  \033[1;33mvalidate-pipeline\033[0m        Validate pipeline configuration"
  echo -e "  \033[1;33mget-quota\033[0m                Get Dataflow quotas and limits"
  echo -e "  \033[1;33mmonitor-job\033[0m              Monitor job progress"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--job-name <name>\033[0m                (Required for job actions) Job name"
  echo -e "  \033[1;33m--job-id <id>\033[0m                    (Required for some actions) Job ID"
  echo -e "  \033[1;33m--template <name>\033[0m                (Required for template actions) Template name"
  echo -e "  \033[1;33m--pipeline-file <file>\033[0m           (Required for pipeline actions) Pipeline file path"
  echo -e "  \033[1;33m--region <region>\033[0m                (Optional) Region (default: us-central1)"
  echo -e "  \033[1;33m--zone <zone>\033[0m                    (Optional) Zone (default: us-central1-a)"
  echo -e "  \033[1;33m--worker-machine-type <type>\033[0m     (Optional) Worker machine type (default: n1-standard-1)"
  echo -e "  \033[1;33m--max-workers <count>\033[0m            (Optional) Maximum workers (default: 10)"
  echo -e "  \033[1;33m--num-workers <count>\033[0m            (Optional) Initial workers (default: 1)"
  echo -e "  \033[1;33m--disk-size <gb>\033[0m                 (Optional) Worker disk size (default: 20GB)"
  echo -e "  \033[1;33m--network <network>\033[0m              (Optional) Network name"
  echo -e "  \033[1;33m--subnetwork <subnet>\033[0m            (Optional) Subnetwork name"
  echo -e "  \033[1;33m--no-public-ips\033[0m                  (Optional) Disable public IPs for workers"
  echo -e "  \033[1;33m--staging-location <uri>\033[0m         (Optional) GCS staging location"
  echo -e "  \033[1;33m--temp-location <uri>\033[0m            (Optional) GCS temp location"
  echo -e "  \033[1;33m--input-topic <topic>\033[0m            (Optional) Input Pub/Sub topic"
  echo -e "  \033[1;33m--input-subscription <sub>\033[0m       (Optional) Input Pub/Sub subscription"
  echo -e "  \033[1;33m--output-topic <topic>\033[0m           (Optional) Output Pub/Sub topic"
  echo -e "  \033[1;33m--output-table <table>\033[0m           (Optional) Output BigQuery table"
  echo -e "  \033[1;33m--input-file <file>\033[0m              (Optional) Input file pattern"
  echo -e "  \033[1;33m--output-file <file>\033[0m             (Optional) Output file pattern"
  echo -e "  \033[1;33m--window-size <duration>\033[0m         (Optional) Window size for streaming (default: 60s)"
  echo -e "  \033[1;33m--template-type <type>\033[0m           (Optional) Template type: batch, streaming (default: batch)"
  echo -e "  \033[1;33m--service-account <email>\033[0m        (Optional) Service account email"
  echo -e "  \033[1;33m--labels <labels>\033[0m                (Optional) Job labels (key=value,key2=value2)"
  echo -e "  \033[1;33m--parameters <params>\033[0m            (Optional) Template parameters (key=value,key2=value2)"
  echo -e "  \033[1;33m--streaming\033[0m                      (Optional) Create streaming job"
  echo -e "  \033[1;33m--enable-streaming-engine\033[0m        (Optional) Enable Streaming Engine"
  echo -e "  \033[1;33m--enable-shuffle-service\033[0m         (Optional) Enable Dataflow Shuffle Service"
  echo -e "  \033[1;33m--use-dataflow-prime\033[0m             (Optional) Use Dataflow Prime"
  echo -e "  \033[1;33m--update\033[0m                         (Optional) Update existing job"
  echo -e "  \033[1;33m--drain\033[0m                          (Optional) Drain job"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-jobs --project my-project --region us-central1"
  echo "  $0 create-job --project my-project --job-name word-count --pipeline-file wordcount.py"
  echo "  $0 run-template --project my-project --template gs://bucket/templates/template --job-name template-job"
  echo "  $0 create-job --project my-project --job-name streaming-job --streaming --input-topic my-topic --output-table my-dataset.my-table"
  echo "  $0 cancel-job --project my-project --job-id 2023-01-01_12_00_00-123456789"
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
      --template)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No template name provided after --template."
          usage
        fi
        TEMPLATE_NAME="$2"
        shift 2
        ;;
      --pipeline-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No pipeline file provided after --pipeline-file."
          usage
        fi
        PIPELINE_FILE="$2"
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
      --worker-machine-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No worker machine type provided after --worker-machine-type."
          usage
        fi
        WORKER_MACHINE_TYPE="$2"
        shift 2
        ;;
      --max-workers)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max workers provided after --max-workers."
          usage
        fi
        MAX_WORKERS="$2"
        shift 2
        ;;
      --num-workers)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No num workers provided after --num-workers."
          usage
        fi
        NUM_WORKERS="$2"
        shift 2
        ;;
      --disk-size)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No disk size provided after --disk-size."
          usage
        fi
        DISK_SIZE_GB="$2"
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
      --subnetwork)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No subnetwork provided after --subnetwork."
          usage
        fi
        SUBNETWORK="$2"
        shift 2
        ;;
      --no-public-ips)
        USE_PUBLIC_IPS=false
        shift
        ;;
      --staging-location)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No staging location provided after --staging-location."
          usage
        fi
        STAGING_LOCATION="$2"
        shift 2
        ;;
      --temp-location)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No temp location provided after --temp-location."
          usage
        fi
        TEMP_LOCATION="$2"
        shift 2
        ;;
      --input-topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No input topic provided after --input-topic."
          usage
        fi
        INPUT_TOPIC="$2"
        shift 2
        ;;
      --input-subscription)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No input subscription provided after --input-subscription."
          usage
        fi
        INPUT_SUBSCRIPTION="$2"
        shift 2
        ;;
      --output-topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No output topic provided after --output-topic."
          usage
        fi
        OUTPUT_TOPIC="$2"
        shift 2
        ;;
      --output-table)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No output table provided after --output-table."
          usage
        fi
        OUTPUT_TABLE="$2"
        shift 2
        ;;
      --input-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No input file provided after --input-file."
          usage
        fi
        INPUT_FILE="$2"
        shift 2
        ;;
      --output-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No output file provided after --output-file."
          usage
        fi
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --window-size)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No window size provided after --window-size."
          usage
        fi
        WINDOW_SIZE="$2"
        shift 2
        ;;
      --template-type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No template type provided after --template-type."
          usage
        fi
        TEMPLATE_TYPE="$2"
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
      --labels)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No labels provided after --labels."
          usage
        fi
        LABELS="$2"
        shift 2
        ;;
      --parameters)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No parameters provided after --parameters."
          usage
        fi
        PARAMETERS="$2"
        shift 2
        ;;
      --streaming)
        STREAMING=true
        shift
        ;;
      --enable-streaming-engine)
        ENABLE_STREAMING_ENGINE=true
        shift
        ;;
      --enable-shuffle-service)
        ENABLE_SHUFFLE_SERVICE=true
        shift
        ;;
      --use-dataflow-prime)
        USE_DATAFLOW_PRIME=true
        shift
        ;;
      --update)
        UPDATE=true
        shift
        ;;
      --drain)
        DRAIN=true
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

# Function to validate pipeline file
validate_pipeline_file() {
  if [ -n "$PIPELINE_FILE" ] && [ ! -f "$PIPELINE_FILE" ]; then
    format-echo "ERROR" "Pipeline file not found: $PIPELINE_FILE"
    return 1
  fi
  return 0
}

#=====================================================================
# JOB MANAGEMENT
#=====================================================================
# Function to create Dataflow job
create_job() {
  local project="$1"
  local job_name="$2"
  local pipeline_file="$3"
  
  format-echo "INFO" "Creating Dataflow job: $job_name"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create job:"
    format-echo "INFO" "  Name: $job_name"
    format-echo "INFO" "  Pipeline: $pipeline_file"
    format-echo "INFO" "  Region: $REGION"
    format-echo "INFO" "  Streaming: $STREAMING"
    return 0
  fi
  
  # For demonstration, this would typically use Apache Beam SDK
  # Here we'll show the gcloud command structure
  local create_cmd="gcloud dataflow jobs run $job_name"
  create_cmd+=" --project=$project"
  create_cmd+=" --region=$REGION"
  create_cmd+=" --gcs-location=$pipeline_file"
  
  # Worker configuration
  create_cmd+=" --worker-machine-type=$WORKER_MACHINE_TYPE"
  create_cmd+=" --max-workers=$MAX_WORKERS"
  create_cmd+=" --num-workers=$NUM_WORKERS"
  
  # Storage locations
  if [ -n "$STAGING_LOCATION" ]; then
    create_cmd+=" --staging-location=$STAGING_LOCATION"
  fi
  
  if [ -n "$TEMP_LOCATION" ]; then
    create_cmd+=" --temp-location=$TEMP_LOCATION"
  fi
  
  # Network configuration
  if [ -n "$NETWORK" ]; then
    create_cmd+=" --network=$NETWORK"
  fi
  
  if [ -n "$SUBNETWORK" ]; then
    create_cmd+=" --subnetwork=$SUBNETWORK"
  fi
  
  if [ "$USE_PUBLIC_IPS" = false ]; then
    create_cmd+=" --no-use-public-ips"
  fi
  
  # Service account
  if [ -n "$SERVICE_ACCOUNT" ]; then
    create_cmd+=" --service-account-email=$SERVICE_ACCOUNT"
  fi
  
  # Streaming options
  if [ "$STREAMING" = true ]; then
    create_cmd+=" --streaming"
    
    if [ "$ENABLE_STREAMING_ENGINE" = true ]; then
      create_cmd+=" --enable-streaming-engine"
    fi
  fi
  
  # Dataflow enhancements
  if [ "$ENABLE_SHUFFLE_SERVICE" = true ]; then
    create_cmd+=" --enable-shuffle-service"
  fi
  
  if [ "$USE_DATAFLOW_PRIME" = true ]; then
    create_cmd+=" --dataflow-kms-key=projects/$project/locations/$REGION/keyRings/dataflow/cryptoKeys/prime"
  fi
  
  # Parameters
  if [ -n "$PARAMETERS" ]; then
    create_cmd+=" --parameters=$PARAMETERS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create job: $job_name"
    return 1
  fi
  
  format-echo "SUCCESS" "Created Dataflow job: $job_name"
  return 0
}

# Function to cancel job
cancel_job() {
  local project="$1"
  local job_id="$2"
  
  format-echo "INFO" "Cancelling Dataflow job: $job_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would cancel job: $job_id"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will cancel the job '$job_id'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud dataflow jobs cancel "$job_id" \
    --project="$project" \
    --region="$REGION"; then
    format-echo "ERROR" "Failed to cancel job: $job_id"
    return 1
  fi
  
  format-echo "SUCCESS" "Cancelled Dataflow job: $job_id"
  return 0
}

# Function to drain job
drain_job() {
  local project="$1"
  local job_id="$2"
  
  format-echo "INFO" "Draining Dataflow job: $job_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would drain job: $job_id"
    return 0
  fi
  
  if ! gcloud dataflow jobs drain "$job_id" \
    --project="$project" \
    --region="$REGION"; then
    format-echo "ERROR" "Failed to drain job: $job_id"
    return 1
  fi
  
  format-echo "SUCCESS" "Draining Dataflow job: $job_id"
  return 0
}

# Function to list jobs
list_jobs() {
  local project="$1"
  
  format-echo "INFO" "Listing Dataflow jobs"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list jobs"
    return 0
  fi
  
  if ! gcloud dataflow jobs list \
    --project="$project" \
    --region="$REGION" \
    --format="table(jobId,name,type,currentState,createTime)"; then
    format-echo "ERROR" "Failed to list jobs"
    return 1
  fi
  
  return 0
}

# Function to get job details
get_job() {
  local project="$1"
  local job_id="$2"
  
  format-echo "INFO" "Getting details for job: $job_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get job details: $job_id"
    return 0
  fi
  
  if ! gcloud dataflow jobs describe "$job_id" \
    --project="$project" \
    --region="$REGION"; then
    format-echo "ERROR" "Failed to get job details: $job_id"
    return 1
  fi
  
  return 0
}

# Function to run template
run_template() {
  local project="$1"
  local template="$2"
  local job_name="$3"
  
  format-echo "INFO" "Running Dataflow template: $template"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would run template:"
    format-echo "INFO" "  Template: $template"
    format-echo "INFO" "  Job name: $job_name"
    return 0
  fi
  
  local run_cmd="gcloud dataflow jobs run $job_name"
  run_cmd+=" --project=$project"
  run_cmd+=" --region=$REGION"
  run_cmd+=" --gcs-location=$template"
  
  if [ -n "$PARAMETERS" ]; then
    run_cmd+=" --parameters=$PARAMETERS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $run_cmd"
  fi
  
  if ! eval "$run_cmd"; then
    format-echo "ERROR" "Failed to run template: $template"
    return 1
  fi
  
  format-echo "SUCCESS" "Started job from template: $template"
  return 0
}

# Function to generate sample pipeline
generate_pipeline() {
  local pipeline_type="${1:-batch}"
  
  format-echo "INFO" "Generating sample pipeline: $pipeline_type"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would generate sample pipeline"
    return 0
  fi
  
  local pipeline_dir="./dataflow-pipeline-$pipeline_type"
  mkdir -p "$pipeline_dir"
  
  # Generate Python Apache Beam pipeline
  cat > "$pipeline_dir/main.py" << 'EOF'
import argparse
import logging
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, StandardOptions


def run_pipeline(input_file, output_file, pipeline_args=None):
    """Run the pipeline with specified input and output."""
    
    pipeline_options = PipelineOptions(pipeline_args)
    
    with beam.Pipeline(options=pipeline_options) as pipeline:
        
        # Read from input
        lines = (pipeline
                | 'Read' >> beam.io.ReadFromText(input_file)
                | 'Split' >> beam.FlatMap(lambda line: line.split())
                | 'PairWithOne' >> beam.Map(lambda word: (word, 1))
                | 'GroupAndSum' >> beam.CombinePerKey(sum)
                | 'Format' >> beam.Map(lambda word_count: f'{word_count[0]}: {word_count[1]}'))
        
        # Write to output
        lines | 'Write' >> beam.io.WriteToText(output_file)


def run_streaming_pipeline(input_topic, output_table, pipeline_args=None):
    """Run a streaming pipeline."""
    
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(StandardOptions).streaming = True
    
    with beam.Pipeline(options=pipeline_options) as pipeline:
        
        # Read from Pub/Sub
        messages = (pipeline
                   | 'Read from Pub/Sub' >> beam.io.ReadFromPubSub(topic=input_topic)
                   | 'Decode' >> beam.Map(lambda message: message.decode('utf-8'))
                   | 'Window' >> beam.WindowInto(beam.window.FixedWindows(60))
                   | 'Count per window' >> beam.combiners.Count.Globally().without_defaults())
        
        # Write to BigQuery
        messages | 'Write to BigQuery' >> beam.io.WriteToBigQuery(
            table=output_table,
            schema='message_count:INTEGER,window_start:TIMESTAMP',
            write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
            create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED)


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_file', help='Input file pattern')
    parser.add_argument('--output_file', help='Output file pattern')
    parser.add_argument('--input_topic', help='Input Pub/Sub topic')
    parser.add_argument('--output_table', help='Output BigQuery table')
    parser.add_argument('--streaming', action='store_true', help='Run as streaming pipeline')
    
    known_args, pipeline_args = parser.parse_known_args()
    
    if known_args.streaming:
        run_streaming_pipeline(
            known_args.input_topic,
            known_args.output_table,
            pipeline_args)
    else:
        run_pipeline(
            known_args.input_file,
            known_args.output_file,
            pipeline_args)
EOF
  
  # Generate requirements.txt
  cat > "$pipeline_dir/requirements.txt" << 'EOF'
apache-beam[gcp]==2.50.0
google-cloud-pubsub==2.18.1
google-cloud-bigquery==3.11.4
EOF
  
  # Generate setup script
  cat > "$pipeline_dir/setup.sh" << 'EOF'
#!/bin/bash
# Setup script for Dataflow pipeline

set -e

echo "Setting up Dataflow pipeline environment..."

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

echo "Environment setup complete!"
echo "To activate: source venv/bin/activate"
echo "To run locally: python main.py --input_file=input.txt --output_file=output.txt --runner=DirectRunner"
echo "To run on Dataflow: python main.py --input_file=gs://bucket/input.txt --output_file=gs://bucket/output --runner=DataflowRunner --project=PROJECT_ID --region=us-central1 --temp_location=gs://bucket/temp"
EOF
  
  chmod +x "$pipeline_dir/setup.sh"
  
  format-echo "SUCCESS" "Generated sample pipeline in: $pipeline_dir"
  format-echo "INFO" "Run: cd $pipeline_dir && ./setup.sh to set up the environment"
  
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
  
  print_with_separator "GCP Dataflow Manager Script"
  format-echo "INFO" "Starting GCP Dataflow Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Dataflow Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Dataflow Manager Script"
    exit 1
  fi
  
  # Validate pipeline file
  if ! validate_pipeline_file; then
    print_with_separator "End of GCP Dataflow Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Dataflow Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-job)
      if [ -z "$JOB_NAME" ]; then
        format-echo "ERROR" "Job name is required for action: $ACTION"
        exit 1
      fi
      ;;
    cancel-job|drain-job|get-job|get-job-logs|get-job-metrics)
      if [ -z "$JOB_ID" ]; then
        format-echo "ERROR" "Job ID is required for action: $ACTION"
        exit 1
      fi
      ;;
    run-template|run-flex-template)
      if [ -z "$TEMPLATE_NAME" ] || [ -z "$JOB_NAME" ]; then
        format-echo "ERROR" "Template name and job name are required for action: $ACTION"
        exit 1
      fi
      ;;
    list-jobs|list-templates|get-quota|generate-pipeline)
      # No additional requirements for these actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-job, update-job, cancel-job, drain-job, list-jobs, get-job, get-job-logs, get-job-metrics, create-template, run-template, list-templates, get-template, generate-pipeline, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-job)
      if create_job "$PROJECT_ID" "$JOB_NAME" "$PIPELINE_FILE"; then
        format-echo "SUCCESS" "Job creation completed successfully"
      else
        format-echo "ERROR" "Failed to create job"
        exit 1
      fi
      ;;
    cancel-job)
      if cancel_job "$PROJECT_ID" "$JOB_ID"; then
        format-echo "SUCCESS" "Job cancellation completed successfully"
      else
        format-echo "ERROR" "Failed to cancel job"
        exit 1
      fi
      ;;
    drain-job)
      if drain_job "$PROJECT_ID" "$JOB_ID"; then
        format-echo "SUCCESS" "Job drain initiated successfully"
      else
        format-echo "ERROR" "Failed to drain job"
        exit 1
      fi
      ;;
    list-jobs)
      if list_jobs "$PROJECT_ID"; then
        format-echo "SUCCESS" "Listed jobs successfully"
      else
        format-echo "ERROR" "Failed to list jobs"
        exit 1
      fi
      ;;
    get-job)
      if get_job "$PROJECT_ID" "$JOB_ID"; then
        format-echo "SUCCESS" "Retrieved job details successfully"
      else
        format-echo "ERROR" "Failed to get job details"
        exit 1
      fi
      ;;
    run-template)
      if run_template "$PROJECT_ID" "$TEMPLATE_NAME" "$JOB_NAME"; then
        format-echo "SUCCESS" "Template execution completed successfully"
      else
        format-echo "ERROR" "Failed to run template"
        exit 1
      fi
      ;;
    generate-pipeline)
      if generate_pipeline "$TEMPLATE_TYPE"; then
        format-echo "SUCCESS" "Pipeline generation completed successfully"
      else
        format-echo "ERROR" "Failed to generate pipeline"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Dataflow Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
