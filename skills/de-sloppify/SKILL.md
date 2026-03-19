---
name: de-sloppify
description: "Focused cleanup pass that removes unnecessary comments, dead code, over-engineering, test slop, and AI-generated cruft after implementation. Use after completing a feature, fix, or refactor to ensure the output is clean, minimal, and production-grade. Two focused agents outperform one constrained agent."
version: "1.0"
last_updated: "2026-03-19"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document must remain aligned with the project's code quality standards.

## Purpose

After implementing a feature or fix, run this skill as a dedicated cleanup pass. Rather than constraining the implementation agent with negative instructions ("don't add comments", "don't over-engineer"), let it work freely and then apply a focused cleanup.

**Principle: Two focused agents outperform one constrained agent.**

## When This Skill Activates

- After completing a feature implementation
- After a build-fix-loop resolves all errors
- Before creating a commit or pull request
- When the user says "clean up", "de-slop", "simplify", or "review for cruft"
- As part of an autonomous pipeline after the implementation step

---

## Cleanup Protocol

### Step 1: Identify Changed Files

```bash
git diff --name-only HEAD  # unstaged changes
git diff --name-only --cached  # staged changes
```

Review only files that were modified in this session. Do not touch unrelated files.

### Step 2: Remove Comment Slop

Remove these categories of comments from changed code:

- **Obvious comments** — Comments that restate the code (`// increment counter`, `// return the result`)
- **AI-generated narration** — Comments that explain what was just done (`// Added error handling for the edge case`)
- **TODO/FIXME added during implementation** — If it's a real TODO, it should be a tracked issue, not a comment
- **Changelog comments** — (`// removed old logic`, `// previously this was X`)
- **Section dividers** — (`// ============`, `// --- helpers ---`)

**Keep:** Comments that explain *why* — business rules, non-obvious constraints, workarounds for known bugs.

### Step 3: Remove Dead Code

- Unused imports
- Unused variables and parameters
- Unused functions and methods
- Commented-out code blocks
- Unused type definitions or interfaces
- Empty error handlers or catch blocks that swallow errors

**Verify:** After each removal, ensure build + tests still pass.

### Step 4: Reduce Over-Engineering

Look for and simplify:

- **Premature abstractions** — Interfaces with only one implementation, factory functions that create one type, generic helpers used once
- **Unnecessary indirection** — Wrapper functions that just delegate, single-method interfaces
- **Speculative features** — Configuration options nobody asked for, feature flags for non-existent features, extensibility hooks with no extensions
- **Over-parameterized functions** — Functions that accept options objects when they're always called the same way

**Rule:** If an abstraction has exactly one user, inline it.

### Step 5: Fix Test Slop

- Remove test helper functions used by only one test — inline them
- Remove overly descriptive test names that duplicate the assertion
- Remove unnecessary setup/teardown that doesn't affect the test
- Remove tests that test implementation details rather than behavior
- Ensure assertions are meaningful (not just `!= nil` / `!= null`)

### Step 6: Verify Cleanliness

Run the full verification:

```bash
# Build
go build ./... || flutter build || npm run build

# Test
go test -race ./... || flutter test || npm test

# Lint
go vet ./... || dart analyze || npx biome check .
```

All three must pass. If anything fails, revert the last cleanup change and skip that cleanup.

---

## What NOT to Clean Up

- Code that was not modified in this session
- Comments that explain business rules or non-obvious constraints
- Test utilities shared across multiple test files
- Abstractions that genuinely serve multiple callers
- Error handling that guards against real failure modes
- Logging that serves operational observability

---

## Output Format

```
DE-SLOPPIFY REPORT
════════════════════════════════════════
Files reviewed:    {N}
Changes made:      {M}

Removals:
  Comments:        {count} removed
  Dead code:       {count} removed
  Unused imports:  {count} removed

Simplifications:
  Inlined:         {count} abstractions
  Reduced:         {count} over-parameterized functions

Verification:
  Build:  [PASS/FAIL]
  Tests:  [PASS/FAIL]
  Lint:   [PASS/FAIL]
════════════════════════════════════════
```

---

## Self-Update Protocol

**WHEN to update:**
- New categories of slop are discovered
- Code quality standards evolve
- Language-specific cleanup patterns emerge

**HOW to update:**
1. Edit this SKILL.md using the Edit tool
2. Increment `version` field
3. Update `last_updated` to current date
4. Preserve this self-update protocol section
