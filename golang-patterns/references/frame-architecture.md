# Frame Architecture Reference

## Table of Contents

1. [Service Initialization](#service-initialization)
2. [Frame Components Table](#frame-components-table)
3. [Async Processing Decision Tree](#async-processing-decision-tree)
4. [Frame Events Pattern](#frame-events-pattern)
5. [Frame Queue Pattern](#frame-queue-pattern)
6. [WorkerPool Pattern](#workerpool-pattern)
7. [Swappable Infrastructure](#swappable-infrastructure)

---

## Service Initialization

```go
func main() {
    ctx := context.Background()

    cfg, err := config.LoadWithOIDC[appconfig.Config](ctx)
    if err != nil {
        util.Log(ctx).WithError(err).Fatal("failed to load configuration")
    }

    ctx, svc := frame.NewServiceWithContext(ctx,
        frame.WithName("service-name"),
        frame.WithConfig(&cfg),
        frame.WithRegisterServerOauth2Client(),
        frame.WithDatastore(),
        frame.WithCacheManager(),
        frame.WithHTTPHandler(handler),
    )

    svc.Init(ctx,
        frame.WithRegisterPublisher("queue-name", cfg.QueueURL),
        frame.WithRegisterSubscriber("queue-name", cfg.QueueURL, subscriptionHandler),
        frame.WithRegisterEvents(eventHandlers...),
    )

    if err := svc.Run(ctx, cfg.ServerPort); err != nil {
        util.Log(ctx).WithError(err).Fatal("failed to run service")
    }
}
```

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
