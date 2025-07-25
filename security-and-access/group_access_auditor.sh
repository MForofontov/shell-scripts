#!/bin/bash
# group_access_auditor.sh
# Script to audit groups and user memberships on the system.

set -euo pipefail

#=====================================================================
# CONFIGURATION AND DEPENDENCIES
#=====================================================================
source "$(dirname "$0")/../functions/common-init.sh"
# DEFAULT VALUES
#=====================================================================
# shellcheck disable=SC2034
LOG_FILE="/dev/null"
OUTPUT_FORMAT="text"  # Options: text, csv, json
OUTPUT_FILE=""
FILTER_GROUP=""
FILTER_USER=""
SORT_BY="group"  # Options: group, members, gid
REVERSE_SORT=false
SHOW_SYSTEM_GROUPS=true
SHOW_EMPTY_GROUPS=true
SHOW_STATISTICS=false
SHOW_SUDO_INFO=false
FIND_USER=""

#=====================================================================
# USAGE AND HELP
#=====================================================================
usage() {
  print_with_separator "Group Access Auditor Script"
  echo -e "\033[1;34mDescription:\033[0m"
  echo "  This script audits groups and user memberships on the system."
  echo
  echo -e "\033[1;34mUsage:\033[0m"
  echo "  $0 [options]"
  echo
  echo -e "\033[1;34mOptions:\033[0m"
  echo -e "  \033[1;33m--log <file>\033[0m             (Optional) Path to save the log messages."
  echo -e "  \033[1;33m--output <file>\033[0m          (Optional) Save audit results to a file."
  echo -e "  \033[1;33m--format <format>\033[0m        (Optional) Output format: text, csv, json (default: text)."
  echo -e "  \033[1;33m--group <group>\033[0m          (Optional) Filter results to show only specified group."
  echo -e "  \033[1;33m--user <user>\033[0m            (Optional) Filter results to show only groups containing user."
  echo -e "  \033[1;33m--find-user <user>\033[0m       (Optional) Search for a specific user across all groups."
  echo -e "  \033[1;33m--sort-by <field>\033[0m        (Optional) Sort by: group, members, gid (default: group)."
  echo -e "  \033[1;33m--reverse\033[0m                (Optional) Reverse the sort order."
  echo -e "  \033[1;33m--no-system-groups\033[0m       (Optional) Hide system groups (GID < 1000)."
  echo -e "  \033[1;33m--no-empty-groups\033[0m        (Optional) Hide groups with no members."
  echo -e "  \033[1;33m--statistics\033[0m             (Optional) Show statistics about group membership."
  echo -e "  \033[1;33m--sudo-info\033[0m              (Optional) Show sudo access information for groups."
  echo -e "  \033[1;33m--help\033[0m                   (Optional) Display this help message."
  echo
  echo -e "\033[1;34mExamples:\033[0m"
  echo "  $0 --log audit.log --output groups.csv --format csv"
  echo "  $0 --group admin --sudo-info"
  echo "  $0 --user johndoe --statistics"
  echo "  $0 --find-user johndoe"
  echo "  $0 --no-system-groups --no-empty-groups --sort-by members --reverse"
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
      --output)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No output file provided after --output."
          usage
        fi
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --format)
        if [ -z "${2:-}" ] || ! [[ "${2,,}" =~ ^(text|csv|json)$ ]]; then
          format-echo "ERROR" "Invalid format. Must be one of: text, csv, json."
          usage
        fi
        OUTPUT_FORMAT="${2,,}"
        shift 2
        ;;
      --group)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No group name provided after --group."
          usage
        fi
        FILTER_GROUP="$2"
        shift 2
        ;;
      --user)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No username provided after --user."
          usage
        fi
        FILTER_USER="$2"
        shift 2
        ;;
      --find-user)
        if [ -z "${2:-}" ]; then
          format-echo "ERROR" "No username provided after --find-user."
          usage
        fi
        FIND_USER="$2"
        shift 2
        ;;
      --sort-by)
        if [ -z "${2:-}" ] || ! [[ "${2,,}" =~ ^(group|members|gid)$ ]]; then
          format-echo "ERROR" "Invalid sort field. Must be one of: group, members, gid."
          usage
        fi
        SORT_BY="${2,,}"
        shift 2
        ;;
      --reverse)
        REVERSE_SORT=true
        shift
        ;;
      --no-system-groups)
        SHOW_SYSTEM_GROUPS=false
        shift
        ;;
      --no-empty-groups)
        SHOW_EMPTY_GROUPS=false
        shift
        ;;
      --statistics)
        SHOW_STATISTICS=true
        shift
        ;;
      --sudo-info)
        SHOW_SUDO_INFO=true
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
# GROUP AUDITING FUNCTIONS
#=====================================================================
# Generate a list of groups with their members
get_groups_and_members() {
  # Use mktemp to create a secure temporary file
  local temp_file
  temp_file=$(mktemp) || {
    format-echo "ERROR" "Failed to create temporary file"
    return 1
  }
  
  # Add to global array for cleanup
  TEMP_FILES+=("$temp_file")
  
  format-echo "INFO" "Collecting group information..."
  
  # Process group information
  while IFS=: read -r group_name password gid members; do
    # Apply system group filter if needed
    if [[ "$SHOW_SYSTEM_GROUPS" == "false" && "$gid" -lt 1000 ]]; then
      continue
    fi
    
    # Apply empty group filter if needed
    if [[ "$SHOW_EMPTY_GROUPS" == "false" && -z "$members" ]]; then
      continue
    fi
    
    # Apply group filter if specified
    if [[ -n "$FILTER_GROUP" && "$group_name" != "$FILTER_GROUP" ]]; then
      continue
    fi
    
    # Apply user filter if specified
    if [[ -n "$FILTER_USER" ]]; then
      if ! echo ",$members," | grep -q ",$FILTER_USER,"; then
        continue
      fi
    fi
    
    # Store group information
    echo "$group_name:$gid:$members" >> "$temp_file"
  done < /etc/group
  
  # Check if we got any data
  if [ ! -s "$temp_file" ]; then
    format-echo "WARNING" "No matching groups found with current filters."
    echo "NO_GROUPS:0:No matching groups" > "$temp_file"
  fi
  
  # For member count sorting, process with awk
  if [[ "$SORT_BY" == "members" ]]; then
    local count_file
    count_file=$(mktemp) || {
      format-echo "ERROR" "Failed to create temporary count file"
      return 1
    }
    TEMP_FILES+=("$count_file")
    
    awk -F: '{
      n = split($3, arr, ",");
      if ($3 == "") { count = 0; } else { count = n; }
      print $1 ":" $2 ":" $3 ":" count;
    }' "$temp_file" > "$count_file"
    
    # Replace original file with count file
    cat "$count_file" > "$temp_file"
  else
    # Add dummy count field for consistency
    sed -i.bak 's/$/&:0/' "$temp_file"
    rm -f "${temp_file}.bak"
  fi
  
  # Sort the results
  local sort_field=1  # Default to sort by group name
  case "$SORT_BY" in
    group) sort_field=1 ;;
    gid) sort_field=2 ;;
    members) sort_field=4 ;;
  esac
  
  # Create sorted file
  local sorted_file
  sorted_file=$(mktemp) || {
    format-echo "ERROR" "Failed to create temporary sorted file"
    return 1
  }
  TEMP_FILES+=("$sorted_file")
  
  if [[ "$REVERSE_SORT" == "true" ]]; then
    sort -t: -k"$sort_field" -r "$temp_file" > "$sorted_file"
  else
    sort -t: -k"$sort_field" "$temp_file" > "$sorted_file"
  fi
  
  # Replace original file with sorted file
  cat "$sorted_file" > "$temp_file"
  
  format-echo "INFO" "Group data collected and processed successfully."
  
  # Return the filename
  echo "$temp_file"
}

# Check if a group has sudo privileges
check_sudo_access() {
  local group_name="$1"
  
  # Check for direct sudo access in sudoers file
  if sudo -l 2>/dev/null | grep -q "%$group_name"; then
    echo "Yes"
    return
  fi
  
  # Check if the group is mentioned in sudoers.d directory
  if grep -q "%$group_name" /etc/sudoers.d/* 2>/dev/null; then
    echo "Yes"
    return
  fi
  
  # Check if the group is an admin group
  if [[ "$group_name" == "sudo" || "$group_name" == "wheel" || "$group_name" == "admin" ]]; then
    echo "Yes (Admin Group)"
    return
  fi
  
  echo "No"
}

# Output results in specified format
output_results() {
  local groups_file="$1"
  local output_dest="${2:-}"  # Can be empty for stdout
  
  # Verify file exists and has content
  if [ ! -f "$groups_file" ]; then
    format-echo "ERROR" "Group data file not found: $groups_file"
    return 1
  fi
  
  format-echo "INFO" "Generating audit report in $OUTPUT_FORMAT format..."
  
  case "$OUTPUT_FORMAT" in
    text)
      output_text_format "$groups_file" "$output_dest"
      ;;
    csv)
      output_csv_format "$groups_file" "$output_dest"
      ;;
    json)
      output_json_format "$groups_file" "$output_dest"
      ;;
  esac
  
  # Show statistics if requested
  if [[ "$SHOW_STATISTICS" == "true" ]]; then
    output_statistics "$groups_file" "$output_dest"
  fi
}

# Output in text format
output_text_format() {
  local groups_file="$1"
  local output_dest="${2:-}"
  
  # Verify file exists before using
  if [ ! -f "$groups_file" ]; then
    format-echo "ERROR" "Text format: Group data file not found: $groups_file"
    return 1
  fi
  
  # Start with a header
  {
    print_with_separator "Group Audit Report - $(date)"
    printf "%-20s %-10s %-6s %-40s" "GROUP NAME" "GID" "SUDO" "MEMBERS"
    echo
    echo "----------------------------------------------------------------------------------------------------"
    
    while IFS=: read -r group_name gid members member_count; do
      # Skip special marker for no groups
      if [ "$group_name" = "NO_GROUPS" ]; then
        echo "No matching groups found with current filters."
        continue
      fi
      
      local sudo_access="N/A"
      if [[ "$SHOW_SUDO_INFO" == "true" ]]; then
        sudo_access=$(check_sudo_access "$group_name")
      fi
      
      # Format members list for better readability
      if [[ -z "$members" ]]; then
        members="(none)"
      else
        # Replace commas with space-comma-space for better readability
        members=$(echo "$members" | sed 's/,/, /g')
      fi
      
      printf "%-20s %-10s %-6s %-40s\n" "$group_name" "$gid" "$sudo_access" "$members"
    done < "$groups_file"
    
    print_with_separator "End of Group Audit Report"
  } > "${output_dest:-/dev/stdout}"
}

# Output in CSV format
output_csv_format() {
  local groups_file="$1"
  local output_dest="${2:-}"
  
  # Verify file exists before using
  if [ ! -f "$groups_file" ]; then
    format-echo "ERROR" "CSV format: Group data file not found: $groups_file"
    return 1
  fi
  
  {
    # CSV header
    echo "Group Name,GID,Members,Member Count,Sudo Access"
    
    while IFS=: read -r group_name gid members member_count; do
      # Skip special marker for no groups
      if [ "$group_name" = "NO_GROUPS" ]; then
        echo "\"No matching groups\",\"0\",\"\",\"0\",\"N/A\""
        continue
      fi
      
      local sudo_access="N/A"
      if [[ "$SHOW_SUDO_INFO" == "true" ]]; then
        sudo_access=$(check_sudo_access "$group_name")
      fi
      
      # CSV needs proper escaping - wrap in quotes and escape existing quotes
      escaped_group_name=$(echo "$group_name" | sed 's/"/""/g')
      escaped_members=$(echo "$members" | sed 's/"/""/g')
      
      echo "\"$escaped_group_name\",\"$gid\",\"$escaped_members\",\"$member_count\",\"$sudo_access\""
    done < "$groups_file"
  } > "${output_dest:-/dev/stdout}"
}

# Output in JSON format
output_json_format() {
  local groups_file="$1"
  local output_dest="${2:-}"
  
  # Verify file exists before using
  if [ ! -f "$groups_file" ]; then
    format-echo "ERROR" "JSON format: Group data file not found: $groups_file"
    return 1
  fi
  
  {
    echo "{"
    echo "  \"report_date\": \"$(date)\","
    echo "  \"groups\": ["
    
    local first_line=true
    while IFS=: read -r group_name gid members member_count; do
      # Skip special marker for no groups
      if [ "$group_name" = "NO_GROUPS" ]; then
        echo "    { \"message\": \"No matching groups found with current filters.\" }"
        continue
      fi
      
      # Get sudo access if needed
      local sudo_access="N/A"
      if [[ "$SHOW_SUDO_INFO" == "true" ]]; then
        sudo_access=$(check_sudo_access "$group_name")
      fi
      
      # Split members string into an array
      local member_array="[]"
      if [[ -n "$members" ]]; then
        member_array="[\"$(echo "$members" | sed 's/,/","/g')\"]"
      fi
      
      # Add comma separator between entries (except for first)
      if [[ "$first_line" == "true" ]]; then
        first_line=false
      else
        echo ","
      fi
      
      # Output the group object
      echo -n "    {"
      echo -n "\"name\":\"$group_name\","
      echo -n "\"gid\":$gid,"
      echo -n "\"members\":$member_array,"
      echo -n "\"member_count\":$member_count"
      if [[ "$SHOW_SUDO_INFO" == "true" ]]; then
        echo -n ",\"sudo_access\":\"$sudo_access\""
      fi
      echo -n "}"
    done < "$groups_file"
    
    echo
    echo "  ]"
    echo "}"
  } > "${output_dest:-/dev/stdout}"
}

# Output statistics about group membership
output_statistics() {
  local groups_file="$1"
  local output_dest="${2:-}"
  
  # Verify file exists before using
  if [ ! -f "$groups_file" ]; then
    format-echo "ERROR" "Statistics: Group data file not found: $groups_file"
    return 1
  fi
  
  # Check if we have any meaningful data
  if grep -q "NO_GROUPS" "$groups_file"; then
    format-echo "WARNING" "No groups found, statistics unavailable."
    return 0
  fi
  
  {
    print_with_separator "Group Membership Statistics"
    
    # Total groups
    local total_groups=$(wc -l < "$groups_file")
    echo "Total Groups: $total_groups"
    
    # Empty groups
    local empty_groups=$(grep -c ':$' "$groups_file" || true)
    # Avoid division by zero
    if [ "$total_groups" -gt 0 ]; then
      local empty_percentage=$((empty_groups * 100 / total_groups))
      echo "Empty Groups: $empty_groups ($empty_percentage%)"
    else
      echo "Empty Groups: $empty_groups (0%)"
    fi
    
    # Users with most group memberships
    echo
    echo "Top 10 Users by Group Membership:"
    echo "--------------------------------"
    
    # Extract all members from all groups
    local users_output
    users_output=$(cut -d: -f3 < "$groups_file" | tr ',' '\n' | sort | uniq -c | sort -nr | head -10)
    if [ -n "$users_output" ]; then
      echo "$users_output" | awk '{printf "%-20s %s groups\n", $2, $1}'
    else
      echo "No user data available."
    fi
    
    # Groups with most members
    echo
    echo "Top 10 Groups by Membership Count:"
    echo "--------------------------------"
    
    # Use the pre-calculated member count (4th field)
    local groups_output
    groups_output=$(awk -F: '{printf "%-20s %s members\n", $1, $4}' "$groups_file" | sort -k2 -nr | head -10)
    if [ -n "$groups_output" ]; then
      echo "$groups_output"
    else
      echo "No group membership data available."
    fi
    
    print_with_separator "End of Statistics"
  } >> "${output_dest:-/dev/stdout}"
}

# Find a specific user across all groups
find_user_in_groups() {
  local username="$1"
  local found=false
  
  print_with_separator "User Group Membership Report for: $username"
  
  # Check if user exists
  if ! id "$username" &>/dev/null; then
    format-echo "ERROR" "User '$username' does not exist on this system."
    return 1
  fi
  
  # Get primary group
  local primary_gid=$(id -g "$username")
  local primary_group=$(getent group "$primary_gid" | cut -d: -f1)
  
  echo "User: $username"
  echo "UID: $(id -u "$username")"
  echo "Primary Group: $primary_group (GID: $primary_gid)"
  echo
  echo "Supplementary Groups:"
  echo "--------------------"
  
  # Get all groups
  while IFS=: read -r group_name password gid members; do
    if echo ",$members," | grep -q ",$username,"; then
      echo "- $group_name (GID: $gid)"
      
      # Check sudo access if requested
      if [[ "$SHOW_SUDO_INFO" == "true" ]]; then
        local sudo_access=$(check_sudo_access "$group_name")
        echo "  Sudo Access: $sudo_access"
      fi
      
      found=true
    fi
  done < /etc/group
  
  # Check if user is in sudo group or has direct sudo access
  if [[ "$SHOW_SUDO_INFO" == "true" ]]; then
    echo
    echo "Sudo Access:"
    echo "------------"
    
    if sudo -l -U "$username" 2>/dev/null; then
      echo "User has sudo privileges."
    else
      echo "User does not have sudo privileges."
    fi
  fi
  
  if [[ "$found" == "false" ]]; then
    echo "User is not a member of any supplementary groups."
  fi
  
  print_with_separator "End of User Group Membership Report"
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

  print_with_separator "Group Access Auditor Script"
  format-echo "INFO" "Starting Group Access Auditor Script..."

  #---------------------------------------------------------------------
  # VALIDATION
  #---------------------------------------------------------------------
  # Check if required commands are available
  if ! command -v sort >/dev/null || ! command -v awk >/dev/null; then
    format-echo "ERROR" "Required commands (sort, awk) are not available."
    exit 1
  fi
  
  # Check if we can read /etc/group
  if [ ! -r /etc/group ]; then
    format-echo "ERROR" "Cannot read /etc/group. Run with sudo if necessary."
    exit 1
  fi
  
  # Validate output file if specified
  if [ -n "$OUTPUT_FILE" ]; then
    if ! touch "$OUTPUT_FILE" 2>/dev/null; then
      format-echo "ERROR" "Cannot write to output file: $OUTPUT_FILE"
      exit 1
    fi
  fi

  #---------------------------------------------------------------------
  # AUDIT OPERATION
  #---------------------------------------------------------------------
  # Special case: if searching for a specific user
  if [ -n "$FIND_USER" ]; then
    if find_user_in_groups "$FIND_USER"; then
      format-echo "SUCCESS" "User search completed successfully."
    else
      format-echo "ERROR" "Failed to search for user '$FIND_USER'."
      print_with_separator "End of Group Access Auditor Script"
      exit 1
    fi
    print_with_separator "End of Group Access Auditor Script"
    exit 0
  fi
  
  # Get group information
  format-echo "INFO" "Retrieving group information..."
  local groups_file
  groups_file=$(get_groups_and_members)
  
  # Verify file exists and has data
  if [ ! -f "$groups_file" ]; then
    format-echo "ERROR" "Failed to retrieve group information."
    print_with_separator "End of Group Access Auditor Script"
    exit 1
  fi
  
  # Output the results
  if [ -n "$OUTPUT_FILE" ]; then
    if output_results "$groups_file" "$OUTPUT_FILE"; then
      format-echo "SUCCESS" "Group audit report saved to: $OUTPUT_FILE"
    else
      format-echo "ERROR" "Failed to save group audit report."
      print_with_separator "End of Group Access Auditor Script"
      exit 1
    fi
  else
    output_results "$groups_file" || {
      format-echo "ERROR" "Failed to display group audit report."
      print_with_separator "End of Group Access Auditor Script"
      exit 1
    }
  fi
  
  format-echo "SUCCESS" "Group access audit completed successfully."
  print_with_separator "End of Group Access Auditor Script"
}

#=====================================================================
# SCRIPT EXECUTION
#=====================================================================
main "$@"
