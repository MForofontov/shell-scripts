#!/bin/bash

# GCP Certificate Manager Script
# This script manages SSL certificates using Google Cloud Certificate Manager

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../functions/common-init.sh"

# Global variables
PROJECT_ID=""
CERTIFICATE_NAME=""
DOMAIN_NAME=""
CERTIFICATE_MAP=""
DNS_AUTHORIZATION=""

# Function to display usage
usage() {
    print_with_separator "GCP Certificate Manager"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --project PROJECT_ID    Set GCP project ID"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Commands:"
    echo "  create-certificate          Create managed SSL certificate"
    echo "  create-self-managed-cert    Create self-managed SSL certificate"
    echo "  list-certificates           List SSL certificates"
    echo "  delete-certificate          Delete SSL certificate"
    echo "  get-certificate             Get certificate details"
    echo "  create-certificate-map      Create certificate map"
    echo "  list-certificate-maps       List certificate maps"
    echo "  delete-certificate-map      Delete certificate map"
    echo "  create-certificate-map-entry Create certificate map entry"
    echo "  list-certificate-map-entries List certificate map entries"
    echo "  delete-certificate-map-entry Delete certificate map entry"
    echo "  create-dns-authorization    Create DNS authorization"
    echo "  list-dns-authorizations     List DNS authorizations"
    echo "  delete-dns-authorization    Delete DNS authorization"
    echo "  get-dns-authorization       Get DNS authorization details"
    echo "  attach-certificate-to-lb    Attach certificate to load balancer"
    echo "  detach-certificate-from-lb  Detach certificate from load balancer"
    echo "  renew-certificate           Renew managed certificate"
    echo "  validate-certificate        Validate certificate configuration"
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
        "certificatemanager.googleapis.com"
        "dns.googleapis.com"
        "compute.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_info "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID"
    done
}

# Function to create managed SSL certificate
create_certificate() {
    print_info "Creating managed SSL certificate..."
    
    read -p "Enter certificate name: " CERTIFICATE_NAME
    if [[ -z "$CERTIFICATE_NAME" ]]; then
        print_error "Certificate name is required"
        return 1
    fi
    
    read -p "Enter domain name(s) (comma-separated): " DOMAIN_NAMES
    if [[ -z "$DOMAIN_NAMES" ]]; then
        print_error "Domain name(s) are required"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    # Convert comma-separated domains to array
    IFS=',' read -ra DOMAINS <<< "$DOMAIN_NAMES"
    DOMAIN_FLAGS=""
    for domain in "${DOMAINS[@]}"; do
        DOMAIN_FLAGS="$DOMAIN_FLAGS --domains=$(echo "$domain" | xargs)"
    done
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager certificates create "$CERTIFICATE_NAME" \
            --global \
            $DOMAIN_FLAGS \
            --project="$PROJECT_ID"
    else
        gcloud certificate-manager certificates create "$CERTIFICATE_NAME" \
            --location="$LOCATION" \
            $DOMAIN_FLAGS \
            --project="$PROJECT_ID"
    fi
    
    print_success "Managed SSL certificate '$CERTIFICATE_NAME' created successfully"
    print_info "Certificate provisioning may take a few minutes to complete"
}

# Function to create self-managed SSL certificate
create_self_managed_cert() {
    print_info "Creating self-managed SSL certificate..."
    
    read -p "Enter certificate name: " CERTIFICATE_NAME
    if [[ -z "$CERTIFICATE_NAME" ]]; then
        print_error "Certificate name is required"
        return 1
    fi
    
    read -p "Enter certificate file path (PEM format): " CERT_FILE
    if [[ ! -f "$CERT_FILE" ]]; then
        print_error "Certificate file not found: $CERT_FILE"
        return 1
    fi
    
    read -p "Enter private key file path (PEM format): " KEY_FILE
    if [[ ! -f "$KEY_FILE" ]]; then
        print_error "Private key file not found: $KEY_FILE"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager certificates create "$CERTIFICATE_NAME" \
            --global \
            --certificate-file="$CERT_FILE" \
            --private-key-file="$KEY_FILE" \
            --project="$PROJECT_ID"
    else
        gcloud certificate-manager certificates create "$CERTIFICATE_NAME" \
            --location="$LOCATION" \
            --certificate-file="$CERT_FILE" \
            --private-key-file="$KEY_FILE" \
            --project="$PROJECT_ID"
    fi
    
    print_success "Self-managed SSL certificate '$CERTIFICATE_NAME' created successfully"
}

# Function to list SSL certificates
list_certificates() {
    print_info "Listing SSL certificates..."
    
    read -p "Enter location (global/region, or 'all'): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "all" ]]; then
        gcloud certificate-manager certificates list --project="$PROJECT_ID"
    elif [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager certificates list --global --project="$PROJECT_ID"
    else
        gcloud certificate-manager certificates list --location="$LOCATION" --project="$PROJECT_ID"
    fi
}

# Function to delete SSL certificate
delete_certificate() {
    print_info "Deleting SSL certificate..."
    
    read -p "Enter certificate name: " CERTIFICATE_NAME
    if [[ -z "$CERTIFICATE_NAME" ]]; then
        print_error "Certificate name is required"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    print_warning "This will delete the SSL certificate '$CERTIFICATE_NAME'"
    read -p "Are you sure? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager certificates delete "$CERTIFICATE_NAME" \
            --global \
            --project="$PROJECT_ID" \
            --quiet
    else
        gcloud certificate-manager certificates delete "$CERTIFICATE_NAME" \
            --location="$LOCATION" \
            --project="$PROJECT_ID" \
            --quiet
    fi
    
    print_success "SSL certificate '$CERTIFICATE_NAME' deleted successfully"
}

# Function to get certificate details
get_certificate() {
    print_info "Getting SSL certificate details..."
    
    read -p "Enter certificate name: " CERTIFICATE_NAME
    if [[ -z "$CERTIFICATE_NAME" ]]; then
        print_error "Certificate name is required"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager certificates describe "$CERTIFICATE_NAME" \
            --global \
            --project="$PROJECT_ID"
    else
        gcloud certificate-manager certificates describe "$CERTIFICATE_NAME" \
            --location="$LOCATION" \
            --project="$PROJECT_ID"
    fi
}

# Function to create certificate map
create_certificate_map() {
    print_info "Creating certificate map..."
    
    read -p "Enter certificate map name: " CERTIFICATE_MAP
    if [[ -z "$CERTIFICATE_MAP" ]]; then
        print_error "Certificate map name is required"
        return 1
    fi
    
    read -p "Enter description: " MAP_DESCRIPTION
    MAP_DESCRIPTION=${MAP_DESCRIPTION:-"Certificate map: $CERTIFICATE_MAP"}
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager maps create "$CERTIFICATE_MAP" \
            --global \
            --description="$MAP_DESCRIPTION" \
            --project="$PROJECT_ID"
    else
        gcloud certificate-manager maps create "$CERTIFICATE_MAP" \
            --location="$LOCATION" \
            --description="$MAP_DESCRIPTION" \
            --project="$PROJECT_ID"
    fi
    
    print_success "Certificate map '$CERTIFICATE_MAP' created successfully"
}

# Function to list certificate maps
list_certificate_maps() {
    print_info "Listing certificate maps..."
    
    read -p "Enter location (global/region, or 'all'): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "all" ]]; then
        gcloud certificate-manager maps list --project="$PROJECT_ID"
    elif [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager maps list --global --project="$PROJECT_ID"
    else
        gcloud certificate-manager maps list --location="$LOCATION" --project="$PROJECT_ID"
    fi
}

# Function to delete certificate map
delete_certificate_map() {
    print_info "Deleting certificate map..."
    
    read -p "Enter certificate map name: " CERTIFICATE_MAP
    if [[ -z "$CERTIFICATE_MAP" ]]; then
        print_error "Certificate map name is required"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    print_warning "This will delete the certificate map '$CERTIFICATE_MAP'"
    read -p "Are you sure? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager maps delete "$CERTIFICATE_MAP" \
            --global \
            --project="$PROJECT_ID" \
            --quiet
    else
        gcloud certificate-manager maps delete "$CERTIFICATE_MAP" \
            --location="$LOCATION" \
            --project="$PROJECT_ID" \
            --quiet
    fi
    
    print_success "Certificate map '$CERTIFICATE_MAP' deleted successfully"
}

# Function to create certificate map entry
create_certificate_map_entry() {
    print_info "Creating certificate map entry..."
    
    read -p "Enter certificate map name: " CERTIFICATE_MAP
    if [[ -z "$CERTIFICATE_MAP" ]]; then
        print_error "Certificate map name is required"
        return 1
    fi
    
    read -p "Enter entry name: " ENTRY_NAME
    if [[ -z "$ENTRY_NAME" ]]; then
        print_error "Entry name is required"
        return 1
    fi
    
    read -p "Enter certificate name: " CERTIFICATE_NAME
    if [[ -z "$CERTIFICATE_NAME" ]]; then
        print_error "Certificate name is required"
        return 1
    fi
    
    read -p "Enter hostname: " HOSTNAME
    if [[ -z "$HOSTNAME" ]]; then
        print_error "Hostname is required"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager maps entries create "$ENTRY_NAME" \
            --map="$CERTIFICATE_MAP" \
            --global \
            --hostname="$HOSTNAME" \
            --certificates="$CERTIFICATE_NAME" \
            --project="$PROJECT_ID"
    else
        gcloud certificate-manager maps entries create "$ENTRY_NAME" \
            --map="$CERTIFICATE_MAP" \
            --location="$LOCATION" \
            --hostname="$HOSTNAME" \
            --certificates="$CERTIFICATE_NAME" \
            --project="$PROJECT_ID"
    fi
    
    print_success "Certificate map entry '$ENTRY_NAME' created successfully"
}

# Function to create DNS authorization
create_dns_authorization() {
    print_info "Creating DNS authorization..."
    
    read -p "Enter DNS authorization name: " DNS_AUTHORIZATION
    if [[ -z "$DNS_AUTHORIZATION" ]]; then
        print_error "DNS authorization name is required"
        return 1
    fi
    
    read -p "Enter domain name: " DOMAIN_NAME
    if [[ -z "$DOMAIN_NAME" ]]; then
        print_error "Domain name is required"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager dns-authorizations create "$DNS_AUTHORIZATION" \
            --global \
            --domain="$DOMAIN_NAME" \
            --project="$PROJECT_ID"
    else
        gcloud certificate-manager dns-authorizations create "$DNS_AUTHORIZATION" \
            --location="$LOCATION" \
            --domain="$DOMAIN_NAME" \
            --project="$PROJECT_ID"
    fi
    
    print_success "DNS authorization '$DNS_AUTHORIZATION' created successfully"
    print_info "Add the DNS record shown above to your DNS zone to complete authorization"
}

# Function to list DNS authorizations
list_dns_authorizations() {
    print_info "Listing DNS authorizations..."
    
    read -p "Enter location (global/region, or 'all'): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "all" ]]; then
        gcloud certificate-manager dns-authorizations list --project="$PROJECT_ID"
    elif [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager dns-authorizations list --global --project="$PROJECT_ID"
    else
        gcloud certificate-manager dns-authorizations list --location="$LOCATION" --project="$PROJECT_ID"
    fi
}

# Function to get DNS authorization details
get_dns_authorization() {
    print_info "Getting DNS authorization details..."
    
    read -p "Enter DNS authorization name: " DNS_AUTHORIZATION
    if [[ -z "$DNS_AUTHORIZATION" ]]; then
        print_error "DNS authorization name is required"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    if [[ "$LOCATION" == "global" ]]; then
        gcloud certificate-manager dns-authorizations describe "$DNS_AUTHORIZATION" \
            --global \
            --project="$PROJECT_ID"
    else
        gcloud certificate-manager dns-authorizations describe "$DNS_AUTHORIZATION" \
            --location="$LOCATION" \
            --project="$PROJECT_ID"
    fi
}

# Function to attach certificate to load balancer
attach_certificate_to_lb() {
    print_info "Attaching certificate to load balancer..."
    
    read -p "Enter load balancer name: " LB_NAME
    if [[ -z "$LB_NAME" ]]; then
        print_error "Load balancer name is required"
        return 1
    fi
    
    read -p "Enter certificate name: " CERTIFICATE_NAME
    if [[ -z "$CERTIFICATE_NAME" ]]; then
        print_error "Certificate name is required"
        return 1
    fi
    
    read -p "Is this a global load balancer? (y/N): " IS_GLOBAL
    
    if [[ $IS_GLOBAL == [yY] ]]; then
        # For global HTTPS load balancer
        gcloud compute target-https-proxies update "$LB_NAME" \
            --ssl-certificates="$CERTIFICATE_NAME" \
            --global \
            --project="$PROJECT_ID"
    else
        read -p "Enter region: " REGION
        if [[ -z "$REGION" ]]; then
            print_error "Region is required for regional load balancer"
            return 1
        fi
        
        gcloud compute target-https-proxies update "$LB_NAME" \
            --ssl-certificates="$CERTIFICATE_NAME" \
            --region="$REGION" \
            --project="$PROJECT_ID"
    fi
    
    print_success "Certificate '$CERTIFICATE_NAME' attached to load balancer '$LB_NAME'"
}

# Function to validate certificate configuration
validate_certificate() {
    print_info "Validating certificate configuration..."
    
    read -p "Enter certificate name: " CERTIFICATE_NAME
    if [[ -z "$CERTIFICATE_NAME" ]]; then
        print_error "Certificate name is required"
        return 1
    fi
    
    read -p "Enter location (global/region): " LOCATION
    LOCATION=${LOCATION:-"global"}
    
    print_info "Checking certificate status..."
    
    if [[ "$LOCATION" == "global" ]]; then
        CERT_STATUS=$(gcloud certificate-manager certificates describe "$CERTIFICATE_NAME" \
            --global \
            --project="$PROJECT_ID" \
            --format="value(state)")
    else
        CERT_STATUS=$(gcloud certificate-manager certificates describe "$CERTIFICATE_NAME" \
            --location="$LOCATION" \
            --project="$PROJECT_ID" \
            --format="value(state)")
    fi
    
    case $CERT_STATUS in
        "ACTIVE")
            print_success "Certificate '$CERTIFICATE_NAME' is active and ready for use"
            ;;
        "PROVISIONING")
            print_warning "Certificate '$CERTIFICATE_NAME' is being provisioned"
            print_info "This may take several minutes to complete"
            ;;
        "FAILED")
            print_error "Certificate '$CERTIFICATE_NAME' provisioning failed"
            print_info "Check domain ownership and DNS configuration"
            ;;
        *)
            print_info "Certificate '$CERTIFICATE_NAME' status: $CERT_STATUS"
            ;;
    esac
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
            create-certificate)
                set_project
                enable_apis
                create_certificate
                exit 0
                ;;
            create-self-managed-cert)
                set_project
                enable_apis
                create_self_managed_cert
                exit 0
                ;;
            list-certificates)
                set_project
                list_certificates
                exit 0
                ;;
            delete-certificate)
                set_project
                delete_certificate
                exit 0
                ;;
            get-certificate)
                set_project
                get_certificate
                exit 0
                ;;
            create-certificate-map)
                set_project
                enable_apis
                create_certificate_map
                exit 0
                ;;
            list-certificate-maps)
                set_project
                list_certificate_maps
                exit 0
                ;;
            delete-certificate-map)
                set_project
                delete_certificate_map
                exit 0
                ;;
            create-certificate-map-entry)
                set_project
                create_certificate_map_entry
                exit 0
                ;;
            create-dns-authorization)
                set_project
                enable_apis
                create_dns_authorization
                exit 0
                ;;
            list-dns-authorizations)
                set_project
                list_dns_authorizations
                exit 0
                ;;
            get-dns-authorization)
                set_project
                get_dns_authorization
                exit 0
                ;;
            attach-certificate-to-lb)
                set_project
                attach_certificate_to_lb
                exit 0
                ;;
            validate-certificate)
                set_project
                validate_certificate
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
