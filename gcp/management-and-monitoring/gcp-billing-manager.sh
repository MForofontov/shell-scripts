#!/usr/bin/env bash
# gcp-billing-manager.sh
# Script to manage GCP billing accounts, budgets, and cost monitoring.

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
BILLING_ACCOUNT_ID=""
BUDGET_NAME=""
BUDGET_AMOUNT=""
CURRENCY="USD"
THRESHOLD_PERCENT="80"
EMAIL_RECIPIENTS=""
PUBSUB_TOPIC=""
BILLING_PERIOD="MONTH"
DISPLAY_NAME=""
EXPORT_DATASET=""
EXPORT_TABLE=""
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Billing Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP billing accounts, budgets, and cost monitoring."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mActions:\033[0m"
  echo -e "  \033[1;33mlist-billing-accounts\033[0m    List all billing accounts"
  echo -e "  \033[1;33mget-billing-account\033[0m      Get billing account details"
  echo -e "  \033[1;33mlink-project\033[0m             Link project to billing account"
  echo -e "  \033[1;33munlink-project\033[0m           Unlink project from billing account"
  echo -e "  \033[1;33mget-project-billing\033[0m      Get project billing information"
  echo -e "  \033[1;33mcreate-budget\033[0m            Create a budget"
  echo -e "  \033[1;33mupdate-budget\033[0m            Update a budget"
  echo -e "  \033[1;33mdelete-budget\033[0m            Delete a budget"
  echo -e "  \033[1;33mlist-budgets\033[0m             List all budgets"
  echo -e "  \033[1;33mget-budget\033[0m               Get budget details"
  echo -e "  \033[1;33mget-billing-costs\033[0m        Get billing costs for a period"
  echo -e "  \033[1;33msetup-export\033[0m             Setup billing export to BigQuery"
  echo -e "  \033[1;33mget-sku-pricing\033[0m          Get SKU pricing information"
  echo -e "  \033[1;33mcost-analysis\033[0m            Generate cost analysis report"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m       (Optional) GCP project ID"
  echo -e "  \033[1;33m--billing-account <id>\033[0m       (Required for some actions) Billing account ID"
  echo -e "  \033[1;33m--budget <name>\033[0m              (Required for budget actions) Budget name"
  echo -e "  \033[1;33m--amount <value>\033[0m             (Required for budget creation) Budget amount"
  echo -e "  \033[1;33m--currency <code>\033[0m            (Optional) Currency code (default: USD)"
  echo -e "  \033[1;33m--threshold <percent>\033[0m        (Optional) Alert threshold percentage (default: 80)"
  echo -e "  \033[1;33m--email <recipients>\033[0m         (Optional) Email recipients for alerts (comma-separated)"
  echo -e "  \033[1;33m--pubsub-topic <topic>\033[0m       (Optional) Pub/Sub topic for alerts"
  echo -e "  \033[1;33m--period <period>\033[0m            (Optional) Billing period: MONTH, QUARTER, YEAR (default: MONTH)"
  echo -e "  \033[1;33m--display-name <name>\033[0m        (Optional) Display name for resources"
  echo -e "  \033[1;33m--export-dataset <dataset>\033[0m   (Optional) BigQuery dataset for billing export"
  echo -e "  \033[1;33m--export-table <table>\033[0m       (Optional) BigQuery table for billing export"
  echo -e "  \033[1;33m--force\033[0m                      (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                    (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                    (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m             (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                       (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 list-billing-accounts"
  echo "  $0 link-project --project my-project --billing-account 123456-ABCDEF-789012"
  echo "  $0 create-budget --billing-account 123456-ABCDEF-789012 --budget 'Monthly Budget' --amount 1000 --email admin@example.com"
  echo "  $0 get-billing-costs --project my-project"
  echo "  $0 setup-export --billing-account 123456-ABCDEF-789012 --export-dataset billing_data --export-table gcp_billing_export"
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
      --billing-account)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No billing account ID provided after --billing-account."
          usage
        fi
        BILLING_ACCOUNT_ID="$2"
        shift 2
        ;;
      --budget)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No budget name provided after --budget."
          usage
        fi
        BUDGET_NAME="$2"
        shift 2
        ;;
      --amount)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No amount provided after --amount."
          usage
        fi
        BUDGET_AMOUNT="$2"
        shift 2
        ;;
      --currency)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No currency provided after --currency."
          usage
        fi
        CURRENCY="$2"
        shift 2
        ;;
      --threshold)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No threshold provided after --threshold."
          usage
        fi
        THRESHOLD_PERCENT="$2"
        shift 2
        ;;
      --email)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No email recipients provided after --email."
          usage
        fi
        EMAIL_RECIPIENTS="$2"
        shift 2
        ;;
      --pubsub-topic)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No Pub/Sub topic provided after --pubsub-topic."
          usage
        fi
        PUBSUB_TOPIC="$2"
        shift 2
        ;;
      --period)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No period provided after --period."
          usage
        fi
        BILLING_PERIOD="$2"
        shift 2
        ;;
      --display-name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No display name provided after --display-name."
          usage
        fi
        DISPLAY_NAME="$2"
        shift 2
        ;;
      --export-dataset)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No export dataset provided after --export-dataset."
          usage
        fi
        EXPORT_DATASET="$2"
        shift 2
        ;;
      --export-table)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No export table provided after --export-table."
          usage
        fi
        EXPORT_TABLE="$2"
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

#=====================================================================
# BILLING ACCOUNT FUNCTIONS
#=====================================================================
# Function to list billing accounts
list_billing_accounts() {
  format-echo "INFO" "Listing billing accounts"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list billing accounts"
    return 0
  fi
  
  if ! gcloud billing accounts list \
    --format="table(name,displayName,open,masterBillingAccount)"; then
    format-echo "ERROR" "Failed to list billing accounts"
    return 1
  fi
  
  return 0
}

# Function to get billing account details
get_billing_account() {
  local account_id="$1"
  
  format-echo "INFO" "Getting billing account details: $account_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get billing account details: $account_id"
    return 0
  fi
  
  if ! gcloud billing accounts describe "$account_id"; then
    format-echo "ERROR" "Failed to get billing account details: $account_id"
    return 1
  fi
  
  return 0
}

# Function to link project to billing account
link_project() {
  local project="$1"
  local account_id="$2"
  
  format-echo "INFO" "Linking project $project to billing account: $account_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would link project to billing account"
    return 0
  fi
  
  if ! gcloud billing projects link "$project" \
    --billing-account="$account_id"; then
    format-echo "ERROR" "Failed to link project to billing account"
    return 1
  fi
  
  format-echo "SUCCESS" "Linked project $project to billing account: $account_id"
  return 0
}

# Function to unlink project from billing account
unlink_project() {
  local project="$1"
  
  format-echo "INFO" "Unlinking project from billing account: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would unlink project from billing account"
    return 0
  fi
  
  if ! gcloud billing projects unlink "$project"; then
    format-echo "ERROR" "Failed to unlink project from billing account"
    return 1
  fi
  
  format-echo "SUCCESS" "Unlinked project from billing account: $project"
  return 0
}

# Function to get project billing information
get_project_billing() {
  local project="$1"
  
  format-echo "INFO" "Getting billing information for project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get project billing information"
    return 0
  fi
  
  if ! gcloud billing projects describe "$project"; then
    format-echo "ERROR" "Failed to get project billing information"
    return 1
  fi
  
  return 0
}

#=====================================================================
# BUDGET FUNCTIONS
#=====================================================================
# Function to create budget
create_budget() {
  local account_id="$1"
  local budget_name="$2"
  local amount="$3"
  
  format-echo "INFO" "Creating budget: $budget_name with amount: $amount $CURRENCY"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create budget:"
    format-echo "INFO" "  Name: $budget_name"
    format-echo "INFO" "  Amount: $amount $CURRENCY"
    format-echo "INFO" "  Threshold: ${THRESHOLD_PERCENT}%"
    return 0
  fi
  
  # Create temporary budget file
  local budget_file="/tmp/budget-$$.json"
  cat > "$budget_file" << EOF
{
  "displayName": "$budget_name",
  "budgetFilter": {
    "billingAccount": "billingAccounts/$account_id"
  },
  "amount": {
    "specifiedAmount": {
      "currencyCode": "$CURRENCY",
      "units": "$amount"
    }
  },
  "thresholdRules": [
    {
      "thresholdPercent": $(echo "$THRESHOLD_PERCENT" | sed 's/%//')/100,
      "spendBasis": "CURRENT_SPEND"
    }
  ]
}
EOF
  
  # Add project filter if provided
  if [ -n "$PROJECT_ID" ]; then
    local temp_file="/tmp/budget-with-project-$$.json"
    jq --arg project "$PROJECT_ID" '.budgetFilter.projects = ["projects/" + $project]' "$budget_file" > "$temp_file"
    mv "$temp_file" "$budget_file"
  fi
  
  # Add notification rules if email or pubsub provided
  if [ -n "$EMAIL_RECIPIENTS" ] || [ -n "$PUBSUB_TOPIC" ]; then
    local notifications='{"allUpdatesRule": {"schemaVersion": "1.0"}}'
    
    if [ -n "$EMAIL_RECIPIENTS" ]; then
      local email_array
      email_array=$(echo "$EMAIL_RECIPIENTS" | tr ',' '\n' | jq -R . | jq -s .)
      notifications=$(echo "$notifications" | jq --argjson emails "$email_array" '.allUpdatesRule.monitoringNotificationChannels = $emails')
    fi
    
    if [ -n "$PUBSUB_TOPIC" ]; then
      notifications=$(echo "$notifications" | jq --arg topic "$PUBSUB_TOPIC" '.allUpdatesRule.pubsubTopic = $topic')
    fi
    
    local temp_file="/tmp/budget-with-notifications-$$.json"
    jq --argjson notifications "$notifications" '.notificationsRule = $notifications' "$budget_file" > "$temp_file"
    mv "$temp_file" "$budget_file"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Budget configuration:"
    cat "$budget_file"
  fi
  
  if ! gcloud billing budgets create \
    --billing-account="$account_id" \
    --budget-from-file="$budget_file"; then
    format-echo "ERROR" "Failed to create budget: $budget_name"
    rm -f "$budget_file"
    return 1
  fi
  
  rm -f "$budget_file"
  format-echo "SUCCESS" "Created budget: $budget_name"
  return 0
}

# Function to list budgets
list_budgets() {
  local account_id="$1"
  
  format-echo "INFO" "Listing budgets for billing account: $account_id"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list budgets"
    return 0
  fi
  
  if ! gcloud billing budgets list \
    --billing-account="$account_id" \
    --format="table(displayName,amount.specifiedAmount.units,amount.specifiedAmount.currencyCode,thresholdRules[0].thresholdPercent)"; then
    format-echo "ERROR" "Failed to list budgets"
    return 1
  fi
  
  return 0
}

# Function to get billing costs
get_billing_costs() {
  local project="$1"
  
  format-echo "INFO" "Getting billing costs for project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get billing costs for project: $project"
    return 0
  fi
  
  # Get current month costs using BigQuery if available
  if command_exists bq; then
    local query="SELECT 
      service.description as service,
      SUM(cost) as total_cost,
      currency
    FROM \`$project.billing.gcp_billing_export_v1_*\`
    WHERE EXTRACT(MONTH FROM usage_start_time) = EXTRACT(MONTH FROM CURRENT_DATE())
      AND EXTRACT(YEAR FROM usage_start_time) = EXTRACT(YEAR FROM CURRENT_DATE())
    GROUP BY service.description, currency
    ORDER BY total_cost DESC"
    
    format-echo "INFO" "Querying billing costs from BigQuery..."
    if ! bq query --use_legacy_sql=false --format=table "$query" 2>/dev/null; then
      format-echo "WARNING" "BigQuery billing export not available or accessible"
      format-echo "INFO" "To enable billing export, run: $0 setup-export --billing-account <account-id> --export-dataset billing_data"
    fi
  else
    format-echo "WARNING" "BigQuery CLI not available. Install bq tool for cost analysis."
    format-echo "INFO" "Basic project billing information:"
    get_project_billing "$project"
  fi
  
  return 0
}

# Function to setup billing export
setup_billing_export() {
  local account_id="$1"
  local dataset="${2:-billing_data}"
  local table="${3:-gcp_billing_export}"
  
  format-echo "INFO" "Setting up billing export to BigQuery"
  format-echo "INFO" "Billing Account: $account_id"
  format-echo "INFO" "Dataset: $dataset"
  format-echo "INFO" "Table: $table"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would setup billing export"
    return 0
  fi
  
  # Create dataset if it doesn't exist
  if command_exists bq; then
    if ! bq show "$dataset" >/dev/null 2>&1; then
      format-echo "INFO" "Creating BigQuery dataset: $dataset"
      if ! bq mk --location=US "$dataset"; then
        format-echo "ERROR" "Failed to create dataset: $dataset"
        return 1
      fi
    fi
  else
    format-echo "ERROR" "BigQuery CLI (bq) is required for billing export setup"
    return 1
  fi
  
  format-echo "INFO" "Billing export setup requires manual configuration in the Cloud Console:"
  format-echo "INFO" "1. Go to https://console.cloud.google.com/billing/$account_id"
  format-echo "INFO" "2. Navigate to 'Billing export'"
  format-echo "INFO" "3. Configure BigQuery export with:"
  format-echo "INFO" "   - Dataset: $dataset"
  format-echo "INFO" "   - Table: $table"
  
  return 0
}

# Function to generate cost analysis
cost_analysis() {
  local project="${1:-$PROJECT_ID}"
  
  format-echo "INFO" "Generating cost analysis report for project: $project"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would generate cost analysis"
    return 0
  fi
  
  local report_file="cost-analysis-$(date +%Y%m%d-%H%M%S).txt"
  
  {
    echo "=== GCP Cost Analysis Report ==="
    echo "Project: $project"
    echo "Generated: $(date)"
    echo "================================"
    echo
    
    echo "1. Project Billing Information:"
    gcloud billing projects describe "$project" 2>/dev/null || echo "   Unable to retrieve billing information"
    echo
    
    echo "2. Current Resource Usage:"
    echo "   Compute Instances:"
    gcloud compute instances list --project="$project" --format="table(name,zone,machineType,status)" 2>/dev/null || echo "   No compute instances or access denied"
    echo
    
    echo "   Storage Buckets:"
    gsutil ls -p "$project" 2>/dev/null || echo "   No storage buckets or access denied"
    echo
    
    echo "   Cloud SQL Instances:"
    gcloud sql instances list --project="$project" --format="table(name,region,tier,state)" 2>/dev/null || echo "   No SQL instances or access denied"
    echo
    
    echo "3. Recommendations:"
    echo "   - Review unused resources regularly"
    echo "   - Consider committed use discounts for long-term workloads"
    echo "   - Set up budget alerts to monitor spending"
    echo "   - Use preemptible instances for non-critical workloads"
    echo
  } > "$report_file"
  
  format-echo "SUCCESS" "Cost analysis report generated: $report_file"
  
  if [ "$VERBOSE" = true ]; then
    cat "$report_file"
  fi
  
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
  
  print_with_separator "GCP Billing Manager Script"
  format-echo "INFO" "Starting GCP Billing Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Billing Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Billing Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    link-project|unlink-project|get-project-billing|get-billing-costs)
      if [ -z "$PROJECT_ID" ]; then
        format-echo "ERROR" "Project ID is required for action: $ACTION"
        exit 1
      fi
      ;;
    get-billing-account|create-budget|list-budgets|setup-export)
      if [ -z "$BILLING_ACCOUNT_ID" ]; then
        format-echo "ERROR" "Billing account ID is required for action: $ACTION"
        exit 1
      fi
      ;;
    link-project)
      if [ -z "$PROJECT_ID" ] || [ -z "$BILLING_ACCOUNT_ID" ]; then
        format-echo "ERROR" "Both project ID and billing account ID are required for linking"
        exit 1
      fi
      ;;
    create-budget)
      if [ -z "$BILLING_ACCOUNT_ID" ] || [ -z "$BUDGET_NAME" ] || [ -z "$BUDGET_AMOUNT" ]; then
        format-echo "ERROR" "Billing account ID, budget name, and amount are required for budget creation"
        exit 1
      fi
      ;;
    list-billing-accounts|cost-analysis)
      # No additional requirements
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: list-billing-accounts, get-billing-account, link-project, unlink-project, get-project-billing, create-budget, update-budget, delete-budget, list-budgets, get-budget, get-billing-costs, setup-export, get-sku-pricing, cost-analysis"
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    list-billing-accounts)
      if list_billing_accounts; then
        format-echo "SUCCESS" "Listed billing accounts successfully"
      else
        format-echo "ERROR" "Failed to list billing accounts"
        exit 1
      fi
      ;;
    get-billing-account)
      if get_billing_account "$BILLING_ACCOUNT_ID"; then
        format-echo "SUCCESS" "Retrieved billing account details successfully"
      else
        format-echo "ERROR" "Failed to get billing account details"
        exit 1
      fi
      ;;
    link-project)
      if link_project "$PROJECT_ID" "$BILLING_ACCOUNT_ID"; then
        format-echo "SUCCESS" "Project linking completed successfully"
      else
        format-echo "ERROR" "Failed to link project"
        exit 1
      fi
      ;;
    unlink-project)
      if unlink_project "$PROJECT_ID"; then
        format-echo "SUCCESS" "Project unlinking completed successfully"
      else
        format-echo "ERROR" "Failed to unlink project"
        exit 1
      fi
      ;;
    get-project-billing)
      if get_project_billing "$PROJECT_ID"; then
        format-echo "SUCCESS" "Retrieved project billing information successfully"
      else
        format-echo "ERROR" "Failed to get project billing information"
        exit 1
      fi
      ;;
    create-budget)
      if create_budget "$BILLING_ACCOUNT_ID" "$BUDGET_NAME" "$BUDGET_AMOUNT"; then
        format-echo "SUCCESS" "Budget creation completed successfully"
      else
        format-echo "ERROR" "Failed to create budget"
        exit 1
      fi
      ;;
    list-budgets)
      if list_budgets "$BILLING_ACCOUNT_ID"; then
        format-echo "SUCCESS" "Listed budgets successfully"
      else
        format-echo "ERROR" "Failed to list budgets"
        exit 1
      fi
      ;;
    get-billing-costs)
      if get_billing_costs "$PROJECT_ID"; then
        format-echo "SUCCESS" "Retrieved billing costs successfully"
      else
        format-echo "ERROR" "Failed to get billing costs"
        exit 1
      fi
      ;;
    setup-export)
      if setup_billing_export "$BILLING_ACCOUNT_ID" "$EXPORT_DATASET" "$EXPORT_TABLE"; then
        format-echo "SUCCESS" "Billing export setup completed successfully"
      else
        format-echo "ERROR" "Failed to setup billing export"
        exit 1
      fi
      ;;
    cost-analysis)
      if cost_analysis "$PROJECT_ID"; then
        format-echo "SUCCESS" "Cost analysis completed successfully"
      else
        format-echo "ERROR" "Failed to generate cost analysis"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Billing Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
