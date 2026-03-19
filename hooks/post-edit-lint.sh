#!/usr/bin/env bash
# Post-edit hook: run language-specific linter on the edited file.
# Outputs lint errors to stderr so the agent sees them immediately.
# Exit code 0 always (non-blocking) — output is informational.

set -uo pipefail

FILE="${1:-}"
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

EXT="${FILE##*.}"
DIR="$(dirname "$FILE")"

case "$EXT" in
  go)
    if command -v go >/dev/null 2>&1; then
      # go vet on the package containing the file
      cd "$DIR" && go vet ./... 2>&1 | head -20 >&2
    fi
    ;;
  dart)
    if command -v dart >/dev/null 2>&1; then
      dart analyze "$FILE" 2>&1 | grep -E '(error|warning|info)' | head -20 >&2
    fi
    ;;
  ts|tsx)
    # Find nearest tsconfig and run tsc --noEmit
    SEARCH_DIR="$DIR"
    while [ "$SEARCH_DIR" != "/" ]; do
      if [ -f "$SEARCH_DIR/tsconfig.json" ]; then
        cd "$SEARCH_DIR" && npx --no-install tsc --noEmit 2>&1 | grep -i "$(basename "$FILE")" | head -20 >&2
        break
      fi
      SEARCH_DIR="$(dirname "$SEARCH_DIR")"
    done
    ;;
  py)
    if command -v ruff >/dev/null 2>&1; then
      ruff check "$FILE" 2>&1 | head -20 >&2
    fi
    ;;
esac

exit 0
