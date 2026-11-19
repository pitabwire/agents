# Frame Architecture Reference

## Table of Contents

1. [Service Initialization](#service-initialization)
2. [Setup vs Runtime (Hard Split)](#setup-vs-runtime-hard-split)
3. [Frame Components Table](#frame-components-table)
4. [Async Processing Decision Tree](#async-processing-decision-tree)
5. [Frame Events Pattern](#frame-events-pattern)
6. [Frame Queue Pattern](#frame-queue-pattern)
7. [WorkerPool Pattern](#workerpool-pattern)
8. [Swappable Infrastructure](#swappable-infrastructure)

---

## Service Initialization

Canonical production shape: **setup early-exit**, then **runtime-only wiring**.

```go
func main() {
    tmpCtx := context.Background()
    cfg, err := config.LoadWithOIDC[appconfig.Config](tmpCtx)
    if err != nil {
        util.Log(tmpCtx).WithError(err).Fatal("failed to load configuration")
    }

    ctx, svc := frame.NewServiceWithContext(tmpCtx,
        frame.WithConfig(&cfg),
        frame.WithDatastore(),
    )
    defer svc.Stop(ctx)

    // Always register migrate on the setup registry.
    svc.Setup().RegisterFunc(setup.NameMigrate, func(ctx context.Context) error {
        return repository.Migrate(ctx, svc.DatastoreManager(), cfg.GetDatabaseMigrationPath())
    })

    // ── Setup Job path (Cloud Run Job argv ["setup"] / DO_SETUP) ──
    // One-time work only. No peer clients, HTTP, or queue consumers.
    sd := mypb.File_….Services().ByName("MyService")
    if frame.ShouldRunSetup(&cfg) {
        svc.Init(ctx, frame.WithPermissionRegistration(sd))
        if err := svc.RunSetupForProcess(ctx, &cfg); err != nil {
            util.Log(ctx).WithError(err).Fatal("setup plan failed")
        }
        return
    }

    // ── Runtime path (Cloud Run Service) ──
    // Requests + queue work only. Never migrate or re-register permissions.
    connectHandler := setupConnectServer(ctx, svc)
    svc.Init(ctx,
        frame.WithHTTPHandler(connectHandler),
        frame.WithRegisterEvents(/* durable handlers */),
        // optional: publishers/subscribers
    )
    if err := svc.Run(ctx, ""); err != nil {
        util.Log(ctx).WithError(err).Fatal("failed to run service")
    }
}
```

---

## Setup vs Runtime (Hard Split)

| Mode | Trigger | Process role |
|------|---------|--------------|
| **Setup** | Job `args = ["setup"]`, `DO_SETUP=true` | Ephemeral bootstrap; exits when plan finishes |
| **Runtime** | Long-lived Service | Serves Connect/HTTP and consumes queues |

### What belongs in setup

| Step | Mechanism |
|------|-----------|
| Schema migrate | `svc.Setup().RegisterFunc(setup.NameMigrate, …)` |
| Permission manifests | `frame.WithPermissionRegistration(sd)` **only inside** `if ShouldRunSetup` |
| Other one-time steps | Named steps on `svc.Setup()`; run via `RunSetupForProcess` |

### What belongs in runtime

| Work | Mechanism |
|------|-----------|
| API traffic | Connect handlers + interceptors |
| Durable async | `WithRegisterEvents` / queue subscribers |
| Domain reapers / periodic cleanup | Bounded loops **only if** they process **existing** domain state (not bootstrap) |

### Forbidden

| Anti-pattern | Why |
|--------------|-----|
| Migrate or POST permissions on Service start | Couples deploy traffic to bootstrap; races multi-replica starts |
| `WithPermissionRegistration` on the runtime `Init` | Blurs modes; permissions are setup-plan only (Frame ≥ v2.1) |
| Building OAuth clients / full handler graph **before** `ShouldRunSetup` | Setup Jobs need DB only; peer deps make Jobs fragile |
| Second `WithPermissionRegistration` call | Overwrites the single `permissions` setup step |
| Hand-rolled curl/scripts for register/migrate | Drift from the Job plan; use `gcloud run jobs execute {app}-migrate` |
| Ad-hoc goroutines for “bootstrap once” | Unreliable; use setup steps or queue-driven workers |

### Deploy contract (cloud.deployment)

```hcl
migrate_args             = ["setup"]
permissions_registration = true   # injects PERMISSIONS_REGISTRATION_URL
migrate_execute          = false  # cloudrun-ship / ops execute the Job
```

Ship flow: **build image → update Job → execute setup → update Service**. Runtime never re-does setup.

---

## Frame Components Table

| Need | Frame Abstraction | Backing Infrastructure | Not |
|------|-------------------|----------------------|-----|
| API development | Connect RPC | — | REST/gRPC directly |
| HTTP requests | `client.Manager` | — | `net/http` directly |
| Quick async jobs | `workerpool` | — | goroutines directly |
| Internal events | `events.Manager` | NATS JetStream | channels |
| Long-running jobs | `queue` (pub/sub) | NATS JetStream | events |
| Database | `datastore.Manager` | PostgreSQL | raw `database/sql` |
| Caching | `cache.Manager` | Valkey | external redis client |
| i18n | `localization.Manager` | — | external i18n libs |
| Auth/authz | `security.Manager` | OAuth2/OIDC | external JWT libs |
| Logging | `util.Log(ctx)` | — | `log` or `slog` directly |
| Tracing | `telemetry` package | OpenTelemetry | external tracing libs |
| Metrics | `telemetry` package | OpenTelemetry | external metrics libs |

> **CRITICAL:** Always use the Frame abstraction column, never the backing infrastructure directly. Frame manages connection pooling, lifecycle, observability, and consistent error handling.

---

## Async Processing Decision Tree

```
START: Need to process work asynchronously?
│
├─► Does the work need to be distributed to OTHER services/processes?
│   ├─► YES → Use FRAME QUEUE (pub/sub)
│   └─► NO → Continue...
│
├─► Is this ONE-OFF async work that should execute in parallel?
│   ├─► YES → Use WORKERPOOL
│   └─► NO → Continue...
│
├─► Is this FAST ASYNC work (< 100ms, no blocking I/O)?
│   ├─► YES → Use FRAME EVENTS
│   └─► NO → Reconsider: This likely needs Frame Queue
│
└─► END
```

### When to use each

| Abstraction | Use when | Never use for |
|-------------|----------|---------------|
| **WorkerPool** | Bounded parallelism, streaming results, batch operations, result pipes | Work surviving restarts, external service consumption, long-running external tasks |
| **Frame Events** | Fast async (<100ms), event chaining, internal DB operations, status updates | External API calls, long-running tasks, cross-service work, durable messaging |
| **Frame Queue** | External consumption, long-running external deps, durability needed, cross-service messaging | Simple internal async, same-process-only work, fast DB operations |

---

## Frame Events Pattern

```go
// events/notification_save.go
package events

const NotificationSaveEvent = "notification.save"

type NotificationSave struct {
    repo NotificationRepository
}

func NewNotificationSave(repo NotificationRepository) *NotificationSave {
    return &NotificationSave{repo: repo}
}

func (e *NotificationSave) Name() string       { return NotificationSaveEvent }
func (e *NotificationSave) PayloadType() any    { return &Notification{} }

func (e *NotificationSave) Validate(ctx context.Context, payload any) error {
    _, ok := payload.(*Notification)
    if !ok {
        return errors.New("invalid payload type")
    }
    return nil
}

func (e *NotificationSave) Execute(ctx context.Context, payload any) error {
    notification := payload.(*Notification)
    return e.repo.Save(ctx, notification) // Fast DB operation only
}

// Registration in main.go
svc.Init(ctx,
    frame.WithRegisterEvents(
        events.NewNotificationSave(notificationRepo),
    ),
)

// Usage
eventsMan.Emit(ctx, events.NotificationSaveEvent, notification)
```

---

## Frame Queue Pattern

```go
// queues/message_to_send.go
package queues

type MessageToSend struct {
    emailClient EmailClient
}

func NewMessageToSend(client EmailClient) queue.SubscribeWorker {
    return &MessageToSend{emailClient: client}
}

func (m *MessageToSend) Handle(ctx context.Context, headers map[string]string, payload []byte) error {
    err := m.emailClient.Send(ctx, headers, payload)
    if err != nil {
        return err // Return error for retry
    }
    return nil
}

// config/config.go
type Config struct {
    config.ConfigurationDefault
    QueueEmailSMTPDequeueName string `env:"QUEUE_EMAIL_SMTP_DEQUEUE_NAME" envDefault:"notifications_to_email"`
    QueueEmailSMTPDequeueURI  string `env:"QUEUE_EMAIL_SMTP_DEQUEUE_URI" envDefault:"nats://localhost:4222"`
}

// Registration in main.go
messageHandler := queues.NewMessageToSend(emailClient)

svc.Init(ctx,
    frame.WithRegisterSubscriber(
        cfg.QueueEmailSMTPDequeueName,
        cfg.QueueEmailSMTPDequeueURI,
        messageHandler,
    ),
)
```

---

## WorkerPool Pattern

```go
// Bounded concurrency with result pipes
func (nb *NotificationBusiness) Release(ctx context.Context, ids []string) (workerpool.JobResultPipe[*ReleaseResponse], error) {
    job := workerpool.NewJob(func(ctx context.Context, resultPipe workerpool.JobResultPipe[*ReleaseResponse]) error {
        var statuses []*NotificationStatus
        for _, id := range ids {
            status, err := nb.processNotification(ctx, id)
            if err != nil {
                return err
            }
            statuses = append(statuses, status)
        }
        return resultPipe.WriteResult(ctx, &ReleaseResponse{Statuses: statuses})
    })

    err := workerpool.SubmitJob(ctx, nb.workMan, job)
    if err != nil {
        return nil, err
    }
    return job, nil
}

// Streaming results consumption
func (nb *NotificationBusiness) Search(ctx context.Context, query string, consumer func([]*Notification) error) error {
    results, err := nb.repo.Search(ctx, query)
    if err != nil {
        return err
    }
    return workerpool.ConsumeResultStream(ctx, results, func(batch []*Notification) error {
        return consumer(batch)
    })
}
```

---

## Swappable Infrastructure

Frame abstractions allow changing backing infrastructure via configuration alone:

```go
// Production: NATS JetStream
QUEUE_URI=nats://localhost:4222?jetstream=true&stream_name=my-stream

// Testing: In-Memory Queue (no external dependencies)
QUEUE_URI=mem://localhost

// CI/CD (ephemeral)
QUEUE_URI=mem://localhost
```

**Testing without mocks:**

```go
func TestBusinessLogic(t *testing.T) {
    cfg := TestConfig{
        QueueURI: "mem://localhost", // Just change URL - no mocks needed
    }
    ctx, svc := frame.NewServiceWithContext(t.Context(),
        frame.WithName("test"),
        frame.WithConfig(&cfg),
    )
    // Same production code paths exercised
}
```

**Benefits:**
- No mock maintenance for queue/cache/datastore clients
- Tests use actual frame code paths
- Environment-specific backends via config only
