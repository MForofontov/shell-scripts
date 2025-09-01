# GitHub Copilot Instructions for shell-scripts

## Project Overview

This is a comprehensive Bash automation toolkit providing production-ready shell scripts for infrastructure management, system administration, and development workflows. The project emphasizes reliability, security, and maintainable code structure with standardized patterns across 100+ scripts.

## Architecture & Structure

### Core Principles
- **Reliability**: Robust error handling with `set -euo pipefail`
- **Consistency**: Standardized script templates and shared function libraries
- **Security**: Input validation, authentication checks, and least privilege access
- **Maintainability**: Clear documentation, modular design, and shared utilities
- **Idempotency**: Operations can be safely run multiple times

### Directory Structure
```
shell-scripts/
├── .github/                           # GitHub-specific files and workflows
├── development-and-code-management/   # Git workflows, dependency updates
│   ├── dependencies-updater/          # Automated package updates (npm, Python)
│   └── git/                          # Git automation (commits, stash, conflicts)
├── file-scripts/                     # File system operations and utilities
├── functions/                        # Shared libraries and utilities (CRITICAL)
│   ├── common-init.sh               # Core initialization, sourced by all scripts
│   ├── utility.sh                   # General utility functions
│   ├── format-echo/                 # Standardized output formatting
│   └── print-functions/             # Print utilities for consistent messaging
├── gcp/                             # Google Cloud Platform service management
│   ├── compute-and-containers/      # VM instances, GKE clusters, container registries
│   ├── data-and-analytics/          # BigQuery, Dataflow, Dataproc
│   ├── developer-tools/             # Source Repos, Cloud Build, Artifact Registry
│   ├── management-and-monitoring/   # Billing, Logging, Monitoring, Project mgmt
│   ├── networking/                  # CDN, NAT, VPN, DNS, Traffic Director
│   ├── security/                    # IAM policies, KMS encryption, Secret Manager
│   ├── serverless/                  # App Engine, Cloud Run, Functions, Pub/Sub
│   └── storage-and-databases/       # Cloud Storage buckets, Cloud SQL instances
├── k8s-scripts/                     # Kubernetes cluster and workload management
│   ├── cluster-maintenance/         # Cluster health, updates, backups
│   ├── cluster-management/          # Cluster creation, configuration
│   ├── image-management/            # Container image operations
│   ├── node-management/             # Node pools, scaling, maintenance
│   ├── pipelines/                   # CI/CD pipeline automation
│   └── workload-management/         # Deployments, services, ingress
├── network-and-connectivity/        # Network diagnostics and monitoring tools
├── security-and-access/            # Security auditing and access control
├── system-scripts/                 # System resource monitoring and management
└── utils/                          # Miscellaneous utilities and helpers
```

## Development Guidelines

### Script Development Standards

#### 1. Script Structure Template
Every script must follow this standardized template:

```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Source common functions
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"

# Configuration section - Default values
PROJECT_ID=""
COMMAND=""
RESOURCE_NAME=""
REGION="us-central1"

# Usage/Help function with comprehensive documentation
usage() {
  print_with_separator "Script Name - Purpose"
  cat << 'EOF'
Description of what this script does and when to use it.

Usage:
  script-name.sh [OPTIONS] COMMAND [ARGS]

Commands:
  create     Create new resource
  list       List existing resources
  update     Update resource configuration
  delete     Delete resource (with confirmation)
  status     Show resource status

Options:
  -p, --project PROJECT_ID    GCP Project ID
  -r, --region REGION         Region (default: us-central1)
  -h, --help                  Show this help message

Examples:
  # List resources
  ./script-name.sh -p my-project list
  
  # Create resource with specific configuration
  ./script-name.sh -p my-project --region us-east1 create resource-name
  
  # Show resource status
  ./script-name.sh -p my-project status resource-name

Requirements:
  - gcloud CLI installed and authenticated
  - Required APIs enabled automatically
  - Appropriate IAM permissions

EOF
}

# Robust argument parsing
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--project)
        PROJECT_ID="$2"
        shift 2
        ;;
      -r|--region)
        REGION="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      create|list|update|delete|status)
        COMMAND="$1"
        shift
        ;;
      *)
        format_echo "ERROR" "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$PROJECT_ID" ]]; then
    format_echo "ERROR" "Project ID is required. Use -p or --project flag."
    usage
    exit 1
  fi

  if [[ -z "$COMMAND" ]]; then
    format_echo "ERROR" "Command is required."
    usage
    exit 1
  fi
}

# Authentication and setup functions
check_authentication() {
  if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    format_echo "ERROR" "Please authenticate with gcloud: gcloud auth login"
    exit 1
  fi
}

set_project_context() {
  format_echo "INFO" "Setting project context to: $PROJECT_ID"
  if ! gcloud config set project "$PROJECT_ID" >/dev/null 2>&1; then
    format_echo "ERROR" "Failed to set project: $PROJECT_ID"
    exit 1
  fi
}

enable_required_apis() {
  local apis=("compute.googleapis.com" "container.googleapis.com")
  
  for api in "${apis[@]}"; do
    format_echo "INFO" "Enabling API: $api"
    gcloud services enable "$api" --quiet
  done
}

# Core CRUD operations
create_resource() {
  format_echo "INFO" "Creating resource: $1"
  # Implementation here
  format_echo "SUCCESS" "Resource created successfully"
}

list_resources() {
  format_echo "INFO" "Listing resources in project: $PROJECT_ID"
  # Implementation here
}

update_resource() {
  format_echo "INFO" "Updating resource: $1"
  # Implementation here
  format_echo "SUCCESS" "Resource updated successfully"
}

delete_resource() {
  format_echo "WARNING" "This will delete resource: $1"
  read -r -p "Are you sure? (y/N): " confirm
  
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    format_echo "INFO" "Deleting resource: $1"
    # Implementation here
    format_echo "SUCCESS" "Resource deleted successfully"
  else
    format_echo "INFO" "Deletion cancelled"
  fi
}

show_resource_status() {
  format_echo "INFO" "Checking status for resource: $1"
  # Implementation here
}

# Command execution dispatcher
execute_command() {
  case "$COMMAND" in
    create)
      create_resource "$@"
      ;;
    list)
      list_resources
      ;;
    update)
      update_resource "$@"
      ;;
    delete)
      delete_resource "$@"
      ;;
    status)
      show_resource_status "$@"
      ;;
    *)
      format_echo "ERROR" "Unknown command: $COMMAND"
      usage
      exit 1
      ;;
  esac
}

# Main function
main() {
  parse_args "$@"
  check_authentication
  set_project_context
  enable_required_apis
  execute_command "$@"
}

# Script execution
main "$@"
```

#### 2. Mandatory Components
Every script must include:

1. **Shebang & Error Handling**:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail  # Critical for reliability
   ```

2. **Function Sourcing**:
   ```bash
   # shellcheck source=functions/common-init.sh
   source "$(dirname "$0")/../../functions/common-init.sh"
   ```

3. **Comprehensive Usage Function**:
   - Clear description and examples
   - All commands and options documented
   - Requirements and prerequisites listed
   - Color-coded output using format-echo

4. **Input Validation**:
   - Robust argument parsing with proper error handling
   - Validation of required parameters
   - Clear error messages for invalid input

5. **Authentication & Setup** (for GCP scripts):
   - Validates gcloud authentication status
   - Sets/validates project context
   - Enables required APIs automatically

### Error Handling Standards

#### Error Handling Patterns
```bash
# Check prerequisites
if ! command -v gcloud >/dev/null 2>&1; then
  format_echo "ERROR" "gcloud CLI not found. Please install Google Cloud SDK."
  exit 1
fi

# Validate required parameters
if [[ -z "$PROJECT_ID" ]]; then
  format_echo "ERROR" "Project ID is required. Use -p or --project flag."
  usage
  exit 1
fi

# Handle API responses with proper error checking
if ! gcloud compute instances create "$INSTANCE_NAME" --project="$PROJECT_ID" 2>/dev/null; then
  format_echo "ERROR" "Failed to create instance: $INSTANCE_NAME"
  exit 1
fi

# Confirmation prompts for destructive operations
confirm_destructive_action() {
  local action="$1"
  local resource="$2"
  
  format_echo "WARNING" "This will $action: $resource"
  read -r -p "Are you sure? This action cannot be undone (y/N): " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    format_echo "INFO" "Operation cancelled"
    exit 0
  fi
}
```

### Testing & Validation Standards

#### Pre-deployment Checks
Before committing any script, ensure:

1. **Syntax Validation**:
   ```bash
   # Use shellcheck for static analysis
   shellcheck script-name.sh
   
   # Test syntax
   bash -n script-name.sh
   ```

2. **Functional Testing**:
   - Test all commands (create, list, update, delete, status)
   - Test error conditions and invalid inputs
   - Verify help/usage output
   - Test with different parameter combinations

3. **Integration Testing**:
   - Test in isolated GCP project/environment
   - Verify API interactions work correctly
   - Test authentication flows
   - Validate resource cleanup

#### Testing Checklist
- [ ] Script uses strict error handling (`set -euo pipefail`)
- [ ] Common functions properly sourced
- [ ] Comprehensive help/usage function exists
- [ ] All user inputs validated
- [ ] Destructive operations have confirmation prompts
- [ ] Script is executable (`chmod +x`)
- [ ] ShellCheck passes without errors
- [ ] All commands tested in safe environment

### Shared Function Library (`functions/`)

#### Core Dependencies
All scripts must source the shared function library:

- **`common-init.sh`**: Core initialization, path resolution, dependency checking
- **`format-echo.sh`**: Standardized output with colors (SUCCESS, ERROR, WARNING, INFO)
- **`print-with-separator.sh`**: Section dividers for readable output
- **`utility.sh`**: General utility functions

#### Usage Example
```bash
# Proper sourcing with relative path resolution
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../../functions/common-init.sh"

# Using shared formatting functions
format_echo "INFO" "Starting operation..."
print_with_separator "Configuration Section"
format_echo "SUCCESS" "Operation completed successfully"
format_echo "ERROR" "Operation failed"
format_echo "WARNING" "This is a warning message"
```

### Naming Conventions & Code Style

#### File Naming
- **Scripts**: `service-action-manager.sh` (e.g., `gcp-storage-manager.sh`)
- **Functions**: `verb_noun()` (e.g., `create_bucket()`, `list_instances()`)
- **Variables**: `UPPER_CASE` for constants/globals, `lower_case` for local vars
- **Commands**: `kebab-case` for user-facing commands (e.g., `create-bucket`)

#### Code Formatting Standards
- **Indentation**: 2 spaces (no tabs)
- **Line Length**: Maximum 120 characters
- **Quotes**: Use double quotes for variables, single quotes for literal strings
- **Comments**: Clear, concise explanations of complex logic

## Best Practices for GitHub Copilot

### When Adding New Scripts

1. **Analyze Script Purpose**: Determine correct directory based on functionality
2. **Follow Template**: Use existing scripts as reference for structure
3. **Use Shared Functions**: Always source `functions/common-init.sh`
4. **Comprehensive Help**: Include detailed usage, examples, and requirements
5. **Error Handling**: Implement robust error checking and user feedback
6. **Test Thoroughly**: Validate in safe environment before committing

### When Adding New Modules/Categories

1. **Create new directory** following the naming convention (e.g., `new-category/`)
2. **Organize by logical grouping** - group related scripts together (e.g., `gcp/serverless/`, `k8s-scripts/cluster-management/`)
3. **Update this document** (`.github/copilot-instructions.md`) to include the new module by:
   - Adding the new directory to the **Directory Structure** section with description
   - Adding placement guidelines in the **Directory Placement Guidelines** section
   - Including any category-specific standards or patterns in relevant sections
4. **Consider organizational impact**: Ensure the new category is distinct and doesn't overlap with existing ones
5. **Create README.md** in the new directory explaining the category's purpose and script organization
6. **Test directory structure** ensures proper relative path resolution for shared functions

### When Extending Existing Scripts

1. **Maintain Consistency**: Follow existing patterns and naming conventions
2. **Backward Compatibility**: Don't break existing command interfaces
3. **Update Documentation**: Modify usage functions with new commands/options
4. **Test Integration**: Ensure new features work with existing functionality
5. **Consider Impact**: Evaluate effects on dependent scripts or workflows

### Directory Placement Guidelines

#### GCP Scripts (`gcp/`)
- **Compute & Containers**: VM instances, GKE clusters, container services
- **Data & Analytics**: BigQuery, Dataflow, Dataproc, data processing
- **Developer Tools**: Source repos, Cloud Build, Artifact Registry
- **Management & Monitoring**: Billing, logging, monitoring, project management
- **Networking**: CDN, VPN, DNS, load balancers, network security
- **Security**: IAM, KMS, Secret Manager, security policies
- **Serverless**: App Engine, Cloud Run, Functions, Pub/Sub
- **Storage & Databases**: Cloud Storage, Cloud SQL, database services

#### Other Categories
- **System Scripts**: OS-level operations, monitoring, resource management
- **Network Scripts**: Network diagnostics, connectivity testing, scanning
- **Security Scripts**: Access audits, key management, security scanning
- **File Scripts**: File system operations, compression, synchronization
- **Development Scripts**: Git automation, dependency management, CI/CD
- **Kubernetes Scripts**: Cluster management, workload deployment, maintenance

### Security Considerations

#### Authentication & Authorization
- **No Hardcoded Credentials**: Use gcloud auth or service accounts
- **Input Validation**: Sanitize all user inputs
- **Least Privilege**: Request minimal required permissions
- **Audit Trails**: Log operations for compliance and debugging

#### Safe Practices
```bash
# Validate service account permissions
check_permissions() {
  local required_roles=("compute.admin" "storage.admin")
  
  for role in "${required_roles[@]}"; do
    if ! gcloud projects get-iam-policy "$PROJECT_ID" \
       --flatten="bindings[].members" \
       --format="value(bindings.role)" | grep -q "$role"; then
      format_echo "WARNING" "Missing role: $role"
    fi
  done
}

# Secure temporary file handling
create_temp_file() {
  local temp_file
  temp_file=$(mktemp)
  trap "rm -f '$temp_file'" EXIT
  echo "$temp_file"
}
```

### Performance & Efficiency Guidelines

#### Resource Management
- **API Call Optimization**: Batch operations when possible
- **Rate Limiting**: Respect API rate limits
- **Resource Cleanup**: Clean up temporary resources
- **Parallel Processing**: Use background jobs for independent operations

#### Script Optimization
```bash
# Efficient resource listing
list_resources_efficiently() {
  # Use filters to reduce data transfer
  gcloud compute instances list \
    --filter="zone:us-central1-*" \
    --format="table(name,status,zone)" \
    --project="$PROJECT_ID"
}

# Parallel execution for independent operations
process_multiple_resources() {
  local resources=("$@")
  
  for resource in "${resources[@]}"; do
    process_resource "$resource" &
  done
  
  wait  # Wait for all background jobs
}
```

### Common Patterns in the Codebase

#### GCP Resource Management Pattern
```bash
# Standard GCP resource management
manage_gcp_resource() {
  local action="$1"
  local resource_name="$2"
  
  case "$action" in
    create)
      format_echo "INFO" "Creating $resource_name..."
      gcloud service create-command --parameters
      ;;
    delete)
      confirm_destructive_action "delete" "$resource_name"
      format_echo "INFO" "Deleting $resource_name..."
      gcloud service delete-command --parameters
      ;;
  esac
}
```

#### Input Validation Pattern
```bash
validate_input() {
  local input="$1"
  local pattern="$2"
  
  if [[ ! "$input" =~ $pattern ]]; then
    format_echo "ERROR" "Invalid input format: $input"
    return 1
  fi
}
```

#### Configuration Loading Pattern
```bash
load_configuration() {
  local config_file="$1"
  
  if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
    format_echo "SUCCESS" "Configuration loaded from: $config_file"
  else
    format_echo "WARNING" "Configuration file not found: $config_file"
  fi
}
```

### Environment & Dependencies

#### Prerequisites
- **Bash 4.0+**: Modern Bash features required
- **gcloud CLI**: For GCP scripts ([Install Guide](https://cloud.google.com/sdk/docs/install))
- **kubectl**: For Kubernetes scripts ([Install Guide](https://kubernetes.io/docs/tasks/tools/))
- **Docker**: For container-related scripts ([Install Guide](https://docs.docker.com/get-docker/))

#### Environment Setup
```bash
# Set default environment variables
export GCP_PROJECT_ID="my-default-project"
export GCP_REGION="us-central1"
export GCP_ZONE="us-central1-a"

# Authenticate with GCP
gcloud auth login
gcloud config set project "$GCP_PROJECT_ID"

# Make scripts executable
find . -name "*.sh" -type f -exec chmod +x {} \;
```

### Troubleshooting & Common Issues

#### Authentication Issues
```bash
# Check authentication status
gcloud auth list --filter=status:ACTIVE

# Re-authenticate if needed
gcloud auth login
gcloud auth application-default login
```

#### Permission Issues
```bash
# Check project permissions
gcloud projects get-iam-policy "$PROJECT_ID"

# Enable required APIs
gcloud services enable compute.googleapis.com
```

#### Script Debugging
```bash
# Enable debug mode
set -x

# Run with verbose output
./script-name.sh --help
```

### Code Review Guidelines

#### Review Checklist
- [ ] Follows standardized script template
- [ ] Proper error handling with `set -euo pipefail`
- [ ] Shared functions correctly sourced
- [ ] Comprehensive usage/help documentation
- [ ] Input validation and error messages
- [ ] Destructive operations have confirmations
- [ ] ShellCheck passes without issues
- [ ] Tested in safe environment
- [ ] Appropriate directory placement
- [ ] Consistent naming conventions

#### Quality Standards
- **Readability**: Clear variable names and logical flow
- **Reliability**: Robust error handling and edge case management
- **Security**: Input validation and safe credential handling
- **Maintainability**: Consistent patterns and shared utilities
- **Documentation**: Clear comments and comprehensive help text

This document serves as the definitive guide for maintaining code quality, consistency, and best practices in the shell-scripts automation toolkit. All contributors and GitHub Copilot should reference these standards when creating, modifying, or reviewing scripts in this repository.
