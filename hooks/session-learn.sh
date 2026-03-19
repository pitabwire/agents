#!/usr/bin/env bash
# Stop hook: lightweight signal to remind the agent to run the
# continuous-learning review checklist before the session ends.
# This doesn't extract patterns itself — it prompts the agent
# to check if any patterns emerged during the session.

set -uo pipefail

# Only trigger if substantial work was done (>5 files modified)
MODIFIED_COUNT="$(git diff --name-only 2>/dev/null | wc -l)"

if [ "$MODIFIED_COUNT" -gt 5 ]; then
  echo "NOTE: Substantial session ($MODIFIED_COUNT files modified). Consider running the continuous-learning review checklist before ending." >&2
fi

exit 0
