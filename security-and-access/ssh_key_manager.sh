#!/bin/bash
# filepath: /Users/mykfor1/Documents/git/github/shell-scripts/security-and-access/ssh_key_manager.sh
# Script to generate, manage and distribute SSH keys with advanced features.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"
SECURE_PERMS_FILE="$SCRIPT_DIR/secure_file_permissions.sh"

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
USERNAME=""
REMOTE_SERVERS=()
LOG_FILE="/dev/null"
KEY_TYPE="ed25519"  # Default to more secure ed25519
KEY_BITS="4096"     # Used for RSA
KEY_NAME="id_${KEY_TYPE}"
KEY_COMMENT=""
KEY_PASSPHRASE=""
KEY_DIR=""
OVERWRITE=false
BACKUP=true
DISTRIBUTE=true
NON_INTERACTIVE=false
SECURE_PERMS=true
VERIFY_CONNECTION=true
VERBOSE=false
ROTATE_KEYS=false
ROTATION_KEEP_OLD=true
GITHUB_UPLOAD=false
GITHUB_TOKEN=""
BITBUCKET_UPLOAD=false
BITBUCKET_TOKEN=""
GITLAB_UPLOAD=false
GITLAB_TOKEN=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Advanced SSH Key Manager Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script generates, manages, and distributes SSH keys with advanced features."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options] [--user <username>] [--server <remote_server1> [--server <remote_server2> ...]]"
  echo
  echo -e "\033[1;34mKey Generation Options:\033[0m"
  echo -e "  \033[1;33m--user <username>\033[0m              (Required) Username for whom the SSH key will be generated"
  echo -e "  \033[1;33m--type <type>\033[0m                  (Optional) Key type: ed25519, rsa, ecdsa, dsa (default: ed25519)"
  echo -e "  \033[1;33m--bits <bits>\033[0m                  (Optional) Key size in bits (default: 4096 for RSA)"
  echo -e "  \033[1;33m--name <name>\033[0m                  (Optional) Key filename (default: id_<type>)"
  echo -e "  \033[1;33m--comment <comment>\033[0m            (Optional) Comment to add to the key"
  echo -e "  \033[1;33m--passphrase <passphrase>\033[0m      (Optional) Set a passphrase for the key"
  echo -e "  \033[1;33m--key-dir <directory>\033[0m          (Optional) Custom location for the key (default: ~/.ssh)"
  echo -e "  \033[1;33m--overwrite\033[0m                    (Optional) Overwrite existing keys without prompting"
  echo -e "  \033[1;33m--no-backup\033[0m                    (Optional) Don't create backups of existing keys"
  echo
  echo -e "\033[1;34mDistribution Options:\033[0m"
  echo -e "  \033[1;33m--server <remote_server>\033[0m       (Optional) Remote server to distribute the key to (can be used multiple times)"
  echo -e "  \033[1;33m--no-distribute\033[0m                (Optional) Generate keys but don't distribute them"
  echo -e "  \033[1;33m--no-verify\033[0m                    (Optional) Skip testing the connection after key distribution"
  echo
  echo -e "\033[1;34mCloud Service Integration:\033[0m"
  echo -e "  \033[1;33m--github\033[0m                       (Optional) Upload key to GitHub"
  echo -e "  \033[1;33m--github-token <token>\033[0m         (Optional) GitHub API token for key upload"
  echo -e "  \033[1;33m--gitlab\033[0m                       (Optional) Upload key to GitLab"
  echo -e "  \033[1;33m--gitlab-token <token>\033[0m         (Optional) GitLab API token for key upload"
  echo -e "  \033[1;33m--bitbucket\033[0m                    (Optional) Upload key to Bitbucket"
  echo -e "  \033[1;33m--bitbucket-token <token>\033[0m      (Optional) Bitbucket API token for key upload"
  echo
  echo -e "\033[1;34mKey Rotation:\033[0m"
  echo -e "  \033[1;33m--rotate\033[0m                       (Optional) Rotate keys - generate new and update all configured servers"
  echo -e "  \033[1;33m--no-keep-old\033[0m                  (Optional) Don't keep old keys when rotating"
  echo
  echo -e "\033[1;34mGeneral Options:\033[0m"
  echo -e "  \033[1;33m--non-interactive\033[0m              (Optional) Run in non-interactive mode (no prompts)"
  echo -e "  \033[1;33m--no-secure-perms\033[0m              (Optional) Skip setting secure file permissions"
  echo -e "  \033[1;33m--verbose\033[0m                      (Optional) Show detailed information"
  echo -e "  \033[1;33m--log <log_file>\033[0m               (Optional) Path to save log messages"
  echo -e "  \033[1;33m--help\033[0m                         (Optional) Display this help message"
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --user johndoe --server user@example.com"
  echo "  $0 --user johndoe --type rsa --bits 4096 --comment \"Work key\" --server server1 --server server2"
  echo "  $0 --user johndoe --rotate --server user@example.com"
  echo "  $0 --user johndoe --github --github-token TOKEN"
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
      --user)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No username provided after --user"
          usage
        fi
        USERNAME="$2"
        shift 2
        ;;
      --server)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No server provided after --server"
          usage
        fi
        REMOTE_SERVERS+=("$2")
        shift 2
        ;;
      --type)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No key type provided after --type"
          usage
        fi
        if [[ ! "$2" =~ ^(ed25519|rsa|ecdsa|dsa)$ ]]; then
          format-echo "ERROR" "Invalid key type: $2. Must be one of: ed25519, rsa, ecdsa, dsa"
          usage
        fi
        KEY_TYPE="$2"
        KEY_NAME="id_${KEY_TYPE}"
        shift 2
        ;;
      --bits)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          format-echo "ERROR" "Invalid key bits value: $2"
          usage
        fi
        KEY_BITS="$2"
        shift 2
        ;;
      --name)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No key name provided after --name"
          usage
        fi
        KEY_NAME="$2"
        shift 2
        ;;
      --comment)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No comment provided after --comment"
          usage
        fi
        KEY_COMMENT="$2"
        shift 2
        ;;
      --passphrase)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No passphrase provided after --passphrase"
          usage
        fi
        KEY_PASSPHRASE="$2"
        shift 2
        ;;
      --key-dir)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No directory provided after --key-dir"
          usage
        fi
        KEY_DIR="$2"
        shift 2
        ;;
      --overwrite)
        OVERWRITE=true
        shift
        ;;
      --no-backup)
        BACKUP=false
        shift
        ;;
      --no-distribute)
        DISTRIBUTE=false
        shift
        ;;
      --no-verify)
        VERIFY_CONNECTION=false
        shift
        ;;
      --non-interactive)
        NON_INTERACTIVE=true
        shift
        ;;
      --no-secure-perms)
        SECURE_PERMS=false
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --rotate)
        ROTATE_KEYS=true
        shift
        ;;
      --no-keep-old)
        ROTATION_KEEP_OLD=false
        shift
        ;;
      --github)
        GITHUB_UPLOAD=true
        shift
        ;;
      --github-token)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No token provided after --github-token"
          usage
        fi
        GITHUB_TOKEN="$2"
        shift 2
        ;;
      --gitlab)
        GITLAB_UPLOAD=true
        shift
        ;;
      --gitlab-token)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No token provided after --gitlab-token"
          usage
        fi
        GITLAB_TOKEN="$2"
        shift 2
        ;;
      --bitbucket)
        BITBUCKET_UPLOAD=true
        shift
        ;;
      --bitbucket-token)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No token provided after --bitbucket-token"
          usage
        fi
        BITBUCKET_TOKEN="$2"
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
      *)
        format-echo "ERROR" "Unknown option: $1"
        usage
        ;;
    esac
  done
  
  # Validate arguments
  validate_args
}

# Validate the parsed arguments
validate_args() {
  # Require username
  if [ -z "$USERNAME" ]; then
    format-echo "ERROR" "Username is required. Use --user <username>"
    usage
  fi
  
  # Check if we need to distribute but no servers specified
  if [[ "$DISTRIBUTE" == "true" && ${#REMOTE_SERVERS[@]} -eq 0 ]]; then
    format-echo "WARNING" "Distribution enabled but no remote servers specified."
    if [[ "$NON_INTERACTIVE" == "false" ]]; then
      read -p "Continue with key generation only? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        exit 0
      fi
    fi
    DISTRIBUTE=false
  fi
  
  # Check key type and bits compatibility
  if [[ "$KEY_TYPE" == "ed25519" && "$KEY_BITS" != "4096" ]]; then
    format-echo "WARNING" "ED25519 keys don't use the --bits parameter. Ignoring bits value."
  fi
  
  # Check if GitHub upload is configured properly
  if [[ "$GITHUB_UPLOAD" == "true" && -z "$GITHUB_TOKEN" ]]; then
    format-echo "ERROR" "GitHub upload requested but no token provided. Use --github-token"
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      exit 1
    else
      read -p "Continue without GitHub upload? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        exit 0
      fi
      GITHUB_UPLOAD=false
    fi
  fi
  
  # Similar checks for GitLab and Bitbucket
  if [[ "$GITLAB_UPLOAD" == "true" && -z "$GITLAB_TOKEN" ]]; then
    format-echo "ERROR" "GitLab upload requested but no token provided. Use --gitlab-token"
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      exit 1
    else
      read -p "Continue without GitLab upload? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        exit 0
      fi
      GITLAB_UPLOAD=false
    fi
  fi
  
  if [[ "$BITBUCKET_UPLOAD" == "true" && -z "$BITBUCKET_TOKEN" ]]; then
    format-echo "ERROR" "Bitbucket upload requested but no token provided. Use --bitbucket-token"
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      exit 1
    else
      read -p "Continue without Bitbucket upload? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Operation cancelled by user."
        exit 0
      fi
      BITBUCKET_UPLOAD=false
    fi
  fi
}

#=====================================================================
# UTILITY FUNCTIONS
#=====================================================================

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Get the SSH directory path
get_ssh_dir() {
  local user_home
  
  if [[ -n "$KEY_DIR" ]]; then
    echo "$KEY_DIR"
    return
  fi
  
  if [[ "$USERNAME" == "$(whoami)" ]]; then
    user_home="$HOME"
  else
    user_home=$(eval echo "~$USERNAME" 2>/dev/null || echo "/home/$USERNAME")
  fi
  
  echo "$user_home/.ssh"
}

# Ensure the SSH directory exists with proper permissions
ensure_ssh_dir() {
  local ssh_dir="$1"
  
  if [[ ! -d "$ssh_dir" ]]; then
    format-echo "INFO" "Creating SSH directory: $ssh_dir"
    mkdir -p "$ssh_dir"
    
    if [[ "$SECURE_PERMS" == "true" ]]; then
      chmod 700 "$ssh_dir"
      chown "$USERNAME:$(id -gn "$USERNAME" 2>/dev/null || echo "$USERNAME")" "$ssh_dir"
    fi
  elif [[ "$VERBOSE" == "true" ]]; then
    format-echo "INFO" "SSH directory already exists: $ssh_dir"
  fi
  
  # Ensure ~/.ssh/config exists
  local config_file="$ssh_dir/config"
  if [[ ! -f "$config_file" ]]; then
    format-echo "INFO" "Creating SSH config file: $config_file"
    touch "$config_file"
    
    if [[ "$SECURE_PERMS" == "true" ]]; then
      chmod 600 "$config_file"
      chown "$USERNAME:$(id -gn "$USERNAME" 2>/dev/null || echo "$USERNAME")" "$config_file"
    fi
  fi
}

# Backup existing SSH keys
backup_ssh_key() {
  local key_path="$1"
  local backup_timestamp
  
  if [[ ! -f "$key_path" ]]; then
    return 0  # Nothing to backup
  fi
  
  if [[ "$BACKUP" != "true" ]]; then
    format-echo "INFO" "Backup disabled, not backing up existing key: $key_path"
    return 0
  fi
  
  backup_timestamp=$(date +"%Y%m%d%H%M%S")
  local backup_path="${key_path}.backup-${backup_timestamp}"
  
  format-echo "INFO" "Backing up existing SSH key to: $backup_path"
  cp "$key_path" "$backup_path"
  
  # Backup the public key as well if it exists
  if [[ -f "${key_path}.pub" ]]; then
    cp "${key_path}.pub" "${key_path}.pub.backup-${backup_timestamp}"
  fi
  
  return 0
}

# Set secure permissions on SSH keys
set_secure_permissions() {
  local key_path="$1"
  
  if [[ "$SECURE_PERMS" != "true" ]]; then
    return 0
  fi
  
  format-echo "INFO" "Setting secure permissions for: $key_path"
  
  # Private key should be readable only by the owner
  chmod 600 "$key_path"
  
  # Public key can be readable by others
  if [[ -f "${key_path}.pub" ]]; then
    chmod 644 "${key_path}.pub"
  fi
  
  # Set ownership
  chown "$USERNAME:$(id -gn "$USERNAME" 2>/dev/null || echo "$USERNAME")" "$key_path"
  if [[ -f "${key_path}.pub" ]]; then
    chown "$USERNAME:$(id -gn "$USERNAME" 2>/dev/null || echo "$USERNAME")" "${key_path}.pub"
  fi
  
  # If we have the secure_file_permissions.sh script, use it for enhanced security
  if [[ -f "$SECURE_PERMS_FILE" && -x "$SECURE_PERMS_FILE" ]]; then
    format-echo "INFO" "Using secure_file_permissions.sh for enhanced security"
    bash "$SECURE_PERMS_FILE" "$key_path" "${key_path}.pub" --file-perm 600 --owner "$USERNAME" --verbose
  fi
  
  return 0
}

# Generate an SSH key
generate_ssh_key() {
  local ssh_dir="$1"
  local key_path="$ssh_dir/$KEY_NAME"
  local key_gen_command
  local key_gen_options=()
  
  # Check if key already exists
  if [[ -f "$key_path" && "$OVERWRITE" != "true" ]]; then
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
      format-echo "ERROR" "SSH key already exists: $key_path (use --overwrite to force)"
      exit 1
    else
      format-echo "WARNING" "SSH key already exists: $key_path"
      read -p "Overwrite this key? (y/n): " confirm
      if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        format-echo "INFO" "Key generation cancelled by user."
        return 1
      fi
    fi
  fi
  
  # Backup existing key
  if [[ -f "$key_path" ]]; then
    backup_ssh_key "$key_path"
  fi
  
  # Build the key generation command
  key_gen_options+=("-t" "$KEY_TYPE")
  
  if [[ "$KEY_TYPE" == "rsa" ]]; then
    key_gen_options+=("-b" "$KEY_BITS")
  elif [[ "$KEY_TYPE" == "ecdsa" ]]; then
    key_gen_options+=("-b" "521")  # Highest security for ECDSA
  fi
  
  key_gen_options+=("-f" "$key_path")
  
  if [[ -n "$KEY_COMMENT" ]]; then
    key_gen_options+=("-C" "$KEY_COMMENT")
  else
    key_gen_options+=("-C" "$USERNAME@$(hostname)")
  fi
  
  # Handle passphrase
  if [[ -n "$KEY_PASSPHRASE" ]]; then
    # For non-interactive mode, use a temporary expect script to provide the passphrase
    if command_exists expect; then
      format-echo "INFO" "Using expect to set passphrase non-interactively"
      
      # Create a temporary expect script
      local expect_script
      expect_script=$(mktemp)
      
      cat > "$expect_script" << EOF
#!/usr/bin/expect -f
spawn ssh-keygen -t $KEY_TYPE $(if [[ "$KEY_TYPE" == "rsa" ]]; then echo "-b $KEY_BITS"; fi) -f $key_path -C "$KEY_COMMENT"
expect "Enter passphrase*"
send "$KEY_PASSPHRASE\r"
expect "Enter same passphrase again:"
send "$KEY_PASSPHRASE\r"
expect eof
EOF
      
      chmod 700 "$expect_script"
      
      # Run the expect script
      expect -f "$expect_script"
      
      # Clean up
      rm -f "$expect_script"
    else
      # If expect is not available, we'll use empty passphrase with warning
      format-echo "WARNING" "expect command not found. Cannot set passphrase non-interactively."
      format-echo "WARNING" "Generating key without passphrase. Install expect for non-interactive passphrase support."
      key_gen_options+=("-N" "")
      
      ssh-keygen "${key_gen_options[@]}"
    fi
  else
    # No passphrase
    key_gen_options+=("-N" "")
    
    ssh-keygen "${key_gen_options[@]}"
  fi
  
  # Verify the key was generated
  if [[ ! -f "$key_path" ]]; then
    format-echo "ERROR" "Failed to generate SSH key: $key_path"
    return 1
  fi
  
  format-echo "SUCCESS" "SSH key generated: $key_path"
  
  # Set secure permissions
  set_secure_permissions "$key_path"
  
  return 0
}

# Distribute an SSH key to a remote server
distribute_ssh_key() {
  local key_path="$1"
  local remote_server="$2"
  
  format-echo "INFO" "Distributing SSH key to: $remote_server"
  
  # Check if ssh-copy-id is available
  if command_exists ssh-copy-id; then
    # If we have a passphrase and expect is available, use it for non-interactive authentication
    if [[ -n "$KEY_PASSPHRASE" ]] && command_exists expect; then
      local expect_script
      expect_script=$(mktemp)
      
      cat > "$expect_script" << EOF
#!/usr/bin/expect -f
spawn ssh-copy-id -i "$key_path.pub" "$remote_server"
expect {
  "Are you sure you want to continue connecting" {
    send "yes\r"
    exp_continue
  }
  "password:" {
    send "\r"  # This will likely fail, but we'll handle it below
  }
  eof
}
EOF
      
      chmod 700 "$expect_script"
      
      # Run the expect script
      expect -f "$expect_script"
      
      # Clean up
      rm -f "$expect_script"
      
      format-echo "WARNING" "Automated authentication with passphrase not fully supported."
      format-echo "INFO" "You may need to manually enter your remote server password."
      ssh-copy-id -i "$key_path.pub" "$remote_server"
    else
      # Regular ssh-copy-id
      if ! ssh-copy-id -i "$key_path.pub" "$remote_server"; then
        format-echo "ERROR" "Failed to distribute SSH key to: $remote_server"
        return 1
      fi
    fi
  else
    # Fallback if ssh-copy-id is not available
    format-echo "WARNING" "ssh-copy-id not found, using manual method"
    
    # Create remote .ssh directory if it doesn't exist
    ssh "$remote_server" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    
    # Append the public key to authorized_keys
    cat "$key_path.pub" | ssh "$remote_server" "cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    
    if [[ $? -ne 0 ]]; then
      format-echo "ERROR" "Failed to distribute SSH key to: $remote_server"
      return 1
    fi
  fi
  
  format-echo "SUCCESS" "SSH key distributed to: $remote_server"
  
  # Verify the connection if requested
  if [[ "$VERIFY_CONNECTION" == "true" ]]; then
    verify_ssh_connection "$key_path" "$remote_server"
  fi
  
  return 0
}

# Verify SSH connection to a remote server
verify_ssh_connection() {
  local key_path="$1"
  local remote_server="$2"
  
  format-echo "INFO" "Verifying SSH connection to: $remote_server"
  
  # If we have a passphrase and we're in non-interactive mode, connection verification is limited
  if [[ -n "$KEY_PASSPHRASE" && "$NON_INTERACTIVE" == "true" ]]; then
    format-echo "WARNING" "Cannot verify connection with passphrase in non-interactive mode"
    return 0
  fi
  
  # Try a simple SSH command
  if ssh -i "$key_path" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$remote_server" "echo 'SSH connection successful'"; then
    format-echo "SUCCESS" "SSH connection verified: $remote_server"
    return 0
  else
    format-echo "ERROR" "Failed to verify SSH connection to: $remote_server"
    return 1
  fi
}

# Upload key to GitHub
upload_key_to_github() {
  local key_path="$1"
  local key_title="$USERNAME@$(hostname) $(date +%Y-%m-%d)"
  
  if [[ -n "$KEY_COMMENT" ]]; then
    key_title="$KEY_COMMENT"
  fi
  
  format-echo "INFO" "Uploading SSH key to GitHub as: $key_title"
  
  # Check if curl is available
  if ! command_exists curl; then
    format-echo "ERROR" "curl command not found. Cannot upload key to GitHub."
    return 1
  fi
  
  # Read the public key
  local public_key
  public_key=$(cat "$key_path.pub")
  
  # Prepare the JSON payload
  local json_payload
  json_payload=$(cat << EOF
{
  "title": "$key_title",
  "key": "$public_key"
}
EOF
)
  
  # Make the API request
  local response
  response=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -d "$json_payload" \
    "https://api.github.com/user/keys")
  
  # Check if the request was successful
  if echo "$response" | grep -q "key_id"; then
    format-echo "SUCCESS" "SSH key uploaded to GitHub successfully"
    return 0
  else
    format-echo "ERROR" "Failed to upload SSH key to GitHub"
    format-echo "ERROR" "API response: $response"
    return 1
  fi
}

# Upload key to GitLab
upload_key_to_gitlab() {
  local key_path="$1"
  local key_title="$USERNAME@$(hostname) $(date +%Y-%m-%d)"
  
  if [[ -n "$KEY_COMMENT" ]]; then
    key_title="$KEY_COMMENT"
  fi
  
  format-echo "INFO" "Uploading SSH key to GitLab as: $key_title"
  
  # Check if curl is available
  if ! command_exists curl; then
    format-echo "ERROR" "curl command not found. Cannot upload key to GitLab."
    return 1
  fi
  
  # Read the public key
  local public_key
  public_key=$(cat "$key_path.pub")
  
  # Make the API request
  local response
  response=$(curl -s -X POST \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"$key_title\", \"key\": \"$public_key\"}" \
    "https://gitlab.com/api/v4/user/keys")
  
  # Check if the request was successful
  if echo "$response" | grep -q "\"id\":"; then
    format-echo "SUCCESS" "SSH key uploaded to GitLab successfully"
    return 0
  else
    format-echo "ERROR" "Failed to upload SSH key to GitLab"
    format-echo "ERROR" "API response: $response"
    return 1
  fi
}

# Upload key to Bitbucket
upload_key_to_bitbucket() {
  local key_path="$1"
  local key_title="$USERNAME@$(hostname) $(date +%Y-%m-%d)"
  
  if [[ -n "$KEY_COMMENT" ]]; then
    key_title="$KEY_COMMENT"
  fi
  
  format-echo "INFO" "Uploading SSH key to Bitbucket as: $key_title"
  
  # Check if curl is available
  if ! command_exists curl; then
    format-echo "ERROR" "curl command not found. Cannot upload key to Bitbucket."
    return 1
  fi
  
  # Read the public key
  local public_key
  public_key=$(cat "$key_path.pub")
  
  # Extract the username from the token (Bitbucket uses username:app_password format)
  local bitbucket_username
  bitbucket_username=$(echo "$BITBUCKET_TOKEN" | cut -d: -f1)
  local bitbucket_password
  bitbucket_password=$(echo "$BITBUCKET_TOKEN" | cut -d: -f2)
  
  # Make the API request
  local response
  response=$(curl -s -X POST \
    -u "$bitbucket_username:$bitbucket_password" \
    -H "Content-Type: application/json" \
    -d "{\"label\": \"$key_title\", \"key\": \"$public_key\"}" \
    "https://api.bitbucket.org/2.0/users/$bitbucket_username/ssh-keys")
  
  # Check if the request was successful
  if echo "$response" | grep -q "\"uuid\":"; then
    format-echo "SUCCESS" "SSH key uploaded to Bitbucket successfully"
    return 0
  else
    format-echo "ERROR" "Failed to upload SSH key to Bitbucket"
    format-echo "ERROR" "API response: $response"
    return 1
  fi
}

# Rotate SSH keys
rotate_ssh_keys() {
  local ssh_dir="$1"
  local old_key_path="$ssh_dir/$KEY_NAME"
  local new_key_name="${KEY_NAME}.new"
  local new_key_path="$ssh_dir/$new_key_name"
  local temp_key_name="$KEY_NAME"
  
  format-echo "INFO" "Rotating SSH keys..."
  
  # Check if the old key exists
  if [[ ! -f "$old_key_path" ]]; then
    format-echo "ERROR" "Cannot rotate key - original key not found: $old_key_path"
    return 1
  fi
  
  # Temporarily change the key name for generation
  KEY_NAME="$new_key_name"
  
  # Generate a new key
  if ! generate_ssh_key "$ssh_dir"; then
    format-echo "ERROR" "Failed to generate new key for rotation"
    KEY_NAME="$temp_key_name"  # Restore original key name
    return 1
  fi
  
  # Restore original key name
  KEY_NAME="$temp_key_name"
  
  # For each remote server, update the authorized_keys file
  local rotation_success=true
  
  for server in "${REMOTE_SERVERS[@]}"; do
    format-echo "INFO" "Updating keys on server: $server"
    
    # Add the new key
    if ! distribute_ssh_key "$new_key_path" "$server"; then
      format-echo "ERROR" "Failed to distribute new key to: $server"
      rotation_success=false
      continue
    fi
    
    # Remove the old key if requested
    if [[ "$ROTATION_KEEP_OLD" != "true" ]]; then
      format-echo "INFO" "Removing old key from server: $server"
      
      # Get the old public key and escape it for sed
      local old_public_key
      old_public_key=$(cat "$old_key_path.pub")
      old_public_key=${old_public_key//\//\\/}
      old_public_key=${old_public_key//\./\\.}
      
      # Remove the key from authorized_keys
      ssh "$server" "sed -i.bak '/$old_public_key/d' ~/.ssh/authorized_keys"
      
      if [[ $? -ne 0 ]]; then
        format-echo "WARNING" "Could not automatically remove old key from: $server"
      else
        format-echo "SUCCESS" "Old key removed from: $server"
      fi
    fi
  done
  
  # Replace the old key with the new one locally
  if [[ "$rotation_success" == "true" ]]; then
    if [[ "$ROTATION_KEEP_OLD" == "true" ]]; then
      format-echo "INFO" "Keeping old key as requested: $old_key_path"
    else
      format-echo "INFO" "Replacing old key with new key"
      
      # Backup the old key first
      backup_ssh_key "$old_key_path"
      
      # Move the new key to the original name
      mv "$new_key_path" "$old_key_path"
      mv "$new_key_path.pub" "$old_key_path.pub"
      
      # Set secure permissions
      set_secure_permissions "$old_key_path"
      
      format-echo "SUCCESS" "Key rotation completed successfully"
    fi
    return 0
  else
    format-echo "ERROR" "Key rotation had errors - keeping both keys"
    return 1
  fi
}

# Update SSH config
update_ssh_config() {
  local ssh_dir="$1"
  local config_file="$ssh_dir/config"
  
  # Only add configurations for remote servers if distribute is enabled
  if [[ "$DISTRIBUTE" != "true" || ${#REMOTE_SERVERS[@]} -eq 0 ]]; then
    return 0
  fi
  
  format-echo "INFO" "Updating SSH config: $config_file"
  
  # Ensure the config file exists
  touch "$config_file"
  
  # For each server, add or update a Host entry
  for server in "${REMOTE_SERVERS[@]}"; do
    # Extract hostname from server (user@hostname)
    local hostname
    hostname=$(echo "$server" | cut -d@ -f2)
    
    # Check if the host is already in the config
    if grep -q "Host $hostname" "$config_file"; then
      format-echo "INFO" "Host $hostname already exists in config, skipping"
      continue
    fi
    
    # Add a new host entry
    format-echo "INFO" "Adding $hostname to SSH config"
    
    cat >> "$config_file" << EOF

Host $hostname
    HostName $hostname
    User $(echo "$server" | cut -d@ -f1)
    IdentityFile $ssh_dir/$KEY_NAME
    IdentitiesOnly yes
EOF
  done
  
  # Set secure permissions
  if [[ "$SECURE_PERMS" == "true" ]]; then
    chmod 600 "$config_file"
    chown "$USERNAME:$(id -gn "$USERNAME" 2>/dev/null || echo "$USERNAME")" "$config_file"
  fi
  
  format-echo "SUCCESS" "SSH config updated"
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
  
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  print_with_separator "Advanced SSH Key Manager Script"
  format-echo "INFO" "Starting SSH Key Manager..."
  
  # Display configuration
  if [[ "$VERBOSE" == "true" ]]; then
    format-echo "INFO" "Configuration:"
    format-echo "INFO" "  Username: $USERNAME"
    format-echo "INFO" "  Key Type: $KEY_TYPE"
    if [[ "$KEY_TYPE" == "rsa" ]]; then
      format-echo "INFO" "  Key Bits: $KEY_BITS"
    fi
    format-echo "INFO" "  Key Name: $KEY_NAME"
    if [[ -n "$KEY_COMMENT" ]]; then
      format-echo "INFO" "  Key Comment: $KEY_COMMENT"
    fi
    format-echo "INFO" "  Remote Servers: ${REMOTE_SERVERS[*]:-None}"
    format-echo "INFO" "  Distribute Keys: $DISTRIBUTE"
    format-echo "INFO" "  Backup Existing Keys: $BACKUP"
    format-echo "INFO" "  Rotate Keys: $ROTATE_KEYS"
    format-echo "INFO" "  GitHub Upload: $GITHUB_UPLOAD"
    format-echo "INFO" "  GitLab Upload: $GITLAB_UPLOAD"
    format-echo "INFO" "  Bitbucket Upload: $BITBUCKET_UPLOAD"
  fi
  
  # Validate the username
  if ! id "$USERNAME" &>/dev/null; then
    format-echo "ERROR" "User $USERNAME does not exist."
    exit 1
  fi
  
  # Get and ensure SSH directory
  SSH_DIR=$(get_ssh_dir)
  ensure_ssh_dir "$SSH_DIR"
  
  if [[ "$VERBOSE" == "true" ]]; then
    format-echo "INFO" "Using SSH directory: $SSH_DIR"
  fi
  
  #---------------------------------------------------------------------
  # KEY OPERATIONS
  #---------------------------------------------------------------------
  # Determine key path
  KEY_PATH="$SSH_DIR/$KEY_NAME"
  
  # Perform key rotation if requested
  if [[ "$ROTATE_KEYS" == "true" ]]; then
    rotate_ssh_keys "$SSH_DIR"
  else
    # Generate a new SSH key
    format-echo "INFO" "Generating SSH key for $USERNAME..."
    generate_ssh_key "$SSH_DIR"
  fi
  
  # Update SSH config
  update_ssh_config "$SSH_DIR"
  
  # Distribute the key to remote servers if requested
  if [[ "$DISTRIBUTE" == "true" ]]; then
    for server in "${REMOTE_SERVERS[@]}"; do
      distribute_ssh_key "$KEY_PATH" "$server"
    done
  fi
  
  # Upload to cloud services if requested
  if [[ "$GITHUB_UPLOAD" == "true" ]]; then
    upload_key_to_github "$KEY_PATH"
  fi
  
  if [[ "$GITLAB_UPLOAD" == "true" ]]; then
    upload_key_to_gitlab "$KEY_PATH"
  fi
  
  if [[ "$BITBUCKET_UPLOAD" == "true" ]]; then
    upload_key_to_bitbucket "$KEY_PATH"
  fi
  
  #---------------------------------------------------------------------
  # SUMMARY
  #---------------------------------------------------------------------
  print_with_separator "End of SSH Key Manager Script"
  format-echo "SUCCESS" "SSH key management completed for $USERNAME"
  
  # Display summary of what was done
  echo
  echo -e "\033[1;34mSummary:\033[0m"
  echo -e "  \033[1;32m✓\033[0m SSH key generated: $KEY_PATH"
  
  if [[ "$DISTRIBUTE" == "true" ]]; then
    echo -e "  \033[1;32m✓\033[0m Key distributed to ${#REMOTE_SERVERS[@]} server(s)"
  fi
  
  if [[ "$GITHUB_UPLOAD" == "true" ]]; then
    echo -e "  \033[1;32m✓\033[0m Key uploaded to GitHub"
  fi
  
  if [[ "$GITLAB_UPLOAD" == "true" ]]; then
    echo -e "  \033[1;32m✓\033[0m Key uploaded to GitLab"
  fi
  
  if [[ "$BITBUCKET_UPLOAD" == "true" ]]; then
    echo -e "  \033[1;32m✓\033[0m Key uploaded to Bitbucket"
  fi
  
  if [[ "$ROTATE_KEYS" == "true" ]]; then
    echo -e "  \033[1;32m✓\033[0m Key rotation completed"
  fi
  
  echo
  echo -e "\033[1;34mNext Steps:\033[0m"
  echo -e "  • Test your SSH connection: \033[1mssh -i $KEY_PATH <server>\033[0m"
  echo -e "  • Add more servers: \033[1m$0 --user $USERNAME --server <new_server>\033[0m"
  echo -e "  • Backup your SSH keys to a secure location"
}

main "$@"