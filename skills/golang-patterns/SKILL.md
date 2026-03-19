---
name: golang-patterns
description: Idiomatic Go patterns using the Frame framework (github.com/pitabwire/frame), Connect RPC, and pitabwire/util conventions. Use when writing, reviewing, refactoring, or scaffolding Go code. Enforces three-layer architecture (handlers/business/repository), Frame abstractions for all infrastructure (database, cache, queue, HTTP, logging, telemetry), data.BaseModel for all models, datastore.BaseRepository for all repositories, util.Log(ctx) for all logging, and Connect RPC for all APIs. Also use when creating new Go projects or services (Frame blueprint scaffolding).
version: "2.0"
last_updated: "2026-03-13"
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
| HTTP client | `svc.HTTPClientManager().Client(ctx)` |
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

---

## Checklist Before Committing

**Infrastructure:**
- [ ] No `&http.Client{}` or `http.DefaultClient`
- [ ] No `nats.Connect()`, `sql.Open()`, `redis.NewClient()`
- [ ] No `log.Println()`, `log.Fatalf()`, `slog`, `fmt.Printf()` for logging

**Code:**
- [ ] All models embed `data.BaseModel` with `TableName()` method
- [ ] All repositories use `datastore.BaseRepository` or raw pool with interface
- [ ] Three-layer architecture: handlers -> business -> repository
- [ ] All errors wrapped with context (`fmt.Errorf("...: %w", err)`)
- [ ] Using `util.IDString()` for ID generation

**Quality:**
- [ ] `golangci-lint run` passes
- [ ] `go test -race ./...` passes
