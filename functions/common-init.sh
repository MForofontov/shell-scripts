# common-init.sh
# Determine repository root relative to the caller and source shared functions.

# Resolve the path of the calling script
CALLER="${BASH_SOURCE[1]:-${0}}"
CALLER_DIR="$(cd "$(dirname "$CALLER")" && pwd)"

# Walk up directories until .git is found or root is reached
REPO_ROOT="$CALLER_DIR"
while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/.git" ]; do
  REPO_ROOT="$(dirname "$REPO_ROOT")"
done

# Fallback: parent directory of this script
if [ ! -d "$REPO_ROOT/.git" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Source common libraries
source "$REPO_ROOT/functions/format-echo/format-echo.sh"
source "$REPO_ROOT/functions/print-functions/print-with-separator.sh"
source "$REPO_ROOT/functions/utility.sh"
