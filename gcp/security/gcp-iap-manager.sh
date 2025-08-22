#!/bin/bash

# GCP Identity-Aware Proxy (IAP) Manager Script
# This script manages Identity-Aware Proxy for zero-trust access

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../functions/common-init.sh"

# Global variables
PROJECT_ID=""
BACKEND_SERVICE=""
OAUTH_CLIENT_ID=""
OAUTH_CLIENT_SECRET=""
TUNNEL_INSTANCE=""
ZONE=""

# Function to display usage
usage() {
    print_header "GCP Identity-Aware Proxy (IAP) Manager"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --project PROJECT_ID    Set GCP project ID"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Commands:"
    echo "  enable-web-iap              Enable IAP for App Engine/Compute Engine"
    echo "  disable-web-iap             Disable IAP for web applications"
    echo "  enable-tcp-iap              Enable IAP for TCP forwarding"
    echo "  disable-tcp-iap             Disable IAP for TCP forwarding"
    echo "  list-web-services           List IAP-enabled web services"
    echo "  list-tunnel-instances       List IAP tunnel instances"
    echo "  add-iam-policy-binding      Add IAM policy binding for IAP access"
    echo "  remove-iam-policy-binding   Remove IAM policy binding for IAP access"
    echo "  get-iam-policy              Get IAP IAM policy"
    echo "  set-oauth-credentials       Set OAuth credentials for IAP"
    echo "  get-oauth-credentials       Get OAuth credentials for IAP"
    echo "  create-oauth-client         Create OAuth client for IAP"
    echo "  get-settings                Get IAP settings"
    echo "  update-settings             Update IAP settings"
    echo "  create-access-policy        Create access policy"
    echo "  list-access-policies        List access policies"
    echo "  delete-access-policy        Delete access policy"
    echo "  test-connection             Test IAP connection"
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
        "iap.googleapis.com"
        "compute.googleapis.com"
        "appengine.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_info "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID"
    done
}

# Function to enable IAP for web applications
enable_web_iap() {
    print_info "Enabling IAP for web applications..."
    
    echo "Select the type of service:"
    echo "1. App Engine"
    echo "2. Compute Engine (Load Balancer)"
    read -p "Enter choice (1-2): " SERVICE_TYPE
    
    case $SERVICE_TYPE in
        1)
            # App Engine
            gcloud iap web enable --project="$PROJECT_ID"
            print_success "IAP enabled for App Engine"
            ;;
        2)
            # Compute Engine
            read -p "Enter backend service name: " BACKEND_SERVICE
            if [[ -z "$BACKEND_SERVICE" ]]; then
                print_error "Backend service name is required"
                return 1
            fi
            
            read -p "Is this a global backend service? (y/N): " IS_GLOBAL
            
            if [[ $IS_GLOBAL == [yY] ]]; then
                gcloud iap web enable --resource-type=backend-services \
                    --service="$BACKEND_SERVICE" \
                    --project="$PROJECT_ID"
            else
                read -p "Enter region: " REGION
                if [[ -z "$REGION" ]]; then
                    print_error "Region is required for regional backend service"
                    return 1
                fi
                
                gcloud iap web enable --resource-type=backend-services \
                    --service="$BACKEND_SERVICE" \
                    --region="$REGION" \
                    --project="$PROJECT_ID"
            fi
            
            print_success "IAP enabled for backend service '$BACKEND_SERVICE'"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

# Function to disable IAP for web applications
disable_web_iap() {
    print_info "Disabling IAP for web applications..."
    
    echo "Select the type of service:"
    echo "1. App Engine"
    echo "2. Compute Engine (Load Balancer)"
    read -p "Enter choice (1-2): " SERVICE_TYPE
    
    case $SERVICE_TYPE in
        1)
            # App Engine
            gcloud iap web disable --project="$PROJECT_ID"
            print_success "IAP disabled for App Engine"
            ;;
        2)
            # Compute Engine
            read -p "Enter backend service name: " BACKEND_SERVICE
            if [[ -z "$BACKEND_SERVICE" ]]; then
                print_error "Backend service name is required"
                return 1
            fi
            
            read -p "Is this a global backend service? (y/N): " IS_GLOBAL
            
            if [[ $IS_GLOBAL == [yY] ]]; then
                gcloud iap web disable --resource-type=backend-services \
                    --service="$BACKEND_SERVICE" \
                    --project="$PROJECT_ID"
            else
                read -p "Enter region: " REGION
                if [[ -z "$REGION" ]]; then
                    print_error "Region is required for regional backend service"
                    return 1
                fi
                
                gcloud iap web disable --resource-type=backend-services \
                    --service="$BACKEND_SERVICE" \
                    --region="$REGION" \
                    --project="$PROJECT_ID"
            fi
            
            print_success "IAP disabled for backend service '$BACKEND_SERVICE'"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

# Function to enable IAP for TCP forwarding
enable_tcp_iap() {
    print_info "Enabling IAP for TCP forwarding..."
    
    read -p "Enter instance name: " TUNNEL_INSTANCE
    if [[ -z "$TUNNEL_INSTANCE" ]]; then
        print_error "Instance name is required"
        return 1
    fi
    
    read -p "Enter zone: " ZONE
    if [[ -z "$ZONE" ]]; then
        print_error "Zone is required"
        return 1
    fi
    
    gcloud iap tcp enable --instance="$TUNNEL_INSTANCE" \
        --zone="$ZONE" \
        --project="$PROJECT_ID"
    
    print_success "IAP TCP forwarding enabled for instance '$TUNNEL_INSTANCE'"
}

# Function to disable IAP for TCP forwarding
disable_tcp_iap() {
    print_info "Disabling IAP for TCP forwarding..."
    
    read -p "Enter instance name: " TUNNEL_INSTANCE
    if [[ -z "$TUNNEL_INSTANCE" ]]; then
        print_error "Instance name is required"
        return 1
    fi
    
    read -p "Enter zone: " ZONE
    if [[ -z "$ZONE" ]]; then
        print_error "Zone is required"
        return 1
    fi
    
    gcloud iap tcp disable --instance="$TUNNEL_INSTANCE" \
        --zone="$ZONE" \
        --project="$PROJECT_ID"
    
    print_success "IAP TCP forwarding disabled for instance '$TUNNEL_INSTANCE'"
}

# Function to list IAP-enabled web services
list_web_services() {
    print_info "Listing IAP-enabled web services..."
    gcloud iap web list --project="$PROJECT_ID"
}

# Function to list IAP tunnel instances
list_tunnel_instances() {
    print_info "Listing IAP tunnel instances..."
    gcloud iap tcp list --project="$PROJECT_ID"
}

# Function to add IAM policy binding for IAP access
add_iam_policy_binding() {
    print_info "Adding IAM policy binding for IAP access..."
    
    read -p "Enter member (user:email@domain.com, group:group@domain.com, etc.): " MEMBER
    if [[ -z "$MEMBER" ]]; then
        print_error "Member is required"
        return 1
    fi
    
    read -p "Enter role (e.g., roles/iap.httpsResourceAccessor): " ROLE
    ROLE=${ROLE:-"roles/iap.httpsResourceAccessor"}
    
    echo "Select the resource type:"
    echo "1. App Engine"
    echo "2. Backend Service (global)"
    echo "3. Backend Service (regional)"
    read -p "Enter choice (1-3): " RESOURCE_TYPE
    
    case $RESOURCE_TYPE in
        1)
            # App Engine
            gcloud iap web add-iam-policy-binding \
                --member="$MEMBER" \
                --role="$ROLE" \
                --project="$PROJECT_ID"
            ;;
        2)
            # Global Backend Service
            read -p "Enter backend service name: " BACKEND_SERVICE
            if [[ -z "$BACKEND_SERVICE" ]]; then
                print_error "Backend service name is required"
                return 1
            fi
            
            gcloud iap web add-iam-policy-binding \
                --resource-type=backend-services \
                --service="$BACKEND_SERVICE" \
                --member="$MEMBER" \
                --role="$ROLE" \
                --project="$PROJECT_ID"
            ;;
        3)
            # Regional Backend Service
            read -p "Enter backend service name: " BACKEND_SERVICE
            if [[ -z "$BACKEND_SERVICE" ]]; then
                print_error "Backend service name is required"
                return 1
            fi
            
            read -p "Enter region: " REGION
            if [[ -z "$REGION" ]]; then
                print_error "Region is required"
                return 1
            fi
            
            gcloud iap web add-iam-policy-binding \
                --resource-type=backend-services \
                --service="$BACKEND_SERVICE" \
                --region="$REGION" \
                --member="$MEMBER" \
                --role="$ROLE" \
                --project="$PROJECT_ID"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    print_success "IAM policy binding added for member '$MEMBER' with role '$ROLE'"
}

# Function to remove IAM policy binding for IAP access
remove_iam_policy_binding() {
    print_info "Removing IAM policy binding for IAP access..."
    
    read -p "Enter member (user:email@domain.com, group:group@domain.com, etc.): " MEMBER
    if [[ -z "$MEMBER" ]]; then
        print_error "Member is required"
        return 1
    fi
    
    read -p "Enter role (e.g., roles/iap.httpsResourceAccessor): " ROLE
    ROLE=${ROLE:-"roles/iap.httpsResourceAccessor"}
    
    echo "Select the resource type:"
    echo "1. App Engine"
    echo "2. Backend Service (global)"
    echo "3. Backend Service (regional)"
    read -p "Enter choice (1-3): " RESOURCE_TYPE
    
    case $RESOURCE_TYPE in
        1)
            # App Engine
            gcloud iap web remove-iam-policy-binding \
                --member="$MEMBER" \
                --role="$ROLE" \
                --project="$PROJECT_ID"
            ;;
        2)
            # Global Backend Service
            read -p "Enter backend service name: " BACKEND_SERVICE
            if [[ -z "$BACKEND_SERVICE" ]]; then
                print_error "Backend service name is required"
                return 1
            fi
            
            gcloud iap web remove-iam-policy-binding \
                --resource-type=backend-services \
                --service="$BACKEND_SERVICE" \
                --member="$MEMBER" \
                --role="$ROLE" \
                --project="$PROJECT_ID"
            ;;
        3)
            # Regional Backend Service
            read -p "Enter backend service name: " BACKEND_SERVICE
            if [[ -z "$BACKEND_SERVICE" ]]; then
                print_error "Backend service name is required"
                return 1
            fi
            
            read -p "Enter region: " REGION
            if [[ -z "$REGION" ]]; then
                print_error "Region is required"
                return 1
            fi
            
            gcloud iap web remove-iam-policy-binding \
                --resource-type=backend-services \
                --service="$BACKEND_SERVICE" \
                --region="$REGION" \
                --member="$MEMBER" \
                --role="$ROLE" \
                --project="$PROJECT_ID"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    print_success "IAM policy binding removed for member '$MEMBER' with role '$ROLE'"
}

# Function to get IAP IAM policy
get_iam_policy() {
    print_info "Getting IAP IAM policy..."
    
    echo "Select the resource type:"
    echo "1. App Engine"
    echo "2. Backend Service (global)"
    echo "3. Backend Service (regional)"
    read -p "Enter choice (1-3): " RESOURCE_TYPE
    
    case $RESOURCE_TYPE in
        1)
            # App Engine
            gcloud iap web get-iam-policy --project="$PROJECT_ID"
            ;;
        2)
            # Global Backend Service
            read -p "Enter backend service name: " BACKEND_SERVICE
            if [[ -z "$BACKEND_SERVICE" ]]; then
                print_error "Backend service name is required"
                return 1
            fi
            
            gcloud iap web get-iam-policy \
                --resource-type=backend-services \
                --service="$BACKEND_SERVICE" \
                --project="$PROJECT_ID"
            ;;
        3)
            # Regional Backend Service
            read -p "Enter backend service name: " BACKEND_SERVICE
            if [[ -z "$BACKEND_SERVICE" ]]; then
                print_error "Backend service name is required"
                return 1
            fi
            
            read -p "Enter region: " REGION
            if [[ -z "$REGION" ]]; then
                print_error "Region is required"
                return 1
            fi
            
            gcloud iap web get-iam-policy \
                --resource-type=backend-services \
                --service="$BACKEND_SERVICE" \
                --region="$REGION" \
                --project="$PROJECT_ID"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

# Function to create OAuth client for IAP
create_oauth_client() {
    print_info "Creating OAuth client for IAP..."
    
    read -p "Enter OAuth client name: " CLIENT_NAME
    if [[ -z "$CLIENT_NAME" ]]; then
        print_error "OAuth client name is required"
        return 1
    fi
    
    # Note: This requires manual steps in the Google Cloud Console
    print_info "To create an OAuth client for IAP:"
    print_info "1. Go to the Google Cloud Console"
    print_info "2. Navigate to APIs & Services > Credentials"
    print_info "3. Click 'Create Credentials' > 'OAuth client ID'"
    print_info "4. Select 'Web application'"
    print_info "5. Add authorized redirect URIs for your domain"
    print_info "6. Save the client ID and secret for use with IAP"
    
    print_warning "OAuth client creation requires manual steps in the console"
}

# Function to test IAP connection
test_connection() {
    print_info "Testing IAP connection..."
    
    read -p "Enter IAP-protected URL: " IAP_URL
    if [[ -z "$IAP_URL" ]]; then
        print_error "IAP-protected URL is required"
        return 1
    fi
    
    print_info "Testing connection to: $IAP_URL"
    
    # Test with gcloud auth
    if curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" "$IAP_URL" > /dev/null; then
        print_success "IAP connection test successful"
    else
        print_error "IAP connection test failed"
        print_info "Make sure you have proper IAP access permissions"
    fi
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
            enable-web-iap)
                set_project
                enable_apis
                enable_web_iap
                exit 0
                ;;
            disable-web-iap)
                set_project
                disable_web_iap
                exit 0
                ;;
            enable-tcp-iap)
                set_project
                enable_apis
                enable_tcp_iap
                exit 0
                ;;
            disable-tcp-iap)
                set_project
                disable_tcp_iap
                exit 0
                ;;
            list-web-services)
                set_project
                list_web_services
                exit 0
                ;;
            list-tunnel-instances)
                set_project
                list_tunnel_instances
                exit 0
                ;;
            add-iam-policy-binding)
                set_project
                add_iam_policy_binding
                exit 0
                ;;
            remove-iam-policy-binding)
                set_project
                remove_iam_policy_binding
                exit 0
                ;;
            get-iam-policy)
                set_project
                get_iam_policy
                exit 0
                ;;
            create-oauth-client)
                set_project
                create_oauth_client
                exit 0
                ;;
            test-connection)
                set_project
                test_connection
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
