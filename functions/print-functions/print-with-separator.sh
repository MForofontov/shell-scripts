#!/usr/bin/env bash
# print-with-separator.sh
print_with_separator() {
  local MESSAGE="${1:-}"
  local TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo 80) # Default to 80 if terminal width is unavailable
  local SEPARATOR_CHAR="="
  local SEPARATOR

  if [ -n "$MESSAGE" ]; then
    local PADDING=$(( (TERMINAL_WIDTH - ${#MESSAGE} - 2) / 2 ))
    SEPARATOR=$(printf "%${PADDING}s" | tr ' ' "$SEPARATOR_CHAR")
    SEPARATOR="$SEPARATOR $MESSAGE $SEPARATOR"
    # Adjust for odd terminal widths
    if [ $(( (TERMINAL_WIDTH - ${#MESSAGE} - 2) % 2 )) -ne 0 ]; then
      SEPARATOR="$SEPARATOR$SEPARATOR_CHAR"
    fi
  else
    SEPARATOR=$(printf "%${TERMINAL_WIDTH}s" | tr ' ' "$SEPARATOR_CHAR")
  fi

  if [ -n "$LOG_FILE" ] && [ "$LOG_FILE" != "/dev/null" ]; then
    echo "$SEPARATOR" | tee -a "$LOG_FILE"
  else
    echo "$SEPARATOR"
  fi
}
