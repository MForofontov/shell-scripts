# Function to print a message with separators to both terminal and log file
print_with_separator() {
  local MESSAGE="$1"
  local SEPARATOR="========== $MESSAGE =========="
  if [ -n "$LOG_FILE" ]; then
    echo "$SEPARATOR" >> "$LOG_FILE"
  else
    echo "$SEPARATOR"
  fi
}