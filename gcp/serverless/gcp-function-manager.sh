#!/usr/bin/env bash
# gcp-function-manager.sh
# Script to manage GCP Cloud Functions (1st and 2nd gen).

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
FUNCTION_NAME=""
REGION="us-central1"
SOURCE_DIR=""
SOURCE_BUCKET=""
ENTRY_POINT=""
RUNTIME="python39"
TRIGGER_TYPE="http"
TRIGGER_TOPIC=""
TRIGGER_BUCKET=""
TRIGGER_EVENT=""
MEMORY="256MB"
TIMEOUT="60s"
ENV_VARS=""
ENV_FILE=""
LABELS=""
SERVICE_ACCOUNT=""
VPC_CONNECTOR=""
INGRESS="all"
EGRESS="private-ranges-only"
MIN_INSTANCES="0"
MAX_INSTANCES="1000"
CONCURRENCY="1"
GEN="1"
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud Functions Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Cloud Functions (1st and 2nd generation)."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mdeploy-function\033[0m      Deploy a Cloud Function"
  echo -e "  \033[1;33mupdate-function\033[0m      Update an existing Cloud Function"
  echo -e "  \033[1;33mdelete-function\033[0m      Delete a Cloud Function"
  echo -e "  \033[1;33mlist-functions\033[0m       List all Cloud Functions"
  echo -e "  \033[1;33mget-function\033[0m         Get function details"
  echo -e "  \033[1;33mcall-function\033[0m        Invoke a Cloud Function"
  echo -e "  \033[1;33mget-logs\033[0m             Get function logs"
  echo -e "  \033[1;33mset-iam-policy\033[0m       Set IAM policy for function"
  echo -e "  \033[1;33mget-iam-policy\033[0m       Get IAM policy for function"
  echo -e "  \033[1;33mgenerate-source\033[0m      Generate sample function source"
  echo -e "  \033[1;33mtest-function\033[0m        Test function locally"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Required) GCP project ID"
  echo -e "  \033[1;33m--function <name>\033[0m            (Required for most actions) Function name"
  echo -e "  \033[1;33m--region <region>\033[0m            (Optional) Region (default: us-central1)"
  echo -e "  \033[1;33m--source <dir>\033[0m               (Optional) Source directory path"
  echo -e "  \033[1;33m--source-bucket <bucket>\033[0m     (Optional) Source bucket for deployment"
  echo -e "  \033[1;33m--entry-point <function>\033[0m     (Optional) Entry point function name"
  echo -e "  \033[1;33m--runtime <runtime>\033[0m          (Optional) Runtime (default: python39)"
  echo -e "  \033[1;33m--trigger <type>\033[0m             (Optional) Trigger type: http, pubsub, storage (default: http)"
  echo -e "  \033[1;33m--trigger-topic <topic>\033[0m      (Optional) Pub/Sub topic for trigger"
  echo -e "  \033[1;33m--trigger-bucket <bucket>\033[0m    (Optional) Storage bucket for trigger"
  echo -e "  \033[1;33m--trigger-event <event>\033[0m      (Optional) Storage event type"
  echo -e "  \033[1;33m--memory <size>\033[0m              (Optional) Memory allocation (default: 256MB)"
  echo -e "  \033[1;33m--timeout <duration>\033[0m         (Optional) Timeout (default: 60s)"
  echo -e "  \033[1;33m--env-vars <vars>\033[0m            (Optional) Environment variables (key=value,key2=value2)"
  echo -e "  \033[1;33m--env-file <file>\033[0m            (Optional) Environment variables file"
  echo -e "  \033[1;33m--labels <labels>\033[0m            (Optional) Labels (key=value,key2=value2)"
  echo -e "  \033[1;33m--service-account <email>\033[0m    (Optional) Service account email"
  echo -e "  \033[1;33m--vpc-connector <connector>\033[0m  (Optional) VPC connector"
  echo -e "  \033[1;33m--ingress <setting>\033[0m          (Optional) Ingress setting: all, internal-only (default: all)"
  echo -e "  \033[1;33m--egress <setting>\033[0m           (Optional) Egress setting: all, private-ranges-only (default: private-ranges-only)"
  echo -e "  \033[1;33m--min-instances <count>\033[0m      (Optional) Min instances (2nd gen only, default: 0)"
  echo -e "  \033[1;33m--max-instances <count>\033[0m      (Optional) Max instances (default: 1000)"
  echo -e "  \033[1;33m--concurrency <count>\033[0m        (Optional) Concurrency (2nd gen only, default: 1)"
  echo -e "  \033[1;33m--gen <generation>\033[0m           (Optional) Function generation: 1, 2 (default: 1)"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-functions --project my-project --region us-central1"
  echo "  $0 deploy-function --project my-project --function hello-world --source ./src --runtime python39"
  echo "  $0 deploy-function --project my-project --function pubsub-handler --trigger pubsub --trigger-topic my-topic"
  echo "  $0 call-function --project my-project --function hello-world --region us-central1"
  echo "  $0 get-logs --project my-project --function hello-world --region us-central1"
  echo "  $0 generate-source --function hello-world --runtime python39"
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
      --function)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No function name provided after --function."
          usage
        fi
        FUNCTION_NAME="$2"
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
      --source)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source directory provided after --source."
          usage
        fi
        SOURCE_DIR="$2"
        shift 2
        ;;
      --source-bucket)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No source bucket provided after --source-bucket."
          usage
        fi
        SOURCE_BUCKET="$2"
        shift 2
        ;;
      --entry-point)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No entry point provided after --entry-point."
          usage
        fi
        ENTRY_POINT="$2"
        shift 2
        ;;
      --runtime)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No runtime provided after --runtime."
          usage
        fi
        RUNTIME="$2"
        shift 2
        ;;
      --trigger)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No trigger type provided after --trigger."
          usage
        fi
        TRIGGER_TYPE="$2"
        shift 2
        ;;
      --trigger-topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No trigger topic provided after --trigger-topic."
          usage
        fi
        TRIGGER_TOPIC="$2"
        shift 2
        ;;
      --trigger-bucket)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No trigger bucket provided after --trigger-bucket."
          usage
        fi
        TRIGGER_BUCKET="$2"
        shift 2
        ;;
      --trigger-event)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No trigger event provided after --trigger-event."
          usage
        fi
        TRIGGER_EVENT="$2"
        shift 2
        ;;
      --memory)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No memory size provided after --memory."
          usage
        fi
        MEMORY="$2"
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
      --env-vars)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No environment variables provided after --env-vars."
          usage
        fi
        ENV_VARS="$2"
        shift 2
        ;;
      --env-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No environment file provided after --env-file."
          usage
        fi
        ENV_FILE="$2"
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
      --service-account)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No service account provided after --service-account."
          usage
        fi
        SERVICE_ACCOUNT="$2"
        shift 2
        ;;
      --vpc-connector)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No VPC connector provided after --vpc-connector."
          usage
        fi
        VPC_CONNECTOR="$2"
        shift 2
        ;;
      --ingress)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No ingress setting provided after --ingress."
          usage
        fi
        INGRESS="$2"
        shift 2
        ;;
      --egress)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No egress setting provided after --egress."
          usage
        fi
        EGRESS="$2"
        shift 2
        ;;
      --min-instances)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No min instances provided after --min-instances."
          usage
        fi
        MIN_INSTANCES="$2"
        shift 2
        ;;
      --max-instances)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No max instances provided after --max-instances."
          usage
        fi
        MAX_INSTANCES="$2"
        shift 2
        ;;
      --concurrency)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No concurrency provided after --concurrency."
          usage
        fi
        CONCURRENCY="$2"
        shift 2
        ;;
      --gen)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No generation provided after --gen."
          usage
        fi
        GEN="$2"
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

# Function to validate source directory
validate_source() {
  if [ -n "$SOURCE_DIR" ] && [ ! -d "$SOURCE_DIR" ]; then
    format-echo "ERROR" "Source directory not found: $SOURCE_DIR"
    return 1
  fi
  return 0
}

#=====================================================================
# CLOUD FUNCTIONS MANAGEMENT
#=====================================================================
# Function to deploy Cloud Function
deploy_function() {
  local project="$1"
  local function="$2"
  local region="$3"
  
  format-echo "INFO" "Deploying Cloud Function: $function (Gen $GEN)"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would deploy function:"
    format-echo "INFO" "  Name: $function"
    format-echo "INFO" "  Region: $region"
    format-echo "INFO" "  Runtime: $RUNTIME"
    format-echo "INFO" "  Trigger: $TRIGGER_TYPE"
    format-echo "INFO" "  Generation: $GEN"
    return 0
  fi
  
  local deploy_cmd
  if [ "$GEN" = "2" ]; then
    deploy_cmd="gcloud functions deploy $function"
    deploy_cmd+=" --gen2"
  else
    deploy_cmd="gcloud functions deploy $function"
  fi
  
  deploy_cmd+=" --project=$project"
  deploy_cmd+=" --region=$region"
  deploy_cmd+=" --runtime=$RUNTIME"
  deploy_cmd+=" --memory=$MEMORY"
  deploy_cmd+=" --timeout=$TIMEOUT"
  
  if [ -n "$SOURCE_DIR" ]; then
    deploy_cmd+=" --source=$SOURCE_DIR"
  fi
  
  if [ -n "$SOURCE_BUCKET" ]; then
    deploy_cmd+=" --source-bucket=$SOURCE_BUCKET"
  fi
  
  if [ -n "$ENTRY_POINT" ]; then
    deploy_cmd+=" --entry-point=$ENTRY_POINT"
  fi
  
  # Configure trigger
  case "$TRIGGER_TYPE" in
    http)
      deploy_cmd+=" --trigger-http"
      ;;
    pubsub)
      if [ -z "$TRIGGER_TOPIC" ]; then
        format-echo "ERROR" "Pub/Sub topic is required for pubsub trigger"
        return 1
      fi
      deploy_cmd+=" --trigger-topic=$TRIGGER_TOPIC"
      ;;
    storage)
      if [ -z "$TRIGGER_BUCKET" ]; then
        format-echo "ERROR" "Storage bucket is required for storage trigger"
        return 1
      fi
      deploy_cmd+=" --trigger-bucket=$TRIGGER_BUCKET"
      if [ -n "$TRIGGER_EVENT" ]; then
        deploy_cmd+=" --trigger-event=$TRIGGER_EVENT"
      fi
      ;;
  esac
  
  # Add environment variables
  if [ -n "$ENV_VARS" ]; then
    deploy_cmd+=" --set-env-vars=$ENV_VARS"
  fi
  
  if [ -n "$ENV_FILE" ]; then
    deploy_cmd+=" --env-vars-file=$ENV_FILE"
  fi
  
  # Add labels
  if [ -n "$LABELS" ]; then
    deploy_cmd+=" --update-labels=$LABELS"
  fi
  
  # Add service account
  if [ -n "$SERVICE_ACCOUNT" ]; then
    deploy_cmd+=" --service-account=$SERVICE_ACCOUNT"
  fi
  
  # Add VPC connector
  if [ -n "$VPC_CONNECTOR" ]; then
    deploy_cmd+=" --vpc-connector=$VPC_CONNECTOR"
    deploy_cmd+=" --vpc-connector-egress-settings=$EGRESS"
  fi
  
  # Add ingress settings
  deploy_cmd+=" --ingress-settings=$INGRESS"
  
  # Gen 2 specific settings
  if [ "$GEN" = "2" ]; then
    deploy_cmd+=" --min-instances=$MIN_INSTANCES"
    deploy_cmd+=" --max-instances=$MAX_INSTANCES"
    deploy_cmd+=" --concurrency=$CONCURRENCY"
  else
    deploy_cmd+=" --max-instances=$MAX_INSTANCES"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $deploy_cmd"
  fi
  
  if ! eval "$deploy_cmd"; then
    format-echo "ERROR" "Failed to deploy function: $function"
    return 1
  fi
  
  format-echo "SUCCESS" "Deployed Cloud Function: $function"
  return 0
}

# Function to update Cloud Function
update_function() {
  local project="$1"
  local function="$2"
  local region="$3"
  
  format-echo "INFO" "Updating Cloud Function: $function"
  
  # For simplicity, update uses the same logic as deploy
  # gcloud functions deploy handles both create and update
  deploy_function "$project" "$function" "$region"
}

# Function to delete Cloud Function
delete_function() {
  local project="$1"
  local function="$2"
  local region="$3"
  
  format-echo "INFO" "Deleting Cloud Function: $function"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would delete function: $function"
    return 0
  fi
  
  local delete_cmd="gcloud functions delete $function"
  delete_cmd+=" --project=$project"
  delete_cmd+=" --region=$region"
  delete_cmd+=" --quiet"
  
  if [ "$GEN" = "2" ]; then
    delete_cmd+=" --gen2"
  fi
  
  if ! eval "$delete_cmd"; then
    format-echo "ERROR" "Failed to delete function: $function"
    return 1
  fi
  
  format-echo "SUCCESS" "Deleted Cloud Function: $function"
  return 0
}

# Function to list Cloud Functions
list_functions() {
  local project="$1"
  local region="$2"
  
  format-echo "INFO" "Listing Cloud Functions in region: $region"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list functions"
    return 0
  fi
  
  if ! gcloud functions list \
    --project="$project" \
    --regions="$region" \
    --format="table(name,status,trigger:label=TRIGGER_TYPE,runtime)"; then
    format-echo "ERROR" "Failed to list functions"
    return 1
  fi
  
  return 0
}

# Function to get function details
get_function() {
  local project="$1"
  local function="$2"
  local region="$3"
  
  format-echo "INFO" "Getting details for function: $function"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get function details: $function"
    return 0
  fi
  
  local describe_cmd="gcloud functions describe $function"
  describe_cmd+=" --project=$project"
  describe_cmd+=" --region=$region"
  
  if [ "$GEN" = "2" ]; then
    describe_cmd+=" --gen2"
  fi
  
  if ! eval "$describe_cmd"; then
    format-echo "ERROR" "Failed to get function details: $function"
    return 1
  fi
  
  return 0
}

# Function to call Cloud Function
call_function() {
  local project="$1"
  local function="$2"
  local region="$3"
  
  format-echo "INFO" "Calling Cloud Function: $function"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would call function: $function"
    return 0
  fi
  
  local call_cmd="gcloud functions call $function"
  call_cmd+=" --project=$project"
  call_cmd+=" --region=$region"
  
  if [ "$GEN" = "2" ]; then
    call_cmd+=" --gen2"
  fi
  
  if ! eval "$call_cmd"; then
    format-echo "ERROR" "Failed to call function: $function"
    return 1
  fi
  
  format-echo "SUCCESS" "Called function: $function"
  return 0
}

# Function to get function logs
get_logs() {
  local project="$1"
  local function="$2"
  local region="$3"
  
  format-echo "INFO" "Getting logs for function: $function"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get function logs: $function"
    return 0
  fi
  
  if [ "$GEN" = "2" ]; then
    # For Gen 2 functions, use Cloud Logging
    if ! gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=$function" \
      --project="$project" \
      --limit=50 \
      --format="table(timestamp,severity,textPayload)"; then
      format-echo "ERROR" "Failed to get function logs: $function"
      return 1
    fi
  else
    # For Gen 1 functions, use functions logs
    if ! gcloud functions logs read "$function" \
      --project="$project" \
      --region="$region" \
      --limit=50; then
      format-echo "ERROR" "Failed to get function logs: $function"
      return 1
    fi
  fi
  
  return 0
}

# Function to generate sample source code
generate_source() {
  local function="${1:-hello_world}"
  local runtime="${2:-python39}"
  
  format-echo "INFO" "Generating sample source for function: $function"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would generate source code"
    return 0
  fi
  
  local source_dir="./function-$function"
  mkdir -p "$source_dir"
  
  case "$runtime" in
    python*|python3*)
      # Generate Python function
      cat > "$source_dir/main.py" << 'EOF'
import functions_framework
from flask import jsonify
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@functions_framework.http
def hello_world(request):
    """HTTP Cloud Function.
    Args:
        request (flask.Request): The request object.
    Returns:
        The response text, or any set of values that can be turned into a
        Response object using `make_response`.
    """
    # Handle CORS
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)
    
    # Set CORS headers for actual request
    headers = {'Access-Control-Allow-Origin': '*'}
    
    try:
        # Get request data
        request_json = request.get_json(silent=True)
        request_args = request.args
        
        name = None
        if request_json and 'name' in request_json:
            name = request_json['name']
        elif request_args and 'name' in request_args:
            name = request_args['name']
        else:
            name = 'World'
        
        logger.info(f'Processing request for name: {name}')
        
        response = {
            'message': f'Hello {name}!',
            'status': 'success',
            'timestamp': request.headers.get('X-Cloud-Trace-Context', 'unknown')
        }
        
        return (jsonify(response), 200, headers)
        
    except Exception as e:
        logger.error(f'Error processing request: {str(e)}')
        error_response = {
            'error': 'Internal server error',
            'status': 'error'
        }
        return (jsonify(error_response), 500, headers)

@functions_framework.cloud_event
def hello_pubsub(cloud_event):
    """Pub/Sub Cloud Function.
    Args:
        cloud_event: The CloudEvent containing the Pub/Sub message
    """
    import base64
    
    try:
        # Decode the Pub/Sub message
        message_data = cloud_event.data['message']['data']
        decoded_data = base64.b64decode(message_data).decode('utf-8')
        
        logger.info(f'Received Pub/Sub message: {decoded_data}')
        
        # Process the message here
        # ...
        
        logger.info('Message processed successfully')
        
    except Exception as e:
        logger.error(f'Error processing Pub/Sub message: {str(e)}')
        raise
EOF
      
      cat > "$source_dir/requirements.txt" << 'EOF'
functions-framework==3.*
flask==2.*
EOF
      
      cat > "$source_dir/.env.yaml" << 'EOF'
# Environment variables for local development
FUNCTION_TARGET: hello_world
PORT: 8080
EOF
      ;;
      
    nodejs*|node*)
      # Generate Node.js function
      cat > "$source_dir/index.js" << 'EOF'
const functions = require('@google-cloud/functions-framework');

// HTTP Cloud Function
functions.http('helloWorld', (req, res) => {
  // Handle CORS
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Max-Age', '3600');
    res.status(204).send('');
    return;
  }
  
  try {
    const name = req.query.name || req.body.name || 'World';
    
    console.log(`Processing request for name: ${name}`);
    
    const response = {
      message: `Hello ${name}!`,
      status: 'success',
      timestamp: new Date().toISOString()
    };
    
    res.status(200).json(response);
    
  } catch (error) {
    console.error('Error processing request:', error);
    res.status(500).json({
      error: 'Internal server error',
      status: 'error'
    });
  }
});

// Pub/Sub Cloud Function
functions.cloudEvent('helloPubSub', (cloudEvent) => {
  try {
    // Decode the Pub/Sub message
    const message = cloudEvent.data.message;
    const data = Buffer.from(message.data, 'base64').toString();
    
    console.log(`Received Pub/Sub message: ${data}`);
    
    // Process the message here
    // ...
    
    console.log('Message processed successfully');
    
  } catch (error) {
    console.error('Error processing Pub/Sub message:', error);
    throw error;
  }
});
EOF
      
      cat > "$source_dir/package.json" << 'EOF'
{
  "name": "cloud-function-sample",
  "version": "1.0.0",
  "description": "Sample Cloud Function",
  "main": "index.js",
  "scripts": {
    "start": "functions-framework --target=helloWorld",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
EOF
      ;;
      
    go*)
      # Generate Go function
      cat > "$source_dir/function.go" << 'EOF'
package function

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

// Response represents the function response
type Response struct {
	Message   string `json:"message"`
	Status    string `json:"status"`
	Timestamp string `json:"timestamp"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Error  string `json:"error"`
	Status string `json:"status"`
}

// HelloWorld is an HTTP Cloud Function
func HelloWorld(w http.ResponseWriter, r *http.Request) {
	// Handle CORS
	w.Header().Set("Access-Control-Allow-Origin", "*")
	
	if r.Method == "OPTIONS" {
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		w.Header().Set("Access-Control-Max-Age", "3600")
		w.WriteHeader(http.StatusNoContent)
		return
	}
	
	// Get name from query or form
	name := r.URL.Query().Get("name")
	if name == "" {
		name = r.FormValue("name")
	}
	if name == "" {
		name = "World"
	}
	
	log.Printf("Processing request for name: %s", name)
	
	response := Response{
		Message:   fmt.Sprintf("Hello %s!", name),
		Status:    "success",
		Timestamp: time.Now().Format(time.RFC3339),
	}
	
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding response: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
}
EOF
      
      cat > "$source_dir/go.mod" << 'EOF'
module function

go 1.19
EOF
      ;;
  esac
  
  format-echo "SUCCESS" "Generated sample source code in: $source_dir"
  format-echo "INFO" "To deploy: $0 deploy-function --project PROJECT_ID --function $function --source $source_dir --runtime $runtime"
  
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
  
  print_with_separator "GCP Cloud Functions Manager Script"
  format-echo "INFO" "Starting GCP Cloud Functions Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Cloud Functions Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Cloud Functions Manager Script"
    exit 1
  fi
  
  # Validate source directory if provided
  if ! validate_source; then
    print_with_separator "End of GCP Cloud Functions Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Cloud Functions Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    deploy-function|update-function|delete-function|get-function|call-function|get-logs|set-iam-policy|get-iam-policy)
      if [ -z "$FUNCTION_NAME" ]; then
        format-echo "ERROR" "Function name is required for action: $ACTION"
        exit 1
      fi
      ;;
    list-functions)
      # No additional requirements for list actions
      ;;
    generate-source|test-function)
      # Optional function name for these actions
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: deploy-function, update-function, delete-function, list-functions, get-function, call-function, get-logs, set-iam-policy, get-iam-policy, generate-source, test-function"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    deploy-function)
      if deploy_function "$PROJECT_ID" "$FUNCTION_NAME" "$REGION"; then
        format-echo "SUCCESS" "Function deployment completed successfully"
      else
        format-echo "ERROR" "Failed to deploy function"
        exit 1
      fi
      ;;
    update-function)
      if update_function "$PROJECT_ID" "$FUNCTION_NAME" "$REGION"; then
        format-echo "SUCCESS" "Function update completed successfully"
      else
        format-echo "ERROR" "Failed to update function"
        exit 1
      fi
      ;;
    delete-function)
      if delete_function "$PROJECT_ID" "$FUNCTION_NAME" "$REGION"; then
        format-echo "SUCCESS" "Function deletion completed successfully"
      else
        format-echo "ERROR" "Failed to delete function"
        exit 1
      fi
      ;;
    list-functions)
      if list_functions "$PROJECT_ID" "$REGION"; then
        format-echo "SUCCESS" "Listed functions successfully"
      else
        format-echo "ERROR" "Failed to list functions"
        exit 1
      fi
      ;;
    get-function)
      if get_function "$PROJECT_ID" "$FUNCTION_NAME" "$REGION"; then
        format-echo "SUCCESS" "Retrieved function details successfully"
      else
        format-echo "ERROR" "Failed to get function details"
        exit 1
      fi
      ;;
    call-function)
      if call_function "$PROJECT_ID" "$FUNCTION_NAME" "$REGION"; then
        format-echo "SUCCESS" "Function call completed successfully"
      else
        format-echo "ERROR" "Failed to call function"
        exit 1
      fi
      ;;
    get-logs)
      if get_logs "$PROJECT_ID" "$FUNCTION_NAME" "$REGION"; then
        format-echo "SUCCESS" "Retrieved function logs successfully"
      else
        format-echo "ERROR" "Failed to get function logs"
        exit 1
      fi
      ;;
    generate-source)
      if generate_source "$FUNCTION_NAME" "$RUNTIME"; then
        format-echo "SUCCESS" "Source code generation completed successfully"
      else
        format-echo "ERROR" "Failed to generate source code"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Cloud Functions Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
