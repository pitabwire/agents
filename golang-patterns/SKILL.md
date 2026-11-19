---
name: golang-patterns
description: Idiomatic Go patterns using the Frame framework (github.com/pitabwire/frame), Connect RPC, and pitabwire/util conventions. Use when writing, reviewing, refactoring, or scaffolding Go code. Enforces three-layer architecture (handlers/business/repository), Frame abstractions for all infrastructure (database, cache, queue, HTTP, logging, telemetry), client-level HTTP timeouts (never per-call micro-budgets), data.BaseModel for all models, datastore.BaseRepository for all repositories, util.Log(ctx) for all logging, and Connect RPC for all APIs. Also use when creating new Go projects or services (Frame blueprint scaffolding).
version: "2.5"
last_updated: "2026-07-22"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update:**
1. Go language version changes introduce new idioms
2. Frame framework API changes affect recommended patterns
3. Connect RPC conventions change
4. Project structure conventions evolve
5. New anti-patterns are discovered

**HOW to update:**
1. Edit this SKILL.md using the Edit tool
2. Increment `version` in frontmatter
3. Update `last_updated` to current date
4. Update affected sections and reference files
5. Do NOT remove this self-update protocol section

---

## Reference Files

Read these on-demand when working in the corresponding area:

| Area | File | When to read |
|------|------|-------------|
| Frame service init, async processing (events/queue/workerpool) | [references/frame-architecture.md](references/frame-architecture.md) | Setting up services, choosing async patterns |
| Connect RPC handlers, clients, streaming, error codes | [references/connect-rpc.md](references/connect-rpc.md) | Implementing or consuming APIs |
| BaseModel, BaseRepository, custom queries | [references/models-repositories.md](references/models-repositories.md) | Defining models or data access |
| Logging, tracing, metrics with util.Log and telemetry | [references/observability.md](references/observability.md) | Adding logging, tracing, or metrics |
| HTTP client patterns with frame | [references/http-client.md](references/http-client.md) | Making HTTP requests or creating API clients |
| Frame blueprint, project structure, asset files | [references/scaffolding.md](references/scaffolding.md) | Creating new projects or services |

---

## Three-Layer Architecture (MANDATORY)

```
Handler (Connect RPC) → Business Logic → Repository (Data)
        ↓                    ↓                ↓
   Validation          Domain Rules       Database
   Serialization       Event Emission     Queries
   Logging/Tracing     Logging/Metrics    Logging
```

- **Handlers**: validation, serialization, Connect error mapping. No business logic.
- **Business**: domain rules, orchestration, event emission.
- **Repository**: data access only. Always behind an interface.

---

## Scaffolding New Projects

Use **Frame blueprint** for new projects:

```bash
go install github.com/pitabwire/frame/cmd/frame@latest

frame blueprint --name my-service --module github.com/org/my-service \
    --with-datastore --with-cache --with-queue --with-auth
```

This generates the full project structure with correct conventions. See [references/scaffolding.md](references/scaffolding.md) for all options and post-generation steps.

For manual creation (without blueprint), copy asset files from `golang-patterns/assets/`.

---

## Mandatory Rules

These rules apply to ALL Go code. Violations fail code review.

### 0. Reuse before implementation

Inspect the Go standard library, Frame, pitabwire/util, generated Connect/protobuf code, existing project packages, and `/home/j/code/antinvestor/common` before writing new functionality.

- Use the existing implementation when it meets correctness, security, performance, and maintenance requirements.
- Configure, compose, or add a thin adapter around library APIs instead of copying or recreating their behavior.
- Do not hand-roll protocols, serialization, authentication, retry/backoff, concurrency primitives, validation, IDs, infrastructure clients, or collection helpers already provided by these libraries.
- Add a third-party module only after confirming existing dependencies do not provide the capability and the module is maintained, compatible, licensed appropriately, and cheaper to own than custom code.
- Implement custom behavior only for a verified gap; document why available libraries are insufficient and keep the implementation minimal and thoroughly tested.

For Antinvestor services, inspect the current `common` source and selected module version. Start with:

| Need | Existing capability to inspect |
|------|--------------------------------|
| Service targets, client configuration, OpenAPI/OPL handlers | `github.com/antinvestor/common` |
| HTTP, Connect, gRPC, OAuth2/private-key JWT, workload API transport | `github.com/antinvestor/common/connection` and `connection/options` |
| Connect authentication, partition metadata, request/response logging | `github.com/antinvestor/common/interceptors` |
| Permission descriptors, manifests, procedure maps | `github.com/antinvestor/common/permissions` and generated `common/v1` types |
| Audit context, clients, interceptors, HTTP middleware | `github.com/antinvestor/common/audit` |
| Service Makefiles, Buf setup, shared build targets | `Makefile.common` and `templates/` |

Use this table only to route discovery; verify exported APIs in the current checkout before choosing or replacing them.

### 1. Always use Frame abstractions

| Need | Use | Never |
|------|-----|-------|
| Database | `frame.WithDatastore()` + `datastore.BaseRepository` | `sql.Open()`, raw `database/sql` |
| Cache | `frame.WithCacheManager()` | `redis.NewClient()` |
| Queue | `frame.WithRegisterPublisher/Subscriber()` | `nats.Connect()` |
| HTTP client | `svc.HTTPClientManager().Client(ctx)` | `&http.Client{}`, `http.DefaultClient` |
| Logging | `util.Log(ctx)` | `log.Println()`, `slog`, `fmt.Printf()` |
| Tracing | `telemetry.StartSpan()` | External tracing libs |
| API | Connect RPC | REST for service-to-service |

### 2. All models embed data.BaseModel

```go
type Job struct {
    data.BaseModel `gorm:"embedded"`
    // Custom fields only — BaseModel provides ID, TenantID, PartitionID, CreatedAt, ModifiedAt, DeletedAt
    ProjectID string    `gorm:"column:project_id;not null"`
    Status    JobStatus `gorm:"column:status;not null"`
}

func (Job) TableName() string { return "jobs" }
```

Never define `ID`, `TenantID`, `CreatedAt`, `ModifiedAt`, or `DeletedAt` manually.

### 3. All repositories use BaseRepository or interfaces

```go
type jobRepository struct {
    datastore.BaseRepository[*models.Job]
}

func NewJobRepository(dbPool pool.Pool) JobRepository {
    return &jobRepository{
        BaseRepository: datastore.NewBaseRepository[*models.Job](
            context.Background(), dbPool, nil,
            func() *models.Job { return &models.Job{} },
        ),
    }
}
```

Use raw `pool.Pool` only for complex aggregations/joins not supported by BaseRepository.

### 4. All logging uses util.Log(ctx)

```go
log := util.Log(ctx)
log.Info("creating profile", "email", req.Email)
log.WithError(err).Error("failed to create profile")
```

### 5. All errors wrapped with context

```go
return nil, fmt.Errorf("create profile: %w", err)
```

### 6. Use util for common operations

```go
id := util.IDString()                          // ID generation
token := util.RandomAlphaNumericString(32)     // Random strings
defer util.CloseAndLogOnError(ctx, f, "msg")   // Deferred close
```

### 7. Timeouts live on clients — never per-call micro-budgets

**Set outbound deadlines once when constructing HTTP/Connect clients.** Handlers and business methods pass `req.Context()` (or the parent context) and let the client enforce the timeout (Frame default retries still apply).

```go
// CORRECT — construction time
hydraHTTP := client.NewHTTPClient(context.Background(),
    client.WithHTTPTimeout(2*time.Second),
)
// CORRECT — call site
loginReq, err := hydra.GetLoginRequest(ctx, challenge)

// FORBIDDEN — per-hop budgets scattered through handlers
hydraCtx, cancel := context.WithTimeout(ctx, 120*time.Millisecond)
defer cancel()
loginReq, err := hydra.GetLoginRequest(hydraCtx, challenge)
```

| Rule | Detail |
|------|--------|
| One client per peer class | Hydra admin, Hydra public, external IdP, S2S — each with an explicit `WithHTTPTimeout` at init |
| Soft-fail is control flow | Optional steps: log + continue. Do not invent a nested timeout just to “soft-fail faster” |
| No `latency_budgets.go` maps | Do not maintain per-branch duration constants for every RPC in a request path |
| Rare `WithTimeout` OK | Migration job wall clock, test suite bounds, pure in-process caps — **not** peer I/O |

**Why this is mandatory:** micro-budgets (e.g. 120ms on Hydra) hard-fail real traffic when peers are briefly slow, produce opaque user errors, and create endless “raise the budget” churn. Client timeouts + soft-fail optional work fix the same class of gateway hangs without scattering deadlines.

Full write-up: [references/http-client.md](references/http-client.md) (“Timeouts: set once on the client”).

For external OAuth/OIDC (`oauth2.Exchange`, `oidc.NewProvider`), inject a timed Frame client via `oauth2.HTTPClient` in context — never rely on `http.DefaultClient`.

### 8. Queue consumers have no wall-clock budget

**Background event/queue work must run until the handler returns.** Do not wrap `Event.Execute` in `context.WithTimeout` “event budgets”.

| Delivery | Frame behaviour (v2.0.8+) |
|----------|---------------------------|
| HTTP push | `FRAME_QUEUE_PUSH_HANDLER_TIMEOUT` defaults to **0** (no timeout). `http.Server.WriteTimeout` auto-unbounds when push has no handler deadline. |
| Pull | Consumer processes the message without inventing per-event deadlines. |

```go
// FORBIDDEN — micro-managing queue work
ctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
defer cancel()
return e.authorizer.WriteTuples(ctx, tuples)

// CORRECT — use delivery context; peer clients enforce I/O limits
return e.authorizer.WriteTuples(ctx, tuples)
```

Optional: chunk large batch writes for progress/idempotency — that is **not** a timeout. Retries for transient peer errors (Unavailable) are fine; inventing a 25s/2m “handler budget” is not.

If a positive push SLA is truly required, set `FRAME_QUEUE_PUSH_HANDLER_TIMEOUT` explicitly — never paper over the default with `WithoutCancel` + per-handler timeouts.

### 9. Never ignore cancellation you created (or inherited)

**`context.WithoutCancel` is forbidden as a way to escape timeouts or cancelled parents** in application code.

Creating a cancellable context (or accepting a parent that can cancel) and then discarding that signal is dangerous: work continues after the caller assumed it stopped, resources leak, and partial side effects race with retries.

```go
// FORBIDDEN — invent a deadline then ignore it
ctx, cancel := context.WithTimeout(parent, 25*time.Second)
defer cancel()
workCtx := context.WithoutCancel(ctx)
doWork(workCtx)

// FORBIDDEN — paper over a short push/parent deadline
ctx, cancel := context.WithTimeout(context.WithoutCancel(parent), 2*time.Minute)

// FORBIDDEN — "fire and forget" by stripping cancel from the request context
emitCtx := context.WithoutCancel(req.Context())
eventsMan.Emit(emitCtx, key, payload)

// CORRECT — honour cancel; bound peers via HTTP clients only
doWork(parent)
if parent.Err() != nil {
    return parent.Err() // or soft-skip optional work
}
eventsMan.Emit(parent, key, payload)
```

| Situation | Do |
|-----------|-----|
| Parent cancelled mid-handler | Return / soft-skip; do not strip cancel to “finish anyway” |
| Queue work needs more time | Fix delivery (Frame push timeout = 0); do not `WithoutCancel` |
| Optional best-effort side effect | Soft-skip if `ctx.Err() != nil`; or emit to a queue that owns its own delivery context |
| Process startup / client construction | `context.Background()` is OK **only** for long-lived clients/managers, not for escaping a cancelled request |

`context.Background()` for **service init** and **HTTP client construction** is fine. Using it (or `WithoutCancel`) to override a live request or event context is not.

---

## Async Processing Decision

```
Need async? → Survives restart? → YES: Frame Queue
                                → NO: Bounded parallel? → YES: WorkerPool
                                                        → NO: Fast <100ms? → YES: Frame Events
                                                                           → NO: Frame Queue
```

See [references/frame-architecture.md](references/frame-architecture.md) for full decision tree and code patterns.

---

## Connect RPC Quick Reference

| Situation | Code |
|-----------|------|
| Resource not found | `connect.NewError(connect.CodeNotFound, err)` |
| Invalid input | `connect.NewError(connect.CodeInvalidArgument, err)` |
| Unauthenticated | `connect.NewError(connect.CodeUnauthenticated, err)` |
| Permission denied | `connect.NewError(connect.CodePermissionDenied, err)` |
| Already exists | `connect.NewError(connect.CodeAlreadyExists, err)` |

See [references/connect-rpc.md](references/connect-rpc.md) for handler, client, and streaming patterns.

---

## Testing Quick Reference

1. **Testcontainers** for real databases, queues, caches
2. **Test suites** extending `frametests.FrameBaseTestSuite`
3. **Table-driven tests** for comprehensive coverage
4. **Mock only external third-party APIs**
5. Use `mem://localhost` for in-memory queue testing

```go
type BaseTestSuite struct {
    frametests.FrameBaseTestSuite
    Cfg         config.Config
    ProfileRepo repository.ProfileRepository
}

func (s *BaseTestSuite) SetupSuite() {
    s.InitResourceFunc = initResources
    s.FrameBaseTestSuite.SetupSuite()
}

func initResources(_ context.Context) []definition.TestResource {
    return []definition.TestResource{
        testpostgres.NewWithOpts("service_test", definition.WithUserName("test")),
    }
}
```

> Full testing standards are in the `testing-core` and `testing-go` skills.

---

## Quick Reference Table

| Need | Use |
|------|-----|
| Logging | `util.Log(ctx)` |
| Tracing | `telemetry.StartSpan(ctx, name)` |
| Metrics | `telemetry.IncrementCounter()`, `telemetry.RecordDuration()` |
| API definitions | `github.com/antinvestor/apis` (ecosystem) or local `proto/` |
| Connect handler | `servicev1connect.NewServiceHandler()` |
| Connect client | `servicev1connect.NewServiceClient()` |
| Unique ID | `util.IDString()` |
| Random token | `util.RandomAlphaNumericString(32)` |
| Close resource | `defer util.CloseAndLogOnError(ctx, closer, "msg")` |
| HTTP client | `svc.HTTPClientManager().Client(ctx)` or `client.NewHTTPClient(..., WithHTTPTimeout(...))` at init |
| Outbound timeout | Client construction (`WithHTTPTimeout`) — not per-call `WithTimeout` |
| Async job | `workerpool.SubmitJob()` |
| Internal event | `eventsMan.Emit()` |
| Database | `datastore.BaseRepository` |
| Auth claims | `security.ClaimsFromContext()` |
| Test suite | `frametests.FrameBaseTestSuite` |

---

## Anti-Patterns (FORBIDDEN)

### Infrastructure

| Don't | Do Instead |
|-------|-----------|
| `&http.Client{}` | `svc.HTTPClientManager().Client(ctx)` |
| `http.DefaultClient` | Frame's HTTP client |
| `nats.Connect()` | `frame.WithRegisterPublisher/Subscriber()` |
| `sql.Open()` | `frame.WithDatastore()` |
| `redis.NewClient()` | `cache.Manager` |

### Logging

| Don't | Do Instead |
|-------|-----------|
| `log.Println()` | `util.Log(ctx).Info()` |
| `log.Fatalf()` | `util.Log(ctx).WithError(err).Fatal()` |
| `slog.Info()` | `util.Log(ctx).Info()` |
| `fmt.Printf()` for logging | `util.Log(ctx).Debug()` |

### Models & Repos

| Don't | Do Instead |
|-------|-----------|
| Manual `ID string` field | Embed `data.BaseModel` |
| Manual `TenantID` field | Embed `data.BaseModel` |
| Repository without interface | Define interface + struct |
| SQL inline in business logic | Create repository method |

### Architecture

| Don't | Do Instead |
|-------|-----------|
| Business logic in handlers | Move to business layer |
| Raw goroutines for critical work | `workerpool.SubmitJob()` |
| External API in Frame Events | Use Frame Queue |
| `internal/` for shared code | `pkg/` for shared packages |
| `panic` for errors | Return errors |
| REST for service-to-service | Connect RPC |

### Timeouts & outbound I/O

| Don't | Do Instead |
|-------|-----------|
| `context.WithTimeout` around every Hydra/RPC/HTTP hop | `client.WithHTTPTimeout` (or common Connect client options) at client construction |
| `latency_budgets.go` / per-branch ms constants for each step | One timeout constant per peer client; soft-fail optional steps in control flow |
| Nested `hydraCtx` / `profileCtx` / `tenCtx` budgets on one request | Pass `req.Context()`; let the client deadline fire |
| Raise micro-budgets to “fix” production timeouts | Fix peer latency, cache, or soft-fail; keep client timeout as the real ceiling |
| `oauth2.Exchange` / IdP calls on `http.DefaultClient` | Inject timed Frame client via `oauth2.HTTPClient` at provider setup |
| Hand-rolled retry loops next to every call | Frame client default retry policy / client-level options |
| `WithTimeout` around queue `Event.Execute` / “event budgets” | Let push/pull run to completion; bound only outbound clients |
| `WithoutCancel` after `WithTimeout` / to escape a cancelled parent | Honour cancel; fix the real deadline source (client timeout, Frame push = 0) |
| `WithoutCancel` + new timeout as “detached budget” | Same anti-pattern — you still invent a wall clock and ignore the parent |
| Stripping cancel so optional work “always runs” | Soft-skip when `ctx.Err() != nil`, or enqueue work that has its own delivery context |

**Reference implementation:** `service-authentication` `apps/default/service/handlers/client_timeouts.go` (construction-only constants) and `providers/http_client.go` (IdP client injection).

---

## Checklist Before Committing

**Infrastructure:**
- [ ] No `&http.Client{}` or `http.DefaultClient`
- [ ] No `nats.Connect()`, `sql.Open()`, `redis.NewClient()`
- [ ] No `log.Println()`, `log.Fatalf()`, `slog`, `fmt.Printf()` for logging
- [ ] Outbound HTTP/Connect clients have timeouts set at construction (not per-call micro-budgets)
- [ ] No new per-handler `context.WithTimeout` around peer I/O (Hydra, S2S, external IdP)
- [ ] No wall-clock budgets on queue/event handlers (`Event.Execute`); Frame push default is unbounded
- [ ] No `context.WithoutCancel` to escape request/event cancellation or pair with artificial timeouts

**Code:**
- [ ] Existing standard-library, Frame, util, generated-code, and project capabilities were reused before adding custom code
- [ ] `/home/j/code/antinvestor/common` was inspected for existing service functionality
- [ ] Any custom replacement for library functionality has a documented compatibility or correctness gap
- [ ] All models embed `data.BaseModel` with `TableName()` method
- [ ] All repositories use `datastore.BaseRepository` or raw pool with interface
- [ ] Three-layer architecture: handlers -> business -> repository
- [ ] All errors wrapped with context (`fmt.Errorf("...: %w", err)`)
- [ ] Using `util.IDString()` for ID generation
- [ ] Optional steps soft-fail via control flow (log + continue), not nested deadline budgets

**Quality:**
- [ ] `golangci-lint run` passes
- [ ] `go test -race ./...` passes
