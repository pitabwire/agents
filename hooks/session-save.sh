#!/usr/bin/env bash
# SessionEnd hook: capture a lightweight session snapshot.
# Saves git branch, modified files, and timestamp to WORK_STATE.md
# in the project root. The AI agent enriches this with decisions/next-steps
# via the session-context skill; this hook captures the mechanical state.

set -uo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

STATE_FILE="$PROJECT_ROOT/WORK_STATE.md"
TIMESTAMP="$(date -Iseconds)"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'detached')"
MODIFIED="$(git diff --name-only 2>/dev/null | head -20)"
STAGED="$(git diff --cached --name-only 2>/dev/null | head -20)"
UNTRACKED="$(git ls-files --others --exclude-standard 2>/dev/null | head -10)"

# Only write if there are actual changes to capture
if [ -z "$MODIFIED" ] && [ -z "$STAGED" ] && [ -z "$UNTRACKED" ]; then
  exit 0
fi

cat > "$STATE_FILE" << EOF
# Work State

## Last Updated
$TIMESTAMP

## Active Work
- Branch: \`$BRANCH\`

## Modified Files
$(echo "$MODIFIED" | sed 's/^/- /' | head -20)

## Staged Files
$(echo "$STAGED" | sed 's/^/- /' | head -20)

## Untracked Files
$(echo "$UNTRACKED" | sed 's/^/- /' | head -10)

## Progress
<!-- Agent should fill this in via session-context skill -->

## Decisions Made
<!-- Agent should fill this in via session-context skill -->

## Next Steps
<!-- Agent should fill this in via session-context skill -->
EOF

# Ensure WORK_STATE.md is gitignored
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
  grep -qxF 'WORK_STATE.md' "$PROJECT_ROOT/.gitignore" 2>/dev/null || echo 'WORK_STATE.md' >> "$PROJECT_ROOT/.gitignore"
else
  echo 'WORK_STATE.md' > "$PROJECT_ROOT/.gitignore"
fi

exit 0
