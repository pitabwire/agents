#!/usr/bin/env bash
# SessionStart hook: check for prior session context.
# If WORK_STATE.md exists in the project root, output its contents
# so the agent can inform the user about prior session state.

set -uo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

STATE_FILE="$PROJECT_ROOT/WORK_STATE.md"

if [ -f "$STATE_FILE" ]; then
  echo "=== Prior session context found ==="
  cat "$STATE_FILE"
  echo "==================================="
fi

exit 0
