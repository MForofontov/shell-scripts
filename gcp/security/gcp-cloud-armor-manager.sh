#!/bin/bash

# GCP Cloud Armor Manager Script
# This script manages Cloud Armor for DDoS protection and WAF

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../functions/common-init.sh"

# Global variables
PROJECT_ID=""
POLICY_NAME=""
RULE_PRIORITY=""
BACKEND_SERVICE=""
RULE_DESCRIPTION=""

# Function to display usage
usage() {
    print_header "GCP Cloud Armor Manager"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --project PROJECT_ID    Set GCP project ID"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Commands:"
    echo "  create-policy               Create Cloud Armor security policy"
    echo "  list-policies               List Cloud Armor security policies"
    echo "  delete-policy               Delete Cloud Armor security policy"
    echo "  add-rule                    Add security rule to policy"
    echo "  delete-rule                 Delete security rule from policy"
    echo "  list-rules                  List rules in security policy"
    echo "  update-rule                 Update existing security rule"
    echo "  attach-policy               Attach policy to backend service"
    echo "  detach-policy               Detach policy from backend service"
    echo "  create-adaptive-protection  Create adaptive protection config"
    echo "  enable-ddos-protection      Enable DDoS protection"
    echo "  disable-ddos-protection     Disable DDoS protection"
    echo "  create-rate-limit-rule      Create rate limiting rule"
    echo "  create-geo-blocking-rule    Create geo-blocking rule"
    echo "  create-ip-whitelist-rule    Create IP whitelist rule"
    echo "  create-ip-blacklist-rule    Create IP blacklist rule"
    echo "  get-policy                  Get security policy details"
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
        "compute.googleapis.com"
        "cloudarmor.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        print_info "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID"
    done
}

# Function to create Cloud Armor security policy
create_policy() {
    print_info "Creating Cloud Armor security policy..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    read -p "Enter policy description: " POLICY_DESC
    POLICY_DESC=${POLICY_DESC:-"Cloud Armor security policy: $POLICY_NAME"}
    
    read -p "Enable adaptive protection? (y/N): " ADAPTIVE_PROTECTION
    
    if [[ $ADAPTIVE_PROTECTION == [yY] ]]; then
        gcloud compute security-policies create "$POLICY_NAME" \
            --description="$POLICY_DESC" \
            --enable-layer7-ddos-defense \
            --project="$PROJECT_ID"
    else
        gcloud compute security-policies create "$POLICY_NAME" \
            --description="$POLICY_DESC" \
            --project="$PROJECT_ID"
    fi
    
    print_success "Cloud Armor security policy '$POLICY_NAME' created successfully"
}

# Function to list security policies
list_policies() {
    print_info "Listing Cloud Armor security policies..."
    gcloud compute security-policies list --project="$PROJECT_ID"
}

# Function to delete security policy
delete_policy() {
    print_info "Deleting Cloud Armor security policy..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    print_warning "This will delete the security policy '$POLICY_NAME'"
    read -p "Are you sure? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    gcloud compute security-policies delete "$POLICY_NAME" \
        --project="$PROJECT_ID" \
        --quiet
    
    print_success "Security policy '$POLICY_NAME' deleted successfully"
}

# Function to add security rule to policy
add_rule() {
    print_info "Adding security rule to Cloud Armor policy..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    read -p "Enter rule priority (1000-2147483647): " RULE_PRIORITY
    if [[ -z "$RULE_PRIORITY" ]]; then
        print_error "Rule priority is required"
        return 1
    fi
    
    read -p "Enter rule description: " RULE_DESCRIPTION
    RULE_DESCRIPTION=${RULE_DESCRIPTION:-"Security rule with priority $RULE_PRIORITY"}
    
    read -p "Enter action (allow/deny-403/deny-404/deny-502/rate-based-ban): " ACTION
    ACTION=${ACTION:-"deny-403"}
    
    read -p "Enter source IP expression (e.g., '192.168.1.0/24' or 'origin.region_code == \"US\"'): " SRC_IP_RANGES
    if [[ -z "$SRC_IP_RANGES" ]]; then
        print_error "Source IP expression is required"
        return 1
    fi
    
    gcloud compute security-policies rules create "$RULE_PRIORITY" \
        --security-policy="$POLICY_NAME" \
        --description="$RULE_DESCRIPTION" \
        --action="$ACTION" \
        --src-ip-ranges="$SRC_IP_RANGES" \
        --project="$PROJECT_ID"
    
    print_success "Security rule added to policy '$POLICY_NAME' with priority $RULE_PRIORITY"
}

# Function to delete security rule from policy
delete_rule() {
    print_info "Deleting security rule from Cloud Armor policy..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    read -p "Enter rule priority: " RULE_PRIORITY
    if [[ -z "$RULE_PRIORITY" ]]; then
        print_error "Rule priority is required"
        return 1
    fi
    
    print_warning "This will delete the security rule with priority $RULE_PRIORITY from policy '$POLICY_NAME'"
    read -p "Are you sure? (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    gcloud compute security-policies rules delete "$RULE_PRIORITY" \
        --security-policy="$POLICY_NAME" \
        --project="$PROJECT_ID" \
        --quiet
    
    print_success "Security rule with priority $RULE_PRIORITY deleted from policy '$POLICY_NAME'"
}

# Function to list rules in security policy
list_rules() {
    print_info "Listing rules in Cloud Armor security policy..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    gcloud compute security-policies rules list \
        --security-policy="$POLICY_NAME" \
        --project="$PROJECT_ID"
}

# Function to update existing security rule
update_rule() {
    print_info "Updating security rule in Cloud Armor policy..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    read -p "Enter rule priority: " RULE_PRIORITY
    if [[ -z "$RULE_PRIORITY" ]]; then
        print_error "Rule priority is required"
        return 1
    fi
    
    read -p "Enter new rule description: " RULE_DESCRIPTION
    read -p "Enter new action (allow/deny-403/deny-404/deny-502/rate-based-ban): " ACTION
    read -p "Enter new source IP expression: " SRC_IP_RANGES
    
    local update_args=()
    [[ -n "$RULE_DESCRIPTION" ]] && update_args+=(--description="$RULE_DESCRIPTION")
    [[ -n "$ACTION" ]] && update_args+=(--action="$ACTION")
    [[ -n "$SRC_IP_RANGES" ]] && update_args+=(--src-ip-ranges="$SRC_IP_RANGES")
    
    if [[ ${#update_args[@]} -eq 0 ]]; then
        print_error "At least one field must be updated"
        return 1
    fi
    
    gcloud compute security-policies rules update "$RULE_PRIORITY" \
        --security-policy="$POLICY_NAME" \
        "${update_args[@]}" \
        --project="$PROJECT_ID"
    
    print_success "Security rule with priority $RULE_PRIORITY updated in policy '$POLICY_NAME'"
}

# Function to attach policy to backend service
attach_policy() {
    print_info "Attaching Cloud Armor policy to backend service..."
    
    read -p "Enter backend service name: " BACKEND_SERVICE
    if [[ -z "$BACKEND_SERVICE" ]]; then
        print_error "Backend service name is required"
        return 1
    fi
    
    read -p "Enter security policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Security policy name is required"
        return 1
    fi
    
    read -p "Is this a global backend service? (y/N): " IS_GLOBAL
    
    if [[ $IS_GLOBAL == [yY] ]]; then
        gcloud compute backend-services update "$BACKEND_SERVICE" \
            --security-policy="$POLICY_NAME" \
            --global \
            --project="$PROJECT_ID"
    else
        read -p "Enter region: " REGION
        if [[ -z "$REGION" ]]; then
            print_error "Region is required for regional backend service"
            return 1
        fi
        
        gcloud compute backend-services update "$BACKEND_SERVICE" \
            --security-policy="$POLICY_NAME" \
            --region="$REGION" \
            --project="$PROJECT_ID"
    fi
    
    print_success "Security policy '$POLICY_NAME' attached to backend service '$BACKEND_SERVICE'"
}

# Function to detach policy from backend service
detach_policy() {
    print_info "Detaching Cloud Armor policy from backend service..."
    
    read -p "Enter backend service name: " BACKEND_SERVICE
    if [[ -z "$BACKEND_SERVICE" ]]; then
        print_error "Backend service name is required"
        return 1
    fi
    
    read -p "Is this a global backend service? (y/N): " IS_GLOBAL
    
    if [[ $IS_GLOBAL == [yY] ]]; then
        gcloud compute backend-services update "$BACKEND_SERVICE" \
            --no-security-policy \
            --global \
            --project="$PROJECT_ID"
    else
        read -p "Enter region: " REGION
        if [[ -z "$REGION" ]]; then
            print_error "Region is required for regional backend service"
            return 1
        fi
        
        gcloud compute backend-services update "$BACKEND_SERVICE" \
            --no-security-policy \
            --region="$REGION" \
            --project="$PROJECT_ID"
    fi
    
    print_success "Security policy detached from backend service '$BACKEND_SERVICE'"
}

# Function to create rate limiting rule
create_rate_limit_rule() {
    print_info "Creating rate limiting rule..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    read -p "Enter rule priority: " RULE_PRIORITY
    if [[ -z "$RULE_PRIORITY" ]]; then
        print_error "Rule priority is required"
        return 1
    fi
    
    read -p "Enter rate limit threshold (requests per minute): " RATE_LIMIT
    RATE_LIMIT=${RATE_LIMIT:-100}
    
    read -p "Enter ban duration in seconds: " BAN_DURATION
    BAN_DURATION=${BAN_DURATION:-600}
    
    gcloud compute security-policies rules create "$RULE_PRIORITY" \
        --security-policy="$POLICY_NAME" \
        --description="Rate limiting rule - $RATE_LIMIT requests per minute" \
        --action="rate-based-ban" \
        --rate-limit-threshold-count="$RATE_LIMIT" \
        --rate-limit-threshold-interval-sec=60 \
        --ban-duration-sec="$BAN_DURATION" \
        --conform-action=allow \
        --exceed-action=deny-429 \
        --enforce-on-key=IP \
        --project="$PROJECT_ID"
    
    print_success "Rate limiting rule created with priority $RULE_PRIORITY"
}

# Function to create geo-blocking rule
create_geo_blocking_rule() {
    print_info "Creating geo-blocking rule..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    read -p "Enter rule priority: " RULE_PRIORITY
    if [[ -z "$RULE_PRIORITY" ]]; then
        print_error "Rule priority is required"
        return 1
    fi
    
    read -p "Enter country codes to block (comma-separated, e.g., CN,RU): " COUNTRY_CODES
    if [[ -z "$COUNTRY_CODES" ]]; then
        print_error "Country codes are required"
        return 1
    fi
    
    # Convert comma-separated list to array and create expression
    IFS=',' read -ra COUNTRIES <<< "$COUNTRY_CODES"
    EXPRESSION=""
    for i in "${!COUNTRIES[@]}"; do
        if [[ $i -eq 0 ]]; then
            EXPRESSION="origin.region_code == \"${COUNTRIES[i]}\""
        else
            EXPRESSION="$EXPRESSION || origin.region_code == \"${COUNTRIES[i]}\""
        fi
    done
    
    gcloud compute security-policies rules create "$RULE_PRIORITY" \
        --security-policy="$POLICY_NAME" \
        --description="Geo-blocking rule - blocking countries: $COUNTRY_CODES" \
        --action="deny-403" \
        --expression="$EXPRESSION" \
        --project="$PROJECT_ID"
    
    print_success "Geo-blocking rule created with priority $RULE_PRIORITY"
}

# Function to create IP whitelist rule
create_ip_whitelist_rule() {
    print_info "Creating IP whitelist rule..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    read -p "Enter rule priority: " RULE_PRIORITY
    if [[ -z "$RULE_PRIORITY" ]]; then
        print_error "Rule priority is required"
        return 1
    fi
    
    read -p "Enter IP ranges to whitelist (comma-separated CIDR blocks): " IP_RANGES
    if [[ -z "$IP_RANGES" ]]; then
        print_error "IP ranges are required"
        return 1
    fi
    
    gcloud compute security-policies rules create "$RULE_PRIORITY" \
        --security-policy="$POLICY_NAME" \
        --description="IP whitelist rule" \
        --action="allow" \
        --src-ip-ranges="$IP_RANGES" \
        --project="$PROJECT_ID"
    
    print_success "IP whitelist rule created with priority $RULE_PRIORITY"
}

# Function to create IP blacklist rule
create_ip_blacklist_rule() {
    print_info "Creating IP blacklist rule..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    read -p "Enter rule priority: " RULE_PRIORITY
    if [[ -z "$RULE_PRIORITY" ]]; then
        print_error "Rule priority is required"
        return 1
    fi
    
    read -p "Enter IP ranges to blacklist (comma-separated CIDR blocks): " IP_RANGES
    if [[ -z "$IP_RANGES" ]]; then
        print_error "IP ranges are required"
        return 1
    fi
    
    gcloud compute security-policies rules create "$RULE_PRIORITY" \
        --security-policy="$POLICY_NAME" \
        --description="IP blacklist rule" \
        --action="deny-403" \
        --src-ip-ranges="$IP_RANGES" \
        --project="$PROJECT_ID"
    
    print_success "IP blacklist rule created with priority $RULE_PRIORITY"
}

# Function to get security policy details
get_policy() {
    print_info "Getting Cloud Armor security policy details..."
    
    read -p "Enter policy name: " POLICY_NAME
    if [[ -z "$POLICY_NAME" ]]; then
        print_error "Policy name is required"
        return 1
    fi
    
    gcloud compute security-policies describe "$POLICY_NAME" \
        --project="$PROJECT_ID"
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
            delete-policy)
                set_project
                delete_policy
                exit 0
                ;;
            add-rule)
                set_project
                add_rule
                exit 0
                ;;
            delete-rule)
                set_project
                delete_rule
                exit 0
                ;;
            list-rules)
                set_project
                list_rules
                exit 0
                ;;
            update-rule)
                set_project
                update_rule
                exit 0
                ;;
            attach-policy)
                set_project
                attach_policy
                exit 0
                ;;
            detach-policy)
                set_project
                detach_policy
                exit 0
                ;;
            create-rate-limit-rule)
                set_project
                create_rate_limit_rule
                exit 0
                ;;
            create-geo-blocking-rule)
                set_project
                create_geo_blocking_rule
                exit 0
                ;;
            create-ip-whitelist-rule)
                set_project
                create_ip_whitelist_rule
                exit 0
                ;;
            create-ip-blacklist-rule)
                set_project
                create_ip_blacklist_rule
                exit 0
                ;;
            get-policy)
                set_project
                get_policy
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
