---
name: continuous-learning
description: "Auto-extracts reusable patterns from coding sessions and promotes them into skills, memories, or rules. Identifies recurring problems, successful approaches, and emerging conventions. Use at session end or when a non-obvious pattern proves successful."
version: "1.0"
last_updated: "2026-03-19"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document must remain aligned with the project's skill and memory systems.

## Purpose

Every coding session generates implicit knowledge: patterns that work, approaches that fail, conventions that emerge. This skill defines a protocol for capturing that knowledge and feeding it back into the system so future sessions benefit.

## When to Extract Patterns

### Automatic Triggers

Extract a pattern when any of these occur during a session:

1. **Same fix applied 3+ times** — A recurring correction indicates a missing convention or rule
2. **User corrects the same behavior twice** — A feedback pattern the agent keeps forgetting
3. **A non-obvious approach succeeds** — Something that worked but wouldn't be the default choice
4. **A debugging session reveals hidden coupling** — Architecture knowledge not visible from code structure
5. **A workaround is needed for a tool/framework limitation** — Future sessions will hit the same wall
6. **A new library or API pattern is established** — First usage sets the convention for future usage

### Manual Triggers

The user explicitly says: "remember this", "save this pattern", "we should always do it this way"

---

## Pattern Classification

When a pattern is identified, classify it to determine where it should be stored:

| Pattern Type | Storage Location | Example |
|-------------|-----------------|---------|
| User preference | Auto-memory (feedback type) | "User prefers single bundled PRs for refactors" |
| Project convention | Auto-memory (project type) | "All new services use Frame blueprint scaffolding" |
| Code pattern | Existing skill update | "Connect RPC handlers must validate pagination params" |
| New domain pattern | New skill or skill reference | "Payment reconciliation follows specific state machine" |
| Tool/framework workaround | Existing skill update | "Drift DB requires explicit type converters for enums" |
| External resource | Auto-memory (reference type) | "CI logs are in GitHub Actions, not Jenkins" |

---

## Extraction Protocol

### Step 1: Identify the Pattern

Describe the pattern concisely:
- **What**: The specific technique, convention, or approach
- **When**: The conditions under which it applies
- **Why**: Why it works (or why the alternative doesn't)

### Step 2: Validate Confidence

Rate the pattern's confidence before storing:

| Confidence | Criteria | Action |
|-----------|----------|--------|
| **High** | Worked 3+ times, user confirmed, or matches documented convention | Store immediately |
| **Medium** | Worked once convincingly, no user objection | Store with a note that it's based on limited evidence |
| **Low** | Seems right but untested, or worked in a special case | Note in WORK_STATE.md for future validation, don't store yet |

Only store High and Medium confidence patterns. Low confidence patterns stay in session notes until validated.

### Step 3: Store the Pattern

Based on classification:

**If updating an existing skill:**
1. Read the relevant SKILL.md
2. Add the pattern to the appropriate section
3. Increment the version
4. Update `last_updated`

**If creating auto-memory:**
1. Write a memory file to the auto-memory directory
2. Follow the memory frontmatter format (type, name, description)
3. Update MEMORY.md index

**If the pattern warrants a new skill:**
1. Only if there are 3+ related patterns forming a coherent topic
2. Create a new skill directory under `coding_agents/skills/`
3. Follow the standard SKILL.md format with self-update protocol

---

## Session Review Checklist

At the end of a significant session, quickly review:

- [ ] Did I apply any fix or pattern repeatedly? → Extract it
- [ ] Did the user correct my approach? → Save as feedback memory
- [ ] Did I discover something non-obvious about the codebase? → Save as project memory
- [ ] Did I establish a new convention for the first time? → Update relevant skill
- [ ] Did I find a useful external resource? → Save as reference memory
- [ ] Did any of my existing skill knowledge turn out to be wrong? → Update the skill

---

## Anti-Patterns

- **Don't extract one-off solutions** — A fix for a specific bug isn't a pattern unless the bug class recurs
- **Don't duplicate existing documentation** — If it's already in a SKILL.md or CLAUDE.md, don't store it again
- **Don't store implementation details** — "Use `frame.NewService()` for init" is code, not a pattern. "All services must use Frame for initialization" is a pattern
- **Don't over-index on negative patterns** — "Don't use X" is less useful than "Use Y instead of X because Z"
- **Don't create skills for single patterns** — A skill needs 3+ coherent patterns. Single patterns go in memories or existing skills

---

## Self-Update Protocol

**WHEN to update:**
- New extraction triggers are identified
- Storage classification evolves
- Confidence criteria change based on experience

**HOW to update:**
1. Edit this SKILL.md using the Edit tool
2. Increment `version` field
3. Update `last_updated` to current date
4. Preserve this self-update protocol section
