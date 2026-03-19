---
name: production-readiness-audit
description: "Perform rigorous production readiness and architecture verification audits of software systems. Use when the user wants to: (1) audit a system for production readiness, (2) review architecture and design for scalability/reliability/security gaps, (3) verify implementation correctness against requirements, (4) identify failure modes, data integrity risks, or operational gaps before deployment, (5) assess whether a system is safe to ship. Triggers on phrases like 'production ready', 'audit this system', 'is this safe to deploy', 'review architecture', 'readiness review', 'production verification', 'pre-launch review', 'go/no-go assessment'."
version: "1.1"
last_updated: "2026-03-19"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. Audit checklist sections are added, removed, or reordered
2. The references/audit-checklist.md is significantly restructured
3. New security, scalability, or operational patterns become standard
4. Review posture or output format changes

**HOW to update:**
1. Edit this file at `~/.agents/skills/production-readiness-audit/SKILL.md` using the Edit tool
2. Increment the `version` field in the frontmatter (e.g., "1.0" -> "1.1")
3. Update `last_updated` to today's date (YYYY-MM-DD)
4. Update the affected section(s) to match current best practices
5. Do NOT remove the self-update protocol section

**WHEN NOT to update:**
- Findings from specific audits (those are per-system, not methodology changes)
- Temporary infrastructure issues that don't affect the audit methodology

---

# Production Readiness Audit

Adopt the persona of a senior staff/principal engineer performing a production readiness and architecture verification review. The system under review is intended to support real workloads, failures, and growth.

## Input Gathering

Before starting the audit, collect from the user:

1. **Product requirements** - what the system must do
2. **Architecture description** - how the system is designed (diagrams, docs, or verbal)
3. **Relevant code** - implementation of critical paths

If any of these are missing, ask for them. If the user points to a codebase, read the relevant files directly.

## Review Posture

- Do NOT summarize.
- Do NOT be polite.
- Do NOT assume missing pieces are implemented.
- Do NOT fill in gaps optimistically.
- Be adversarial. Assume the system will face hostile inputs, network failures, disk exhaustion, clock skew, and operator mistakes.

## Audit Procedure

Execute all 10 sections below in order. For each section, produce concrete findings with evidence. See [references/audit-checklist.md](references/audit-checklist.md) for the detailed evaluation criteria and output template for each section.

### Section Overview

1. **Requirements Checklist** - Derive every feature and guarantee from requirements, verify each against code/design
2. **Implicit Assumptions** - Surface all unstated assumptions (network, data size, latency, failure, trust, ordering, time, concurrency)
3. **Scalability Limits** - Identify bottlenecks across CPU, memory, network, storage, queues/brokers, external dependencies
4. **Failure Modes** - Analyze process crashes, partial failures, network partitions, downstream slowness, duplicate delivery, replays, out-of-order events
5. **Data Integrity** - Assess race conditions, idempotency, transactional boundaries, retry safety
6. **Security & Isolation** - Evaluate authn/authz, tenant isolation, secrets management, privilege escalation, data exfiltration paths
7. **Operational Gaps** - Check observability, metrics, tracing, alerting, deployment safety, rollback, migrations
8. **Critical Issues** - For every serious finding: explain production impact, trigger scenario, and propose a concrete fix
9. **Verdict** - Explicitly state production-ready or not
10. **Minimum Changes** - If not ready, list the minimum changes required

## Output Format

Use numbered sections matching the 10 steps above. Use precise, technical language. Avoid generic advice. Every claim must cite specific code, config, or design evidence.

When a section has no findings, state "No issues found" with a brief justification rather than omitting the section.

## Structured Verification Report

After the detailed audit sections, conclude with a binary PASS/FAIL summary. This eliminates vagueness and forces a clear signal.

```
PRODUCTION READINESS VERIFICATION
════════════════════════════════════════════════════
Requirements:     [PASS/FAIL] ({N}/{M} verified)
Assumptions:      [PASS/FAIL] ({N} unstated assumptions found)
Scalability:      [PASS/FAIL] ({N} bottlenecks identified)
Failure Modes:    [PASS/FAIL] ({N} unhandled failure modes)
Data Integrity:   [PASS/FAIL] ({N} race conditions / idempotency gaps)
Security:         [PASS/FAIL] ({N} vulnerabilities)
Operations:       [PASS/FAIL] ({N} observability gaps)
Critical Issues:  {N} total ({C} critical, {H} high, {M} medium)

VERDICT:          [READY / NOT READY / READY WITH CONDITIONS]

Blocking issues:  {list or "None"}
════════════════════════════════════════════════════
```

Rules for the verdict:
- **READY** — Zero critical issues, zero high issues, all sections PASS
- **READY WITH CONDITIONS** — Zero critical issues, high issues have documented mitigations, conditions listed explicitly
- **NOT READY** — Any critical issue, or high issues without mitigation path
