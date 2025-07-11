#!/bin/bash
# user_access_auditor.sh
# Script to audit user access and log the results.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
SCRIPT_DIR=$(dirname "$(realpath "$0" 2>/dev/null || echo "$0")")
FORMAT_ECHO_FILE="$SCRIPT_DIR/../functions/format-echo/format-echo.sh"
UTILITY_FUNCTION_FILE="$SCRIPT_DIR/../functions/print-functions/print-with-separator.sh"
COMMON_FUNCTION_FILE="$SCRIPT_DIR/../functions/utility.sh"

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

if [ -f "$COMMON_FUNCTION_FILE" ]; then
  source "$COMMON_FUNCTION_FILE"
else
  echo -e "\033[1;31mError:\033[0m Utility file not found at $COMMON_FUNCTION_FILE"
  exit 1
fi

#=====================================================================
# DEFAULT VALUES
#=====================================================================
LOG_FILE="/dev/null"
OUTPUT_FORMAT="text" # Options: text, csv, json
INCLUDE_SUDO=true
INCLUDE_LOGIN_HISTORY=true
INCLUDE_GROUP_INFO=true
VERBOSE=false
# Detect if running on macOS
IS_MACOS=false
[[ "$OSTYPE" == "darwin"* ]] && IS_MACOS=true

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "User Access Auditor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script audits user access and logs the results."
  echo "  It provides details about system users, their permissions, and login history."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <log_file>\033[0m       (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--format <format>\033[0m      (Optional) Output format: text, csv, json (default: text)"
  echo -e "  \033[1;33m--no-sudo\033[0m              (Optional) Skip sudo access information"
  echo -e "  \033[1;33m--no-login-history\033[0m     (Optional) Skip login history information"
  echo -e "  \033[1;33m--no-group-info\033[0m        (Optional) Skip group membership information"
  echo -e "  \033[1;33m--verbose\033[0m              (Optional) Show more detailed information"
  echo -e "  \033[1;33m--help\033[0m                 (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log custom_user_access.log"
  echo "  $0 --format json --no-login-history"
  echo "  $0 --verbose"
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
      --log)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No log file provided after --log."
          usage
        fi
        LOG_FILE="$2"
        shift 2
        ;;
      --format)
        if [ -z "${2:-}" ] || ! [[ "$2" =~ ^(text|csv|json)$ ]]; then
          format-echo "ERROR" "Invalid format: $2. Must be one of: text, csv, json"
          usage
        fi
        OUTPUT_FORMAT="$2"
        shift 2
        ;;
      --no-sudo)
        INCLUDE_SUDO=false
        shift
        ;;
      --no-login-history)
        INCLUDE_LOGIN_HISTORY=false
        shift
        ;;
      --no-group-info)
        INCLUDE_GROUP_INFO=false
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
# Function to create a horizontal separator line
create_separator() {
  echo "----------------------------------------------------------------------------------------"
}

# Function to create a table separator with specific column widths
create_table_separator() {
  local widths=("$@")
  local separator="+"
  
  for width in "${widths[@]}"; do
    separator+="$(printf '%0.s-' $(seq 1 $((width+2))))"
    separator+="+"
  done
  
  echo "$separator"
}

# Function to print a table row with specific column widths
print_table_row() {
  local values=("$@")
  local num_cols=${#values[@]}
  local half=$((num_cols/2))
  local row="| "
  
  for ((i=0; i<half; i++)); do
    local width=${values[$((i+half))]}
    local content=${values[$i]}
    row+="$(printf "%-${width}s" "$content") | "
  done
  
  echo "$row"
}

#=====================================================================
# AUDIT FUNCTIONS
#=====================================================================
# Function to get basic user information
get_user_info() {
  format-echo "INFO" "Gathering system users information..."
  
  echo
  echo "User Account Information"
  create_separator
  
  # Define user source based on OS
  local users_file="/etc/passwd"
  if [[ "$IS_MACOS" == "true" ]]; then
    # On macOS, we can use dscl for more accurate results
    if command_exists dscl; then
      echo "Using Directory Service on macOS"
      get_macos_user_info
      return 0
    fi
  fi
  
  # Fallback to passwd file
  if [[ ! -f "$users_file" ]]; then
    format-echo "ERROR" "Cannot access $users_file"
    return 1
  fi
  
  # Define column widths
  local col_username=15
  local col_uid=7
  local col_gid=7
  local col_home=25
  local col_shell=20
  local col_type=10
  local widths=($col_username $col_uid $col_gid $col_home $col_shell $col_type)
  
  case "$OUTPUT_FORMAT" in
    text)
      # Print table header
      create_table_separator "${widths[@]}"
      print_table_row "Username" "UID" "GID" "Home Directory" "Shell" "Type" \
                     $col_username $col_uid $col_gid $col_home $col_shell $col_type
      create_table_separator "${widths[@]}"
      ;;
    csv)
      echo "Username,UID,GID,Home Directory,Shell,Account Type"
      ;;
    json)
      echo "{"
      echo "  \"users\": ["
      ;;
  esac
  
  local first_user=true
  while IFS=: read -r username password uid gid description home_dir shell; do
    # Skip comment lines
    [[ "$username" =~ ^#.*$ ]] && continue
    
    # Skip system users with UID < 1000 unless verbose mode is enabled
    if [[ "$uid" -lt 1000 && "$VERBOSE" == "false" ]]; then
      continue
    fi
    
    # Determine account type
    local account_type="Regular"
    if [[ "$uid" -eq 0 ]]; then
      account_type="Root"
    elif [[ "$uid" -lt 1000 ]]; then
      account_type="System"
    elif [[ "$shell" == "/usr/sbin/nologin" || "$shell" == "/bin/false" ]]; then
      account_type="Service"
    fi
    
    # Truncate long values for better display
    if [[ ${#username} -gt $col_username ]]; then
      username="${username:0:$((col_username-3))}..."
    fi
    
    if [[ ${#home_dir} -gt $col_home ]]; then
      home_dir="${home_dir:0:$((col_home-3))}..."
    fi
    
    if [[ ${#shell} -gt $col_shell ]]; then
      shell="${shell:0:$((col_shell-3))}..."
    fi
    
    case "$OUTPUT_FORMAT" in
      text)
        print_table_row "$username" "$uid" "$gid" "$home_dir" "$shell" "$account_type" \
                       $col_username $col_uid $col_gid $col_home $col_shell $col_type
        ;;
      csv)
        echo "\"$username\",\"$uid\",\"$gid\",\"$home_dir\",\"$shell\",\"$account_type\""
        ;;
      json)
        if [[ "$first_user" == "true" ]]; then
          first_user=false
        else
          echo ","
        fi
        echo "    {"
        echo "      \"username\": \"$username\","
        echo "      \"uid\": \"$uid\","
        echo "      \"gid\": \"$gid\","
        echo "      \"home_directory\": \"$home_dir\","
        echo "      \"shell\": \"$shell\","
        echo "      \"account_type\": \"$account_type\""
        echo -n "    }"
        ;;
    esac
  done < "$users_file"
  
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    create_table_separator "${widths[@]}"
  elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo ""
    echo "  ]"
  fi
}

# Function to get macOS user information using dscl
get_macos_user_info() {
  # Define column widths
  local col_username=15
  local col_uid=7
  local col_gid=7
  local col_home=25
  local col_shell=20
  local col_type=10
  local widths=($col_username $col_uid $col_gid $col_home $col_shell $col_type)
  
  case "$OUTPUT_FORMAT" in
    text)
      # Print table header
      create_table_separator "${widths[@]}"
      print_table_row "Username" "UID" "GID" "Home Directory" "Shell" "Type" \
                     $col_username $col_uid $col_gid $col_home $col_shell $col_type
      create_table_separator "${widths[@]}"
      ;;
    csv)
      echo "Username,UID,GID,Home Directory,Shell,Account Type"
      ;;
    json)
      echo "{"
      echo "  \"users\": ["
      ;;
  esac
  
  local first_user=true
  local userlist=$(dscl . -list /Users | grep -v "^#")
  
  if [[ "$VERBOSE" == "false" ]]; then
    # Filter out system users unless in verbose mode
    userlist=$(echo "$userlist" | grep -v "^_")
  fi
  
  for username in $userlist; do
    # Skip comment lines
    [[ "$username" =~ ^#.*$ ]] && continue
    
    local uid=$(dscl . -read /Users/"$username" UniqueID 2>/dev/null | awk '{print $2}')
    local gid=$(dscl . -read /Users/"$username" PrimaryGroupID 2>/dev/null | awk '{print $2}')
    local home_dir=$(dscl . -read /Users/"$username" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    local shell=$(dscl . -read /Users/"$username" UserShell 2>/dev/null | awk '{print $2}')
    
    # Set defaults if values are empty
    [[ -z "$uid" ]] && uid="N/A"
    [[ -z "$gid" ]] && gid="N/A"
    [[ -z "$home_dir" ]] && home_dir="N/A"
    [[ -z "$shell" ]] && shell="N/A"
    
    # Determine account type
    local account_type="Regular"
    if [[ "$username" == "root" ]]; then
      account_type="Root"
    elif [[ "$username" == *"_"* || "$uid" -lt 500 ]]; then
      account_type="System"
    elif [[ "$shell" == "/usr/bin/false" ]]; then
      account_type="Service"
    fi
    
    # Truncate long values for better display
    if [[ ${#username} -gt $col_username ]]; then
      username="${username:0:$((col_username-3))}..."
    fi
    
    if [[ ${#home_dir} -gt $col_home ]]; then
      home_dir="${home_dir:0:$((col_home-3))}..."
    fi
    
    if [[ ${#shell} -gt $col_shell ]]; then
      shell="${shell:0:$((col_shell-3))}..."
    fi
    
    case "$OUTPUT_FORMAT" in
      text)
        print_table_row "$username" "$uid" "$gid" "$home_dir" "$shell" "$account_type" \
                       $col_username $col_uid $col_gid $col_home $col_shell $col_type
        ;;
      csv)
        echo "\"$username\",\"$uid\",\"$gid\",\"$home_dir\",\"$shell\",\"$account_type\""
        ;;
      json)
        if [[ "$first_user" == "true" ]]; then
          first_user=false
        else
          echo ","
        fi
        echo "    {"
        echo "      \"username\": \"$username\","
        echo "      \"uid\": \"$uid\","
        echo "      \"gid\": \"$gid\","
        echo "      \"home_directory\": \"$home_dir\","
        echo "      \"shell\": \"$shell\","
        echo "      \"account_type\": \"$account_type\""
        echo -n "    }"
        ;;
    esac
  done
  
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    create_table_separator "${widths[@]}"
  elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo ""
    echo "  ]"
  fi
}

# Function to get sudo access information
get_sudo_info() {
  if [[ "$INCLUDE_SUDO" == "false" ]]; then
    return 0
  fi
  
  format-echo "INFO" "Checking sudo access information..."
  
  echo
  echo "Sudo Access Information"
  create_separator
  
  if ! command_exists sudo; then
    format-echo "WARNING" "sudo command not found, skipping sudo access check"
    return 0
  fi
  
  # Define column widths for sudo entities table
  local col_entity=30
  local col_type=25
  local widths=($col_entity $col_type)
  
  case "$OUTPUT_FORMAT" in
    text)
      # Print table header
      create_table_separator "${widths[@]}"
      print_table_row "Entity" "Type" $col_entity $col_type
      create_table_separator "${widths[@]}"
      ;;
    csv)
      echo "Entity,Type"
      ;;
    json)
      echo ",\"sudo\": {"
      echo "    \"entities\": ["
      ;;
  esac
  
  # Simplified approach for macOS - just show admin group and current user
  if [[ "$IS_MACOS" == "true" ]]; then
    # Get current user
    local current_user=$(whoami)
    
    # First output the admin group
    case "$OUTPUT_FORMAT" in
      text)
        print_table_row "admin" "Group with sudo access" $col_entity $col_type
        # Also show current user if likely to have sudo (based on id command)
        if id | grep -q "admin"; then
          print_table_row "$current_user" "User with sudo access" $col_entity $col_type
        fi
        # Add root user only if current user is not already root
        if [[ "$current_user" != "root" ]]; then
          print_table_row "root" "User with sudo access" $col_entity $col_type
        fi
        ;;
      csv)
        echo "\"admin\",\"Group with sudo access\""
        if id | grep -q "admin"; then
          echo "\"$current_user\",\"User with sudo access\""
        fi
        if [[ "$current_user" != "root" ]]; then
          echo "\"root\",\"User with sudo access\""
        fi
        ;;
      json)
        local entries=0
        echo "      {"
        echo "        \"name\": \"admin\","
        echo "        \"type\": \"Group with sudo access\""
        echo "      }"
        entries=$((entries+1))
        
        if id | grep -q "admin"; then
          echo ","
          echo "      {"
          echo "        \"name\": \"$current_user\","
          echo "        \"type\": \"User with sudo access\""
          echo "      }"
          entries=$((entries+1))
        fi
        
        if [[ "$current_user" != "root" ]]; then
          echo ","
          echo "      {"
          echo "        \"name\": \"root\","
          echo "        \"type\": \"User with sudo access\""
          echo "      }"
        fi
        ;;
    esac
  else
    # For Linux systems, just check for wheel group
    if grep -q "^wheel:" /etc/group 2>/dev/null; then
      case "$OUTPUT_FORMAT" in
        text)
          print_table_row "wheel" "Group with sudo access" $col_entity $col_type
          ;;
        csv)
          echo "\"wheel\",\"Group with sudo access\""
          ;;
        json)
          echo "      {"
          echo "        \"name\": \"wheel\","
          echo "        \"type\": \"Group with sudo access\""
          echo "      }"
          ;;
      esac
    else
      # No obvious sudo groups found
      case "$OUTPUT_FORMAT" in
        text)
          print_table_row "None found" "No sudo access detected" $col_entity $col_type
          ;;
        csv)
          echo "\"None found\",\"No sudo access detected\""
          ;;
        json)
          echo "      {"
          echo "        \"name\": \"None found\","
          echo "        \"type\": \"No sudo access detected\""
          echo "      }"
          ;;
      esac
    fi
  fi
  
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    create_table_separator "${widths[@]}"
  elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo ""
    echo "    ]"
    echo "  }"
  fi
}

# Function to get login history
get_login_history() {
  if [[ "$INCLUDE_LOGIN_HISTORY" == "false" ]]; then
    return 0
  fi
  
  format-echo "INFO" "Checking login history..."
  
  echo
  echo "Login History Information"
  create_separator
  
  if ! command_exists last; then
    format-echo "WARNING" "last command not found, skipping login history check"
    return 0
  fi
  
  # Define column widths for login history table
  local col_user=15
  local col_terminal=15
  local col_from=15
  local col_logintime=25
  local col_status=15
  local widths=($col_user $col_terminal $col_from $col_logintime $col_status)
  
  case "$OUTPUT_FORMAT" in
    text)
      # Print table header
      create_table_separator "${widths[@]}"
      print_table_row "Username" "Terminal" "From" "Login Time" "Status" \
                     $col_user $col_terminal $col_from $col_logintime $col_status
      create_table_separator "${widths[@]}"
      ;;
    csv)
      echo "Username,Terminal,From,Login Time,Status,Duration"
      ;;
    json)
      echo ",\"login_history\": ["
      ;;
  esac
  
  # Get recent login history (last 10 entries)
  local login_entries=()
  local entry_count=0
  
  while read -r line && [[ $entry_count -lt 10 ]]; do
    # Skip empty lines and wtmp entries
    [[ -z "$line" || "$line" == wtmp* ]] && continue
    
    # Handle reboot entries
    if [[ "$line" == reboot* ]]; then
      local reboot_time=$(echo "$line" | awk '{print $3, $4, $5, $6, $7, $8}')
      
      # Truncate values if necessary
      [[ ${#reboot_time} -gt $col_logintime ]] && reboot_time="${reboot_time:0:$((col_logintime-3))}..."
      
      case "$OUTPUT_FORMAT" in
        text)
          login_entries+=("$(print_table_row "SYSTEM" "console" "local" "$reboot_time" "reboot" \
                         $col_user $col_terminal $col_from $col_logintime $col_status)")
          ;;
        csv)
          login_entries+=("\"SYSTEM\",\"console\",\"local\",\"$reboot_time\",\"reboot\",\"\"")
          ;;
        json)
          local json_entry="    {\n      \"username\": \"SYSTEM\",\n      \"terminal\": \"console\",\n"
          json_entry+="      \"from\": \"local\",\n      \"login_time\": \"$reboot_time\",\n"
          json_entry+="      \"status\": \"reboot\",\n      \"duration\": \"\"\n    }"
          login_entries+=("$json_entry")
          ;;
      esac
    else
      # Regular login entries
      local username=$(echo "$line" | awk '{print $1}')
      local terminal=$(echo "$line" | awk '{print $2}')
      local from="local"
      if [[ "$line" == *"from "* ]]; then
        from=$(echo "$line" | grep -o "from [^ ]*" | cut -d' ' -f2)
      fi
      local login_time=$(echo "$line" | awk '{print $3, $4, $5, $6, $7, $8}')
      local status="logged out"
      local duration=""
      
      if [[ "$line" == *"still logged in"* ]]; then
        status="still logged in"
      elif [[ "$line" == *"crash"* ]]; then
        status="crash"
        duration=$(echo "$line" | grep -o "([0-9+:]*)" | sed 's/[()]//g')
      else
        duration=$(echo "$line" | grep -o "([0-9+:]*)" | sed 's/[()]//g')
      fi
      
      # Truncate values if necessary
      [[ ${#username} -gt $col_user ]] && username="${username:0:$((col_user-3))}..."
      [[ ${#terminal} -gt $col_terminal ]] && terminal="${terminal:0:$((col_terminal-3))}..."
      [[ ${#from} -gt $col_from ]] && from="${from:0:$((col_from-3))}..."
      [[ ${#login_time} -gt $col_logintime ]] && login_time="${login_time:0:$((col_logintime-3))}..."
      
      case "$OUTPUT_FORMAT" in
        text)
          login_entries+=("$(print_table_row "$username" "$terminal" "$from" "$login_time" "$status" \
                         $col_user $col_terminal $col_from $col_logintime $col_status)")
          ;;
        csv)
          login_entries+=("\"$username\",\"$terminal\",\"$from\",\"$login_time\",\"$status\",\"$duration\"")
          ;;
        json)
          local json_entry="    {\n      \"username\": \"$username\",\n      \"terminal\": \"$terminal\",\n"
          json_entry+="      \"from\": \"$from\",\n      \"login_time\": \"$login_time\",\n"
          json_entry+="      \"status\": \"$status\",\n      \"duration\": \"$duration\"\n    }"
          login_entries+=("$json_entry")
          ;;
      esac
    fi
    
    entry_count=$((entry_count+1))
  done < <(last 2>/dev/null)
  
  # Output the entries
  if [[ $entry_count -eq 0 ]]; then
    case "$OUTPUT_FORMAT" in
      text)
        print_table_row "No entries" "No login history found" "N/A" "N/A" "N/A" \
                       $col_user $col_terminal $col_from $col_logintime $col_status
        ;;
      csv)
        echo "\"No entries\",\"N/A\",\"N/A\",\"No login history found\",\"N/A\",\"N/A\""
        ;;
      json)
        echo "    {"
        echo "      \"username\": \"No entries\","
        echo "      \"terminal\": \"N/A\","
        echo "      \"from\": \"N/A\","
        echo "      \"login_time\": \"No login history found\","
        echo "      \"status\": \"N/A\","
        echo "      \"duration\": \"N/A\""
        echo "    }"
        ;;
    esac
  else
    for ((i=0; i<entry_count; i++)); do
      if [[ "$OUTPUT_FORMAT" == "json" && $i -gt 0 ]]; then
        echo ","
      fi
      echo -e "${login_entries[$i]}"
    done
  fi
  
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    create_table_separator "${widths[@]}"
  elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo ""
    echo "  ]"
  fi
}

# Function to get group membership information
get_group_info() {
  if [[ "$INCLUDE_GROUP_INFO" == "false" ]]; then
    return 0
  fi
  
  format-echo "INFO" "Checking group membership information..."
  
  echo
  echo "Group Membership Information"
  create_separator
  
  # Use dscl on macOS for more accurate results
  if [[ "$IS_MACOS" == "true" && $(command_exists dscl) ]]; then
    get_macos_group_info
    return 0
  fi
  
  # Define column widths for group table
  local col_group=20
  local col_gid=8
  local col_members=50
  local widths=($col_group $col_gid $col_members)
  
  case "$OUTPUT_FORMAT" in
    text)
      # Print table header
      create_table_separator "${widths[@]}"
      print_table_row "Group Name" "GID" "Members" $col_group $col_gid $col_members
      create_table_separator "${widths[@]}"
      ;;
    csv)
      echo "Group,GID,Members"
      ;;
    json)
      echo ",\"groups\": ["
      ;;
  esac
  
  local first_group=true
  
  # Fallback to reading /etc/group directly
  while IFS=: read -r groupname password gid members; do
    # Skip comment lines
    [[ "$groupname" =~ ^#.*$ ]] && continue
    
    # Skip empty groups or system groups with no members unless verbose mode is enabled
    if [[ -z "$members" && "$VERBOSE" == "false" ]]; then
      continue
    fi
    
    # Truncate long values
    if [[ ${#groupname} -gt $col_group ]]; then
      groupname="${groupname:0:$((col_group-3))}..."
    fi
    
    if [[ ${#members} -gt $col_members ]]; then
      members="${members:0:$((col_members-3))}..."
    fi
    
    case "$OUTPUT_FORMAT" in
      text)
        print_table_row "$groupname" "$gid" "$members" $col_group $col_gid $col_members
        ;;
      csv)
        echo "\"$groupname\",\"$gid\",\"$members\""
        ;;
      json)
        if [[ "$first_group" == "true" ]]; then
          first_group=false
        else
          echo ","
        fi
        echo "    {"
        echo "      \"name\": \"$groupname\","
        echo "      \"gid\": \"$gid\","
        echo "      \"members\": \"$members\""
        echo -n "    }"
        ;;
    esac
  done < /etc/group
  
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    create_table_separator "${widths[@]}"
  elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo ""
    echo "  ]"
  fi
}

# Function to get macOS group information using dscl
get_macos_group_info() {
  # Define column widths for group table
  local col_group=20
  local col_gid=8
  local col_members=50
  local widths=($col_group $col_gid $col_members)
  
  case "$OUTPUT_FORMAT" in
    text)
      # Print table header
      create_table_separator "${widths[@]}"
      print_table_row "Group Name" "GID" "Members" $col_group $col_gid $col_members
      create_table_separator "${widths[@]}"
      ;;
    csv)
      echo "Group,GID,Members"
      ;;
    json)
      echo ",\"groups\": ["
      ;;
  esac
  
  local first_group=true
  local grouplist=$(dscl . -list /Groups | grep -v "^#")
  
  if [[ "$VERBOSE" == "false" ]]; then
    # Filter out system groups in non-verbose mode
    grouplist=$(echo "$grouplist" | grep -v "^_")
  fi
  
  for groupname in $grouplist; do
    # Skip comment lines
    [[ "$groupname" =~ ^#.*$ ]] && continue
    
    local gid=$(dscl . -read /Groups/"$groupname" PrimaryGroupID 2>/dev/null | awk '{print $2}')
    local members_raw=$(dscl . -read /Groups/"$groupname" GroupMembership 2>/dev/null | sed 's/GroupMembership: //')
    
    # Skip if we couldn't get a GID
    [[ -z "$gid" ]] && continue
    
    # Skip empty groups unless verbose mode is enabled
    if [[ -z "$members_raw" && "$VERBOSE" == "false" ]]; then
      continue
    fi
    
    # Format members list
    local members=""
    for member in $members_raw; do
      if [[ "$member" != "GroupMembership:" ]]; then
        [[ -n "$members" ]] && members="$members,"
        members="$members$member"
      fi
    done
    
    # Truncate long values
    if [[ ${#groupname} -gt $col_group ]]; then
      groupname="${groupname:0:$((col_group-3))}..."
    fi
    
    if [[ ${#members} -gt $col_members ]]; then
      members="${members:0:$((col_members-3))}..."
    fi
    
    case "$OUTPUT_FORMAT" in
      text)
        print_table_row "$groupname" "$gid" "$members" $col_group $col_gid $col_members
        ;;
      csv)
        echo "\"$groupname\",\"$gid\",\"$members\""
        ;;
      json)
        if [[ "$first_group" == "true" ]]; then
          first_group=false
        else
          echo ","
        fi
        echo "    {"
        echo "      \"name\": \"$groupname\","
        echo "      \"gid\": \"$gid\","
        echo "      \"members\": \"$members\""
        echo -n "    }"
        ;;
    esac
  done
  
  if [[ "$OUTPUT_FORMAT" == "text" ]]; then
    create_table_separator "${widths[@]}"
  elif [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo ""
    echo "  ]"
  fi
}

# Main audit function that combines all checks
audit_user_access() {
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "{"
    echo "  \"audit_timestamp\": \"$(date +'%Y-%m-%d %H:%M:%S')\","
    echo "  \"hostname\": \"$(hostname)\","
    echo "  \"platform\": \"$(uname -s)\","
  fi
  
  # Get basic user information
  get_user_info
  
  # Get sudo access information
  get_sudo_info
  
  # Get login history
  get_login_history
  
  # Get group membership information
  get_group_info
  
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    echo "}"
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
  
  # Configure log file
  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    if ! touch "$LOG_FILE" 2>/dev/null; then
      echo -e "\033[1;31mError:\033[0m Cannot write to log file $LOG_FILE."
      exit 1
    fi
    exec > >(tee -a "$LOG_FILE") 2>&1
  fi
  
  print_with_separator "User Access Auditor Script"
  format-echo "INFO" "Starting User Access Auditor Script..."
  
  # Display platform information if verbose
  if [[ "$VERBOSE" == "true" ]]; then
    if [[ "$IS_MACOS" == "true" ]]; then
      format-echo "INFO" "Detected macOS platform: $(sw_vers -productVersion)"
    else
      format-echo "INFO" "Detected platform: $(uname -s) $(uname -r)"
    fi
  fi
  
  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check for required permissions
  if [[ "$(id -u)" -ne 0 && "$INCLUDE_SUDO" == "true" ]]; then
    format-echo "WARNING" "Script not running as root. Sudo information may be incomplete."
  fi
  
  #---------------------------------------------------------------------
  # EXECUTION
  #---------------------------------------------------------------------
  if audit_user_access; then
    format-echo "SUCCESS" "User access audit completed successfully."
  else
    format-echo "ERROR" "Failed to audit user access."
    print_with_separator "End of User Access Auditor Script"
    exit 1
  fi
  
  #---------------------------------------------------------------------
  # COMPLETION
  #---------------------------------------------------------------------
  print_with_separator "End of User Access Auditor Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
