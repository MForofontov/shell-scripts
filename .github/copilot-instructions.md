# Copilot Instructions for Shell Scripts Repository

## Purpose
This file provides comprehensive guidance for GitHub Copilot and future contributors on the logic, structure, and best practices of the `shell-scripts` repository. It ensures consistency, maintainability, and extensibility for all automation scripts in this workspace.

## Repository Context
This is a production-ready automation toolkit containing 100+ Bash scripts for:
- **Cloud Infrastructure Management** (primarily Google Cloud Platform)
- **System Administration** (monitoring, resource management, scheduling)
- **Network Operations** (diagnostics, connectivity testing, security scanning)
- **File & Directory Operations** (compression, sync, cleanup, permissions)
- **Development Workflow** (Git automation, dependency management, CI/CD)
- **Security & Access Control** (key management, user audits, firewall configuration)

**Primary Use Cases:**
- DevOps engineers automating cloud infrastructure
- SysAdmins managing servers and networks
- Developers streamlining development workflows
- Security teams auditing and hardening systems

## Project Structure
Scripts are organized by functional domain with clear separation of concerns:

### Core Directories:
- **`development-and-code-management/`** — Git workflows, dependency updates (npm, pip)
  - `git/` — Commit validation, changelog generation, conflict resolution, stash management
  - `dependencies-updater/` — Automated package updates for npm and Python projects
- **`file-scripts/`** — File system operations and utilities
  - Compression/extraction (tar, zip), file comparison, large file detection
  - Directory synchronization, symlink creation, batch file operations
- **`functions/`** — Shared libraries and utilities (CRITICAL: all scripts depend on these)
  - `common-init.sh` — Core initialization functions, sourced by all major scripts
  - `format-echo/` — Standardized output formatting with colors and separators
  - `print-functions/` — Print utilities for consistent messaging across scripts
- **`gcp/`** — Google Cloud Platform service management (largest directory)
  - **`compute-and-containers/`** — VM instances, GKE clusters, container registries
  - **`data-and-analytics/`** — BigQuery, Dataflow, Dataproc for data processing
  - **`developer-tools/`** — Source Repositories, Cloud Build, Artifact Registry, Debugger, Profiler
  - **`management-and-monitoring/`** — Billing, Logging, Monitoring, Trace, Error Reporting, Project management
  - **`networking/`** — CDN, NAT, VPN, Interconnect, DNS, Traffic Director, Network management
  - **`security/`** — IAM policies, KMS encryption, Secret Manager
  - **`serverless/`** — App Engine, Cloud Run, Functions, Pub/Sub messaging
  - **`storage-and-databases/`** — Cloud Storage buckets, Cloud SQL instances
- **`k8s-scripts/`** — Kubernetes cluster and workload management
  - Organized by: cluster-maintenance, cluster-management, image-management, node-management, pipelines, workload-management
- **`network-and-connectivity/`** — Network diagnostics and monitoring tools
  - Port scanning, bandwidth monitoring, DNS resolution, ping utilities, ARP table viewing
- **`security-and-access/`** — Security auditing and access control
  - User/group access audits, SSH key management, firewall configuration, malware scanning
- **`system-scripts/`** — System resource monitoring and process management
  - CPU/disk/network monitoring, system reports, update checks, task scheduling
- **`utils/`** — Miscellaneous utilities and helper scripts
  - SSH key generation, Docker utilities, npm helpers, service management

## Script Logic & Architecture
Every script in this repository follows a standardized template for consistency and reliability:

### Mandatory Components:
1. **Shebang & Error Handling:**
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail  # Exit on error, undefined vars, pipe failures
   ```

2. **Function Sourcing:**
   ```bash
   # shellcheck source=functions/common-init.sh
   source "$(dirname "$0")/../../functions/common-init.sh"
   ```

3. **Configuration Section:**
   - Default values for all variables
   - Clear variable declarations
   - Environment-specific configurations

4. **Usage/Help Function:**
   - Comprehensive documentation with examples
   - Color-coded output using format-echo
   - All available commands and options listed
   - Real-world usage examples

5. **Argument Parsing:**
   - Robust parsing with proper error handling
   - Support for both short (-p) and long (--project) flags
   - Validation of required arguments
   - Clear error messages for invalid input

6. **Authentication & Setup (GCP scripts):**
   - Validates gcloud authentication status
   - Sets/validates project context
   - Enables required APIs automatically
   - Checks service account permissions

7. **Core Operations:**
   - **Create:** Resource creation with validation
   - **Read/List:** Resource enumeration and details
   - **Update:** Resource modification
   - **Delete:** Resource removal with confirmation prompts
   - **Status:** Health checks and configuration display

8. **Output Formatting:**
   - Consistent use of `format-echo` for status messages
   - `print_with_separator` for section divisions
   - Color-coded success/error/warning messages
   - Structured output for complex data

### Example Script Structure:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Source common functions
source "$(dirname "$0")/../../functions/common-init.sh"

# Default values
PROJECT_ID=""
COMMAND=""
RESOURCE_NAME=""

# Usage function with comprehensive help
usage() {
  print_with_separator "Script Name"
  echo "Description and examples..."
}

# Argument parsing
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -p|--project) PROJECT_ID="$2"; shift 2 ;;
      # ... more options
    esac
  done
}

# Authentication and setup
check_auth() { ... }
set_project() { ... }
enable_apis() { ... }

# Core operations
create_resource() { ... }
list_resources() { ... }
# ... more operations

# Command execution
execute_command() {
  case "$COMMAND" in
    create) create_resource ;;
    list) list_resources ;;
    # ... more commands
  esac
}

# Main function
main() {
  parse_args "$@"
  check_auth
  set_project
  execute_command
}

main "$@"
```

## Defining Features & Patterns

### Code Quality & Reliability:
- **Defensive Programming:** Scripts handle edge cases, validate inputs, and provide clear error messages
- **Idempotency:** Operations can be run multiple times safely
- **Atomic Operations:** Complex tasks are broken into smaller, reversible steps
- **Confirmation Prompts:** Destructive operations require user confirmation
- **Logging & Debugging:** Verbose output options and debug modes available

### GCP Integration Patterns:
- **Service Discovery:** Scripts automatically detect available services and regions
- **API Management:** Automatic enablement of required APIs with dependency checking
- **Resource Lifecycle:** Full CRUD operations with proper cleanup and validation
- **IAM Integration:** Automatic permission checking and role assignment
- **Monitoring Integration:** Built-in connection to Cloud Monitoring and Logging
- **Multi-Project Support:** Scripts can operate across different GCP projects

### Common Function Library (`functions/`):
- **`common-init.sh`:** Core initialization, path resolution, dependency checking
- **`format-echo.sh`:** Standardized output with colors (SUCCESS, ERROR, WARNING, INFO)
- **`print-with-separator.sh`:** Section dividers for readable output
- **Utility functions:** Date formatting, validation helpers, common operations

### Naming Conventions:
- **Files:** `service-action-manager.sh` (e.g., `gcp-storage-manager.sh`)
- **Functions:** `verb_noun()` (e.g., `create_bucket()`, `list_instances()`)
- **Variables:** `UPPER_CASE` for constants, `lower_case` for local vars
- **Commands:** `kebab-case` for user-facing commands (e.g., `create-bucket`)

### Error Handling Patterns:
```bash
# Check prerequisites
if ! command -v gcloud >/dev/null 2>&1; then
  format-echo "ERROR" "gcloud CLI not found"
  exit 1
fi

# Validate required parameters
if [[ -z "$PROJECT_ID" ]]; then
  format-echo "ERROR" "Project ID is required"
  usage
fi

# Handle API responses
if ! gcloud compute instances create "$INSTANCE_NAME" 2>/dev/null; then
  format-echo "ERROR" "Failed to create instance"
  exit 1
fi
```

### Security Considerations:
- **Secrets Management:** No hardcoded credentials, uses gcloud auth or service accounts
- **Input Validation:** All user inputs are validated and sanitized
- **Least Privilege:** Scripts request minimal required permissions
- **Audit Trails:** Operations are logged for compliance and debugging

## Best Practices for Contributors

### When Creating New Scripts:
1. **Follow the Template:** Use existing scripts as reference (e.g., `gcp/networking/gcp-dns-manager.sh`)
2. **Use Shared Functions:** Always source `functions/common-init.sh` and use formatting functions
3. **Comprehensive Help:** Include detailed usage, examples, and all available commands
4. **Error Handling:** Use `set -euo pipefail` and validate all inputs
5. **Testing:** Test scripts in isolated environments before committing
6. **Documentation:** Add inline comments explaining complex logic

### When Extending Existing Scripts:
1. **Maintain Consistency:** Follow existing patterns and naming conventions
2. **Backward Compatibility:** Don't break existing command interfaces
3. **Add Help Text:** Update usage functions with new commands/options
4. **Test Integration:** Ensure new features work with existing functionality

### Code Review Checklist:
- [ ] Script uses strict error handling (`set -euo pipefail`)
- [ ] Common functions are properly sourced
- [ ] Comprehensive help/usage function exists
- [ ] All user inputs are validated
- [ ] Destructive operations have confirmation prompts
- [ ] Script is made executable (`chmod +x`)
- [ ] Documentation is updated if needed

### Directory Placement Guidelines:
- **GCP Services:** Place in appropriate `gcp/` subdirectory by service type
- **System Tools:** Use `system-scripts/` for OS-level operations
- **Network Tools:** Use `network-and-connectivity/` for network diagnostics
- **Security Tools:** Use `security-and-access/` for security-related operations
- **File Operations:** Use `file-scripts/` for file system operations
- **Development Tools:** Use `development-and-code-management/` for dev workflows

## Getting Started

### Prerequisites:
- **Bash 4.0+** (most scripts require modern Bash features)
- **gcloud CLI** (for GCP scripts) - [Install Guide](https://cloud.google.com/sdk/docs/install)
- **kubectl** (for Kubernetes scripts) - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **Docker** (for container-related scripts) - [Install Guide](https://docs.docker.com/get-docker/)

### Setup Process:
1. **Clone the repository:**
   ```bash
   git clone https://github.com/MForofontov/shell-scripts.git
   cd shell-scripts
   ```

2. **Make scripts executable:**
   ```bash
   find . -name "*.sh" -type f -exec chmod +x {} \;
   ```

3. **Authenticate with GCP (if using GCP scripts):**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

4. **Test a script:**
   ```bash
   ./gcp/networking/gcp-cdn-manager.sh --help
   ./system-scripts/system-report.sh
   ```

### Common Usage Patterns:
```bash
# List GCP resources
./gcp/compute-and-containers/gcp-compute-manager.sh -p my-project list-instances

# Create GCP resources with specific configuration
./gcp/storage-and-databases/gcp-storage-manager.sh -p my-project --bucket-name my-bucket --region us-central1 create-bucket

# System monitoring
./system-scripts/monitor-resources.sh --cpu --memory --disk

# Network diagnostics
./network-and-connectivity/port-scanner.sh --host 8.8.8.8 --port 53

# File operations
./file-scripts/compress-tar-directory.sh --source /path/to/dir --output backup.tar.gz
```

### Environment Variables:
Many scripts support environment variables for default values:
```bash
export GCP_PROJECT_ID="my-default-project"
export GCP_REGION="us-central1"
export GCP_ZONE="us-central1-a"
```

## Troubleshooting & Support

### Common Issues:
1. **Permission Denied:**
   ```bash
   chmod +x script-name.sh
   ```

2. **gcloud Not Authenticated:**
   ```bash
   gcloud auth login
   gcloud config set project PROJECT_ID
   ```

3. **Missing Dependencies:**
   - Check script requirements in help text
   - Install missing tools (gcloud, kubectl, docker, etc.)

4. **API Not Enabled:**
   - Scripts automatically enable required APIs
   - Check GCP Console if manual enablement is needed

### Debug Mode:
Most scripts support verbose output:
```bash
./script.sh --help  # Shows all available options
set -x; ./script.sh  # Bash debug mode
```

### Script Maintenance:
- Scripts are designed to be self-contained and portable
- Regular updates ensure compatibility with latest API versions
- Community contributions welcome via pull requests

## License & Contributing
- **License:** See `LICENSE` file for details
- **Contributing:** Follow the patterns documented in this file
- **Issues:** Report bugs and feature requests via GitHub issues
- **Pull Requests:** Welcome for bug fixes and new features

---
**For GitHub Copilot:** This repository contains production-ready automation scripts following strict patterns for reliability, security, and maintainability. When suggesting code or helping with modifications, always follow the established architecture, error handling patterns, and function sourcing requirements detailed above. All scripts should be self-contained, well-documented, and follow the CRUD operation patterns for consistency.
