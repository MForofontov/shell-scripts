#!/usr/bin/env bash
# gcp-firestore-manager.sh
# Script to manage Google Cloud Firestore resources

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
DATABASE_ID=""
COLLECTION_PATH=""
DOCUMENT_ID=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Firestore Manager"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages Google Cloud Firestore (NoSQL document database) resources."
  echo "  Provides comprehensive management capabilities for Firestore databases and documents."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [OPTIONS] <command>"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m-p, --project PROJECT_ID\033[0m    Set GCP project ID"
  echo -e "  \033[1;33m-d, --database DATABASE_ID\033[0m  Set Firestore database ID"
  echo -e "  \033[1;33m-c, --collection PATH\033[0m       Set collection path"
  echo -e "  \033[1;33m-i, --document-id DOC_ID\033[0m    Set document ID"
  echo -e "  \033[1;33m-h, --help\033[0m                  Show this help message"
  echo
  echo -e "\033[1;34mCommands:\033[0m"
  echo -e "  \033[1;36mcreate-database\033[0m             Create new Firestore database"
  echo -e "  \033[1;36mlist-databases\033[0m              List Firestore databases"
  echo -e "  \033[1;36mdelete-database\033[0m             Delete Firestore database"
  echo -e "  \033[1;36mlist-collections\033[0m            List collections in database"
  echo -e "  \033[1;36mlist-documents\033[0m              List documents in collection"
  echo -e "  \033[1;36mget-document\033[0m                Get specific document"
  echo -e "  \033[1;36mdelete-document\033[0m             Delete specific document"
  echo -e "  \033[1;36mexport\033[0m                      Export Firestore data"
  echo -e "  \033[1;36mimport\033[0m                      Import Firestore data"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 -p my-project list-databases"
  echo "  $0 --project my-project --database my-db list-collections"
  echo "  $0 -p my-project -d my-db -c users list-documents"
  echo "  $0 -p my-project -d my-db -c users -i user123 get-document"
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
      -d|--database)
        if [[ -n "${2:-}" ]]; then
          DATABASE_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --database"
          usage
        fi
        ;;
      -c|--collection)
        if [[ -n "${2:-}" ]]; then
          COLLECTION_PATH="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --collection"
          usage
        fi
        ;;
      -i|--document-id)
        if [[ -n "${2:-}" ]]; then
          DOCUMENT_ID="$2"
          shift 2
        else
          format-echo "ERROR" "Missing argument for --document-id"
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
    "firestore.googleapis.com"
    "appengine.googleapis.com"
  )
  
  for api in "${apis[@]}"; do
    format-echo "INFO" "Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID" >/dev/null 2>&1
  done
}

#=====================================================================
# FIRESTORE OPERATIONS
#=====================================================================
create_database() {
  format-echo "INFO" "Creating Firestore database..."
  
  if [[ -z "$DATABASE_ID" ]]; then
    DATABASE_ID="(default)"
  fi
  
  gcloud firestore databases create --database="$DATABASE_ID" --location=us-central1 --project="$PROJECT_ID"
  format-echo "SUCCESS" "Firestore database created successfully"
}

list_databases() {
  format-echo "INFO" "Listing Firestore databases..."
  
  print_with_separator "Firestore Databases"
  gcloud firestore databases list --project="$PROJECT_ID"
  print_with_separator "End of Firestore Databases"
}

delete_database() {
  format-echo "INFO" "Deleting Firestore database..."
  
  if [[ -z "$DATABASE_ID" ]]; then
    format-echo "ERROR" "Database ID is required for delete operation"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the database and all its data"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud firestore databases delete --database="$DATABASE_ID" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Firestore database deleted successfully"
}

list_collections() {
  format-echo "INFO" "Listing Firestore collections..."
  
  if [[ -z "$DATABASE_ID" ]]; then
    DATABASE_ID="(default)"
  fi
  
  print_with_separator "Firestore Collections"
  gcloud firestore collections list --database="$DATABASE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Firestore Collections"
}

list_documents() {
  format-echo "INFO" "Listing Firestore documents..."
  
  if [[ -z "$DATABASE_ID" ]]; then
    DATABASE_ID="(default)"
  fi
  
  if [[ -z "$COLLECTION_PATH" ]]; then
    format-echo "ERROR" "Collection path is required for listing documents"
    exit 1
  fi
  
  print_with_separator "Firestore Documents in $COLLECTION_PATH"
  gcloud firestore documents list --database="$DATABASE_ID" --collection-ids="$COLLECTION_PATH" --project="$PROJECT_ID"
  print_with_separator "End of Firestore Documents"
}

get_document() {
  format-echo "INFO" "Getting Firestore document..."
  
  if [[ -z "$DATABASE_ID" ]]; then
    DATABASE_ID="(default)"
  fi
  
  if [[ -z "$COLLECTION_PATH" ]] || [[ -z "$DOCUMENT_ID" ]]; then
    format-echo "ERROR" "Collection path and document ID are required"
    exit 1
  fi
  
  print_with_separator "Firestore Document: $COLLECTION_PATH/$DOCUMENT_ID"
  gcloud firestore documents describe "$COLLECTION_PATH/$DOCUMENT_ID" --database="$DATABASE_ID" --project="$PROJECT_ID"
  print_with_separator "End of Firestore Document"
}

delete_document() {
  format-echo "INFO" "Deleting Firestore document..."
  
  if [[ -z "$DATABASE_ID" ]]; then
    DATABASE_ID="(default)"
  fi
  
  if [[ -z "$COLLECTION_PATH" ]] || [[ -z "$DOCUMENT_ID" ]]; then
    format-echo "ERROR" "Collection path and document ID are required"
    exit 1
  fi
  
  format-echo "WARNING" "This will permanently delete the document"
  read -p "Are you sure? (y/N): " confirm
  if [[ $confirm != [yY] ]]; then
    format-echo "INFO" "Operation cancelled"
    return 0
  fi
  
  gcloud firestore documents delete "$COLLECTION_PATH/$DOCUMENT_ID" --database="$DATABASE_ID" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Firestore document deleted successfully"
}

export_data() {
  format-echo "INFO" "Exporting Firestore data..."
  
  if [[ -z "$DATABASE_ID" ]]; then
    DATABASE_ID="(default)"
  fi
  
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local bucket_name="gs://${PROJECT_ID}-firestore-backup-${timestamp}"
  
  format-echo "INFO" "Creating backup bucket: $bucket_name"
  gsutil mb "$bucket_name" 2>/dev/null || true
  
  gcloud firestore export "$bucket_name" --database="$DATABASE_ID" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Firestore data exported to $bucket_name"
}

import_data() {
  format-echo "INFO" "Importing Firestore data..."
  format-echo "WARNING" "Please specify the GCS bucket URI containing the export"
  format-echo "INFO" "Example: gs://my-project-firestore-backup-20231201_120000"
  
  read -p "Enter GCS bucket URI: " bucket_uri
  if [[ -z "$bucket_uri" ]]; then
    format-echo "ERROR" "Bucket URI is required"
    exit 1
  fi
  
  if [[ -z "$DATABASE_ID" ]]; then
    DATABASE_ID="(default)"
  fi
  
  gcloud firestore import "$bucket_uri" --database="$DATABASE_ID" --project="$PROJECT_ID"
  format-echo "SUCCESS" "Firestore data imported successfully"
}

#=====================================================================
# COMMAND EXECUTION
#=====================================================================
execute_command() {
  case "$COMMAND" in
    create-database)
      enable_apis
      create_database
      ;;
    list-databases)
      list_databases
      ;;
    delete-database)
      delete_database
      ;;
    list-collections)
      list_collections
      ;;
    list-documents)
      list_documents
      ;;
    get-document)
      get_document
      ;;
    delete-document)
      delete_document
      ;;
    export)
      export_data
      ;;
    import)
      import_data
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
  
  print_with_separator "GCP Firestore Manager"
  format-echo "INFO" "Starting Firestore management operations..."
  
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
  format-echo "SUCCESS" "Firestore management operation completed successfully."
  print_with_separator "End of GCP Firestore Manager"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
exit $?