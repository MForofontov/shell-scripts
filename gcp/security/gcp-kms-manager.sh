#!/usr/bin/env bash
# gcp-kms-manager.sh
# Script to manage GCP Cloud Key Management Service (KMS) keys, keyrings, and cryptographic operations.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
# shellcheck source=functions/common-init.sh
source "$(dirname "$0")/../functions/common-init.sh"

#=====================================================================
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
PROJECT_ID=""
LOCATION="global"
KEYRING=""
KEY=""
VERSION=""
PURPOSE="encryption"
ALGORITHM="google-symmetric-encryption"
PROTECTION_LEVEL="software"
NEXT_ROTATION_TIME=""
ROTATION_PERIOD=""
LABELS=""
IMPORT_METHOD=""
IMPORT_JOB=""
PUBLIC_KEY_FILE=""
PRIVATE_KEY_FILE=""
PLAINTEXT_FILE=""
CIPHERTEXT_FILE=""
AAD_FILE=""
INPUT_FILE=""
OUTPUT_FILE=""
PLAINTEXT_DATA=""
CIPHERTEXT_DATA=""
DIGEST=""
SIGNATURE_FILE=""
VERIFY_FILE=""
MEMBER=""
ROLE=""
CONDITION=""
HSM_CLUSTER=""
ATTESTATION_FILE=""
BACKUP_FILE=""
RESTORE_SOURCE=""
STATE="enabled"
ACTION=""
VERBOSE=false
DRY_RUN=false
FORCE=false

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "GCP Cloud KMS Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script manages GCP Cloud KMS keyrings, keys, and cryptographic operations."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 <action> [options]"
  echo
  echo -e "\033[1;34mKeyring Actions:\033[0m"
  echo -e "  \033[1;33mcreate-keyring\033[0m            Create a keyring"
  echo -e "  \033[1;33mlist-keyrings\033[0m             List keyrings"
  echo -e "  \033[1;33mdescribe-keyring\033[0m          Describe a keyring"
  echo -e "  \033[1;33mget-keyring-policy\033[0m        Get keyring IAM policy"
  echo -e "  \033[1;33mset-keyring-policy\033[0m        Set keyring IAM policy"
  echo
  echo -e "\033[1;34mKey Actions:\033[0m"
  echo -e "  \033[1;33mcreate-key\033[0m                Create a key"
  echo -e "  \033[1;33mupdate-key\033[0m                Update key configuration"
  echo -e "  \033[1;33mlist-keys\033[0m                 List keys in keyring"
  echo -e "  \033[1;33mdescribe-key\033[0m              Describe a key"
  echo -e "  \033[1;33menable-key\033[0m                Enable a key"
  echo -e "  \033[1;33mdisable-key\033[0m               Disable a key"
  echo -e "  \033[1;33mdestroy-key\033[0m               Schedule key for destruction"
  echo -e "  \033[1;33mrestore-key\033[0m               Restore a key from destruction"
  echo -e "  \033[1;33mrotate-key\033[0m                Rotate a key"
  echo -e "  \033[1;33mset-rotation-schedule\033[0m     Set automatic rotation"
  echo
  echo -e "\033[1;34mKey Version Actions:\033[0m"
  echo -e "  \033[1;33mlist-versions\033[0m             List key versions"
  echo -e "  \033[1;33mdescribe-version\033[0m          Describe a key version"
  echo -e "  \033[1;33menable-version\033[0m            Enable a key version"
  echo -e "  \033[1;33mdisable-version\033[0m           Disable a key version"
  echo -e "  \033[1;33mdestroy-version\033[0m           Schedule version for destruction"
  echo -e "  \033[1;33mrestore-version\033[0m           Restore version from destruction"
  echo -e "  \033[1;33mget-public-key\033[0m            Get public key"
  echo
  echo -e "\033[1;34mCryptographic Operations:\033[0m"
  echo -e "  \033[1;33mencrypt\033[0m                   Encrypt data"
  echo -e "  \033[1;33mdecrypt\033[0m                   Decrypt data"
  echo -e "  \033[1;33mencrypt-file\033[0m              Encrypt file"
  echo -e "  \033[1;33mdecrypt-file\033[0m              Decrypt file"
  echo -e "  \033[1;33msign\033[0m                      Sign data"
  echo -e "  \033[1;33mverify\033[0m                    Verify signature"
  echo -e "  \033[1;33msign-file\033[0m                 Sign file"
  echo -e "  \033[1;33mverify-file\033[0m               Verify file signature"
  echo
  echo -e "\033[1;34mKey Import/Export:\033[0m"
  echo -e "  \033[1;33mcreate-import-job\033[0m         Create key import job"
  echo -e "  \033[1;33mlist-import-jobs\033[0m          List import jobs"
  echo -e "  \033[1;33mdescribe-import-job\033[0m       Describe import job"
  echo -e "  \033[1;33mimport-key\033[0m                Import external key"
  echo -e "  \033[1;33mexport-key\033[0m                Export key for backup"
  echo
  echo -e "\033[1;34mAccess Control:\033[0m"
  echo -e "  \033[1;33mget-key-policy\033[0m            Get key IAM policy"
  echo -e "  \033[1;33mset-key-policy\033[0m            Set key IAM policy"
  echo -e "  \033[1;33madd-key-binding\033[0m           Add key IAM policy binding"
  echo -e "  \033[1;33mremove-key-binding\033[0m        Remove key IAM policy binding"
  echo -e "  \033[1;33mtest-key-permissions\033[0m      Test key permissions"
  echo
  echo -e "\033[1;34mMonitoring & Audit:\033[0m"
  echo -e "  \033[1;33mget-key-usage\033[0m             Get key usage statistics"
  echo -e "  \033[1;33mlist-key-operations\033[0m       List key operations"
  echo -e "  \033[1;33mget-attestation\033[0m           Get HSM attestation"
  echo -e "  \033[1;33maudit-keys\033[0m                Audit key configurations"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--project <project-id>\033[0m           (Required) GCP project ID"
  echo -e "  \033[1;33m--location <location>\033[0m            (Optional) Key location (default: global)"
  echo -e "  \033[1;33m--keyring <name>\033[0m                 (Required for most actions) Keyring name"
  echo -e "  \033[1;33m--key <name>\033[0m                     (Required for key actions) Key name"
  echo -e "  \033[1;33m--version <version>\033[0m              (Optional) Key version number"
  echo -e "  \033[1;33m--purpose <purpose>\033[0m              (Optional) Key purpose: encryption, mac, sign"
  echo -e "  \033[1;33m--algorithm <algorithm>\033[0m          (Optional) Key algorithm"
  echo -e "  \033[1;33m--protection-level <level>\033[0m       (Optional) Protection level: software, hsm"
  echo -e "  \033[1;33m--rotation-period <period>\033[0m       (Optional) Rotation period (e.g., 90d, 1y)"
  echo -e "  \033[1;33m--labels <labels>\033[0m                (Optional) Labels (KEY=VALUE,KEY2=VALUE2)"
  echo -e "  \033[1;33m--plaintext <text>\033[0m               (Optional) Plaintext data to encrypt"
  echo -e "  \033[1;33m--ciphertext <data>\033[0m              (Optional) Ciphertext data to decrypt"
  echo -e "  \033[1;33m--input-file <file>\033[0m              (Optional) Input file path"
  echo -e "  \033[1;33m--output-file <file>\033[0m             (Optional) Output file path"
  echo -e "  \033[1;33m--plaintext-file <file>\033[0m          (Optional) Plaintext file path"
  echo -e "  \033[1;33m--ciphertext-file <file>\033[0m         (Optional) Ciphertext file path"
  echo -e "  \033[1;33m--signature-file <file>\033[0m          (Optional) Signature file path"
  echo -e "  \033[1;33m--public-key-file <file>\033[0m         (Optional) Public key file path"
  echo -e "  \033[1;33m--private-key-file <file>\033[0m        (Optional) Private key file path"
  echo -e "  \033[1;33m--member <member>\033[0m                (Optional) IAM member"
  echo -e "  \033[1;33m--role <role>\033[0m                    (Optional) IAM role"
  echo -e "  \033[1;33m--import-method <method>\033[0m         (Optional) Key import method"
  echo -e "  \033[1;33m--import-job <job>\033[0m               (Optional) Import job name"
  echo -e "  \033[1;33m--state <state>\033[0m                  (Optional) Key state: enabled, disabled"
  echo -e "  \033[1;33m--force\033[0m                          (Optional) Force operations without confirmation"
  echo -e "  \033[1;33m--dry-run\033[0m                        (Optional) Show what would be done"
  echo -e "  \033[1;33m--verbose\033[0m                        (Optional) Show detailed output"
  echo -e "  \033[1;33m--log <log_file>\033[0m                 (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                           (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 create-keyring --project my-project --keyring my-keyring"
  echo "  $0 create-key --project my-project --keyring my-keyring --key my-key --purpose encryption"
  echo "  $0 encrypt --project my-project --keyring my-keyring --key my-key --plaintext 'Hello World'"
  echo "  $0 encrypt-file --project my-project --keyring my-keyring --key my-key --input-file data.txt --output-file data.enc"
  echo "  $0 rotate-key --project my-project --keyring my-keyring --key my-key"
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
      --location)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No location provided after --location."
          usage
        fi
        LOCATION="$2"
        shift 2
        ;;
      --keyring)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No keyring name provided after --keyring."
          usage
        fi
        KEYRING="$2"
        shift 2
        ;;
      --key)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No key name provided after --key."
          usage
        fi
        KEY="$2"
        shift 2
        ;;
      --version)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No version provided after --version."
          usage
        fi
        VERSION="$2"
        shift 2
        ;;
      --purpose)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No purpose provided after --purpose."
          usage
        fi
        PURPOSE="$2"
        shift 2
        ;;
      --algorithm)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No algorithm provided after --algorithm."
          usage
        fi
        ALGORITHM="$2"
        shift 2
        ;;
      --protection-level)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No protection level provided after --protection-level."
          usage
        fi
        PROTECTION_LEVEL="$2"
        shift 2
        ;;
      --rotation-period)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No rotation period provided after --rotation-period."
          usage
        fi
        ROTATION_PERIOD="$2"
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
      --plaintext)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No plaintext provided after --plaintext."
          usage
        fi
        PLAINTEXT_DATA="$2"
        shift 2
        ;;
      --ciphertext)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No ciphertext provided after --ciphertext."
          usage
        fi
        CIPHERTEXT_DATA="$2"
        shift 2
        ;;
      --input-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No input file provided after --input-file."
          usage
        fi
        INPUT_FILE="$2"
        shift 2
        ;;
      --output-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No output file provided after --output-file."
          usage
        fi
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --plaintext-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No plaintext file provided after --plaintext-file."
          usage
        fi
        PLAINTEXT_FILE="$2"
        shift 2
        ;;
      --ciphertext-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No ciphertext file provided after --ciphertext-file."
          usage
        fi
        CIPHERTEXT_FILE="$2"
        shift 2
        ;;
      --signature-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No signature file provided after --signature-file."
          usage
        fi
        SIGNATURE_FILE="$2"
        shift 2
        ;;
      --public-key-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No public key file provided after --public-key-file."
          usage
        fi
        PUBLIC_KEY_FILE="$2"
        shift 2
        ;;
      --private-key-file)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No private key file provided after --private-key-file."
          usage
        fi
        PRIVATE_KEY_FILE="$2"
        shift 2
        ;;
      --member)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No member provided after --member."
          usage
        fi
        MEMBER="$2"
        shift 2
        ;;
      --role)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No role provided after --role."
          usage
        fi
        ROLE="$2"
        shift 2
        ;;
      --import-method)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No import method provided after --import-method."
          usage
        fi
        IMPORT_METHOD="$2"
        shift 2
        ;;
      --import-job)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No import job provided after --import-job."
          usage
        fi
        IMPORT_JOB="$2"
        shift 2
        ;;
      --state)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No state provided after --state."
          usage
        fi
        STATE="$2"
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
  local missing_deps=()
  
  if ! command_exists gcloud; then
    missing_deps+=("gcloud")
  fi
  
  if [ ${#missing_deps[@]} -gt 0 ]; then
    format-echo "ERROR" "Missing required dependencies: ${missing_deps[*]}"
    format-echo "INFO" "Please install Google Cloud SDK"
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

# Function to get keyring full name
get_keyring_full_name() {
  echo "projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEYRING"
}

# Function to get key full name
get_key_full_name() {
  echo "projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEYRING/cryptoKeys/$KEY"
}

# Function to get key version full name
get_key_version_full_name() {
  echo "projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEYRING/cryptoKeys/$KEY/cryptoKeyVersions/$VERSION"
}

#=====================================================================
# KEYRING MANAGEMENT
#=====================================================================
# Function to create keyring
create_keyring() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  
  format-echo "INFO" "Creating KMS keyring: $keyring"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create keyring:"
    format-echo "INFO" "  Name: $keyring"
    format-echo "INFO" "  Location: $location"
    return 0
  fi
  
  if ! gcloud kms keyrings create "$keyring" \
    --project="$project" \
    --location="$location"; then
    format-echo "ERROR" "Failed to create keyring: $keyring"
    return 1
  fi
  
  format-echo "SUCCESS" "Created keyring: $keyring"
  return 0
}

# Function to list keyrings
list_keyrings() {
  local project="$1"
  local location="$2"
  
  format-echo "INFO" "Listing KMS keyrings"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list keyrings"
    return 0
  fi
  
  if ! gcloud kms keyrings list \
    --project="$project" \
    --location="$location" \
    --format="table(name.basename(),createTime.date())"; then
    format-echo "ERROR" "Failed to list keyrings"
    return 1
  fi
  
  return 0
}

# Function to describe keyring
describe_keyring() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  
  format-echo "INFO" "Describing keyring: $keyring"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would describe keyring: $keyring"
    return 0
  fi
  
  if ! gcloud kms keyrings describe "$keyring" \
    --project="$project" \
    --location="$location"; then
    format-echo "ERROR" "Failed to describe keyring: $keyring"
    return 1
  fi
  
  return 0
}

#=====================================================================
# KEY MANAGEMENT
#=====================================================================
# Function to create key
create_key() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  
  format-echo "INFO" "Creating KMS key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would create key:"
    format-echo "INFO" "  Name: $key"
    format-echo "INFO" "  Purpose: $PURPOSE"
    format-echo "INFO" "  Algorithm: $ALGORITHM"
    format-echo "INFO" "  Protection: $PROTECTION_LEVEL"
    return 0
  fi
  
  local create_cmd="gcloud kms keys create $key"
  create_cmd+=" --project=$project"
  create_cmd+=" --location=$location"
  create_cmd+=" --keyring=$keyring"
  create_cmd+=" --purpose=$PURPOSE"
  
  if [ -n "$ALGORITHM" ]; then
    create_cmd+=" --default-algorithm=$ALGORITHM"
  fi
  
  if [ -n "$PROTECTION_LEVEL" ]; then
    create_cmd+=" --protection-level=$PROTECTION_LEVEL"
  fi
  
  if [ -n "$ROTATION_PERIOD" ]; then
    create_cmd+=" --rotation-period=$ROTATION_PERIOD"
  fi
  
  if [ -n "$LABELS" ]; then
    create_cmd+=" --labels=$LABELS"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $create_cmd"
  fi
  
  if ! eval "$create_cmd"; then
    format-echo "ERROR" "Failed to create key: $key"
    return 1
  fi
  
  format-echo "SUCCESS" "Created key: $key"
  return 0
}

# Function to list keys
list_keys() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  
  format-echo "INFO" "Listing KMS keys in keyring: $keyring"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list keys in keyring: $keyring"
    return 0
  fi
  
  if ! gcloud kms keys list \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring" \
    --format="table(name.basename(),purpose,primary.algorithm,primary.state,createTime.date())"; then
    format-echo "ERROR" "Failed to list keys"
    return 1
  fi
  
  return 0
}

# Function to describe key
describe_key() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  
  format-echo "INFO" "Describing key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would describe key: $key"
    return 0
  fi
  
  if ! gcloud kms keys describe "$key" \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring"; then
    format-echo "ERROR" "Failed to describe key: $key"
    return 1
  fi
  
  return 0
}

# Function to rotate key
rotate_key() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  
  format-echo "INFO" "Rotating key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would rotate key: $key"
    return 0
  fi
  
  if [ "$FORCE" != true ]; then
    echo "WARNING: This will create a new version of the key '$key'."
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      format-echo "INFO" "Operation cancelled."
      return 0
    fi
  fi
  
  if ! gcloud kms keys versions create \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring" \
    --key="$key"; then
    format-echo "ERROR" "Failed to rotate key: $key"
    return 1
  fi
  
  format-echo "SUCCESS" "Rotated key: $key"
  return 0
}

# Function to set rotation schedule
set_rotation_schedule() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  local period="$5"
  
  format-echo "INFO" "Setting rotation schedule for key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would set rotation period to: $period"
    return 0
  fi
  
  if ! gcloud kms keys update "$key" \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring" \
    --rotation-period="$period"; then
    format-echo "ERROR" "Failed to set rotation schedule"
    return 1
  fi
  
  format-echo "SUCCESS" "Set rotation schedule: $period"
  return 0
}

#=====================================================================
# KEY VERSION MANAGEMENT
#=====================================================================
# Function to list key versions
list_versions() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  
  format-echo "INFO" "Listing versions for key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would list versions for key: $key"
    return 0
  fi
  
  if ! gcloud kms keys versions list \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring" \
    --key="$key" \
    --format="table(name.basename(),algorithm,state,createTime.date(),destroyTime.date())"; then
    format-echo "ERROR" "Failed to list key versions"
    return 1
  fi
  
  return 0
}

# Function to get public key
get_public_key() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  local version="$5"
  local output_file="$6"
  
  format-echo "INFO" "Getting public key for version: $version"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get public key for version: $version"
    return 0
  fi
  
  local get_cmd="gcloud kms keys versions get-public-key $version"
  get_cmd+=" --project=$project"
  get_cmd+=" --location=$location"
  get_cmd+=" --keyring=$keyring"
  get_cmd+=" --key=$key"
  
  if [ -n "$output_file" ]; then
    get_cmd+=" --output-file=$output_file"
  fi
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running: $get_cmd"
  fi
  
  if ! eval "$get_cmd"; then
    format-echo "ERROR" "Failed to get public key"
    return 1
  fi
  
  format-echo "SUCCESS" "Retrieved public key"
  return 0
}

#=====================================================================
# CRYPTOGRAPHIC OPERATIONS
#=====================================================================
# Function to encrypt data
encrypt_data() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  local plaintext="$5"
  
  format-echo "INFO" "Encrypting data with key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would encrypt data with key: $key"
    return 0
  fi
  
  local encrypt_cmd="echo '$plaintext' | gcloud kms encrypt"
  encrypt_cmd+=" --project=$project"
  encrypt_cmd+=" --location=$location"
  encrypt_cmd+=" --keyring=$keyring"
  encrypt_cmd+=" --key=$key"
  encrypt_cmd+=" --plaintext-file=-"
  encrypt_cmd+=" --ciphertext-file=-"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running encryption operation"
  fi
  
  local result
  if result=$(eval "$encrypt_cmd" 2>/dev/null); then
    format-echo "SUCCESS" "Data encrypted successfully"
    echo "Ciphertext (base64): $result"
    return 0
  else
    format-echo "ERROR" "Failed to encrypt data"
    return 1
  fi
}

# Function to decrypt data
decrypt_data() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  local ciphertext="$5"
  
  format-echo "INFO" "Decrypting data with key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would decrypt data with key: $key"
    return 0
  fi
  
  local decrypt_cmd="echo '$ciphertext' | gcloud kms decrypt"
  decrypt_cmd+=" --project=$project"
  decrypt_cmd+=" --location=$location"
  decrypt_cmd+=" --keyring=$keyring"
  decrypt_cmd+=" --key=$key"
  decrypt_cmd+=" --ciphertext-file=-"
  decrypt_cmd+=" --plaintext-file=-"
  
  if [ "$VERBOSE" = true ]; then
    format-echo "INFO" "Running decryption operation"
  fi
  
  local result
  if result=$(eval "$decrypt_cmd" 2>/dev/null); then
    format-echo "SUCCESS" "Data decrypted successfully"
    echo "Plaintext: $result"
    return 0
  else
    format-echo "ERROR" "Failed to decrypt data"
    return 1
  fi
}

# Function to encrypt file
encrypt_file() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  local input_file="$5"
  local output_file="$6"
  
  format-echo "INFO" "Encrypting file: $input_file"
  
  if [ ! -f "$input_file" ]; then
    format-echo "ERROR" "Input file not found: $input_file"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would encrypt file:"
    format-echo "INFO" "  Input: $input_file"
    format-echo "INFO" "  Output: $output_file"
    return 0
  fi
  
  if ! gcloud kms encrypt \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring" \
    --key="$key" \
    --plaintext-file="$input_file" \
    --ciphertext-file="$output_file"; then
    format-echo "ERROR" "Failed to encrypt file"
    return 1
  fi
  
  format-echo "SUCCESS" "File encrypted: $output_file"
  return 0
}

# Function to decrypt file
decrypt_file() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  local input_file="$5"
  local output_file="$6"
  
  format-echo "INFO" "Decrypting file: $input_file"
  
  if [ ! -f "$input_file" ]; then
    format-echo "ERROR" "Input file not found: $input_file"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would decrypt file:"
    format-echo "INFO" "  Input: $input_file"
    format-echo "INFO" "  Output: $output_file"
    return 0
  fi
  
  if ! gcloud kms decrypt \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring" \
    --key="$key" \
    --ciphertext-file="$input_file" \
    --plaintext-file="$output_file"; then
    format-echo "ERROR" "Failed to decrypt file"
    return 1
  fi
  
  format-echo "SUCCESS" "File decrypted: $output_file"
  return 0
}

# Function to sign data
sign_data() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  local version="$5"
  local input_file="$6"
  local signature_file="$7"
  
  format-echo "INFO" "Signing data with key: $key"
  
  if [ ! -f "$input_file" ]; then
    format-echo "ERROR" "Input file not found: $input_file"
    return 1
  fi
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would sign data:"
    format-echo "INFO" "  Input: $input_file"
    format-echo "INFO" "  Signature: $signature_file"
    return 0
  fi
  
  if ! gcloud kms asymmetric-sign \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring" \
    --key="$key" \
    --version="$version" \
    --digest-algorithm=sha256 \
    --input-file="$input_file" \
    --signature-file="$signature_file"; then
    format-echo "ERROR" "Failed to sign data"
    return 1
  fi
  
  format-echo "SUCCESS" "Data signed: $signature_file"
  return 0
}

#=====================================================================
# IAM MANAGEMENT
#=====================================================================
# Function to add key IAM binding
add_key_iam_binding() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  local member="$5"
  local role="$6"
  
  format-echo "INFO" "Adding IAM binding to key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would add IAM binding:"
    format-echo "INFO" "  Member: $member"
    format-echo "INFO" "  Role: $role"
    return 0
  fi
  
  if ! gcloud kms keys add-iam-policy-binding "$key" \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring" \
    --member="$member" \
    --role="$role"; then
    format-echo "ERROR" "Failed to add IAM binding"
    return 1
  fi
  
  format-echo "SUCCESS" "Added IAM binding to key"
  return 0
}

# Function to get key IAM policy
get_key_iam_policy() {
  local project="$1"
  local location="$2"
  local keyring="$3"
  local key="$4"
  
  format-echo "INFO" "Getting IAM policy for key: $key"
  
  if [ "$DRY_RUN" = true ]; then
    format-echo "INFO" "[DRY RUN] Would get IAM policy for key: $key"
    return 0
  fi
  
  if ! gcloud kms keys get-iam-policy "$key" \
    --project="$project" \
    --location="$location" \
    --keyring="$keyring"; then
    format-echo "ERROR" "Failed to get IAM policy"
    return 1
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
  
  print_with_separator "GCP Cloud KMS Manager Script"
  format-echo "INFO" "Starting GCP Cloud KMS Manager..."
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check dependencies
  if ! check_dependencies; then
    print_with_separator "End of GCP Cloud KMS Manager Script"
    exit 1
  fi
  
  # Validate authentication
  if ! validate_auth; then
    print_with_separator "End of GCP Cloud KMS Manager Script"
    exit 1
  fi
  
  # Validate required parameters
  if [ -z "$PROJECT_ID" ]; then
    format-echo "ERROR" "Project ID is required. Use --project <project-id>"
    print_with_separator "End of GCP Cloud KMS Manager Script"
    exit 1
  fi
  
  # Validate action-specific requirements
  case "$ACTION" in
    create-keyring|describe-keyring)
      if [ -z "$KEYRING" ]; then
        format-echo "ERROR" "Keyring name is required for action: $ACTION"
        exit 1
      fi
      ;;
    create-key|list-keys|describe-key|rotate-key)
      if [ -z "$KEYRING" ] || [ -z "$KEY" ]; then
        format-echo "ERROR" "Keyring and key names are required for action: $ACTION"
        exit 1
      fi
      ;;
    encrypt|decrypt|encrypt-file|decrypt-file)
      if [ -z "$KEYRING" ] || [ -z "$KEY" ]; then
        format-echo "ERROR" "Keyring and key names are required for cryptographic operations"
        exit 1
      fi
      ;;
    encrypt)
      if [ -z "$PLAINTEXT_DATA" ]; then
        format-echo "ERROR" "Plaintext data is required for encryption"
        exit 1
      fi
      ;;
    decrypt)
      if [ -z "$CIPHERTEXT_DATA" ]; then
        format-echo "ERROR" "Ciphertext data is required for decryption"
        exit 1
      fi
      ;;
    encrypt-file|decrypt-file)
      if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
        format-echo "ERROR" "Input and output files are required for file operations"
        exit 1
      fi
      ;;
    set-rotation-schedule)
      if [ -z "$KEYRING" ] || [ -z "$KEY" ] || [ -z "$ROTATION_PERIOD" ]; then
        format-echo "ERROR" "Keyring, key, and rotation period are required"
        exit 1
      fi
      ;;
    add-key-binding)
      if [ -z "$KEYRING" ] || [ -z "$KEY" ] || [ -z "$MEMBER" ] || [ -z "$ROLE" ]; then
        format-echo "ERROR" "Keyring, key, member, and role are required for IAM binding"
        exit 1
      fi
      ;;
    list-keyrings)
      # No additional requirements
      ;;
    *)
      format-echo "ERROR" "Unknown action: $ACTION"
      format-echo "INFO" "Valid actions: create-keyring, create-key, encrypt, decrypt, etc."
      exit 1
      ;;
  esac
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  case "$ACTION" in
    create-keyring)
      if create_keyring "$PROJECT_ID" "$LOCATION" "$KEYRING"; then
        format-echo "SUCCESS" "Keyring creation completed successfully"
      else
        format-echo "ERROR" "Failed to create keyring"
        exit 1
      fi
      ;;
    list-keyrings)
      if list_keyrings "$PROJECT_ID" "$LOCATION"; then
        format-echo "SUCCESS" "Listed keyrings successfully"
      else
        format-echo "ERROR" "Failed to list keyrings"
        exit 1
      fi
      ;;
    describe-keyring)
      if describe_keyring "$PROJECT_ID" "$LOCATION" "$KEYRING"; then
        format-echo "SUCCESS" "Described keyring successfully"
      else
        format-echo "ERROR" "Failed to describe keyring"
        exit 1
      fi
      ;;
    create-key)
      if create_key "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY"; then
        format-echo "SUCCESS" "Key creation completed successfully"
      else
        format-echo "ERROR" "Failed to create key"
        exit 1
      fi
      ;;
    list-keys)
      if list_keys "$PROJECT_ID" "$LOCATION" "$KEYRING"; then
        format-echo "SUCCESS" "Listed keys successfully"
      else
        format-echo "ERROR" "Failed to list keys"
        exit 1
      fi
      ;;
    describe-key)
      if describe_key "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY"; then
        format-echo "SUCCESS" "Described key successfully"
      else
        format-echo "ERROR" "Failed to describe key"
        exit 1
      fi
      ;;
    rotate-key)
      if rotate_key "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY"; then
        format-echo "SUCCESS" "Key rotation completed successfully"
      else
        format-echo "ERROR" "Failed to rotate key"
        exit 1
      fi
      ;;
    set-rotation-schedule)
      if set_rotation_schedule "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY" "$ROTATION_PERIOD"; then
        format-echo "SUCCESS" "Rotation schedule set successfully"
      else
        format-echo "ERROR" "Failed to set rotation schedule"
        exit 1
      fi
      ;;
    list-versions)
      if list_versions "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY"; then
        format-echo "SUCCESS" "Listed key versions successfully"
      else
        format-echo "ERROR" "Failed to list key versions"
        exit 1
      fi
      ;;
    get-public-key)
      if get_public_key "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY" "$VERSION" "$PUBLIC_KEY_FILE"; then
        format-echo "SUCCESS" "Retrieved public key successfully"
      else
        format-echo "ERROR" "Failed to get public key"
        exit 1
      fi
      ;;
    encrypt)
      if encrypt_data "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY" "$PLAINTEXT_DATA"; then
        format-echo "SUCCESS" "Encryption completed successfully"
      else
        format-echo "ERROR" "Failed to encrypt data"
        exit 1
      fi
      ;;
    decrypt)
      if decrypt_data "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY" "$CIPHERTEXT_DATA"; then
        format-echo "SUCCESS" "Decryption completed successfully"
      else
        format-echo "ERROR" "Failed to decrypt data"
        exit 1
      fi
      ;;
    encrypt-file)
      if encrypt_file "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY" "$INPUT_FILE" "$OUTPUT_FILE"; then
        format-echo "SUCCESS" "File encryption completed successfully"
      else
        format-echo "ERROR" "Failed to encrypt file"
        exit 1
      fi
      ;;
    decrypt-file)
      if decrypt_file "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY" "$INPUT_FILE" "$OUTPUT_FILE"; then
        format-echo "SUCCESS" "File decryption completed successfully"
      else
        format-echo "ERROR" "Failed to decrypt file"
        exit 1
      fi
      ;;
    sign-file)
      if sign_data "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY" "$VERSION" "$INPUT_FILE" "$SIGNATURE_FILE"; then
        format-echo "SUCCESS" "File signing completed successfully"
      else
        format-echo "ERROR" "Failed to sign file"
        exit 1
      fi
      ;;
    add-key-binding)
      if add_key_iam_binding "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY" "$MEMBER" "$ROLE"; then
        format-echo "SUCCESS" "IAM binding added successfully"
      else
        format-echo "ERROR" "Failed to add IAM binding"
        exit 1
      fi
      ;;
    get-key-policy)
      if get_key_iam_policy "$PROJECT_ID" "$LOCATION" "$KEYRING" "$KEY"; then
        format-echo "SUCCESS" "Retrieved key IAM policy successfully"
      else
        format-echo "ERROR" "Failed to get key IAM policy"
        exit 1
      fi
      ;;
  esac
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of GCP Cloud KMS Manager Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
