---
name: build-fix-loop
description: "Autonomous build-test-fix loop with strict guardrails: one error at a time, 3-strike limit, net-new error detection, and architectural change escalation. Use when fixing build errors, test failures, lint violations, or type errors. Enforces disciplined incremental resolution instead of shotgun fixes."
version: "1.0"
last_updated: "2026-03-19"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document must remain aligned with the project's build tooling and verification patterns.

## Purpose

This skill defines the mandatory protocol for fixing build errors, test failures, lint violations, and type errors. It prevents the common failure mode where an agent makes cascading changes that introduce more problems than they solve.

## When This Skill Activates

- Build fails (`go build`, `flutter build`, `npm run build`, `tsc`, etc.)
- Tests fail (`go test`, `flutter test`, `npm test`, etc.)
- Lint violations reported (`go vet`, `dart analyze`, `ruff check`, `biome check`, etc.)
- Type errors from static analysis
- CI/CD pipeline failures

---

## Core Protocol: One Error at a Time

### Phase 1: Collect All Errors

Run the full build/test/lint command and capture all errors. Categorize them:

| Category | Examples |
|----------|---------|
| Type errors | missing types, wrong signatures, incompatible assignments |
| Import errors | missing imports, circular dependencies, unresolved modules |
| Lint violations | unused variables, style violations, complexity warnings |
| Test failures | assertion failures, timeout, panic/crash |
| Build errors | compilation failures, missing dependencies |

### Phase 2: Fix Loop (One at a Time)

For each error, in order of dependency (imports → types → build → lint → tests):

1. **Read** — Read 15 lines of context around the error location
2. **Diagnose** — Identify the root cause, not just the symptom
3. **Fix minimally** — Make the smallest change that resolves the error. Do NOT:
   - Refactor surrounding code
   - Rename variables for style
   - Add comments or documentation
   - Change function signatures unless required
   - Add error handling beyond what's needed
4. **Re-run** — Run the same build/test/lint command
5. **Verify** — Confirm the error is gone AND no new errors were introduced
6. **Next** — Move to the next error

### Phase 3: Final Verification

After all errors are resolved:

1. Run full build
2. Run full test suite
3. Run full lint check
4. Confirm zero errors across all three

---

## Guardrails (MANDATORY)

### 3-Strike Rule

If the same error persists after 3 fix attempts:

- **STOP fixing that error**
- Report to the user: the error, what was tried, why it failed
- Ask for guidance before continuing

### Net-New Error Rule

After each fix, compare the error count:

- If the fix **reduced** total errors → continue
- If the fix **kept the same** error count but changed which errors → acceptable, continue cautiously
- If the fix **increased** total errors → **immediately revert** the change and try a different approach

### Architectural Change Escalation

If a fix requires any of the following, **STOP and ask the user**:

- Changing a public API signature
- Modifying a protobuf/schema definition
- Adding a new dependency
- Changing database migrations
- Modifying CI/CD configuration
- Changing more than 30 lines of code for a single error

### Config Protection

Never fix lint errors by:

- Disabling lint rules
- Adding `//nolint`, `// ignore`, `@ts-ignore`, `# noqa` annotations
- Modifying linter configuration files
- Lowering strictness settings

Fix the code to satisfy the rule. If the rule is genuinely wrong, escalate to the user.

---

## Output Format

After completing the fix loop, produce a structured report:

```
BUILD-FIX REPORT
════════════════════════════════════════
Errors found:     {N}
Errors fixed:     {M}
Errors remaining: {N-M}
Fix attempts:     {total attempts}
Reverts:          {number of reverted fixes}

Per-error breakdown:
  1. [FIXED]     {file}:{line} — {description}
  2. [FIXED]     {file}:{line} — {description}
  3. [ESCALATED] {file}:{line} — {description} (reason: {why})

Verification:
  Build:  [PASS/FAIL]
  Tests:  [PASS/FAIL] ({passed}/{total})
  Lint:   [PASS/FAIL] ({warnings} warnings)
════════════════════════════════════════
```

---

## Language-Specific Commands

### Go
```bash
# Build
go build ./...
# Test
go test -race -count=1 ./...
# Lint
go vet ./...
# Format (should be handled by post-edit hook)
gofmt -w .
```

### Flutter/Dart
```bash
# Build
flutter build apk --debug  # or flutter build web
# Test
flutter test
# Lint
dart analyze
# Format
dart format --fix .
```

### TypeScript/JavaScript
```bash
# Build
npx tsc --noEmit  # or npm run build
# Test
npm test
# Lint
npx biome check .  # or npx eslint .
```

### Python
```bash
# Test
pytest
# Lint
ruff check .
# Format
ruff format .
```

---

## Anti-Patterns

- Fixing multiple errors in one edit — makes it impossible to attribute regressions
- Fixing lint by suppressing rules — treats symptoms, not causes
- Changing tests to match broken code instead of fixing the code
- Adding `any` types or `interface{}` to bypass type errors
- Catching and swallowing errors to make tests pass
- Commenting out failing tests

---

## Self-Update Protocol

**WHEN to update:**
- Build tooling or commands change
- New guardrails are needed based on experience
- Language-specific sections need updating

**HOW to update:**
1. Edit this SKILL.md using the Edit tool
2. Increment `version` field
3. Update `last_updated` to current date
4. Preserve this self-update protocol section
