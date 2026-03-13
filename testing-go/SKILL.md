---
name: testing-go
description: Go-specific testing standards enforcing BaseTestSuite inheritance, table-driven tests, testcontainers for owned infrastructure, real integration over mocks, race detection, and context-aware testing. Use when writing, modifying, reviewing, or running Go tests.
version: "1.0"
last_updated: "2026-03-13"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document must remain aligned with the Go testing conventions and infrastructure patterns used in this codebase.
>
> **Companion skill:** `testing-core` defines the universal testing philosophy. This skill adds Go-specific standards. Both skills apply when working with Go tests.

## Go Testing Defaults

### 1. Use test suites

Tests should use suites wherever practical, especially for service, repository, handler, and integration testing.

- Define suites that extend `BaseTestSuite`
- Centralize setup and teardown
- Centralize shared fixtures and helpers
- Keep individual tests focused on case definitions and assertions

Expected lifecycle methods:

- `SetupSuite` for shared container/resource bootstrapping when safe
- `SetupTest` for per-test isolation/reset
- `TearDownTest` / `TearDownSuite` for cleanup
- Suite helpers for common assertions and fixture creation

### 2. Table-driven tests by default

Use table-driven tests as the default pattern, especially for:

- validation logic
- authorization matrices
- transformation rules
- error mapping
- edge cases
- API request/response variants
- repository queries with different filters

Avoid forcing a table when a single expressive test is clearer, but default toward tables.

### 3. Arrange / Act / Assert

Each test must be clearly structured. Move setup noise into suite helpers where possible.

### 4. Name tests by behavior

Good:

- `TestCreateLoan_RejectsMissingNationalID`
- `TestListRepayments_ReturnsOnlyTenantRecords`
- `TestSubmitApplication_PersistsAndPublishesEvent`
- `TestAuthorizeAdminAction_DeniesAgentRole`

Bad:

- `TestService`
- `TestValidation`
- `TestRepo2`

### 5. Explicit assertions

Assertions must communicate what was expected, what was observed, and why failure matters.

Bad:

```go
assert.True(t, ok)
```

Better:

```go
require.NoError(t, err)
require.Equal(t, expectedStatus, got.Status)
require.Len(t, records, 3)
```

### 6. Test concurrency explicitly

For concurrency-sensitive code, consider:

- race conditions
- deadlocks
- goroutine leaks
- duplicate execution
- ordering guarantees
- cancellation propagation

Use `go test -race`, repeated execution, contexts with cancellation, and explicit synchronization in tests.

### 7. Context-aware tests

If production code accepts `context.Context`, tests should validate:

- cancellation
- deadlines where relevant
- propagation into lower layers where behavior depends on context

---

## Infrastructure Testing Rules

### Databases and services

If the service uses a real database in production, prefer that database in tests via testcontainers.

| Production dependency | Test approach |
|----------------------|---------------|
| Postgres | Postgres container |
| MySQL | MySQL container |
| Redis | Redis container |
| NATS | NATS container |
| Kafka/Redpanda | Containerized broker |
| MinIO/S3-like | Local compatible container |

Do not replace a real DB with a mock repository for convenience.

### Container lifecycle

- One container per suite when state can be reliably reset
- One database/schema per test when isolation requires it
- Migrations applied as part of suite setup
- Deterministic seed/fixture creation
- Cleanup guarantees no cross-test contamination

### Data isolation

Use one or more of:

- transactional rollback per test
- schema recreation
- table truncation
- unique tenant IDs / namespaces / test IDs
- isolated DB names

---

## BaseTestSuite Expectations

- `BaseTestSuite` provides logger, context factory, temp resources, common cleanup hooks
- Specialized suites compose on top of it
- Service-specific suites own infrastructure setup
- Helpers create realistic fixtures, not arbitrary brittle objects

A good suite should:

- minimize duplication
- make test intent obvious
- make realistic setup easy
- keep case definitions concise
- avoid excessive magic

Avoid large monolithic suites that hide too much behavior.

---

## Test Case Minimums for Go Services

For any non-trivial service or handler, cover at least:

1. **happy path**
2. **validation failures**
3. **authorization failures**
4. **not found behavior**
5. **conflict/duplicate behavior**
6. **dependency failure behavior**
7. **transactionality / persistence correctness**
8. **tenant or scope isolation**
9. **idempotency where relevant**
10. **event/message side effects where relevant**
11. **context cancellation where relevant**
12. **serialization / contract correctness where relevant**

If any category does not apply, that must be a conscious decision, not an accidental omission.

---

## Execution

At minimum, consider running:

```bash
go test ./...
go test -race ./...
go test -count=10 ./...
```

Also consider:

- package-targeted runs for faster iteration
- coverage inspection
- integration-specific test targets
- leak detection tools if used by the repo

### Execution expectations

- Failures must be explained by root cause, not just repeated output
- Flaky behavior must be called out explicitly
- Test fixes must preserve intent, not merely make the suite pass
- Skipped tests should be justified, not casually introduced

---

## Definition of Done (Go Checklist)

In addition to the universal checklist from `testing-core`:

- [ ] suite-based structure used where appropriate
- [ ] extends `BaseTestSuite` where that is the project pattern
- [ ] table-driven cases used where appropriate
- [ ] real infra used via testcontainers where practical
- [ ] concurrency validated where relevant
- [ ] race-sensitive code tested with `-race`
- [ ] context cancellation tested where relevant

---

## Examples of Correct Preference

### Repository/service with Postgres

Preferred:

- start Postgres with testcontainers
- run migrations
- exercise real repository and service logic

Discouraged:

- mock repository methods for service tests if the repository is owned and practical to run

### External SMS gateway

Preferred:

- mock or stub the gateway client
- verify the service reacts correctly to success, timeout, malformed response, and provider failure

---

## Self-Update Protocol

**WHEN to update:**

- Go testing conventions or tooling change
- BaseTestSuite patterns evolve
- New infrastructure dependencies are introduced

**HOW to update:**

1. Edit this SKILL.md using the Edit tool
2. Increment `version` field
3. Update `last_updated` to current date
4. Modify affected sections
5. Preserve this self-update protocol section

**WHEN NOT to update:**

- One-off project-specific decisions
- Temporary debugging sessions
