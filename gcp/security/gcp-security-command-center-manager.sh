#!/bin/bash

# GCP Security Command Center Manager Script
# This script manages Security Command Center for security posture management

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../functions/common-init.sh"

# Global variables
PROJECT_ID=""
ORGANIZATION_ID=""
SOURCE_ID=""
FINDING_ID=""
ASSET_NAME=""

# Function to display usage
usage() {
    print_with_separator "GCP Security Command Center Manager"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --project PROJECT_ID       Set GCP project ID"
    echo "  -o, --organization ORG_ID       Set organization ID"
    echo "  -h, --help                      Show this help message"
    echo ""
    echo "Commands:"
    echo "  list-assets                     List security assets"
    echo "  list-findings                   List security findings"
    echo "  create-finding                  Create a custom finding"
    echo "  update-finding                  Update finding state"
    echo "  list-sources                    List security sources"
    echo "  create-source                   Create custom security source"
    echo "  get-iam-policy                  Get organization IAM policy"
    echo "  test-iam-permissions            Test IAM permissions"
    echo "  run-asset-discovery             Run asset discovery"
    echo "  export-assets                   Export assets to Cloud Storage"
    echo "  create-notification             Create notification config"
    echo "  list-notifications              List notification configs"
    echo "  delete-notification             Delete notification config"
    echo "  get-organization-settings       Get organization settings"
    echo "  update-organization-settings    Update organization settings"
    echo ""
}

# Function to check if gcloud is authenticated
check_auth() {
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        print_error "Not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    fi
}

# Function to set project and organization
set_project() {
    if [[ -z "$PROJECT_ID" ]]; then
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
        if [[ -z "$PROJECT_ID" ]]; then
            print_error "No project set. Use -p flag or run 'gcloud config set project PROJECT_ID'"
            exit 1
        fi
    fi
    
    if [[ -z "$ORGANIZATION_ID" ]]; then
        read -p "Enter organization ID: " ORGANIZATION_ID
        if [[ -z "$ORGANIZATION_ID" ]]; then
            print_error "Organization ID is required for Security Command Center"
            exit 1
        fi
    fi
    
    print_info "Using project: $PROJECT_ID"
    print_info "Using organization: $ORGANIZATION_ID"
    gcloud config set project "$PROJECT_ID"
}

# Function to enable required APIs
enable_apis() {
    print_info "Enabling required APIs..."
    
    local apis=(
        "securitycenter.googleapis.com"
        "cloudasset.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_info "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID"
    done
}

# Function to list security assets
list_assets() {
    print_info "Listing security assets..."
    
    read -p "Enter filter (optional, e.g., 'security_center_properties.resource_type=\"google.compute.Instance\"'): " FILTER
    
    if [[ -n "$FILTER" ]]; then
        gcloud scc assets list "organizations/$ORGANIZATION_ID" --filter="$FILTER"
    else
        gcloud scc assets list "organizations/$ORGANIZATION_ID"
    fi
}

# Function to list security findings
list_findings() {
    print_info "Listing security findings..."
    
    read -p "Enter filter (optional, e.g., 'state=\"ACTIVE\"'): " FILTER
    
    if [[ -n "$FILTER" ]]; then
        gcloud scc findings list "organizations/$ORGANIZATION_ID" --filter="$FILTER"
    else
        gcloud scc findings list "organizations/$ORGANIZATION_ID"
    fi
}

# Function to create a custom finding
create_finding() {
    print_info "Creating custom security finding..."
    
    read -p "Enter source ID: " SOURCE_ID
    if [[ -z "$SOURCE_ID" ]]; then
        print_error "Source ID is required"
        return 1
    fi
    
    read -p "Enter finding ID: " FINDING_ID
    if [[ -z "$FINDING_ID" ]]; then
        print_error "Finding ID is required"
        return 1
    fi
    
    read -p "Enter resource name (e.g., //compute.googleapis.com/projects/PROJECT/zones/ZONE/instances/INSTANCE): " RESOURCE_NAME
    if [[ -z "$RESOURCE_NAME" ]]; then
        print_error "Resource name is required"
        return 1
    fi
    
    read -p "Enter category (e.g., 'UNAUTHORIZED_API_USAGE'): " CATEGORY
    CATEGORY=${CATEGORY:-"CUSTOM_FINDING"}
    
    read -p "Enter severity (CRITICAL, HIGH, MEDIUM, LOW): " SEVERITY
    SEVERITY=${SEVERITY:-"MEDIUM"}
    
    # Create finding JSON
    cat > /tmp/finding.json << EOF
{
  "state": "ACTIVE",
  "resourceName": "$RESOURCE_NAME",
  "category": "$CATEGORY",
  "externalUri": "https://example.com/finding/$FINDING_ID",
  "sourceProperties": {
    "custom_property": "custom_value"
  },
  "securityMarks": {
    "marks": {
      "environment": "production"
    }
  },
  "eventTime": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "createTime": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
EOF

    gcloud scc findings create "$FINDING_ID" \
        --source="organizations/$ORGANIZATION_ID/sources/$SOURCE_ID" \
        --finding-from-file=/tmp/finding.json
    
    print_success "Security finding '$FINDING_ID' created successfully"
    rm -f /tmp/finding.json
}

# Function to update finding state
update_finding() {
    print_info "Updating security finding state..."
    
    read -p "Enter source ID: " SOURCE_ID
    if [[ -z "$SOURCE_ID" ]]; then
        print_error "Source ID is required"
        return 1
    fi
    
    read -p "Enter finding ID: " FINDING_ID
    if [[ -z "$FINDING_ID" ]]; then
        print_error "Finding ID is required"
        return 1
    fi
    
    read -p "Enter new state (ACTIVE, INACTIVE): " NEW_STATE
    NEW_STATE=${NEW_STATE:-"INACTIVE"}
    
    gcloud scc findings update "$FINDING_ID" \
        --source="organizations/$ORGANIZATION_ID/sources/$SOURCE_ID" \
        --state="$NEW_STATE"
    
    print_success "Finding '$FINDING_ID' state updated to '$NEW_STATE'"
}

# Function to list security sources
list_sources() {
    print_info "Listing security sources..."
    gcloud scc sources list "organizations/$ORGANIZATION_ID"
}

# Function to create custom security source
create_source() {
    print_info "Creating custom security source..."
    
    read -p "Enter source display name: " SOURCE_NAME
    if [[ -z "$SOURCE_NAME" ]]; then
        print_error "Source display name is required"
        return 1
    fi
    
    read -p "Enter source description: " SOURCE_DESC
    SOURCE_DESC=${SOURCE_DESC:-"Custom security source: $SOURCE_NAME"}
    
    gcloud scc sources create \
        --display-name="$SOURCE_NAME" \
        --description="$SOURCE_DESC" \
        "organizations/$ORGANIZATION_ID"
    
    print_success "Security source '$SOURCE_NAME' created successfully"
}

# Function to get organization IAM policy
get_iam_policy() {
    print_info "Getting organization IAM policy..."
    gcloud organizations get-iam-policy "$ORGANIZATION_ID"
}

# Function to test IAM permissions
test_iam_permissions() {
    print_info "Testing IAM permissions..."
    
    local permissions=(
        "securitycenter.assets.list"
        "securitycenter.findings.list"
        "securitycenter.sources.list"
    )
    
    gcloud organizations test-iam-permissions "$ORGANIZATION_ID" \
        --permissions="$(IFS=','; echo "${permissions[*]}")"
}

# Function to run asset discovery
run_asset_discovery() {
    print_info "Running asset discovery..."
    
    print_warning "Asset discovery is automatically performed by Security Command Center"
    print_info "You can view discovered assets using the 'list-assets' command"
    
    # Show recent asset discovery operations
    gcloud logging read 'resource.type="audited_resource" AND protoPayload.serviceName="securitycenter.googleapis.com"' \
        --limit=10 \
        --format="table(timestamp, protoPayload.methodName, protoPayload.authenticationInfo.principalEmail)"
}

# Function to export assets to Cloud Storage
export_assets() {
    print_info "Exporting assets to Cloud Storage..."
    
    read -p "Enter Cloud Storage URI (e.g., gs://bucket-name/path/): " GCS_URI
    if [[ -z "$GCS_URI" ]]; then
        print_error "Cloud Storage URI is required"
        return 1
    fi
    
    read -p "Enter content type (ASSET, IAM_POLICY, ORG_POLICY, ACCESS_POLICY): " CONTENT_TYPE
    CONTENT_TYPE=${CONTENT_TYPE:-"ASSET"}
    
    gcloud asset export \
        --organization="$ORGANIZATION_ID" \
        --output-path="$GCS_URI" \
        --content-type="$CONTENT_TYPE"
    
    print_success "Assets exported to $GCS_URI"
}

# Function to create notification configuration
create_notification() {
    print_info "Creating notification configuration..."
    
    read -p "Enter notification config ID: " CONFIG_ID
    if [[ -z "$CONFIG_ID" ]]; then
        print_error "Notification config ID is required"
        return 1
    fi
    
    read -p "Enter Pub/Sub topic (e.g., projects/PROJECT/topics/TOPIC): " PUBSUB_TOPIC
    if [[ -z "$PUBSUB_TOPIC" ]]; then
        print_error "Pub/Sub topic is required"
        return 1
    fi
    
    read -p "Enter filter (e.g., 'state=\"ACTIVE\"'): " FILTER
    FILTER=${FILTER:-'state="ACTIVE"'}
    
    gcloud scc notifications create "$CONFIG_ID" \
        --organization="$ORGANIZATION_ID" \
        --pubsub-topic="$PUBSUB_TOPIC" \
        --filter="$FILTER"
    
    print_success "Notification configuration '$CONFIG_ID' created successfully"
}

# Function to list notification configurations
list_notifications() {
    print_info "Listing notification configurations..."
    gcloud scc notifications list "organizations/$ORGANIZATION_ID"
}

# Function to delete notification configuration
delete_notification() {
    print_info "Deleting notification configuration..."
    
    read -p "Enter notification config ID: " CONFIG_ID
    if [[ -z "$CONFIG_ID" ]]; then
        print_error "Notification config ID is required"
        return 1
    fi
    
    print_warning "This will delete the notification configuration '$CONFIG_ID'"
    read -p "Are you sure? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    gcloud scc notifications delete "$CONFIG_ID" \
        --organization="$ORGANIZATION_ID" \
        --quiet
    
    print_success "Notification configuration '$CONFIG_ID' deleted successfully"
}

# Function to get organization settings
get_organization_settings() {
    print_info "Getting organization settings..."
    gcloud scc settings describe --organization="$ORGANIZATION_ID"
}

# Function to update organization settings
update_organization_settings() {
    print_info "Updating organization settings..."
    
    read -p "Enable asset discovery service? (true/false): " ENABLE_ASSET_DISCOVERY
    ENABLE_ASSET_DISCOVERY=${ENABLE_ASSET_DISCOVERY:-"true"}
    
    gcloud scc settings update \
        --organization="$ORGANIZATION_ID" \
        --enable-asset-discovery="$ENABLE_ASSET_DISCOVERY"
    
    print_success "Organization settings updated successfully"
}

# Main function
main() {
    check_auth
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project)
                PROJECT_ID="$2"
                shift 2
                ;;
            -o|--organization)
                ORGANIZATION_ID="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            list-assets)
                set_project
                list_assets
                exit 0
                ;;
            list-findings)
                set_project
                list_findings
                exit 0
                ;;
            create-finding)
                set_project
                enable_apis
                create_finding
                exit 0
                ;;
            update-finding)
                set_project
                update_finding
                exit 0
                ;;
            list-sources)
                set_project
                list_sources
                exit 0
                ;;
            create-source)
                set_project
                enable_apis
                create_source
                exit 0
                ;;
            get-iam-policy)
                set_project
                get_iam_policy
                exit 0
                ;;
            test-iam-permissions)
                set_project
                test_iam_permissions
                exit 0
                ;;
            run-asset-discovery)
                set_project
                run_asset_discovery
                exit 0
                ;;
            export-assets)
                set_project
                export_assets
                exit 0
                ;;
            create-notification)
                set_project
                enable_apis
                create_notification
                exit 0
                ;;
            list-notifications)
                set_project
                list_notifications
                exit 0
                ;;
            delete-notification)
                set_project
                delete_notification
                exit 0
                ;;
            get-organization-settings)
                set_project
                get_organization_settings
                exit 0
                ;;
            update-organization-settings)
                set_project
                update_organization_settings
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # If no command provided, show usage
    usage
}

# Run main function
main "$@"
