#!/usr/bin/env bash
# Post-edit hook: auto-format the edited file based on language.
# Called with the file path as the first argument.
# Exit 0 on success or if no formatter found (non-blocking).

set -euo pipefail

FILE="${1:-}"
[ -z "$FILE" ] || [ ! -f "$FILE" ] && exit 0

EXT="${FILE##*.}"

case "$EXT" in
  go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" 2>/dev/null
    ;;
  dart)
    command -v dart >/dev/null 2>&1 && dart format --fix "$FILE" 2>/dev/null
    ;;
  ts|tsx|js|jsx|mjs|cjs)
    # Prefer biome, fallback to prettier
    if [ -f "biome.json" ] || [ -f "biome.jsonc" ]; then
      npx --no-install @biomejs/biome check --write "$FILE" 2>/dev/null
    elif [ -f ".prettierrc" ] || [ -f ".prettierrc.json" ] || [ -f "prettier.config.js" ]; then
      npx --no-install prettier --write "$FILE" 2>/dev/null
    fi
    ;;
  py)
    command -v ruff >/dev/null 2>&1 && ruff format "$FILE" 2>/dev/null
    ;;
  yaml|yml)
    command -v yamlfmt >/dev/null 2>&1 && yamlfmt "$FILE" 2>/dev/null
    ;;
esac

exit 0
