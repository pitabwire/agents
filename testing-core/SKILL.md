---
name: testing-core
description: Enforces production-grade test standards for writing, improving, reviewing, and running tests across all languages, prioritizing determinism, real integration over mocks, and maintainability. Use when writing, modifying, reviewing, debugging, or running tests in any language.
version: "1.0"
last_updated: "2026-03-13"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document must remain aligned with the codebase's testing philosophy, framework conventions, and infrastructure patterns.

## Purpose

This skill defines the mandatory protocol an agent must follow whenever it writes, updates, reviews, debugs, or runs tests.

Tests must be:

- behavior-focused
- deterministic
- isolated
- maintainable
- hard to falsely satisfy
- representative of real runtime behavior
- explicit about failures
- scalable as the codebase grows

This skill strongly prefers **real execution paths** over artificial mocks.

---

## Core Testing Philosophy

Optimize for **confidence**, not just passing tests.

Tests should prove that the system works under realistic conditions, not merely that mocked expectations were satisfied.

### Mandatory Principles

1. **Test observable behavior, not implementation details**
   - Prefer public APIs, public methods, RPC boundaries, UI behavior, and externally visible side effects.
   - Do not assert private/internal implementation unless there is no better test seam.

2. **Prefer real dependencies we control**
   - If the dependency is part of the system or under organizational control, do not mock it by default.
   - Use real databases, queues, caches, storage backends, and service dependencies where practical.

3. **Mock only dependencies we do not control**
   - Third-party APIs, payment gateways, telecom providers, cloud-hosted systems not practical to provision locally, remote OAuth/OIDC providers not owned by the system, other truly external integrations.

4. **Use testcontainers for infrastructure**
   - When a service requires a database, broker, cache, object store, or comparable runtime dependency, prefer **testcontainers** over mocks or fake in-memory substitutes unless the in-memory substitute is the actual intended runtime mode.

5. **Prefer deterministic integration tests over broad mocking**
   - The more a test resembles production behavior while remaining deterministic, the better.

6. **Each test must justify its value**
   - A test should guard against a real regression.
   - Avoid low-signal tests that merely execute code without meaningful assertions.

---

## When This Skill Activates

This protocol runs whenever the agent:

- writes new tests
- modifies existing tests
- reviews a pull request involving tests
- fixes broken tests
- investigates flaky tests
- runs a test suite
- adds new service/database/resource dependencies
- adds UI flows in any frontend framework
- changes public behavior that should affect test coverage

---

## Required Reasoning Workflow

Before writing or changing tests, perform these steps.

### 1. Identify the unit of behavior

Determine what is being verified: domain behavior, API behavior, persistence behavior, authorization behavior, validation behavior, concurrency behavior, UI interaction behavior, rendering behavior, integration behavior, or end-to-end flow.

### 2. Enumerate cases

Reason through:

- success paths
- invalid inputs
- boundary values
- empty/nil states
- duplicate/repeated operations
- permission/authorization failures
- timeout/cancellation behavior
- partial failure scenarios
- concurrency or race-sensitive behavior
- idempotency where applicable
- recovery/retry behavior where applicable

### 3. Choose the correct test level

Choose the smallest test level that still provides real confidence:

- **unit test**
- **integration test**
- **component/service test**
- **UI/widget test**
- **end-to-end test**

Do not force everything into unit tests if integration tests are the correct tool.

### 4. Verify determinism

The test must not depend on:

- wall-clock time without control
- random behavior without fixed seeds
- real internet access
- shared mutable global state
- unordered assertions where order matters
- external process state not owned by the test
- environment-specific assumptions without explicit setup

---

## Mocking Policy

### Allowed uses of mocks/stubs/fakes

Mocks are allowed only when:

1. The dependency is external and not controlled by the system.
2. The real dependency is prohibitively expensive or impossible to run in tests.
3. The test specifically validates reactions to edge-case responses from an external provider.
4. The boundary itself is the subject under test, and a narrowly scoped fake is the cleanest seam.

### Disallowed uses of mocks

Do not mock:

- internal repositories you own, if a real DB can be run
- internal services you own, if the integration can be exercised
- business-domain components solely to make tests easier
- persistence layers just to avoid using testcontainers
- code paths where the mock reproduces most of the real implementation anyway

### Preference order

1. real dependency in isolated test environment
2. testcontainers-managed dependency
3. lightweight local fake with faithful semantics
4. mock/stub only for external or uncontrollable systems

---

## General Standards for All Languages

### 1. Deterministic

Control time, randomness, ordering, IO, and environment state.

### 2. Isolated

A test must not require another test to run first.

### 3. Behavior-oriented

Assert results, outputs, state transitions, rendered UI, and persisted effects.

### 4. Diagnostic

When a test fails, the reason should be obvious.

### 5. Minimal but sufficient

Avoid bloated setup and redundant assertions, but do not sacrifice confidence.

### 6. Regression-resistant

The test should fail if the underlying behavior is broken in a meaningful way.

---

## Flakiness Prevention Protocol

### Disallowed by default

- arbitrary `sleep` calls to wait for conditions
- non-deterministic timing assumptions
- dependence on execution order between tests
- port collisions from unmanaged local services
- assertions against unstable string formatting unless contractually defined
- reliance on shared machine state
- hidden global caches not reset between tests

### Preferred alternatives

- polling with timeout for eventual consistency
- controlled fake clock when appropriate
- explicit synchronization hooks
- containerized dependencies
- unique resource names per test
- retry-free deterministic setup

Flaky tests are correctness issues, not minor nuisances.

---

## Mutation-Thinking Requirement

Before concluding test work, pressure-test the suite:

- If I invert this condition, will the test fail?
- If I remove this persistence step, will the test fail?
- If I skip this authorization check, will the test fail?
- If I return a zero/default value, will the test fail?
- If I publish the wrong event or no event, will the test fail?
- If I break tenant isolation, will the test fail?

If the answer is no, the test is weak and must be improved.

---

## Test Review Protocol

When reviewing tests, inspect for:

1. incorrect use of mocks
2. over-coupling to implementation details
3. missing negative cases
4. missing boundary cases
5. flaky timing assumptions
6. unverified side effects
7. poor naming
8. hidden shared state
9. non-diagnostic assertions
10. failure to exercise critical branches
11. UI tests that only assert presence without behavior
12. repository/service tests that should have used real infra

---

## Self-Critique Loop

For important or non-trivial changes:

1. identify required behaviors and risks
2. write or improve tests
3. challenge the tests with mutation thinking
4. run the tests
5. inspect failures and weak points
6. strengthen tests where necessary
7. rerun until confidence is high

This loop is mandatory for business-critical logic, persistence logic, authorization, money movement, workflow engines, and user-facing submission flows.

---

## Anti-Patterns

Avoid:

- mocking internal dependencies to avoid proper integration tests
- writing tests that mirror implementation line-by-line
- testing private helper functions instead of public behavior
- using sleeps instead of synchronization
- asserting too little
- asserting too much unrelated detail
- creating brittle snapshot/golden tests without reason
- writing tests that cannot fail for meaningful regressions
- using shared fixtures that make test intent obscure
- adding coverage without adding confidence
- weakening tests just to make CI green

---

## Definition of Done (Universal Checklist)

- [ ] behavior under test is explicit
- [ ] test level is appropriate
- [ ] happy path is covered
- [ ] failure paths are covered
- [ ] boundary cases are covered
- [ ] tests are deterministic
- [ ] tests are isolated
- [ ] assertions are meaningful
- [ ] failures are diagnostic
- [ ] the test would fail for a real regression
- [ ] unnecessary mocks were not introduced

---

## Output Expectations

When test work is complete, the agent must explain:

1. what behavior is being tested
2. why the chosen test level is correct
3. why mocks were or were not used
4. what edge cases were covered
5. what risks remain untested, if any

Be transparent when coverage is partial.

---

## Self-Update Protocol

**WHEN to update:**

- Core testing philosophy or principles change
- New patterns or anti-patterns emerge from project experience
- Framework conventions evolve

**HOW to update:**

1. Edit this SKILL.md using the Edit tool
2. Increment `version` field
3. Update `last_updated` to current date
4. Modify affected sections
5. Preserve this self-update protocol section

**WHEN NOT to update:**

- One-off project-specific decisions
- Temporary debugging sessions
