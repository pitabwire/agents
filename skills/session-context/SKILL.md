---
name: session-context
description: "Persistent session context that bridges conversations. Auto-saves progress, decisions, blockers, and next steps at session end. Auto-loads context at session start so new conversations pick up where the last one left off. Use when starting a session to check for prior context, or when ending a session to persist state."
version: "1.0"
last_updated: "2026-03-19"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document must remain aligned with the project's session management patterns.

## Purpose

AI coding sessions lose all context when they end. This skill defines a protocol for persisting session state so that the next conversation can pick up where you left off, without the user having to re-explain context.

This works alongside Claude Code's built-in auto-memory system but focuses specifically on **active work state** — what was being done, what's blocked, what's next.

## Session Context File

Each project workspace maintains a session context file:

**Location:** `WORK_STATE.md` in the project root (git-ignored)

### Format

```markdown
# Work State

## Last Updated
{ISO timestamp}

## Active Work
- {What was being worked on}
- {Current branch, if applicable}

## Progress
- [x] {Completed step}
- [x] {Completed step}
- [ ] {Pending step}
- [ ] {Pending step}

## Decisions Made
- {Decision}: {Rationale}

## Blockers
- {What's blocked and why}

## Next Steps
1. {Most important next action}
2. {Second priority}
3. {Third priority}

## Environment Notes
- {Any relevant env state: running services, open PRs, pending deploys}
```

---

## Session Start Protocol

When beginning a new session in a project:

1. **Check for WORK_STATE.md** in the project root
2. If it exists, read it and briefly inform the user:
   - What was last being worked on
   - What the next steps are
   - Any blockers noted
3. If the user's request aligns with the saved state, continue from where things left off
4. If the user's request is different, acknowledge the saved state but follow the new direction

---

## Session End Protocol

Before a session ends (when the user says goodbye, or when wrapping up a task):

1. **Update WORK_STATE.md** with:
   - What was accomplished in this session
   - Any decisions made and their rationale
   - Current blockers
   - Clear next steps, ordered by priority
   - Current branch name if working in git
2. Keep it concise — this is a handoff document, not a journal

---

## Cross-Session Task Bridging

For multi-session work (features that span multiple conversations):

### SHARED_TASK_NOTES.md

For complex features, maintain a `SHARED_TASK_NOTES.md` alongside `WORK_STATE.md`:

```markdown
# {Feature/Task Name}

## Goal
{One sentence description of what we're building}

## Scope
- {In scope}
- {Explicitly out of scope}

## Architecture Decisions
| Decision | Chosen | Alternatives Considered | Reason |
|----------|--------|------------------------|--------|
| {What} | {Choice} | {Other options} | {Why} |

## Implementation Progress
### Phase 1: {name}
- [x] {done}
- [ ] {todo}

### Phase 2: {name}
- [ ] {todo}

## Open Questions
- {Question that needs user input}

## Lessons Learned
- {Pattern that worked well}
- {Approach that failed and why}
```

---

## Integration with Auto-Memory

Session context is **ephemeral work state** — it describes what's happening now. Auto-memory stores **durable knowledge** — who the user is, how they prefer to work, project-level context.

- When a decision from WORK_STATE.md becomes a lasting project pattern → save it as auto-memory
- When a blocker reveals a user preference → save it as feedback memory
- When work state becomes stale (>7 days old) → consider whether anything should be promoted to memory before discarding

---

## Self-Update Protocol

**WHEN to update:**
- Session management patterns evolve
- New handoff strategies prove effective

**HOW to update:**
1. Edit this SKILL.md using the Edit tool
2. Increment `version` field
3. Update `last_updated` to current date
4. Preserve this self-update protocol section
