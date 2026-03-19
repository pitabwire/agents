#!/usr/bin/env bash
# Pre-edit hook: block edits to linter/formatter configuration files.
# Prevents agents from gaming lint rules by disabling them.
# Exit 1 to block the edit, exit 0 to allow.

set -euo pipefail

FILE="${1:-}"
[ -z "$FILE" ] && exit 0

BASENAME="$(basename "$FILE")"

# Protected config files — agents must not modify these
PROTECTED_FILES=(
  "analysis_options.yaml"
  ".golangci.yml"
  ".golangci.yaml"
  "golangci-lint.yml"
  "biome.json"
  "biome.jsonc"
  ".prettierrc"
  ".prettierrc.json"
  ".prettierrc.yaml"
  "prettier.config.js"
  "prettier.config.mjs"
  ".eslintrc"
  ".eslintrc.json"
  ".eslintrc.js"
  "eslint.config.js"
  "eslint.config.mjs"
  ".ruff.toml"
  "ruff.toml"
  "pyproject.toml"
  ".flake8"
  ".pylintrc"
  "tsconfig.json"
  ".stylelintrc"
  ".stylelintrc.json"
)

for PROTECTED in "${PROTECTED_FILES[@]}"; do
  if [ "$BASENAME" = "$PROTECTED" ]; then
    echo "BLOCKED: Editing $BASENAME is not allowed." >&2
    echo "Fix the code to satisfy the linter, do not modify linter configuration." >&2
    exit 1
  fi
done

exit 0
