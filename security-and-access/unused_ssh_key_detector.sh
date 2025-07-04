#!/bin/bash
# unused_ssh_key_detector.sh
# Script to detect unused SSH keys and suggest remediation actions.

set -eo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0" 2>/dev/null || echo "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"

if [ -f "$FORMAT_ECHO_FILE" ]; then
  source "$FORMAT_ECHO_FILE"
else
  echo -e "\033[1;31mError:\033[0m format-echo file not found at $FORMAT_ECHO_FILE"
  exit 1
fi

if [ -f "$UTILITY_FUNCTION_FILE" ]; then
  source "$UTILITY_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $UTILITY_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
if [[ "$OSTYPE" == "darwin"* ]]; then
  SSH_DIR="/Users"
  SSH_LOG_FILES=("/var/log/system.log" "/var/log/secure.log" "/Library/Logs/DiagnosticReports")
else
  SSH_DIR="/home"
  SSH_LOG_FILES=("/var/log/auth.log" "/var/log/secure" "/var/log/audit/audit.log")
fi
LOG_FILE="/dev/null"
SINGLE_USER=""
AGE_THRESHOLD=90  # Keys unused for 90+ days are considered old
CHECK_AUTH_KEYS=true
CHECK_KNOWN_HOSTS=true
CHECK_SSH_AGENT=true
CHECK_SSH_LOGS=true
CHECK_ACCESS_TIME=true
VERBOSE=false
DRY_RUN=false
FORMAT="text"  # Options: text, json, csv
ACTION="report"  # Options: report, backup, archive, disable, remove
EXCLUSIONS=()
OUTPUT_FILE=""
MAX_THREADS=4  # For parallel processing
MIN_USAGE_SCORE=1  # Minimum score required to consider a key as used

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Unused SSH Key Detector Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script scans for unused SSH keys in user directories and identifies keys"
  echo "  that haven't been used recently based on multiple detection methods."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--ssh-dir <directory>\033[0m       (Optional) Base directory to scan for SSH keys (default: $SSH_DIR)"
  echo -e "  \033[1;33m--user <username>\033[0m           (Optional) Scan only this specific user's SSH directory"
  echo -e "  \033[1;33m--age <days>\033[0m                (Optional) Age threshold in days (default: 90)"
  echo -e "  \033[1;33m--min-score <number>\033[0m        (Optional) Minimum usage score to consider a key as used (default: 1)"
  echo -e "  \033[1;33m--no-auth-keys\033[0m              (Optional) Don't check authorized_keys files"
  echo -e "  \033[1;33m--no-known-hosts\033[0m            (Optional) Don't check known_hosts files"
  echo -e "  \033[1;33m--no-ssh-agent\033[0m              (Optional) Don't check SSH agent for loaded keys"
  echo -e "  \033[1;33m--no-ssh-logs\033[0m               (Optional) Don't check SSH logs for key usage"
  echo -e "  \033[1;33m--no-access-time\033[0m            (Optional) Don't use file access time for detection"
  echo -e "  \033[1;33m--exclude <pattern>\033[0m         (Optional) Exclude keys matching pattern (can be used multiple times)"
  echo -e "  \033[1;33m--format <format>\033[0m           (Optional) Output format: text, json, csv (default: text)"
  echo -e "  \033[1;33m--output <file>\033[0m             (Optional) Write results to file instead of stdout"
  echo -e "  \033[1;33m--action <action>\033[0m           (Optional) Action to take: report, backup, archive, disable, remove (default: report)"
  echo -e "  \033[1;33m--log <log_file>\033[0m            (Optional) Path to save detailed log messages"
  echo -e "  \033[1;33m--verbose\033[0m                   (Optional) Show detailed information during execution"
  echo -e "  \033[1;33m--dry-run\033[0m                   (Optional) Show what would be done without making changes"
  echo -e "  \033[1;33m--help\033[0m                      (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --user johndoe --age 180 --action report"
  echo "  $0 --ssh-dir $SSH_DIR --exclude '*.backup' --format json --output unused_keys.json"
  echo "  $0 --action backup --verbose --min-score 2"
  print_with_separator
  exit 1
}

#=====================================================================
# ARGUMENT PARSING
#=====================================================================
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help)
        usage
        ;;
      --ssh-dir)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No directory provided after --ssh-dir"
          usage
        fi
        SSH_DIR="$2"
        shift 2
        ;;
      --user)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No username provided after --user"
          usage
        fi
        SINGLE_USER="$2"
        shift 2
        ;;
      --age)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid age value: $2. Must be a positive integer."
          usage
        fi
        AGE_THRESHOLD="$2"
        shift 2
        ;;
      --min-score)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid min-score value: $2. Must be a positive integer."
          usage
        fi
        MIN_USAGE_SCORE="$2"
        shift 2
        ;;
      --no-auth-keys)
        CHECK_AUTH_KEYS=false
        shift
        ;;
      --no-known-hosts)
        CHECK_KNOWN_HOSTS=false
        shift
        ;;
      --no-ssh-agent)
        CHECK_SSH_AGENT=false
        shift
        ;;
      --no-ssh-logs)
        CHECK_SSH_LOGS=false
        shift
        ;;
      --no-access-time)
        CHECK_ACCESS_TIME=false
        shift
        ;;
      --exclude)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No pattern provided after --exclude"
          usage
        fi
        EXCLUSIONS+=("$2")
        shift 2
        ;;
      --format)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^(text|json|csv)$ ]]; then
          format-echo "ERROR" "Invalid format: $2. Must be one of: text, json, csv"
          usage
        fi
        FORMAT="$2"
        shift 2
        ;;
      --output)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No file provided after --output"
          usage
        fi
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --action)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^(report|backup|archive|disable|remove)$ ]]; then
          format-echo "ERROR" "Invalid action: $2. Must be one of: report, backup, archive, disable, remove"
          usage
        fi
        ACTION="$2"
        shift 2
        ;;
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log"
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  # Validate arguments
  validate_args
}

validate_args() {
  # Check if we have destructive action but dry-run is not enabled
  if [[ "$ACTION" =~ ^(disable|remove)$ && "$DRY_RUN" == "false" ]]; then
    format-echo "WARNING" "You selected a potentially destructive action ($ACTION) without --dry-run"
    read -p "Are you sure you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      format-echo "INFO" "Operation cancelled by user."
      exit 0
    fi
  fi
  
  # Check if ssh-dir is valid
  if [[ ! -d "$SSH_DIR" ]]; then
    format-echo "ERROR" "The specified SSH directory does not exist: $SSH_DIR"
    exit 1
  fi
  
  # Check if single user exists
  if [[ -n "$SINGLE_USER" ]]; then
    if [[ "$SSH_DIR" == "/home" ]]; then
      if [[ ! -d "$SSH_DIR/$SINGLE_USER" ]]; then
        format-echo "ERROR" "User directory does not exist: $SSH_DIR/$SINGLE_USER"
        exit 1
      fi
    else
      # For custom SSH directories, just issue a warning
      format-echo "WARNING" "Custom SSH directory with specific user - will scan $SSH_DIR for user $SINGLE_USER"
    fi
  fi
  
  # Check if output file is writable
  if [[ -n "$OUTPUT_FILE" ]]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
      format-echo "ERROR" "Cannot write to output file: $OUTPUT_FILE"
      exit 1
    fi
  fi
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================
# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to get keys that match exclusion patterns
is_excluded() {
  local key_path="$1"
  
  for pattern in "${EXCLUSIONS[@]}"; do
    if [[ "$key_path" == *"$pattern"* ]]; then
      return 0  # Key matches exclusion pattern
    fi
  done
  
  return 1  # Key does not match any exclusion pattern
}

# Function to get all SSH key files for a user
find_ssh_keys() {
  local user_dir="$1"
  local ssh_dir="$user_dir/.ssh"
  local key_files=()
  
  if [[ ! -d "$ssh_dir" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
      format-echo "INFO" "No .ssh directory found at $ssh_dir"
    fi
    echo "${key_files[@]}"
    return
  fi
  
  # Find all private key files (common naming patterns)
  while IFS= read -r key_file; do
    [[ -z "$key_file" ]] && continue
    # Skip files that match exclusion patterns
    if is_excluded "$key_file"; then
      if [[ "$VERBOSE" == "true" ]]; then
        format-echo "INFO" "Excluded key file: $key_file"
      fi
      continue
    fi
    
    key_files+=("$key_file")
  done < <(find "$ssh_dir" -type f -name "id_*" ! -name "*.pub" 2>/dev/null || echo "")
  
  # Also look for custom key files that don't match the id_* pattern
  while IFS= read -r key_file; do
    [[ -z "$key_file" ]] && continue
    # Skip if this is a public key
    if [[ "$key_file" == *.pub ]]; then
      continue
    fi
    
    # Check if this is likely a private key
    if grep -q "BEGIN.*PRIVATE KEY" "$key_file" 2>/dev/null; then
      # Skip files that match exclusion patterns
      if is_excluded "$key_file"; then
        if [[ "$VERBOSE" == "true" ]]; then
          format-echo "INFO" "Excluded key file: $key_file"
        fi
        continue
      fi
      
      key_files+=("$key_file")
    fi
  done < <(find "$ssh_dir" -type f ! -name "id_*" ! -name "*.pub" ! -name "config" ! -name "known_hosts*" ! -name "authorized_keys*" 2>/dev/null || echo "")
  
  echo "${key_files[@]}"
}

# Function to check if a key is in authorized_keys
is_in_authorized_keys() {
  local key_path="$1"
  local key_fingerprint=""
  
  # Get the fingerprint of the private key
  if command_exists ssh-keygen; then
    key_fingerprint=$(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}')
    
    # If we couldn't get the fingerprint, try with the public key
    if [[ -z "$key_fingerprint" && -f "${key_path}.pub" ]]; then
      key_fingerprint=$(ssh-keygen -lf "${key_path}.pub" 2>/dev/null | awk '{print $2}')
    fi
  fi
  
  if [[ -z "$key_fingerprint" ]]; then
    return 1  # Couldn't determine fingerprint
  fi
  
  # Check all authorized_keys files in the system
  while IFS= read -r auth_keys_file; do
    if [[ -f "$auth_keys_file" ]]; then
      # Extract public keys and check fingerprints
      while read -r line; do
        [[ "$line" =~ ^# || -z "$line" ]] && continue  # Skip comments and empty lines
        
        # Create a temporary file with the key
        local temp_key_file=$(mktemp)
        echo "$line" > "$temp_key_file"
        
        # Get the fingerprint of this authorized key
        local auth_key_fingerprint=""
        auth_key_fingerprint=$(ssh-keygen -lf "$temp_key_file" 2>/dev/null | awk '{print $2}')
        rm "$temp_key_file"
        
        # Compare fingerprints
        if [[ "$auth_key_fingerprint" == "$key_fingerprint" ]]; then
          return 0  # Key is in authorized_keys
        fi
      done < "$auth_keys_file"
    fi
  done < <(find /home -name "authorized_keys" 2>/dev/null || echo "")
  
  return 1  # Key is not in any authorized_keys file
}

# Function to check if a key is in known_hosts
is_in_known_hosts() {
  local key_path="$1"
  local key_type=""
  
  # Determine the key type from the first line of the private key
  key_type=$(head -n 1 "$key_path" | grep -o "BEGIN.*PRIVATE KEY" | awk '{print $2}')
  
  if [[ -z "$key_type" ]]; then
    return 1  # Couldn't determine key type
  fi
  
  # Map internal key type to known_hosts key type
  case "$key_type" in
    "RSA")
      key_type="ssh-rsa"
      ;;
    "DSA")
      key_type="ssh-dss"
      ;;
    "EC")
      key_type="ecdsa-sha2-nistp256"
      ;;
    "OPENSSH")
      key_type="ssh-ed25519"
      ;;
    *)
      return 1  # Unknown key type
      ;;
  esac
  
  # Check all known_hosts files
  while IFS= read -r known_hosts_file; do
    if [[ -f "$known_hosts_file" ]]; then
      if grep -q "$key_type" "$known_hosts_file" 2>/dev/null; then
        return 0  # Key type is in known_hosts
      fi
    fi
  done < <(find /home -name "known_hosts" 2>/dev/null || echo "")
  
  return 1  # Key is not referenced in any known_hosts file
}

# Function to check if a key is loaded in SSH agent
is_in_ssh_agent() {
  local key_path="$1"
  local key_fingerprint=""
  
  # Skip if ssh-add is not available
  if ! command_exists ssh-add; then
    return 1
  fi
  
  # Get the fingerprint of the private key
  if command_exists ssh-keygen; then
    key_fingerprint=$(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}')
  fi
  
  if [[ -z "$key_fingerprint" ]]; then
    return 1  # Couldn't determine fingerprint
  fi
  
  # Check if the key is loaded in SSH agent
  local agent_keys=$(ssh-add -l 2>/dev/null)
  if [[ $? -eq 0 && -n "$agent_keys" ]]; then
    if echo "$agent_keys" | grep -q "$key_fingerprint"; then
      return 0  # Key is loaded in SSH agent
    fi
  fi
  
  return 1  # Key is not loaded in SSH agent
}

# Function to count how many times a key appears in logs
count_key_usages_in_logs() {
  local key_path="$1"
  local key_fingerprint=""
  local count=0
  
  # Get the fingerprint of the private key
  if command_exists ssh-keygen; then
    key_fingerprint=$(ssh-keygen -lf "$key_path" 2>/dev/null | awk '{print $2}')
    
    # If we couldn't get the fingerprint, try with the public key
    if [[ -z "$key_fingerprint" && -f "${key_path}.pub" ]]; then
      key_fingerprint=$(ssh-keygen -lf "${key_path}.pub" 2>/dev/null | awk '{print $2}')
    fi
  fi
  
  if [[ -z "$key_fingerprint" ]]; then
    echo "0"
    return
  fi
  
  # Check all SSH log files
  for log_file in "${SSH_LOG_FILES[@]}"; do
    if [[ -f "$log_file" ]]; then
      if ! this_count=$(grep -c "$key_fingerprint" "$log_file" 2>/dev/null); then
        this_count=0
      fi
      count=$((count + this_count))
      
      # Also check by key file name (logs may not show fingerprint)
      local key_basename=$(basename "$key_path")
      if ! this_count=$(grep -c "$key_basename" "$log_file" 2>/dev/null); then
        this_count=0
      fi
      count=$((count + this_count))
    fi
  done
  
  echo "$count"
}

# Function to check if a key has been used in SSH logs
is_in_ssh_logs() {
  local key_path="$1"
  local usage_count=$(count_key_usages_in_logs "$key_path")
  
  if [[ "$usage_count" -gt 0 ]]; then
    return 0  # Key is found in logs
  fi
  
  return 1  # Key is not found in any SSH log
}

# Function to check if a key has been used based on file access time
is_recently_accessed() {
  local key_path="$1"
  local threshold_seconds=$((AGE_THRESHOLD * 86400))  # Convert days to seconds
  local current_time=$(date +%s)
  local file_access_time=0
  
  # Get file access time in seconds since epoch
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use stat -f %a
    file_access_time=$(stat -f %a "$key_path" 2>/dev/null)
  else
    # Linux - use stat -c %X
    file_access_time=$(stat -c %X "$key_path" 2>/dev/null)
  fi
  
  if [[ -z "$file_access_time" || "$file_access_time" -eq 0 ]]; then
    return 1  # Couldn't determine access time
  fi
  
  local time_diff=$((current_time - file_access_time))
  
  if [[ "$time_diff" -lt "$threshold_seconds" ]]; then
    return 0  # Key was accessed recently
  fi
  
  return 1  # Key has not been accessed recently
}

# Function to get key details
get_key_details() {
  local key_path="$1"
  local key_type=""
  local key_bits=""
  local key_fingerprint=""
  local key_comment=""
  local creation_time=""
  local access_time=""
  local modification_time=""
  
  # Get key type and bits
  if command_exists ssh-keygen; then
    local key_info=$(ssh-keygen -lf "$key_path" 2>/dev/null)
    
    # If that fails, try the public key
    if [[ -z "$key_info" && -f "${key_path}.pub" ]]; then
      key_info=$(ssh-keygen -lf "${key_path}.pub" 2>/dev/null)
    fi
    
    if [[ -n "$key_info" ]]; then
      key_bits=$(echo "$key_info" | awk '{print $1}')
      key_fingerprint=$(echo "$key_info" | awk '{print $2}')
      key_comment=$(echo "$key_info" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' | xargs)
      key_type=$(echo "$key_info" | awk '{print $3}' | tr -d '()')
    fi
  fi
  
  # Get file timestamps
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    creation_time=$(stat -f %SB -t "%Y-%m-%d %H:%M:%S" "$key_path" 2>/dev/null)
    access_time=$(stat -f %Sa -t "%Y-%m-%d %H:%M:%S" "$key_path" 2>/dev/null)
    modification_time=$(stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$key_path" 2>/dev/null)
  else
    # Linux
    creation_time=$(stat -c %W "$key_path" 2>/dev/null)
    if [[ -n "$creation_time" && "$creation_time" != "0" ]]; then
      creation_time=$(date -d "@$creation_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    else
      creation_time="Unknown"
    fi
    
    access_time=$(date -d "@$(stat -c %X "$key_path" 2>/dev/null)" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
    modification_time=$(date -d "@$(stat -c %Y "$key_path" 2>/dev/null)" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
  fi
  
  # Create a JSON-like string with key details
  echo "{"
  echo "  \"path\": \"$key_path\","
  echo "  \"type\": \"${key_type:-Unknown}\","
  echo "  \"bits\": \"${key_bits:-Unknown}\","
  echo "  \"fingerprint\": \"${key_fingerprint:-Unknown}\","
  echo "  \"comment\": \"${key_comment:-None}\","
  echo "  \"creation_time\": \"${creation_time:-Unknown}\","
  echo "  \"access_time\": \"${access_time:-Unknown}\","
  echo "  \"modification_time\": \"${modification_time:-Unknown}\""
  echo "}"
}

#=====================================================================
# DETECTION FUNCTIONS
#=====================================================================
# Function to analyze a key for usage
analyze_key_usage() {
  local key_path="$1"
  local usage_score=0
  local usage_reasons=()
  local usage_count=0
  
  # Check if key is in authorized_keys
  if [[ "$CHECK_AUTH_KEYS" == "true" ]]; then
    if is_in_authorized_keys "$key_path"; then
      usage_score=$((usage_score + 1))
      usage_reasons+=("Found in authorized_keys")
    fi
  fi
  
  # Check if key is in known_hosts
  if [[ "$CHECK_KNOWN_HOSTS" == "true" ]]; then
    if is_in_known_hosts "$key_path"; then
      usage_score=$((usage_score + 1))
      usage_reasons+=("Referenced in known_hosts")
    fi
  fi
  
  # Check if key is loaded in SSH agent
  if [[ "$CHECK_SSH_AGENT" == "true" ]]; then
    if is_in_ssh_agent "$key_path"; then
      usage_score=$((usage_score + 1))
      usage_reasons+=("Loaded in SSH agent")
    fi
  fi
  
  # Check if key has been used in SSH logs
  if [[ "$CHECK_SSH_LOGS" == "true" ]]; then
    # Sanitize the usage count to ensure it's a clean integer
    local raw_count=$(count_key_usages_in_logs "$key_path")
    usage_count=$(echo "$raw_count" | tr -d '\n\r' | grep -o '[0-9]*' || echo "0")
    usage_count=${usage_count:-0}  # Default to 0 if empty
    
    if [[ $usage_count -gt 0 ]]; then
      usage_score=$((usage_score + 1))
      usage_reasons+=("Referenced in SSH logs ($usage_count times)")
    fi
  fi
  
  # Check if key has been accessed recently
  if [[ "$CHECK_ACCESS_TIME" == "true" ]]; then
    if is_recently_accessed "$key_path"; then
      usage_score=$((usage_score + 1))
      usage_reasons+=("Recently accessed")
    fi
  fi
  
  # Clean up and ensure the score is a valid integer
  usage_score=${usage_score:-0}
  
  # Prepare the reason text
  local reason=""
  if [[ "$usage_score" -lt "$MIN_USAGE_SCORE" ]]; then
    status="unused"
    reason="No significant usage indicators found (score: $usage_score, required: $MIN_USAGE_SCORE)"
  else
    status="used"
    reason="${usage_reasons[*]}"
    [[ -z "$reason" ]] && reason="Recently accessed"
  fi
  
  # Output in a format that's easier to parse reliably
  printf "STATUS=%s\nREASON=%s\nSCORE=%d\nCOUNT=%d\n" "$status" "$reason" "$usage_score" "$usage_count"
}

# Function to scan all users for unused SSH keys
scan_users_for_keys() {
  local temp_results_file=$(mktemp)

  if [[ "$FORMAT" == "json" ]]; then
    echo "[" > "$temp_results_file"
  elif [[ "$FORMAT" == "csv" ]]; then
    echo "User,Key Path,Key Type,Key Bits,Fingerprint,Status,Usage Score,Times Used,Reason,Last Accessed,Creation Time,Comment" > "$temp_results_file"
  fi

  if [[ -n "$SINGLE_USER" ]]; then
    if [[ "$SSH_DIR" == "/home" || "$SSH_DIR" == "/Users" ]]; then
      scan_single_user "$SSH_DIR/$SINGLE_USER" "$temp_results_file"
    else
      scan_single_user "$SSH_DIR" "$temp_results_file" "$SINGLE_USER"
    fi
  else
    # Scan all users
    local users=()
    if [[ "$SSH_DIR" == "/home" ]]; then
      while IFS= read -r user_dir; do
        [[ -d "$user_dir" && "$user_dir" != "/home/lost+found" ]] && users+=("$user_dir")
      done < <(find "$SSH_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
    elif [[ "$SSH_DIR" == "/Users" ]]; then
      while IFS= read -r user_dir; do
        local base=$(basename "$user_dir")
        [[ "$base" =~ ^(Shared|Guest|.localized)$ ]] && continue
        [[ -d "$user_dir" ]] && users+=("$user_dir")
      done < <(find "$SSH_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
    else
      users=("$SSH_DIR")
    fi

    local user_count=${#users[@]}
    for ((i=0; i<user_count; i+=MAX_THREADS)); do
      local jobs=()
      for ((j=i; j<i+MAX_THREADS && j<user_count; j++)); do
        scan_single_user "${users[$j]}" "$temp_results_file" &
        jobs+=($!)
      done
      for job in "${jobs[@]}"; do
        wait "$job"
      done
    done
  fi

  if [[ "$FORMAT" == "json" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # For macOS sed
      sed -i '' -e '$ s/,$//' "$temp_results_file"
    else
      # For Linux sed
      sed -i '$ s/,$//' "$temp_results_file"
    fi
    echo "]" >> "$temp_results_file"
  fi

  if [[ -n "$OUTPUT_FILE" ]]; then
    cat "$temp_results_file" > "$OUTPUT_FILE"
    format-echo "SUCCESS" "Results written to $OUTPUT_FILE"
  else
    cat "$temp_results_file"
  fi

  rm -f "$temp_results_file"
}

# Function to scan a single user for unused SSH keys
scan_single_user() {
  local user_dir="$1"
  local results_file="$2"
  local specific_username="${3:-}"
  local username=$(basename "$user_dir")
  
  # If specific username is provided, check if it matches
  if [[ -n "$specific_username" && "$username" != "$specific_username" ]]; then
    username="$specific_username"
  fi
  
  if [[ "$VERBOSE" == "true" ]]; then
    format-echo "INFO" "Scanning SSH keys for user: $username"
  fi
  
  # Find SSH keys for this user
  local key_files=()
  IFS=" " read -r -a key_files <<< "$(find_ssh_keys "$user_dir")"
  
  if [[ ${#key_files[@]} -eq 0 ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
      format-echo "INFO" "No SSH keys found for user: $username"
    fi
    return
  fi
  
  # Process each key
  for key_path in "${key_files[@]}"; do
    if [[ ! -f "$key_path" ]]; then
      continue
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
      format-echo "INFO" "Analyzing key: $key_path"
    fi
    
    # Analyze key usage
    local usage_result=$(analyze_key_usage "$key_path")
    local status=$(echo "$usage_result" | grep "^STATUS=" | cut -d= -f2)
    local reason=$(echo "$usage_result" | grep "^REASON=" | cut -d= -f2-)
    local usage_score=$(echo "$usage_result" | grep "^SCORE=" | cut -d= -f2)
    local usage_count=$(echo "$usage_result" | grep "^COUNT=" | cut -d= -f2)
    
    # Default values in case parsing fails
    [[ -z "$status" ]] && status="unknown"
    [[ -z "$usage_score" ]] && usage_score=0
    [[ -z "$usage_count" ]] && usage_count=0

    # Get key details
    local key_details=$(get_key_details "$key_path")
    local key_type=$(echo "$key_details" | grep '"type"' | cut -d'"' -f4)
    local key_bits=$(echo "$key_details" | grep '"bits"' | cut -d'"' -f4)
    local fingerprint=$(echo "$key_details" | grep '"fingerprint"' | cut -d'"' -f4)
    local comment=$(echo "$key_details" | grep '"comment"' | cut -d'"' -f4)
    local access_time=$(echo "$key_details" | grep '"access_time"' | cut -d'"' -f4)
    local creation_time=$(echo "$key_details" | grep '"creation_time"' | cut -d'"' -f4)
    
    # Skip used keys unless verbose is enabled
    if [[ "$status" == "used" && "$VERBOSE" != "true" ]]; then
      continue
    fi
    
    # Format and output the results
    case "$FORMAT" in
      text)
        {
          echo "User: $username"
          echo "Key: $key_path"
          echo "Type: ${key_type:-no}"
          echo "Bits: ${key_bits:-no}"
          echo "Fingerprint: ${fingerprint:-no}"
          echo "Status: $status"
          echo "Usage Score: $usage_score/$MIN_USAGE_SCORE required"
          echo "Reason: $reason"
          echo "Last Accessed: $access_time"
          echo "Created: $creation_time"
          if [[ -n "$comment" && "$comment" != "None" ]]; then
            echo "Comment: $comment"
          fi
          echo "---"
        } >> "$results_file"
        ;;
      
      json)
        {
          echo "  {"
          echo "    \"user\": \"$username\","
          echo "    \"key_path\": \"$key_path\","
          echo "    \"key_type\": \"${key_type:-no}\","
          echo "    \"key_bits\": \"${key_bits:-no}\","
          echo "    \"fingerprint\": \"${fingerprint:-no}\","
          echo "    \"status\": \"$status\","
          echo "    \"usage_score\": \"$usage_score/$MIN_USAGE_SCORE\","
          echo "    \"times_used\": \"$usage_count\","
          echo "    \"reason\": \"$reason\","
          echo "    \"last_accessed\": \"$access_time\","
          echo "    \"creation_time\": \"$creation_time\","
          echo "    \"comment\": \"$comment\""
          echo "  },"
        } >> "$results_file"
        ;;
      
      csv)
        echo "$username,\"$key_path\",\"${key_type:-no}\",\"${key_bits:-no}\",\"${fingerprint:-no}\",\"$status\",\"$usage_score/$MIN_USAGE_SCORE\",\"$usage_count\",\"$reason\",\"$access_time\",\"$creation_time\",\"$comment\"" >> "$results_file"
        ;;
    esac
    
    # If the key is unused and we need to take action, do it
    if [[ "$status" == "unused" && "$ACTION" != "report" ]]; then
      take_action_on_key "$key_path" "$username"
    fi
  done
}

#=====================================================================
# ACTION FUNCTIONS
#=====================================================================
# Function to take action on an unused key
take_action_on_key() {
  local key_path="$1"
  local username="$2"
  
  case "$ACTION" in
    backup)
      backup_key "$key_path"
      ;;
    archive)
      archive_key "$key_path"
      ;;
    disable)
      disable_key "$key_path"
      ;;
    remove)
      remove_key "$key_path"
      ;;
  esac
}

# Function to backup a key
backup_key() {
  local key_path="$1"
  local backup_dir="/tmp/ssh-key-backups"
  local timestamp=$(date +"%Y%m%d%H%M%S")
  local key_basename=$(basename "$key_path")
  local backup_path="$backup_dir/${key_basename}.${timestamp}.bak"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    format-echo "DRY-RUN" "Would backup key $key_path to $backup_path"
    return
  fi
  
  # Create backup directory if it doesn't exist
  mkdir -p "$backup_dir"
  
  # Backup the key
  if cp "$key_path" "$backup_path"; then
    format-echo "SUCCESS" "Backed up key $key_path to $backup_path"
    
    # Also backup the public key if it exists
    if [[ -f "${key_path}.pub" ]]; then
      cp "${key_path}.pub" "${backup_path}.pub"
    fi
  else
    format-echo "ERROR" "Failed to backup key $key_path"
  fi
}

# Function to archive a key (compress and move to archive location)
archive_key() {
  local key_path="$1"
  local archive_dir="/tmp/ssh-key-archives"
  local timestamp=$(date +"%Y%m%d%H%M%S")
  local key_basename=$(basename "$key_path")
  local archive_name="${key_basename}.${timestamp}.tar.gz"
  local archive_path="$archive_dir/$archive_name"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    format-echo "DRY-RUN" "Would archive key $key_path to $archive_path"
    return
  fi
  
  # Create archive directory if it doesn't exist
  mkdir -p "$archive_dir"
  
  # Create a temporary directory for the archive
  local temp_dir=$(mktemp -d)
  cp "$key_path" "$temp_dir/$key_basename"
  
  # Also include the public key if it exists
  if [[ -f "${key_path}.pub" ]]; then
    cp "${key_path}.pub" "$temp_dir/${key_basename}.pub"
  fi
  
  # Create the archive
  if tar -czf "$archive_path" -C "$temp_dir" .; then
    format-echo "SUCCESS" "Archived key $key_path to $archive_path"
    
    # Clean up the temporary directory
    rm -rf "$temp_dir"
    
    # Remove the original files since they're now archived
    rm -f "$key_path"
    rm -f "${key_path}.pub"
  else
    format-echo "ERROR" "Failed to archive key $key_path"
    rm -rf "$temp_dir"
  fi
}

# Function to disable a key (rename to .disabled)
disable_key() {
  local key_path="$1"
  local disabled_path="${key_path}.disabled"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    format-echo "DRY-RUN" "Would disable key $key_path by renaming to $disabled_path"
    return
  fi
  
  # Rename the key
  if mv "$key_path" "$disabled_path"; then
    format-echo "SUCCESS" "Disabled key $key_path by renaming to $disabled_path"
    
    # Also disable the public key if it exists
    if [[ -f "${key_path}.pub" ]]; then
      mv "${key_path}.pub" "${disabled_path}.pub"
    fi
  else
    format-echo "ERROR" "Failed to disable key $key_path"
  fi
}

# Function to remove a key
remove_key() {
  local key_path="$1"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    format-echo "DRY-RUN" "Would remove key $key_path"
    return
  fi
  
  # Remove the key
  if rm -f "$key_path"; then
    format-echo "SUCCESS" "Removed key $key_path"
    
    # Also remove the public key if it exists
    if [[ -f "${key_path}.pub" ]]; then
      rm -f "${key_path}.pub"
    fi
  else
    format-echo "ERROR" "Failed to remove key $key_path"
  fi
}

#=====================================================================
# MAIN FUNCTION
#=====================================================================
main() {
  parse_args "$@"
  
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  print_with_separator "Unused SSH Key Detector Script"
  format-echo "INFO" "Starting Unused SSH Key Detector Script..."
  
  # Display configuration if verbose
  if [[ "$VERBOSE" == "true" ]]; then
    format-echo "INFO" "Configuration:"
    format-echo "INFO" "  SSH Directory: $SSH_DIR"
    format-echo "INFO" "  User: ${SINGLE_USER:-All users}"
    format-echo "INFO" "  Age Threshold: $AGE_THRESHOLD days"
    format-echo "INFO" "  Min Usage Score: $MIN_USAGE_SCORE"
    format-echo "INFO" "  Action: $ACTION"
    format-echo "INFO" "  Output Format: $FORMAT"
    if [[ -n "$OUTPUT_FILE" ]]; then
      format-echo "INFO" "  Output File: $OUTPUT_FILE"
    fi
    format-echo "INFO" "  Check Auth Keys: $CHECK_AUTH_KEYS"
    format-echo "INFO" "  Check Known Hosts: $CHECK_KNOWN_HOSTS"
    format-echo "INFO" "  Check SSH Agent: $CHECK_SSH_AGENT"
    format-echo "INFO" "  Check SSH Logs: $CHECK_SSH_LOGS"
    format-echo "INFO" "  Check Access Time: $CHECK_ACCESS_TIME"
    if [[ ${#EXCLUSIONS[@]} -gt 0 ]]; then
      format-echo "INFO" "  Exclusions: ${EXCLUSIONS[*]}"
    fi
    format-echo "INFO" "  Dry Run: $DRY_RUN"
  fi
  
  # Scan for unused SSH keys
  format-echo "INFO" "Scanning for unused SSH keys..."
  scan_users_for_keys
  
  print_with_separator "End of Unused SSH Key Detector Script"
  format-echo "SUCCESS" "Unused SSH key scan completed."
  
  # Display summary based on action
  case "$ACTION" in
    report)
      format-echo "INFO" "Generated report of SSH key usage."
      ;;
    backup)
      format-echo "INFO" "Backed up unused SSH keys to /tmp/ssh-key-backups directory."
      ;;
    archive)
      format-echo "INFO" "Archived unused SSH keys to /tmp/ssh-key-archives directory."
      ;;
    disable)
      format-echo "INFO" "Disabled unused SSH keys by renaming them with .disabled extension."
      ;;
    remove)
      format-echo "INFO" "Removed unused SSH keys from the system."
      ;;
  esac
}

main "$@"
