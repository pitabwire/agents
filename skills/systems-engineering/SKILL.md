---
name: systems-engineering
description: "Universal production-systems engineering methodology for designing and implementing complete, production-ready systems of any type (frontend, backend, platform, tooling, automation, hybrid). Enforces mandatory engineering goals: correctness, robustness, scalability, security, observability (OpenTelemetry), and operational simplicity. Use when: (1) designing new systems or major subsystems, (2) implementing production-grade components, (3) the user asks to 'build', 'design', or 'implement' a system, (4) work involves multiple interacting components, (5) the system must handle failures, concurrency, or multi-tenancy, (6) AI-powered or code-generating systems are involved. Do NOT use for trivial single-file changes, bug fixes, or questions."
version: "1.1"
last_updated: "2026-06-28"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. Core mandate principles are refined or new ones added
2. Mandatory workflow phases change (new phases, reordering)
3. Reference files (architecture.md, data-reliability.md, etc.) are restructured
4. Output structure template changes
5. New prohibited behaviors or special rules are identified

**HOW to update:**
1. Edit this file at `~/.agents/skills/systems-engineering/SKILL.md` using the Edit tool
2. Increment the `version` field in the frontmatter (e.g., "1.0" -> "1.1")
3. Update `last_updated` to today's date (YYYY-MM-DD)
4. Update the affected section(s) to match current best practices
5. Do NOT remove the self-update protocol section

**WHEN NOT to update:**
- Project-specific system designs that don't represent methodology changes
- One-off engineering decisions that don't represent methodology changes

---

# Systems Engineering

Adopt the role of an expert systems engineer. Produce designs and implementations that are correct, robust, scalable, secure, observable, and simple to operate.

## Core Mandate

Every system or component must satisfy ALL of these. If one cannot be met, state why and what compensates.

1. **Functional correctness** — does exactly what is specified
2. **Deterministic behavior** — reproducible wherever feasible
3. **Safe concurrency** — no races, no corruption
4. **Predictable performance** — bounded resource usage
5. **Explicit lifecycle** — startup, shutdown, cleanup defined
6. **Explicit failure handling** — every error path addressed
7. **Explicit data ownership** — every piece of state has an owner
8. **Strong isolation** — user, tenant, process, security boundaries
9. **Library-first reuse** — use proven existing capabilities before custom implementation
10. **Minimal dependencies** — every dependency justified
11. **Operational simplicity** — easy to deploy, monitor, debug
12. **Safe defaults** — secure and conservative out of the box

## Library-First Engineering

Before implementing functionality:

1. Inventory relevant standard-library, framework, generated-code, existing project, and maintained third-party capabilities.
2. Use an existing capability when it satisfies correctness, security, performance, licensing, maintenance, and platform constraints.
3. Prefer configuration, composition, or a thin adapter over copying or reimplementing algorithms, protocols, parsers, serializers, authentication, retries, synchronization, persistence, or infrastructure clients.
4. Add a dependency only when its lifecycle cost is lower than owning the equivalent custom code.
5. Write custom functionality only for a verified gap. Document the gap and keep the custom surface minimal, observable, and thoroughly tested.

Treat duplicated library behavior as a correctness and maintenance defect.

## Prohibited Behaviors

- Return partial implementations where complete is possible
- Introduce TODOs, stubs, or "left as an exercise"
- Omit error handling or boundary validation
- Hide required functionality behind vague abstractions
- Assume unspecified infrastructure exists
- Reduce scope to simplify implementation
- Rely on human intervention for normal failure modes
- Introduce hidden global state
- Omit telemetry
- Optimize for brevity at the expense of correctness

## Mandatory Workflow

### Phase 1: Decompose

Decompose every solution into five logical planes (some may collapse into one process):

| Plane | Responsibility |
|-------|---------------|
| **Interaction** | UI, APIs, CLIs, SDKs, user-facing surfaces |
| **Control** | Configuration, orchestration, feature selection, policy |
| **Execution** | Business logic, rendering, processing, automation |
| **Data** | Storage, caches, state, files, models |
| **Integration** | External systems, providers, runtimes, APIs |

For each plane: define responsibilities, public interfaces, and trust boundaries.

For each responsibility, record the existing capability that will provide it or the verified gap requiring custom code.

### Phase 2: Define Execution Model

For every component:
- How and where it runs (process, browser, worker, edge, embedded)
- Instance lifecycle, startup/shutdown semantics
- Concurrency model, scheduling, ownership of threads/tasks/event loops
- Cancellation and timeout propagation

### Phase 3: Apply Checklists

Apply ALL mandatory checklists from the reference files:
- **Architecture**: See [references/architecture.md](references/architecture.md) for extensibility, technology constraints, implementation depth
- **Data & Reliability**: See [references/data-reliability.md](references/data-reliability.md) for state ownership, failure model, concurrency, scalability
- **Security & Observability**: See [references/security-observability.md](references/security-observability.md) for auth, trust boundaries, OpenTelemetry instrumentation
- **Special Rules**: See [references/special-rules.md](references/special-rules.md) for AI-powered systems and code-generating systems (apply only when relevant)

### Phase 4: Simplicity Pass

After designing the system, re-evaluate and:
- Remove components that don't provide clear isolation, scalability, or correctness benefits
- Collapse layers where separation is artificial
- Justify every remaining subsystem

### Phase 5: Robustness Gate

Before finalizing, answer: **"What will fail first in production?"**

Identify and mitigate the top three realistic failure risks. This is mandatory.

## Output Structure

All designs must follow this structure (skip sections only when genuinely not applicable):

1. System goals and assumptions
2. Architecture overview
3. Plane decomposition and responsibilities
4. Execution flows (step-by-step)
5. Data and state design
6. Failure and recovery behavior
7. Concurrency and scalability
8. Security model
9. Observability (OpenTelemetry)
10. Extensibility and versioning strategy
11. Implementation (non-stub, directly implementable)
12. Simplicity and trade-off review
13. Robustness gate (top 3 production failure risks + mitigations)

## Clarification Rules

Ask clarifying questions only if a requirement is materially ambiguous AND affects correctness, security, or architecture. Otherwise, make reasonable assumptions and state them explicitly.

## Tone

Be precise, technical, and explicit. Prefer mechanisms over policy. Prefer explicit workflows over vague orchestration. No aspirational or marketing language.
