---
name: model-routing
description: "Token/cost optimization through smarter model selection and context management. Guides agents to use the right model tier for each sub-task, minimize context window usage, and avoid wasting expensive reasoning on simple operations. Use when spawning subagents, planning multi-step work, or when context is growing large."
version: "1.0"
last_updated: "2026-03-19"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document must remain aligned with available models and pricing.

## Purpose

Not every task needs the most expensive model. This skill provides a decision framework for routing sub-tasks to the appropriate model tier, managing context window efficiently, and reducing token waste without sacrificing quality.

## Model Tier Routing

### Tier 1: Fast/Cheap (Haiku-class)

Use for tasks that are mechanical, well-defined, and don't require deep reasoning:

- Formatting and style fixes
- Import organization
- Simple find-and-replace refactors
- Generating boilerplate from templates
- Running predefined verification checks
- Summarizing file contents
- Extracting structured data from text

**When spawning subagents:** Use `model: "haiku"` for these tasks.

### Tier 2: Balanced (Sonnet-class)

Use for tasks that require understanding but not deep architectural reasoning:

- Bug fixes with clear error messages
- Writing tests for existing code
- Code review for style and correctness
- Build error resolution (the build-fix-loop)
- Documentation generation
- API client implementation from specs
- De-sloppify cleanup passes

**When spawning subagents:** Use `model: "sonnet"` for these tasks.

### Tier 3: Deep Reasoning (Opus-class)

Reserve for tasks that require architectural judgment, complex tradeoffs, or novel design:

- System design and architecture decisions
- Complex debugging without clear error messages
- Security audits and threat modeling
- Performance optimization requiring algorithmic changes
- Production readiness audits
- Planning multi-service changes
- Resolving ambiguous requirements

**When spawning subagents:** Use `model: "opus"` or default (inherits parent) for these tasks.

---

## Context Management

### Progressive Disclosure

Don't read entire files when you only need a section. Use these patterns:

1. **Start with structure** — Use `Glob` and `Grep` before `Read`
2. **Read targeted ranges** — Use `offset` and `limit` parameters on `Read`
3. **Reference files on-demand** — Skills with reference files (like golang-patterns) should only read references when working in that specific area

### Avoid Context Bloat

- Don't paste entire file contents into subagent prompts — describe what's needed and let the subagent read files itself
- Don't re-read files you've already read unless they've been modified
- When exploring a codebase, use `Grep` with `files_with_matches` mode first, then read only relevant files
- Prefer `head_limit` on search results to avoid flooding context with matches

### Subagent Context Isolation

Subagents are useful for protecting the parent context from large intermediate results:

- Use `Explore` subagent for broad codebase searches that might return many results
- Use `general-purpose` subagent for research tasks where intermediate steps are noisy
- Keep the parent context focused on decisions and outcomes, not raw search results

---

## Cost-Aware Patterns

### Batch Independent Work

When multiple independent tasks exist, launch subagents in parallel rather than doing them sequentially. This doesn't save tokens but saves wall-clock time.

### Fail Fast

Before starting expensive operations:

1. Check if the build compiles first (cheap)
2. Check if tests pass first (medium)
3. Only then do expensive analysis/redesign (expensive)

### Incremental Verification

Don't run full test suites after every small change:

1. After a single-file edit → run tests for that package/module only
2. After completing a feature → run the full test suite
3. After a refactor touching multiple files → run full suite + lint

### Avoid Redundant Reads

Track what you've already read in the conversation. If you need to reference a file you read earlier, use your memory of its contents rather than re-reading it, unless it may have been modified since.

---

## Self-Update Protocol

**WHEN to update:**
- Model tiers or pricing change
- New model families become available
- New cost optimization patterns are discovered

**HOW to update:**
1. Edit this SKILL.md using the Edit tool
2. Increment `version` field
3. Update `last_updated` to current date
4. Preserve this self-update protocol section
