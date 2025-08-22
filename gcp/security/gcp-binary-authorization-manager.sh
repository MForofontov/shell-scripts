#!/bin/bash

# GCP Binary Authorization Manager Script
# This script manages Binary Authorization policies for container image security

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../functions/common-init.sh"

# Global variables
PROJECT_ID=""
POLICY_NAME=""
ATTESTOR_NAME=""
CLUSTER_NAME=""
ZONE=""

# Function to display usage
usage() {
    print_header "GCP Binary Authorization Manager"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --project PROJECT_ID    Set GCP project ID"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Commands:"
    echo "  create-policy               Create Binary Authorization policy"
    echo "  list-policies               List Binary Authorization policies"
    echo "  create-attestor             Create attestor"
    echo "  list-attestors              List attestors"
    echo "  enable-enforcement          Enable enforcement on GKE cluster"
    echo "  disable-enforcement         Disable enforcement on GKE cluster"
    echo "  get-policy                  Get current policy"
    echo "  update-policy               Update existing policy"
    echo "  delete-attestor             Delete attestor"
    echo "  create-note                 Create Container Analysis note"
    echo "  list-notes                  List Container Analysis notes"
    echo ""
}

# Function to check if gcloud is authenticated
check_auth() {
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        print_error "Not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    fi
}

# Function to set project
set_project() {
    if [[ -z "$PROJECT_ID" ]]; then
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
        if [[ -z "$PROJECT_ID" ]]; then
            print_error "No project set. Use -p flag or run 'gcloud config set project PROJECT_ID'"
            exit 1
        fi
    fi
    
    print_info "Using project: $PROJECT_ID"
    gcloud config set project "$PROJECT_ID"
}

# Function to enable required APIs
enable_apis() {
    print_info "Enabling required APIs..."
    
    local apis=(
        "binaryauthorization.googleapis.com"
        "containeranalysis.googleapis.com"
        "container.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_info "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID"
    done
}

# Function to create Binary Authorization policy
create_policy() {
    print_info "Creating Binary Authorization policy..."
    
    read -p "Enter policy name (default: default): " POLICY_NAME
    POLICY_NAME=${POLICY_NAME:-"default"}
    
    # Create policy YAML file
    cat > /tmp/binauth-policy.yaml << EOF
admissionWhitelistPatterns:
- namePattern: gcr.io/$PROJECT_ID/*
defaultAdmissionRule:
  requireAttestationsBy:
  - projects/$PROJECT_ID/attestors/$ATTESTOR_NAME
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
name: projects/$PROJECT_ID/policy
EOF

    gcloud container binauthz policy import /tmp/binauth-policy.yaml
    
    print_success "Binary Authorization policy created successfully"
    rm -f /tmp/binauth-policy.yaml
}

# Function to list policies
list_policies() {
    print_info "Listing Binary Authorization policies..."
    gcloud container binauthz policy export
}

# Function to create attestor
create_attestor() {
    print_info "Creating attestor..."
    
    read -p "Enter attestor name: " ATTESTOR_NAME
    if [[ -z "$ATTESTOR_NAME" ]]; then
        print_error "Attestor name is required"
        return 1
    fi
    
    read -p "Enter attestor description: " ATTESTOR_DESC
    ATTESTOR_DESC=${ATTESTOR_DESC:-"Attestor for $ATTESTOR_NAME"}
    
    read -p "Enter public key file path (PEM format): " PUBLIC_KEY_FILE
    if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
        print_error "Public key file not found: $PUBLIC_KEY_FILE"
        return 1
    fi
    
    # Create Container Analysis note first
    NOTE_ID="${ATTESTOR_NAME}-note"
    gcloud container analysis notes create "$NOTE_ID" \
        --attestation-authority-hint="$ATTESTOR_DESC" \
        --project="$PROJECT_ID"
    
    # Create attestor
    gcloud container binauthz attestors create "$ATTESTOR_NAME" \
        --attestation-authority-note="projects/$PROJECT_ID/notes/$NOTE_ID" \
        --description="$ATTESTOR_DESC" \
        --project="$PROJECT_ID"
    
    # Add public key to attestor
    gcloud container binauthz attestors public-keys add \
        --attestor="$ATTESTOR_NAME" \
        --public-key-file="$PUBLIC_KEY_FILE" \
        --project="$PROJECT_ID"
    
    print_success "Attestor '$ATTESTOR_NAME' created successfully"
}

# Function to list attestors
list_attestors() {
    print_info "Listing Binary Authorization attestors..."
    gcloud container binauthz attestors list --project="$PROJECT_ID"
}

# Function to enable enforcement on GKE cluster
enable_enforcement() {
    print_info "Enabling Binary Authorization enforcement on GKE cluster..."
    
    read -p "Enter cluster name: " CLUSTER_NAME
    if [[ -z "$CLUSTER_NAME" ]]; then
        print_error "Cluster name is required"
        return 1
    fi
    
    read -p "Enter zone/region: " ZONE
    if [[ -z "$ZONE" ]]; then
        print_error "Zone/region is required"
        return 1
    fi
    
    gcloud container clusters update "$CLUSTER_NAME" \
        --enable-binauthz \
        --zone="$ZONE" \
        --project="$PROJECT_ID"
    
    print_success "Binary Authorization enforcement enabled on cluster '$CLUSTER_NAME'"
}

# Function to disable enforcement on GKE cluster
disable_enforcement() {
    print_info "Disabling Binary Authorization enforcement on GKE cluster..."
    
    read -p "Enter cluster name: " CLUSTER_NAME
    if [[ -z "$CLUSTER_NAME" ]]; then
        print_error "Cluster name is required"
        return 1
    fi
    
    read -p "Enter zone/region: " ZONE
    if [[ -z "$ZONE" ]]; then
        print_error "Zone/region is required"
        return 1
    fi
    
    gcloud container clusters update "$CLUSTER_NAME" \
        --no-enable-binauthz \
        --zone="$ZONE" \
        --project="$PROJECT_ID"
    
    print_success "Binary Authorization enforcement disabled on cluster '$CLUSTER_NAME'"
}

# Function to get current policy
get_policy() {
    print_info "Getting current Binary Authorization policy..."
    gcloud container binauthz policy export --project="$PROJECT_ID"
}

# Function to update policy
update_policy() {
    print_info "Updating Binary Authorization policy..."
    
    read -p "Enter policy file path (YAML format): " POLICY_FILE
    if [[ ! -f "$POLICY_FILE" ]]; then
        print_error "Policy file not found: $POLICY_FILE"
        return 1
    fi
    
    gcloud container binauthz policy import "$POLICY_FILE" --project="$PROJECT_ID"
    print_success "Binary Authorization policy updated successfully"
}

# Function to delete attestor
delete_attestor() {
    print_info "Deleting attestor..."
    
    read -p "Enter attestor name: " ATTESTOR_NAME
    if [[ -z "$ATTESTOR_NAME" ]]; then
        print_error "Attestor name is required"
        return 1
    fi
    
    print_warning "This will delete the attestor '$ATTESTOR_NAME'"
    read -p "Are you sure? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    gcloud container binauthz attestors delete "$ATTESTOR_NAME" \
        --project="$PROJECT_ID" \
        --quiet
    
    print_success "Attestor '$ATTESTOR_NAME' deleted successfully"
}

# Function to create Container Analysis note
create_note() {
    print_info "Creating Container Analysis note..."
    
    read -p "Enter note ID: " NOTE_ID
    if [[ -z "$NOTE_ID" ]]; then
        print_error "Note ID is required"
        return 1
    fi
    
    read -p "Enter note description: " NOTE_DESC
    NOTE_DESC=${NOTE_DESC:-"Container Analysis note for $NOTE_ID"}
    
    gcloud container analysis notes create "$NOTE_ID" \
        --attestation-authority-hint="$NOTE_DESC" \
        --project="$PROJECT_ID"
    
    print_success "Container Analysis note '$NOTE_ID' created successfully"
}

# Function to list Container Analysis notes
list_notes() {
    print_info "Listing Container Analysis notes..."
    gcloud container analysis notes list --project="$PROJECT_ID"
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
            -h|--help)
                usage
                exit 0
                ;;
            create-policy)
                set_project
                enable_apis
                create_policy
                exit 0
                ;;
            list-policies)
                set_project
                list_policies
                exit 0
                ;;
            create-attestor)
                set_project
                enable_apis
                create_attestor
                exit 0
                ;;
            list-attestors)
                set_project
                list_attestors
                exit 0
                ;;
            enable-enforcement)
                set_project
                enable_enforcement
                exit 0
                ;;
            disable-enforcement)
                set_project
                disable_enforcement
                exit 0
                ;;
            get-policy)
                set_project
                get_policy
                exit 0
                ;;
            update-policy)
                set_project
                update_policy
                exit 0
                ;;
            delete-attestor)
                set_project
                delete_attestor
                exit 0
                ;;
            create-note)
                set_project
                enable_apis
                create_note
                exit 0
                ;;
            list-notes)
                set_project
                list_notes
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
