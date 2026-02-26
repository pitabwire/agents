---
name: golang-patterns
description: Idiomatic Go patterns, best practices, and conventions for building robust, efficient, and maintainable Go applications.
version: "1.0"
last_updated: "2026-02-26"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. Go language version changes introduce new idioms (generics improvements, iterator patterns, etc.)
2. Frame framework API changes affect recommended patterns
3. Connect RPC conventions change
4. Project structure conventions evolve
5. Testing, error handling, or concurrency best practices change
6. New anti-patterns are discovered

**HOW to update:**
1. Edit this file at `~/.agents/skills/golang-patterns/SKILL.md` using the Edit tool
2. Increment the `version` field in the frontmatter (e.g., "1.0" -> "1.1")
3. Update `last_updated` to today's date (YYYY-MM-DD)
4. Update the affected section(s) to match current best practices
5. Do NOT remove the self-update protocol section

**WHEN NOT to update:**
- Project-specific Go conventions that don't represent universal pattern changes
- Minor Go patch versions that don't affect patterns

---

# Go Development Patterns

## Activation

Apply these rules when writing, reviewing, or refactoring Go code.

---

## Project Structure

All applications follow this structure:

```
project/
├── apps/
│   ├── default/                    # Primary service
│   │   ├── cmd/main.go             # Entry point
│   │   ├── config/                 # Configuration structs
│   │   ├── service/
│   │   │   ├── handlers/           # Connect RPC handlers
│   │   │   ├── business/           # Business logic
│   │   │   ├── repository/         # Data access layer
│   │   │   ├── models/             # Domain models
│   │   │   └── events/             # Event handlers
│   │   ├── migrations/0001/        # Database migrations
│   │   ├── tests/                  # Integration tests
│   │   └── Dockerfile              # App-specific Dockerfile
│   └── secondary/                  # Additional services (same structure)
├── pkg/                            # Shared code across apps
│   ├── cryptoutil/                 # Encryption utilities
│   ├── dbutil/                     # Database utilities
│   └── errorutil/                  # Error handling
├── localization/                   # i18n files (messages.{lang}.toml)
├── .github/workflows/              # CI/CD workflows
├── .golangci.yaml                  # Linter configuration
├── go.mod
├── go.sum
└── Makefile
```

---

## Sample Files

Copy these sample files when creating new projects:

| File | Source |
|------|--------|
| Linter config | `~/.claude/skills/golang-patterns/samples/.golangci.yaml` |
| Dockerfile | `~/.claude/skills/golang-patterns/samples/Dockerfile` |
| Makefile | `~/.claude/skills/golang-patterns/samples/Makefile` |
| Lint workflow | `~/.claude/skills/golang-patterns/samples/workflows/golangci-lint.yml` |
| Test workflow | `~/.claude/skills/golang-patterns/samples/workflows/run_tests.yml` |
| Release workflow | `~/.claude/skills/golang-patterns/samples/workflows/release.yml` |
| Publish workflow | `~/.claude/skills/golang-patterns/samples/workflows/publish-release.yml` |

---

## Required Dependencies

```go
require (
    github.com/pitabwire/frame v0.x.x       // Server framework
    github.com/pitabwire/util v0.x.x        // Utility functions
    github.com/antinvestor/apis v0.x.x      // Shared API definitions (for antinvestor ecosystem)
)
```

> **Note on API definitions:** Projects within the antinvestor ecosystem use `github.com/antinvestor/apis` for shared proto definitions. Standalone projects may define protos locally in a `proto/` directory. Choose based on whether APIs are shared across repos or project-specific.

---

## Logging, Metrics, and Tracing

### Logging with util.Log(ctx)

**Always use `util.Log(ctx)` to get a logger with the current context.** This ensures logs are correlated with traces and include request metadata.

```go
import "github.com/pitabwire/util"

func (b *profileBusiness) Create(ctx context.Context, req *CreateRequest) (*Profile, error) {
    log := util.Log(ctx)
    
    log.Info("creating profile", "email", req.Email)
    
    profile, err := b.profileRepo.Create(ctx, req)
    if err != nil {
        log.WithError(err).Error("failed to create profile")
        return nil, fmt.Errorf("create profile: %w", err)
    }
    
    log.Info("profile created", "profile_id", profile.ID)
    return profile, nil
}
```

### Logging Levels

```go
log := util.Log(ctx)

// Debug - detailed information for debugging
log.Debug("processing item", "item_id", itemID, "step", "validation")

// Info - general operational information
log.Info("request processed", "duration_ms", duration.Milliseconds())

// Warn - warning conditions that don't stop execution
log.Warn("retry attempt", "attempt", 3, "max_attempts", 5)

// Error - error conditions (always include error)
log.WithError(err).Error("operation failed", "operation", "create_profile")
```

### Structured Logging

```go
log := util.Log(ctx)

// Add fields for context
log.WithField("user_id", userID).Info("user action")

// Multiple fields
log.WithFields(map[string]any{
    "order_id":    orderID,
    "total":       total,
    "item_count":  len(items),
}).Info("order placed")
```

### Telemetry (Metrics and Tracing)

Frame provides OpenTelemetry integration automatically. Use frame's telemetry package for custom instrumentation.

```go
import "github.com/pitabwire/frame/telemetry"

// Create a span for tracing
func (b *profileBusiness) ProcessOrder(ctx context.Context, order *Order) error {
    ctx, span := telemetry.StartSpan(ctx, "ProcessOrder")
    defer span.End()
    
    // Add attributes to span
    span.SetAttributes(
        attribute.String("order.id", order.ID),
        attribute.Int("order.item_count", len(order.Items)),
    )
    
    // Business logic...
    if err := b.validateOrder(ctx, order); err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, "validation failed")
        return err
    }
    
    span.SetStatus(codes.Ok, "")
    return nil
}

// Record metrics
func (b *profileBusiness) Create(ctx context.Context, req *CreateRequest) (*Profile, error) {
    start := time.Now()
    defer func() {
        telemetry.RecordDuration(ctx, "profile.create.duration", time.Since(start))
    }()
    
    // Increment counter
    telemetry.IncrementCounter(ctx, "profile.create.total")
    
    profile, err := b.profileRepo.Create(ctx, req)
    if err != nil {
        telemetry.IncrementCounter(ctx, "profile.create.errors")
        return nil, err
    }
    
    return profile, nil
}
```

### Observability Configuration

Frame auto-configures OpenTelemetry based on environment:

```go
type Config struct {
    config.ConfigurationDefault
    // OpenTelemetry settings from ConfigurationDefault:
    // - OpenTelemetryDisable bool
    // - OpenTelemetryTraceRatio float64 (sampling ratio)
}
```

Environment variables:
- `OTEL_EXPORTER_OTLP_ENDPOINT` - OTLP collector endpoint
- `OTEL_SERVICE_NAME` - Service name for traces
- `OTEL_TRACES_SAMPLER_ARG` - Sampling ratio (0.0-1.0)

---

## Connect RPC (Default API Protocol)

**Connect RPC is the default protocol for all API development.** API definitions are stored in `github.com/antinvestor/apis` (shared ecosystem) or locally in `proto/` (standalone projects).

### API Structure (github.com/antinvestor/apis)

```
github.com/antinvestor/apis/
├── go/
│   ├── common/v1/                  # Shared types
│   ├── notification/v1/            # Notification service APIs
│   │   ├── notification.pb.go
│   │   └── notificationv1connect/
│   │       └── notification.connect.go
│   ├── profile/v1/                 # Profile service APIs
│   │   ├── profile.pb.go
│   │   └── profilev1connect/
│   │       └── profile.connect.go
│   └── ...                         # Other service APIs
└── proto/                          # Proto source files
```

### Importing APIs

```go
import (
    "connectrpc.com/connect"
    
    // API types
    profilev1 "github.com/antinvestor/apis/go/profile/v1"
    notificationv1 "github.com/antinvestor/apis/go/notification/v1"
    
    // Connect clients/handlers
    "github.com/antinvestor/apis/go/profile/v1/profilev1connect"
    "github.com/antinvestor/apis/go/notification/v1/notificationv1connect"
)
```

### Implementing a Connect RPC Handler

```go
package handlers

import (
    "context"

    "connectrpc.com/connect"
    "github.com/pitabwire/util"
    profilev1 "github.com/antinvestor/apis/go/profile/v1"
    "github.com/antinvestor/apis/go/profile/v1/profilev1connect"
    "github.com/pitabwire/frame"
)

type ProfileServer struct {
    Service         *frame.Service
    profileBusiness business.ProfileBusiness
    profilev1connect.UnimplementedProfileServiceHandler
}

func NewProfileServer(svc *frame.Service, biz business.ProfileBusiness) *ProfileServer {
    return &ProfileServer{
        Service:         svc,
        profileBusiness: biz,
    }
}

// Unary RPC
func (s *ProfileServer) GetById(ctx context.Context,
    req *connect.Request[profilev1.GetByIdRequest]) (*connect.Response[profilev1.GetByIdResponse], error) {
    
    log := util.Log(ctx)
    log.Debug("getting profile", "id", req.Msg.GetId())
    
    profile, err := s.profileBusiness.GetByID(ctx, req.Msg.GetId())
    if err != nil {
        if frame.ErrorIsNotFound(err) {
            return nil, connect.NewError(connect.CodeNotFound, err)
        }
        log.WithError(err).Error("failed to get profile")
        return nil, connect.NewError(connect.CodeInternal, err)
    }
    
    return connect.NewResponse(&profilev1.GetByIdResponse{
        Data: profile.ToAPI(),
    }), nil
}

// Server streaming RPC
func (s *ProfileServer) Search(ctx context.Context,
    req *connect.Request[profilev1.SearchRequest],
    stream *connect.ServerStream[profilev1.SearchResponse]) error {
    
    log := util.Log(ctx)
    log.Info("searching profiles", "query", req.Msg.GetQuery())
    
    results, err := s.profileBusiness.Search(ctx, req.Msg)
    if err != nil {
        log.WithError(err).Error("search failed")
        return connect.NewError(connect.CodeInternal, err)
    }
    
    count := 0
    for {
        result, ok := results.ReadResult(ctx)
        if !ok {
            log.Info("search completed", "results_count", count)
            return nil
        }
        if result.IsError() {
            return connect.NewError(connect.CodeInternal, result.Error())
        }
        
        for _, profile := range result.Item() {
            count++
            if err := stream.Send(&profilev1.SearchResponse{
                Data: []*profilev1.ProfileObject{profile.ToAPI()},
            }); err != nil {
                return err
            }
        }
    }
}
```

### Registering Connect Handlers

```go
func main() {
    ctx := context.Background()
    
    cfg, err := config.LoadWithOIDC[appconfig.Config](ctx)
    if err != nil {
        log.Fatalf("load config: %v", err)
    }

    // Create service
    ctx, svc := frame.NewServiceWithContext(ctx,
        frame.WithName("profile-service"),
        frame.WithConfig(&cfg),
        frame.WithRegisterServerOauth2Client(),
        frame.WithDatastore(),
    )

    // Initialize business layer
    dbPool := svc.DatastoreManager().GetPool(ctx, datastore.DefaultPoolName)
    profileRepo := repository.NewProfileRepository(ctx, dbPool, svc.WorkManager())
    profileBiz := business.NewProfileBusiness(&cfg, profileRepo, svc.EventsManager())

    // Create Connect handler with authentication
    securityMan := svc.SecurityManager()
    authenticator := securityMan.GetAuthenticator(ctx)
    interceptors, _ := connectInterceptors.DefaultList(ctx, authenticator)

    profileServer := handlers.NewProfileServer(svc, profileBiz)
    _, connectHandler := profilev1connect.NewProfileServiceHandler(
        profileServer,
        connect.WithInterceptors(interceptors...),
    )

    // Register HTTP handler
    mux := http.NewServeMux()
    mux.Handle(profilev1connect.NewProfileServiceHandler(profileServer))

    svc.Init(ctx, frame.WithHTTPHandler(mux))

    if err := svc.Run(ctx, cfg.ServerPort); err != nil {
        log.Fatalf("run: %v", err)
    }
}
```

### Creating Connect Clients

```go
// Create client for calling other services
func NewNotificationClient(httpClient *http.Client, baseURL string) notificationv1connect.NotificationServiceClient {
    return notificationv1connect.NewNotificationServiceClient(
        httpClient,
        baseURL,
    )
}

// Usage in business layer
type profileBusiness struct {
    notificationCli notificationv1connect.NotificationServiceClient
}

func (b *profileBusiness) CreateWithWelcome(ctx context.Context, req *profilev1.CreateRequest) (*models.Profile, error) {
    log := util.Log(ctx)
    
    profile, err := b.profileRepo.Create(ctx, profileFromRequest(req))
    if err != nil {
        return nil, fmt.Errorf("create profile: %w", err)
    }
    
    // Call notification service
    _, err = b.notificationCli.Send(ctx, connect.NewRequest(&notificationv1.SendRequest{
        Recipient: profile.Email,
        Template:  "welcome",
    }))
    if err != nil {
        // Log but don't fail - notification is best-effort
        log.WithError(err).Warn("failed to send welcome notification")
    }
    
    return profile, nil
}
```

### Connect Error Codes

| Situation | Code |
|-----------|------|
| Resource not found | `connect.CodeNotFound` |
| Invalid input | `connect.CodeInvalidArgument` |
| Authentication required | `connect.CodeUnauthenticated` |
| Permission denied | `connect.CodePermissionDenied` |
| Already exists | `connect.CodeAlreadyExists` |
| Precondition failed | `connect.CodeFailedPrecondition` |
| Internal error | `connect.CodeInternal` |
| Unavailable | `connect.CodeUnavailable` |

### REST Endpoints (When Needed)

For cases requiring REST (webhooks, public APIs):

```go
func (s *ProfileServer) NewSecureRouterV1() *http.ServeMux {
    mux := http.NewServeMux()
    mux.HandleFunc("/user/info", s.RestUserInfo)
    mux.HandleFunc("/user/relations", s.RestListRelationships)
    return mux
}

func (s *ProfileServer) RestUserInfo(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    log := util.Log(ctx)
    
    claims := security.ClaimsFromContext(ctx)
    if claims == nil {
        http.Error(w, "unauthorized", http.StatusUnauthorized)
        return
    }
    
    profile, err := s.profileBusiness.GetBySubject(ctx, claims.GetSubject())
    if err != nil {
        log.WithError(err).Error("failed to get user info")
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(profile.ToAPI())
}
```

---

## Utility Functions (github.com/pitabwire/util)

**Always use util for common operations instead of implementing from scratch.**

```go
import "github.com/pitabwire/util"

// Logging (always use context-aware logger)
log := util.Log(ctx)
log.Info("message", "key", value)
log.WithError(err).Error("failed")

// ID generation
id := util.IDString()

// Random strings
token := util.RandomAlphaNumericString(32)
code := util.RandomNumericString(6)

// Deferred closing with error logging
defer util.CloseAndLogOnError(ctx, file, "failed to close file")

// Encryption
ciphertext, err := util.EncryptValue(aesKey, []byte(plaintext))
plaintext, err := util.DecryptValue(aesKey, ciphertext)
token := util.ComputeLookupToken(hmacKey, normalizedValue)

// Environment variables
dbURL := util.GetEnv("DATABASE_URL", "postgres://localhost/dev")
```

---

## Frame Framework (github.com/pitabwire/frame)

**Always use frame for all server applications.**

### Service Initialization

```go
func main() {
    ctx := context.Background()
    
    cfg, err := config.LoadWithOIDC[appconfig.Config](ctx)
    if err != nil {
        log.Fatalf("load config: %v", err)
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
        log.Fatalf("run: %v", err)
    }
}
```

### Frame Components

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

> **CRITICAL:** Always use the Frame abstraction column, never the backing infrastructure directly. Frame manages connection pooling, lifecycle, observability, and consistent error handling for all infrastructure.

---

## Async Task Processing: WorkerPool vs Events vs Queue

**This is the most critical decision in frame architecture. Use this section to determine the correct abstraction.**

### Decision Tree

```
START: Need to process work asynchronously?
│
├─► Does the work need to be distributed to OTHER services/processes?
│   │
│   ├─► YES → Use FRAME QUEUE (pub/sub)
│   │   • Build events that other services consume
│   │   • Notifications to be sent via external gateways
│   │   • Tasks requiring external consumption
│   │   • Messages that must survive application restarts
│   │
│   └─► NO → Continue...
│
├─► Is this ONE-OFF async work that should execute in parallel?
│   │
│   ├─► YES → Use WORKERPOOL
│   │   • Batch processing multiple items
│   │   • Parallel processing with bounded concurrency
│   │   • Streaming results processing
│   │   • Tasks that need result pipes/channels
│   │
│   └─► NO → Continue...
│
├─► Is this FAST ASYNC work (< 100ms, no blocking I/O)?
│   │
│   ├─► YES → Use FRAME EVENTS
│   │   • Database operations
│   │   • Event chaining (one event triggers another)
│   │   • Quick async tasks within the same application
│   │   • Status updates, persistence operations
│   │
│   └─► NO → Reconsider: This likely needs Frame Queue
│
└─► END
```

### Explicit Rules

#### **USE WORKERPOOL WHEN:**

1. **Bounded Parallelism Required**
   ```go
   // GOOD: Processing 1000 items with max 10 concurrent workers
   job := workerpool.NewJob(func(ctx context.Context, pipe workerpool.JobResultPipe[*Result]) error {
       for _, item := range items {
           // Process item
           pipe.WriteResult(ctx, result)
       }
       return nil
   })
   workerpool.SubmitJob(ctx, workMan, job)
   ```

2. **Streaming Results**
   ```go
   // GOOD: Processing streaming search results
   workerpool.ConsumeResultStream(ctx, results, func(batch []*Model) error {
       // Process batch
       return nil
   })
   ```

3. **Need Result Pipe/Channel**
   ```go
   // GOOD: Job needs to return results
   job := workerpool.NewJob(func(ctx context.Context, pipe workerpool.JobResultPipe[*Result]) error {
       result := processWork()
       return pipe.WriteResult(ctx, result)
   })
   ```

4. **Batch Operations**
   ```go
   // GOOD: Release 100 notifications at once
   func (nb *notificationBusiness) Release(ctx context.Context, req *ReleaseRequest) 
       (workerpool.JobResultPipe[*ReleaseResponse], error) {
       // Process batch
   }
   ```

**NEVER USE WORKERPOOL FOR:**
- ❌ Simple one-off goroutines (use `go func()` if no result needed)
- ❌ Work that needs to survive application restarts
- ❌ Work that needs to be consumed by external services
- ❌ Long-running tasks with external dependencies

#### **USE FRAME EVENTS WHEN:**

1. **Fast Async Work (< 100ms)**
   ```go
   // GOOD: Quick DB operations
   func (e *NotificationSave) Execute(ctx context.Context, payload any) error {
       notification := payload.(*Notification)
       return e.repo.Save(ctx, notification)  // Fast DB write
   }
   ```

2. **Event Chaining**
   ```go
   // GOOD: One event triggers another
   func (e *NotificationInRoute) Execute(ctx context.Context, payload any) error {
       // ... routing logic ...
       return event.eventMan.Emit(ctx, NotificationInQueueEvent, notification)
   }
   ```

3. **Internal Application Tasks**
   ```go
   // GOOD: Status updates, persistence
   eventsMan.Emit(ctx, NotificationStatusSaveEvent, nStatus)
   ```

**NEVER USE FRAME EVENTS FOR:**
- ❌ External API calls (use Frame Queue)
- ❌ Long-running tasks (use Frame Queue)
- ❌ Work that needs persistence across restarts (use Frame Queue)
- ❌ Work consumed by other services (use Frame Queue)

#### **USE FRAME QUEUE WHEN:**

1. **External Consumption Required**
   ```go
   // GOOD: Publish events for external consumers
   func (e *FrameEventEmitter) Emit(ctx context.Context, ...) error {
       err = e.qMan.Publish(ctx, e.subject, data, nil)
       return err
   }
   ```

2. **Long-Running Tasks with External Dependencies**
   ```go
   // GOOD: Sending email via SMTP
   func (ms *messageToSend) Handle(ctx context.Context, headers map[string]string, payload []byte) error {
       err := ms.emailSMTPCli.Send(ctx, headers, notification)
       // Handle retries, errors
       return err
   }
   ```

3. **Durability Required**
   ```go
   // GOOD: Register subscriber that survives restarts
   svc.Init(ctx,
       frame.WithRegisterSubscriber(
           cfg.QueueEmailSMTPDequeueName,
           cfg.QueueEmailSMTPDequeueURI,
           messageHandler,
       ),
   )
   ```

4. **Message Queuing Between Services**
   ```go
   // GOOD: Queue for external service to consume
   frame.WithRegisterPublisher(
       appnats.StreamBuildRequests,
       appnats.BuildRequestsPublisherURL(streamCfg),
   )
   ```

**NEVER USE FRAME QUEUE FOR:**
- ❌ Simple internal async work (use Frame Events)
- ❌ Work that only needs to run within the same process
- ❌ Work that completes in < 100ms with no external calls (use Frame Events)
- ❌ Direct NATS access (always use frame abstractions)

### Code Patterns

#### Pattern 1: Frame Events (Fast Async)

```go
// events/notification_save.go
package events

import (
    "context"
    "github.com/pitabwire/frame/events"
)

const NotificationSaveEvent = "notification.save"

type NotificationSave struct {
    repo NotificationRepository
}

func NewNotificationSave(repo NotificationRepository) *NotificationSave {
    return &NotificationSave{repo: repo}
}

func (e *NotificationSave) Name() string {
    return NotificationSaveEvent
}

func (e *NotificationSave) PayloadType() any {
    return &Notification{}
}

func (e *NotificationSave) Validate(ctx context.Context, payload any) error {
    _, ok := payload.(*Notification)
    if !ok {
        return errors.New("invalid payload type")
    }
    return nil
}

func (e *NotificationSave) Execute(ctx context.Context, payload any) error {
    notification := payload.(*Notification)
    // Fast DB operation only
    return e.repo.Save(ctx, notification)
}

// main.go registration
import "github.com/pitabwire/frame"

svc.Init(ctx,
    frame.WithRegisterEvents(
        events.NewNotificationSave(notificationRepo),
    ),
)

// Usage
import "github.com/pitabwire/frame/events"

eventsMan.Emit(ctx, events.NotificationSaveEvent, notification)
```

#### Pattern 2: Frame Queue (Long-Running External)

```go
// queues/message_to_send.go
package queues

import (
    "context"
    "github.com/pitabwire/frame/queue"
)

type MessageToSend struct {
    emailClient EmailClient
}

func NewMessageToSend(client EmailClient) queue.SubscribeWorker {
    return &MessageToSend{emailClient: client}
}

func (m *MessageToSend) Handle(ctx context.Context, headers map[string]string, payload []byte) error {
    // Long-running external API call
    err := m.emailClient.Send(ctx, headers, payload)
    if err != nil {
        // Return error for retry if retriable
        return err
    }
    return nil
}

// config/config.go
type Config struct {
    config.ConfigurationDefault
    QueueEmailSMTPDequeueName string `env:"QUEUE_EMAIL_SMTP_DEQUEUE_NAME" envDefault:"notifications_to_email"`
    QueueEmailSMTPDequeueURI  string `env:"QUEUE_EMAIL_SMTP_DEQUEUE_URI" envDefault:"nats://localhost:4222"`
}

// main.go registration
messageHandler := queues.NewMessageToSend(emailClient)

svc.Init(ctx,
    frame.WithRegisterSubscriber(
        cfg.QueueEmailSMTPDequeueName,
        cfg.QueueEmailSMTPDequeueURI,
        messageHandler,
    ),
)
```

#### Pattern 3: WorkerPool (Bounded Concurrency)

```go
// business/notification.go
package business

import (
    "context"
    "github.com/pitabwire/frame/workerpool"
)

type NotificationBusiness struct {
    workMan workerpool.Manager
    repo    NotificationRepository
}

// Release processes notifications with bounded concurrency
func (nb *NotificationBusiness) Release(ctx context.Context, ids []string) 
    (workerpool.JobResultPipe[*ReleaseResponse], error) {
    
    job := workerpool.NewJob(func(ctx context.Context, 
        resultPipe workerpool.JobResultPipe[*ReleaseResponse]) error {
        
        var statuses []*NotificationStatus
        for _, id := range ids {
            // Process each notification
            status, err := nb.processNotification(ctx, id)
            if err != nil {
                return err
            }
            statuses = append(statuses, status)
        }
        
        // Write results
        return resultPipe.WriteResult(ctx, &ReleaseResponse{
            Statuses: statuses,
        })
    })
    
    err := workerpool.SubmitJob(ctx, nb.workMan, job)
    if err != nil {
        return nil, err
    }
    
    return job, nil
}

// Search processes streaming results
func (nb *NotificationBusiness) Search(ctx context.Context, query string, 
    consumer func([]*Notification) error) error {
    
    results, err := nb.repo.Search(ctx, query)
    if err != nil {
        return err
    }
    
    return workerpool.ConsumeResultStream(ctx, results, func(batch []*Notification) error {
        return consumer(batch)
    })
}
```

### Common Misconceptions

| Misconception | Reality |
|---------------|---------|
| "Events and Queue are the same" | **NO**: Events are for fast internal work; Queue is for external/durable work |
| "WorkerPool is just for goroutines" | **NO**: WorkerPool provides bounded concurrency and result pipes; use `go func()` for simple fire-and-forget |
| "I should use Queue for everything" | **NO**: Queue adds overhead; use Events for internal fast work |
| "Events need retry logic" | **NO**: Frame Events execute immediately; Queue handles retries |
| "I can directly use NATS" | **NO**: Always use frame abstractions; never `nats.Connect()` |
| "WorkerPool is for background jobs" | **NO**: WorkerPool is for bounded parallelism; use Queue for background jobs that survive restarts |

### Anti-Patterns Summary

| Don't | Do Instead | Why |
|-------|------------|-----|
| Use `nats.Connect()` directly | Use `frame.WithRegisterPublisher/Subscriber()` | Frame manages lifecycle, pooling, observability |
| Use raw goroutines for bounded work | Use `workerpool.SubmitJob()` | Prevents resource exhaustion, provides observability |
| Use Events for external API calls | Use `frame.WithRegisterSubscriber()` | Events don't handle retries or external consumption |
| Use Queue for simple DB operations | Use `frame.WithRegisterEvents()` | Queue adds unnecessary overhead |
| Mix event and queue patterns | Choose ONE based on decision tree | Each has specific semantics |
| Create direct NATS JetStream context | Use frame queue manager | Frame abstracts connection and error handling |

### Benefits of Frame Abstractions

**1. Swappable Implementations via Configuration**

One of the key benefits of using frame abstractions is that you can change the underlying infrastructure by simply changing a URL in configuration. No code changes required.

```go
// Production: NATS JetStream
QUEUE_URI=nats://localhost:4222?jetstream=true&stream_name=my-stream

// Testing: In-Memory Queue (no external dependencies)
QUEUE_URI=mem://localhost

// Different message broker (e.g., RabbitMQ via NATS compatibility)
QUEUE_URI=nats://rabbitmq-bridge:4222
```

**Example: Testing with In-Memory Queue**

```go
// test_config.go - No mocks needed!
type TestConfig struct {
    config.ConfigurationDefault
    QueueName string `envDefault:"test-queue"`
    QueueURI  string `envDefault:"mem://localhost"`  // In-memory for tests
}

// Test automatically uses in-memory queue without code changes
func TestBusinessLogic(t *testing.T) {
    cfg := TestConfig{
        QueueURI: "mem://localhost",  // Just change URL
    }
    
    ctx, svc := frame.NewServiceWithContext(t.Context(),
        frame.WithName("test"),
        frame.WithConfig(&cfg),
    )
    
    qMan := svc.QueueManager()
    
    // Same code works with in-memory queue
    emitter := NewFrameEventEmitter(qMan, cfg.QueueName, jobID, runnerID)
    
    // Test runs without NATS, no mocks needed!
    err := emitter.Emit(ctx, "test.event", "test message", "")
    require.NoError(t, err)
}
```

**Example: Testing with Real NATS**

```go
// For integration tests, just point to testcontainers NATS
func TestWithRealNATS(t *testing.T) {
    natsContainer := testnats.Run(t)  // From testcontainers
    
    cfg := TestConfig{
        QueueURI: natsContainer.URI(),  // Real NATS instance
    }
    
    // Same code, different infrastructure
    ctx, svc := frame.NewServiceWithContext(t.Context(),
        frame.WithConfig(&cfg),
    )
    
    // Production code tested against real infrastructure
}
```

**2. No Mock Maintenance**

By using frame abstractions with configurable URLs:
- No need to maintain queue mocks
- No need to stub `nats.JetStreamContext`
- No need to mock `js.Publish()` calls
- Tests use actual frame code paths

```go
// DON'T: Maintain complex mocks
mockNATS := &MockNATSConnection{}
mockJS := &MockJetStream{}
mockNATS.On("JetStream").Return(mockJS, nil)
mockJS.On("Publish", mock.Anything, mock.Anything).Return(nil, nil)

// DO: Just change the URL
cfg.QueueURI = "mem://localhost"  // That's it!
```

**3. Environment-Specific Backends**

```go
// Development
QUEUE_URI=nats://localhost:4222

// Production (clustered)
QUEUE_URI=nats://nats-1:4222,nats://nats-2:4222,nats://nats-3:4222?jetstream=true&stream_num_replicas=3

// CI/CD (ephemeral)
QUEUE_URI=mem://localhost

// Migration (legacy system)
QUEUE_URI=nats://legacy-bridge:4222
```

All environments use the same code, only configuration changes.

---

---

## Three-Layer Architecture

```
Handler (Connect RPC) → Business Logic → Repository (Data)
        ↓                    ↓                ↓
   Validation          Domain Rules       Database
   Serialization       Event Emission     Queries
   Logging/Tracing     Logging/Metrics    Logging
```

---

## Testing

### Testing Philosophy

1. **Use testcontainers** - always test against real databases, queues, and services
2. **Use test suites** - organize tests using testify's suite package
3. **Only mock what you cannot run** - external third-party APIs
4. **Table-driven tests** - comprehensive coverage with many scenarios
5. **Test behavior, not implementation**

### Test Suite Structure

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

func (s *BaseTestSuite) CreateService(t *testing.T) (context.Context, *frame.Service) {
    cfg := config.Config{}
    cfg.DatabasePrimaryURL = []string{s.GetDependencyOption().DatabaseURL}
    s.Cfg = cfg

    ctx, svc := frame.NewServiceWithContext(t.Context(),
        frame.WithName("test"),
        frame.WithConfig(&cfg),
        frame.WithDatastore(),
        frametests.WithNoopDriver(),
    )

    repository.Migrate(ctx, svc.DatastoreManager(), "../../migrations/0001")
    svc.Run(ctx, "")

    return security.SkipTenancyChecksOnClaims(ctx), svc
}
```

### Table-Driven Tests

```go
func (s *ProfileTestSuite) Test_CreateProfile() {
    t := s.T()
    ctx, svc := s.CreateService(t)
    profileBiz := business.NewProfileBusiness(&s.Cfg, s.ProfileRepo, svc.EventsManager())

    tests := []struct {
        name    string
        input   *profilev1.CreateRequest
        wantErr bool
        check   func(t *testing.T, profile *models.Profile)
    }{
        {
            name:  "valid profile",
            input: &profilev1.CreateRequest{Name: "Test", Email: "test@example.com"},
            check: func(t *testing.T, p *models.Profile) {
                require.NotEmpty(t, p.GetID())
            },
        },
        {
            name:    "empty name",
            input:   &profilev1.CreateRequest{Email: "test@example.com"},
            wantErr: true,
        },
        {
            name:    "invalid email",
            input:   &profilev1.CreateRequest{Name: "Test", Email: "not-email"},
            wantErr: true,
        },
        // Add more scenarios...
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            profile, err := profileBiz.Create(ctx, tt.input)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            if tt.check != nil {
                tt.check(t, profile)
            }
        })
    }
}
```

### When to Mock

```go
// Mock only external third-party APIs
mc := minimock.NewController(t)
notificationCli := notificationv1mocks.NewNotificationServiceClientMock(mc)
notificationCli.SendMock.Return(&connect.Response[notificationv1.SendResponse]{}, nil)
```

---

---

## HTTP Client Usage (MANDATORY)

**CRITICAL:** Never create `http.Client` directly or use `http.DefaultClient`. Always use frame's HTTP client manager for proper telemetry, circuit breaking, and retry logic.

### The Rule

```go
// ❌ FORBIDDEN: Direct HTTP client creation
client := &http.Client{Timeout: 30 * time.Second}

// ❌ FORBIDDEN: Using default client
resp, err := http.DefaultClient.Do(req)

// ✅ CORRECT: Use frame's HTTP client manager
httpClient := svc.HTTPClientManager().Client(ctx)
resp, err := httpClient.Do(req)
```

### Pattern 1: Webhook Senders and External API Calls

When creating components that make HTTP calls, accept an interface:

```go
// business/webhook.go
package business

// HTTPClient abstracts HTTP client operations for testability
type HTTPClient interface {
    Do(req *http.Request) (*http.Response, error)
}

type HTTPWebhookSender struct {
    client HTTPClient
}

// NewHTTPWebhookSender creates a new webhook sender.
// The client should be obtained from frame's HTTPClientManager.
func NewHTTPWebhookSender(client HTTPClient) *HTTPWebhookSender {
    if client == nil {
        panic("HTTP client is required")
    }
    return &HTTPWebhookSender{client: client}
}
```

**In main.go:**
```go
// Get properly configured HTTP client from frame
httpClient := svc.HTTPClientManager().Client(ctx)

// Pass to components that need HTTP
webhook := business.NewHTTPWebhookSender(httpClient)
```

### Pattern 2: Connect RPC Clients

All Connect RPC client constructors must accept `*http.Client` as first parameter:

```go
// pkg/client/build.go
package client

import (
    "context"
    "net/http"
    "connectrpc.com/connect"
    "github.com/stawi-dev/foundry/gen/build/v1/buildv1connect"
)

// NewBuildServiceClient creates a client with the given HTTP client.
// The httpClient should be obtained from frame's HTTPClientManager.
func NewBuildServiceClient(httpClient *http.Client, baseURL string, opts ...Option) buildv1connect.BuildServiceClient {
    cfg := &clientConfig{}
    for _, opt := range opts {
        opt.apply(cfg)
    }
    
    // Use provided HTTP client
    if cfg.httpClient == nil {
        cfg.httpClient = httpClient
    }
    
    return buildv1connect.NewBuildServiceClient(
        cfg.getHTTPClient(),
        baseURL,
        connect.WithInterceptors(cfg.getInterceptors()...),
    )
}

// BuildServiceClientFromManager creates a client using frame's HTTP client manager.
// This is the PREFERRED method.
func BuildServiceClientFromManager(ctx context.Context, clientManager interface{ Client(ctx context.Context) *http.Client }, baseURL string, opts ...Option) buildv1connect.BuildServiceClient {
    return NewBuildServiceClient(clientManager.Client(ctx), baseURL, opts...)
}
```

**In main.go:**
```go
// CORRECT: Use frame's HTTP client
apiClient := client.NewRunnerServiceClient(
    svc.HTTPClientManager().Client(ctx),
    cfg.APIEndpoint,
)

// CORRECT: Or use the FromManager helper
apiClient := client.RunnerServiceClientFromManager(
    ctx, 
    svc.HTTPClientManager(), 
    cfg.APIEndpoint,
)
```

### Pattern 3: Custom HTTP Clients

If you need custom HTTP client configuration, use frame's client options:

```go
import "github.com/pitabwire/frame/client"

// Create frame-configured HTTP client with custom options
httpClient := client.NewHTTPClient(ctx,
    client.WithHTTPTimeout(30 * time.Second),
    client.WithHTTPRetryPolicy(&client.RetryPolicy{
        MaxRetries: 3,
        Backoff:    time.Second,
    }),
    client.WithHTTPTraceRequests(),
)
```

### Anti-Patterns (FORBIDDEN)

| Don't | Why | Do Instead |
|-------|-----|-----------|
| `&http.Client{}` | Bypasses frame telemetry, circuit breaking, retry | `svc.HTTPClientManager().Client(ctx)` |
| `http.DefaultClient` | No observability, no configuration | Frame's HTTP client |
| `http.Get()`, `http.Post()` | Uses default client | Use frame client with `client.Do(req)` |
| Hardcoded timeouts | Can't be configured per environment | Use frame client options |

---

## Logging (MANDATORY)

**CRITICAL:** Never use `log.Println()`, `log.Fatalf()`, `slog`, or `fmt.Println()` for logging. Always use `util.Log(ctx)` for structured, contextual logging.

### The Rule

```go
// ❌ FORBIDDEN: Standard library logging
log.Println("starting service")
log.Fatalf("failed: %v", err)
slog.Info("message")
fmt.Println("debug info")

// ✅ CORRECT: Frame contextual logging
log := util.Log(ctx)
log.Info("starting service")
log.WithError(err).Fatal("failed to initialize")
```

### Pattern 1: Function Entry

```go
func (b *buildBusiness) StartBuild(ctx context.Context, req *StartBuildRequest) (*models.Job, error) {
    log := util.Log(ctx)
    log.Info("starting build",
        "project_id", req.ProjectID,
        "build_type", req.BuildType,
    )
    // ... logic
}
```

### Pattern 2: Error Logging

```go
result, err := b.repo.Create(ctx, job)
if err != nil {
    log.WithError(err).Error("failed to create job",
        "project_id", req.ProjectID,
    )
    return nil, fmt.Errorf("create job: %w", err)
}
```

### Pattern 3: Main Function Fatal Errors

```go
func main() {
    ctx := context.Background()
    
    cfg, err := config.LoadWithOIDC[appconfig.Config](ctx)
    if err != nil {
        // CORRECT: Use util.Log before frame service is initialized
        util.Log(ctx).WithError(err).Fatal("failed to load configuration")
    }
    
    ctx, svc := frame.NewServiceWithContext(ctx, ...)
    defer svc.Stop(ctx)
    
    // After svc is created, use svc.Log(ctx)
    log := svc.Log(ctx)
    log.Info("service initialized")
}
```

### Pattern 4: Debug and Trace Logging

```go
// Debug for detailed troubleshooting
log.Debug("processing item",
    "item_id", itemID,
    "step", "validation",
    "duration_ms", elapsed.Milliseconds(),
)

// Warn for concerning but non-fatal conditions
log.Warn("retry attempt",
    "attempt", 3,
    "max_attempts", 5,
    "backoff_ms", delay.Milliseconds(),
)
```

### Anti-Patterns (FORBIDDEN)

| Don't | Why | Do Instead |
|-------|-----|-----------|
| `log.Println()` | No context, no structure | `util.Log(ctx).Info()` |
| `log.Fatalf()` | Can't use in production code | `util.Log(ctx).WithError(err).Fatal()` |
| `fmt.Printf()` | Not logged properly | `util.Log(ctx).Debug()` |
| String concatenation | Not structured | `log.WithField("key", value)` |

---

## Models and Repositories (MANDATORY)

**CRITICAL:** All database models must embed `data.BaseModel`. All repositories must use `datastore.BaseRepository` or implement proper repository interfaces.

### Model Definition Pattern

#### The Rule

```go
// ❌ FORBIDDEN: Manual ID, TenantID, timestamps
type Job struct {
    ID        string    `gorm:"column:id;primaryKey"`
    TenantID  string    `gorm:"column:tenant_id"`
    CreatedAt time.Time `gorm:"column:created_at"`
    // ...
}

// ✅ CORRECT: Embed data.BaseModel
type Job struct {
    data.BaseModel `gorm:"embedded"`
    
    ProjectID   string    `gorm:"column:project_id;not null"`
    Status      JobStatus `gorm:"column:status;not null"`
    // Custom fields only - BaseModel provides ID, TenantID, PartitionID, CreatedAt, ModifiedAt
}
```

#### Pattern 1: Basic Model

```go
// models/job.go
package models

import (
    "github.com/pitabwire/frame/data"
    "time"
)

type JobStatus string

const (
    JobStatusQueued    JobStatus = "queued"
    JobStatusRunning   JobStatus = "running"
    JobStatusCompleted JobStatus = "completed"
)

// Job represents a job record in the database.
// Embeds data.BaseModel for standard fields (ID, TenantID, PartitionID, CreatedAt, ModifiedAt, DeletedAt).
type Job struct {
    data.BaseModel `gorm:"embedded"`
    
    // Custom fields only
    ProjectID   string    `gorm:"column:project_id;not null"`
    Status      JobStatus `gorm:"column:status;not null;default:queued"`
    StartedAt   *time.Time `gorm:"column:started_at"`
    CompletedAt *time.Time `gorm:"column:completed_at"`
}

// TableName returns the database table name.
func (Job) TableName() string {
    return "jobs"
}
```

#### Pattern 2: Model with State Machine

```go
// models/repo.go
type RepoState string

const (
    RepoStatePending RepoState = "pending"
    RepoStateReady   RepoState = "ready"
    RepoStateError   RepoState = "error"
)

type Repo struct {
    data.BaseModel `gorm:"embedded"`
    
    ProjectID string    `gorm:"column:project_id;not null"`
    S3Path    string    `gorm:"column:s3_path;not null"`
    State     RepoState `gorm:"column:state;not null;default:pending"`
}

func (Repo) TableName() string {
    return "repos"
}

// TransitionTo validates and applies state transitions.
func (r *Repo) TransitionTo(state RepoState) error {
    if !ValidRepoTransition(r.State, state) {
        return fmt.Errorf("invalid transition from %s to %s", r.State, state)
    }
    r.State = state
    r.ModifiedAt = time.Now() // Use BaseModel's ModifiedAt
    return nil
}
```

### Repository Definition Pattern

#### The Rule

```go
// ❌ FORBIDDEN: Raw pool access without BaseRepository
type jobRepository struct {
    pool pool.Pool
}

func (r *jobRepository) GetByID(ctx context.Context, id string) (*models.Job, error) {
    db := r.pool.DB(ctx, true)
    var job models.Job
    db.Where("id = ?", id).First(&job)
    return &job, nil
}

// ✅ CORRECT: Use datastore.BaseRepository
type jobRepository struct {
    datastore.BaseRepository[*models.Job]
}

func NewJobRepository(dbPool pool.Pool) JobRepository {
    ctx := context.Background()
    return &jobRepository{
        BaseRepository: datastore.NewBaseRepository[*models.Job](
            ctx,
            dbPool,
            nil,
            func() *models.Job { return &models.Job{} },
        ),
    }
}
```

#### Pattern 1: Basic Repository

```go
// repository/job.go
package repository

import (
    "context"
    "fmt"
    
    "github.com/pitabwire/frame/datastore"
    "github.com/pitabwire/frame/datastore/pool"
    
    "github.com/stawi-dev/foundry/apps/default/service/models"
)

// JobRepository defines the interface for job data access.
type JobRepository interface {
    Create(ctx context.Context, job *models.Job) error
    GetByID(ctx context.Context, jobID string) (*models.Job, error)
    Update(ctx context.Context, job *models.Job) error
    Delete(ctx context.Context, jobID string) error
}

type jobRepository struct {
    datastore.BaseRepository[*models.Job]
}

// NewJobRepository creates a new JobRepository.
func NewJobRepository(dbPool pool.Pool) JobRepository {
    ctx := context.Background()
    return &jobRepository{
        BaseRepository: datastore.NewBaseRepository[*models.Job](
            ctx,
            dbPool,
            nil,
            func() *models.Job { return &models.Job{} },
        ),
    }
}

func (r *jobRepository) Create(ctx context.Context, job *models.Job) error {
    return r.BaseRepository.Create(ctx, job)
}

func (r *jobRepository) GetByID(ctx context.Context, jobID string) (*models.Job, error) {
    return r.BaseRepository.GetByID(ctx, jobID)
}

func (r *jobRepository) Update(ctx context.Context, job *models.Job) error {
    return r.BaseRepository.Update(ctx, job)
}

func (r *jobRepository) Delete(ctx context.Context, jobID string) error {
    return r.BaseRepository.Delete(ctx, jobID)
}
```

#### Pattern 2: Repository with Custom Queries

```go
// repository/job.go

// Custom query methods extend BaseRepository
type JobRepository interface {
    // Base CRUD from BaseRepository
    Create(ctx context.Context, job *models.Job) error
    GetByID(ctx context.Context, jobID string) (*models.Job, error)
    
    // Custom query methods
    GetByIdempotencyKey(ctx context.Context, key string) (*models.Job, error)
    ListByProject(ctx context.Context, projectID string) ([]*models.Job, error)
    UpdateStatus(ctx context.Context, jobID string, status models.JobStatus) error
}

func (r *jobRepository) GetByIdempotencyKey(ctx context.Context, key string) (*models.Job, error) {
    db := r.Pool().DB(ctx, true) // Access pool for custom queries
    
    var job models.Job
    result := db.Where("idempotency_key = ? AND deleted_at IS NULL", key).First(&job)
    if result.Error != nil {
        return nil, fmt.Errorf("get job by idempotency key: %w", result.Error)
    }
    
    return &job, nil
}

func (r *jobRepository) ListByProject(ctx context.Context, projectID string) ([]*models.Job, error) {
    db := r.Pool().DB(ctx, true)
    
    var jobs []*models.Job
    result := db.Where("project_id = ? AND deleted_at IS NULL").
        Order("created_at DESC").
        Find(&jobs)
    if result.Error != nil {
        return nil, fmt.Errorf("list jobs by project: %w", result.Error)
    }
    
    return jobs, nil
}
```

#### Pattern 3: Repository with Complex Queries (Raw Pool Access)

**Only use raw pool access when BaseRepository doesn't provide the needed functionality** (aggregations, complex joins, etc.):

```go
// repository/plan_media.go

type planMediaRepository struct {
    pool pool.Pool
}

// Use raw pool for complex aggregations not supported by BaseRepository
func (r *planMediaRepository) TenantStorageUsed(ctx context.Context, tenantID string) (int64, error) {
    db := r.pool.DB(ctx, true)
    
    var totalBytes *int64
    result := db.Table(models.PlanMedia{}.TableName()).
        Select("COALESCE(SUM(size_bytes), 0)").
        Where("tenant_id = ? AND upload_state = ?", tenantID, string(models.UploadStateConfirmed)).
        Scan(&totalBytes)
    if result.Error != nil {
        return 0, fmt.Errorf("tenant storage used: %w", result.Error)
    }
    
    return *totalBytes, nil
}
```

### BaseModel Fields Reference

When you embed `data.BaseModel`, these fields are automatically available:

| Field | Type | Description |
|-------|------|-------------|
| `ID` | `string` | Primary key (auto-generated) |
| `TenantID` | `string` | Multi-tenancy identifier |
| `PartitionID` | `string` | Partition identifier |
| `CreatedAt` | `time.Time` | Creation timestamp |
| `ModifiedAt` | `time.Time` | Last modification timestamp |
| `DeletedAt` | `*time.Time` | Soft delete timestamp (nil if not deleted) |

**Do NOT define these fields manually** in your models.

### BaseRepository Methods Reference

When you embed `datastore.BaseRepository[T]`, these methods are available:

| Method | Description |
|--------|-------------|
| `Create(ctx, entity)` | Insert new record |
| `GetByID(ctx, id)` | Get by primary key |
| `Update(ctx, entity)` | Update existing record |
| `Delete(ctx, id)` | Soft delete by ID |
| `HardDelete(ctx, id)` | Hard delete by ID |
| `List(ctx, query)` | List with query options |
| `Count(ctx, query)` | Count with query options |
| `Pool()` | Access underlying pool for custom queries |

### Anti-Patterns (FORBIDDEN)

| Don't | Why | Do Instead |
|-------|-----|-----------|
| Manual `ID string` field | BaseModel provides ID | Remove and embed `data.BaseModel` |
| Manual `TenantID string` field | BaseModel provides TenantID | Remove and use `data.BaseModel` |
| Manual `CreatedAt time.Time` | BaseModel provides CreatedAt | Remove and use `data.BaseModel` |
| Raw SQL without repository | Bypasses abstraction | Create repository method |
| Repository without interface | Can't mock for tests | Define interface, implement struct |
| Repository returning `any` | Loses type safety | Return concrete types |

---

## Quick Decision Guide

Use this guide when you're unsure which pattern to use:

### I Need to Make an HTTP Request

```
Am I in main.go after frame service initialization?
├─► YES → httpClient := svc.HTTPClientManager().Client(ctx)
│
└─► NO (before frame init)
    └─► Use custom HTTP client via dependency injection
        → Accept HTTPClient interface in constructor
        → Pass frame client from main.go

Am I creating a webhook sender or external API client?
├─► YES → Define HTTPClient interface, accept in constructor
│         → In main.go: pass svc.HTTPClientManager().Client(ctx)
│
└─► NO (just making an API call)
    └─► Use Connect RPC client with frame HTTP client
```

### I Need to Log Something

```
Am I in main.go before frame service initialization?
├─► YES → util.Log(ctx).WithError(err).Fatal("...")
│
└─► NO (after frame init or in business/handler)
    └─► log := util.Log(ctx)
        log.Info("...", "key", value)
        log.WithError(err).Error("...")
```

### I Need to Define a Database Model

```
Does this entity need database persistence?
├─► YES → Must embed data.BaseModel
│         type MyModel struct {
│             data.BaseModel `gorm:"embedded"`
│             CustomField string `gorm:"column:custom_field"`
│         }
│
└─► NO (transient/pure logic)
    └─► Regular struct, no BaseModel needed
```

### I Need to Create a Repository

```
Am I writing custom queries beyond CRUD?
├─► YES (complex aggregations, joins, etc.)
│   └─► Use raw pool.Pool with interface definition
│         type myRepository struct { pool pool.Pool }
│
└─► NO (standard CRUD operations)
    └─► Must embed datastore.BaseRepository[T]
          type myRepository struct {
              datastore.BaseRepository[*models.MyModel]
          }
```

### I Need Async Processing

```
Does the work need to survive application restarts?
├─► YES → Use Frame Queue (WithRegisterPublisher/Subscriber)
│
└─► NO → Is this batch/streaming with bounded concurrency?
         ├─► YES → Use workerpool
         │
         └─► NO → Is it fast (<100ms) with no external calls?
                  ├─► YES → Use Frame Events
                  │
                  └─► NO → Reconsider: probably needs Frame Queue
```

---

## Checklist Before Committing

**Infrastructure:**
- [ ] No `&http.Client{}` - using frame's HTTPClientManager
- [ ] No `http.DefaultClient` - using frame's HTTPClientManager
- [ ] No `nats.Connect()` - using frame queue abstractions
- [ ] No `sql.Open()` - using frame datastore
- [ ] No `redis.NewClient()` - using frame cache

**Logging:**
- [ ] No `log.Println()` - using `util.Log(ctx)`
- [ ] No `log.Fatalf()` - using `util.Log(ctx).WithError().Fatal()`
- [ ] No `slog` or `fmt.Printf()` for logging - using `util.Log(ctx)`

**Models:**
- [ ] All models embed `data.BaseModel`
- [ ] No manual `ID`, `TenantID`, `CreatedAt` fields
- [ ] All models have `TableName()` method

**Repositories:**
- [ ] All repositories use `datastore.BaseRepository` or raw pool with interface
- [ ] Repository methods return concrete types, not `any`
- [ ] Repository interfaces defined for testability

**Architecture:**
- [ ] Three-layer architecture: handlers → business → repository
- [ ] Handlers only do validation/serialization
- [ ] Business layer contains domain logic
- [ ] Repository layer handles data access

**Testing:**
- [ ] Tests use testcontainers for real integrations
- [ ] Tests use table-driven pattern
- [ ] No mocked databases (use testcontainers)

**Quality:**
- [ ] All errors wrapped with context (`fmt.Errorf("...: %w", err)`)
- [ ] Using `util.IDString()` for ID generation
- [ ] Using `util.CloseAndLogOnError()` for deferred closes
- [ ] `golangci-lint run` passes
- [ ] `go test -race ./...` passes

---

## Quick Reference

| Need | Use |
|------|-----|
| Logging | `util.Log(ctx)` |
| Tracing | `telemetry.StartSpan(ctx, name)` |
| Metrics | `telemetry.IncrementCounter()`, `telemetry.RecordDuration()` |
| API definitions | `github.com/antinvestor/apis` |
| Connect handler | `servicev1connect.NewServiceHandler()` |
| Connect client | `servicev1connect.NewServiceClient()` |
| Connect error | `connect.NewError(connect.CodeX, err)` |
| Unique ID | `util.IDString()` |
| Random token | `util.RandomAlphaNumericString(32)` |
| Close resource | `defer util.CloseAndLogOnError(ctx, closer, "msg")` |
| HTTP client | `svc.HTTPClient()` |
| Async job | `workerpool.SubmitJob()` |
| Durable event | `eventsMan.Emit()` |
| Database | `datastore.BaseRepository` |
| Auth claims | `security.ClaimsFromContext()` |
| Test suite | `frametests.FrameBaseTestSuite` |

## Anti-Patterns (CRITICAL)

These patterns are **FORBIDDEN** and will fail code review. The table shows what NOT to do and what to do instead.

### Infrastructure Access

| Don't | Do Instead | Consequence |
|-------|-----------|-------------|
| `&http.Client{}` | `svc.HTTPClientManager().Client(ctx)` | No telemetry, no circuit breaking |
| `http.DefaultClient` | Frame's HTTP client | No observability, no retry logic |
| `http.Get()`, `http.Post()` | Use frame client with `Do(req)` | Bypasses all frame instrumentation |
| `nats.Connect()` | `frame.WithRegisterPublisher/Subscriber()` | No lifecycle management |
| `sql.Open()` | `frame.WithDatastore()` | No connection pooling |
| `redis.NewClient()` | `cache.Manager` | No abstraction |

### Logging

| Don't | Do Instead | Consequence |
|-------|-----------|-------------|
| `log.Println()` | `util.Log(ctx).Info()` | No context, no structure |
| `log.Fatalf()` | `util.Log(ctx).WithError(err).Fatal()` | Can't use in production code |
| `slog.Info()` | `util.Log(ctx).Info()` | Different format, no correlation |
| `fmt.Printf()` | `util.Log(ctx).Debug()` | Not logged properly |
| String concatenation in logs | `log.WithField("key", value)` | Not queryable |

### Models

| Don't | Do Instead | Consequence |
|-------|-----------|-------------|
| `type Job struct { ID string ... }` | Embed `data.BaseModel` | Missing standard fields |
| Manual `CreatedAt time.Time` | Use `BaseModel.CreatedAt` | Inconsistent timestamps |
| Manual `TenantID string` | Use `BaseModel.TenantID` | No multi-tenancy support |
| Manual `DeletedAt *time.Time` | Use `BaseModel.DeletedAt` | No soft delete |

### Repositories

| Don't | Do Instead | Consequence |
|-------|-----------|-------------|
| Raw `pool.Pool` without interface | Embed `datastore.BaseRepository` | No abstraction |
| Repository returning `any` | Return concrete types | Lost type safety |
| Repository without interface | Define interface + struct | Can't mock for tests |
| SQL inline in business logic | Create repository method | Violates 3-layer architecture |

### Async Processing

| Don't | Do Instead | Consequence |
|-------|-----------|-------------|
| Raw goroutines for critical work | `workerpool.SubmitJob()` | No bounded concurrency |
| External API in Frame Events | Use Frame Queue | No retry, no durability |
| Simple DB work in Frame Queue | Use Frame Events | Unnecessary overhead |
| Direct NATS pub/sub | `queue.Manager.Publish()` | No abstraction |

### Testing

| Don't | Do Instead | Consequence |
|-------|-----------|-------------|
| Mock databases | Testcontainers | Not testing real behavior |
| Single test case | Table-driven tests | Poor coverage |
| `http.DefaultClient` in tests | Pass `http.Client` parameter | Non-deterministic |

### Project Structure

| Don't | Do Instead | Consequence |
|-------|-----------|-------------|
| `internal/` for shared code | `pkg/` for shared packages | Can't import across apps |
| `panic` for errors | Return errors | Unhandled crashes |
| REST for service-to-service | Connect RPC | Poor type safety |

> **Note on API definitions:** For projects in the antinvestor ecosystem, use `github.com/antinvestor/apis`. For standalone projects, local `proto/` definitions are preferred.

---

## Pre-Commit Verification Script

Before committing, verify your code complies with these patterns:

```bash
#!/bin/bash
# run this before committing

echo "=== GOLANG-PATTERNS COMPLIANCE CHECK ==="

# Check for forbidden imports
echo "Checking for forbidden patterns..."

if grep -r "log\.Println\|log\.Fatalf" --include="*.go" .; then
    echo "❌ FAIL: Found log.Println or log.Fatalf - use util.Log(ctx)"
    exit 1
fi

if grep -r "&http\.Client{\|http\.DefaultClient" --include="*.go" . | grep -v "_test.go"; then
    echo "❌ FAIL: Found direct http.Client usage - use svc.HTTPClientManager().Client(ctx)"
    exit 1
fi

if grep -r "nats\.Connect\|nats\.JetStream" --include="*.go" . | grep -v "_test.go"; then
    echo "❌ FAIL: Found direct NATS usage - use frame queue abstractions"
    exit 1
fi

if grep -r "sql\.Open\|database/sql" --include="*.go" . | grep -v "_test.go"; then
    echo "❌ FAIL: Found direct database/sql usage - use frame datastore"
    exit 1
fi

# Check model definitions
if grep -r "type.*struct.*{\s*ID\s*string" --include="*.go" ./apps/**/models/ | grep -v "data.BaseModel"; then
    echo "⚠️  WARNING: Model with manual ID field - should embed data.BaseModel"
fi

# Check repository definitions
if grep -r "type.*Repository.*struct" --include="*.go" ./apps/**/repository/ | grep -v "BaseRepository"; then
    echo "⚠️  WARNING: Repository not using BaseRepository - verify pattern"
fi

echo "✅ PASS: All critical patterns verified!"
```
