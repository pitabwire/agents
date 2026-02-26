# Special Rules

Apply these checklists only when the system matches the category.

## Table of Contents
- [AI-Powered Systems](#ai-powered-systems)
- [Code-Producing or Code-Modifying Systems](#code-producing-or-code-modifying-systems)

---

## AI-Powered Systems

Apply when the system uses machine learning models, LLMs, or AI providers.

### Required Definitions

| Area | Must Define |
|------|-------------|
| **Prompt ownership** | Which component owns prompt templates, where they are stored, how they are versioned |
| **Prompt lifecycle** | How prompts are created, tested, deployed, and retired |
| **Model selection** | How the system chooses which model/provider to use (routing, fallback, cost) |
| **Deterministic replay** | How to reproduce a given AI interaction for debugging or audit |
| **Sandboxing** | What the AI can and cannot do; how tool execution is bounded |
| **Tool boundaries** | Which tools/actions the AI has access to, permission model, scope limits |
| **Output validation** | How AI output is validated before being used (schema checks, constraint enforcement) |
| **Prompt/output versioning** | How prompt templates and output schemas evolve over time |
| **Safety controls** | Content filtering, rate limiting, cost caps, misuse detection |
| **Audit trail** | What is logged: prompt, model, parameters, output, tool calls, duration, cost |

### AI-Specific Failure Modes

| Failure | Required Response |
|---------|------------------|
| Model unavailable | Fallback model, queue for retry, or graceful degradation |
| Rate limited | Backoff, request queuing, provider rotation |
| Output violates constraints | Reject output, revert changes, report to user |
| Excessive cost | Per-request cost caps, daily budget limits, alerting |
| Timeout | Kill process, revert partial work, report failure |
| Hallucinated actions | Post-execution constraint validation, allow-list enforcement |

---

## Code-Producing or Code-Modifying Systems

Apply when the system generates, edits, transforms, or analyzes source code or artifacts.

### Required Definitions

| Area | Must Define |
|------|-------------|
| **Repository state** | How repo is cloned, locked, modified, and committed; conflict prevention |
| **Artifact management** | What artifacts are produced, where they are stored, how they are versioned |
| **Deterministic validation** | Build, test, and lint steps that verify generated code is correct |
| **Conflict detection** | How concurrent modifications to the same files/repo are detected |
| **Conflict resolution** | Strategy: reject, merge, last-writer-wins, or manual resolution |
| **Rollback** | How to revert generated changes (git revert, checkpoint restore, etc.) |
| **Replay** | How to re-execute a code generation operation deterministically |
| **Provenance** | What metadata is recorded: who triggered, what prompt, which model, what changed |
| **Audit trail** | Full history of every code modification with attribution |

### Code-Specific Failure Modes

| Failure | Required Response |
|---------|------------------|
| Generated code fails build | Revert changes, report error with build output |
| Generated code fails tests | Revert changes, report which tests failed |
| Generated code violates constraints | Revert changes, report constraint violations |
| Concurrent modification | Repo-level locking or optimistic concurrency with conflict detection |
| Partial generation (timeout/crash) | Revert all changes atomically (git checkout .) |
| Generated code introduces vulnerability | Static analysis gate, constraint enforcement, human review gate |
