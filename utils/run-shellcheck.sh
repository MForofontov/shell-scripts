#!/usr/bin/env bash
# run-shellcheck.sh
# Script to run shellcheck on all .sh files in the repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

UTILITY_FILE="$REPO_ROOT/functions/utility.sh"

if [ -f "$UTILITY_FILE" ]; then
  # shellcheck source=functions/utility.sh
  source "$UTILITY_FILE"
else
  command_exists() { command -v "$1" >/dev/null 2>&1; }
fi

if ! command_exists shellcheck; then
  echo "shellcheck is not installed. Please install it and re-run this script." >&2
  exit 1
fi

find "$REPO_ROOT" -type f -name '*.sh' -exec shellcheck -x "$@" {} +
