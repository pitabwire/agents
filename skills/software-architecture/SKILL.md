---
name: software-architecture
description: Master software architect for modern architecture patterns, clean architecture, microservices, event-driven systems, and DDD. Reviews system designs, makes architectural decisions with trade-off analysis, and documents ADRs. Use when reviewing architecture, making design decisions, evaluating scalability, or assessing pattern compliance.
version: "1.0"
last_updated: "2026-02-26"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. Default technology stack changes (Frame, PostgreSQL, NATS, Valkey versions or replacements)
2. New architecture patterns are adopted (beyond CQRS, Saga, Event-Driven)
3. Frame framework API changes (new managers, changed abstractions)
4. Connect RPC conventions or alternatives change
5. Infrastructure defaults change (docker-compose, production checklist)
6. Anti-patterns list needs updating

**HOW to update:**
1. Edit this file at `~/.agents/skills/software-architecture/SKILL.md` using the Edit tool
2. Increment the `version` field in the frontmatter (e.g., "1.0" -> "1.1")
3. Update `last_updated` to today's date (YYYY-MM-DD)
4. Update the affected section(s) to match current best practices
5. Do NOT remove the self-update protocol section

**WHEN NOT to update:**
- Project-specific architecture decisions (those go in ADRs)
- Temporary technology evaluations that haven't been adopted

---

# Software Architecture

> **Core Principle:** "Simplicity is the ultimate sophistication." Start with the proven stack, add complexity ONLY when proven necessary.

## When to Use This Skill

- Reviewing system architecture or major design changes
- Making architectural decisions that need trade-off analysis
- Evaluating scalability, resilience, or maintainability impacts
- Choosing between architectural patterns
- Documenting Architecture Decision Records (ADRs)
- Assessing architecture compliance with standards

---

## Default Technology Stack

**Always start with the proven Go stack unless there's a compelling reason not to.**

### Core Stack

| Layer | Technology | Frame Abstraction | Purpose |
|-------|------------|-------------------|---------|
| **Language** | Go | — | Backend services |
| **Framework** | github.com/pitabwire/frame | — | Service framework with built-in patterns |
| **API Protocol** | Connect RPC | — | Service-to-service and client communication |
| **API Definitions** | github.com/antinvestor/apis or local `proto/` | — | Shared or project-specific protobuf definitions |
| **Database** | PostgreSQL | `datastore.Manager` | Primary data store |
| **Message Queue** | NATS / NATS JetStream | `queue.Manager` / pub/sub | Async messaging, events, durable queues |
| **Cache** | Valkey (Redis-compatible) | `cache.Manager` | Caching, sessions, rate limiting |
| **Auth** | OAuth2 / OIDC | `security.Manager` | Authentication via frame's security package |
| **Authorization** | Ory Keto | — | Fine-grained permissions |

> **CRITICAL:** Never access PostgreSQL, NATS, or Valkey directly. Always use the corresponding Frame abstraction (`datastore.Manager`, `queue.Manager`/pub/sub, `cache.Manager`). Frame provides connection management, observability, and consistent patterns. Direct access bypasses these guarantees.

### Why This Stack

| Choice | Rationale |
|--------|-----------|
| **Go** | Simple, fast, excellent concurrency, single binary deployment |
| **Frame** | Batteries-included: datastore, events, queues, security, observability |
| **Connect RPC** | Type-safe, browser-compatible, streaming support, better than REST |
| **PostgreSQL** | ACID, JSON support, full-text search, battle-tested, scales well |
| **NATS** | Lightweight, fast, supports pub/sub and queues, JetStream for durability |
| **Valkey** | Redis-compatible, open source, excellent for caching and sessions |

### Stack Capabilities

```
┌─────────────────────────────────────────────────────────────┐
│                      Client Applications                      │
│                  (Web, Mobile, CLI, Services)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                    Connect RPC / REST
                              │
┌─────────────────────────────────────────────────────────────┐
│                     Go Services (Frame)                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Handler   │→ │  Business   │→ │ Repository  │          │
│  │ (Connect)   │  │   Logic     │  │  (GORM)     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│         │                │                │                   │
│         │         Events/Queue           │                   │
│         │                │                │                   │
│  ┌──────┴────────────────┴────────────────┴──────────────┐   │
│  │              Frame Abstraction Layer                    │   │
│  │  cache.Manager    queue.Manager    datastore.Manager   │   │
│  │  security.Manager workerpool       events.Manager      │   │
│  └──────┬────────────────┬────────────────┬──────────────┘   │
└─────────│────────────────│────────────────│───────────────────┘
          │                │                │
    ┌─────▼─────┐   ┌──────▼──────┐   ┌─────▼─────┐
    │   Valkey  │   │    NATS     │   │ PostgreSQL │
    │  (Cache)  │   │ (Messages)  │   │   (Data)   │
    └───────────┘   └─────────────┘   └────────────┘
```

> Services NEVER access infrastructure directly. All access goes through Frame abstractions.

### When to Use Each Component

| Need | Use | Frame Component |
|------|-----|-----------------|
| Persistent data | PostgreSQL | `datastore.Manager` |
| Quick async jobs | NATS (in-memory) | `workerpool` |
| Durable events (fast completion) | NATS JetStream | `events.Manager` |
| Long-running jobs | NATS JetStream | `queue.Manager` |
| Caching | Valkey | `cache.Manager` |
| Sessions | Valkey | `cache.Manager` |
| Rate limiting | Valkey | Custom with cache |
| Pub/Sub | NATS | `queue.Manager` |

---

## Project Classification

```
              Startup/MVP        Growth           Scale
────────────────────────────────────────────────────────────
Scale         <10K users        10K-500K         500K+
Team          1-3               3-15             15+
Services      1-3               3-10             10+
Database      Single PG         PG + Replicas    PG Cluster/Sharding
Queue         NATS              NATS JetStream   NATS Cluster
Cache         Optional Valkey   Valkey           Valkey Cluster
```

### Starting Architecture (Default)

For most projects, start here:

```
┌──────────────────────────────────────────┐
│           Single Go Service              │
│  (Modular monolith with Frame)           │
│                                          │
│  apps/default/                           │
│  ├── handlers/    (Connect RPC)          │
│  ├── business/    (Domain logic)         │
│  ├── repository/  (Data access)          │
│  ├── models/      (Domain models)        │
│  └── events/      (Event handlers)       │
│                                          │
│  pkg/              (Shared across apps)  │
│  ├── common/                             │
│  └── util/                               │
├──────────────────────────────────────────┤
│  Frame Abstractions                      │
│  datastore.Manager │ queue.Manager       │
│  cache.Manager     │ security.Manager    │
└──────────────────────────────────────────┘
          │              │              │
    ┌─────▼─────┐  ┌─────▼─────┐  ┌─────▼─────┐
    │ PostgreSQL│  │   NATS    │  │  Valkey   │
    │           │  │           │  │ (optional)│
    └───────────┘  └───────────┘  └───────────┘
```

### Scaling Path

```
Phase 1: Modular Monolith
    └── Single service, multiple internal modules
    └── All modules share database
    └── NATS for async processing

Phase 2: Extract Services (when needed)
    └── Extract module with clear boundaries
    └── Database per service OR shared with schemas
    └── NATS JetStream for service communication

Phase 3: Full Microservices (rarely needed)
    └── Independent services
    └── Database per service
    └── Event-driven communication
```

---

## Context Discovery (ASK FIRST)

Before suggesting architecture changes, gather context:

### Essential Questions

1. **Scale**: Users? Data volume? Transaction rate?
2. **Team**: Size and Go expertise?
3. **Timeline**: MVP or long-term product?
4. **Existing Stack**: Already using Frame? PostgreSQL? NATS?
5. **Pain Points**: What's not working with current architecture?

### Default Assumptions

If context is unclear, assume:
- Use the default Go stack (Frame, PostgreSQL, NATS, Valkey)
- Start with modular monolith
- Extract services only when there's proven need
- Connect RPC for all APIs

---

## Pattern Selection

### The 3 Questions (Before ANY Pattern)

1. **Does Frame already provide this?** Check frame's capabilities first
2. **Simpler Alternative?** Can PostgreSQL/NATS/Valkey handle this directly?
3. **Defer?** Can we add complexity LATER when needed?

### Decision Tree

```
START: What's your concern?

├─ Need async processing?
│  ├─ Quick jobs, no retry → frame workerpool
│  ├─ Durable, fast completion → frame events (NATS)
│  └─ Long-running, guaranteed → frame queue (NATS JetStream)
│
├─ Need caching?
│  └─ Use Valkey via frame cache.Manager
│
├─ Complex business rules?
│  ├─ YES → Three-layer architecture (already in Frame pattern)
│  └─ NO  → Simple handlers with repository
│
├─ Multiple services needed?
│  ├─ Different scaling needs? → Extract service
│  ├─ Different teams? → Extract service
│  └─ Same team, similar scale → Keep in monolith
│
└─ Real-time updates needed?
   └─ Use NATS pub/sub + WebSocket or SSE
```

### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Use Instead |
|--------------|---------|-------------|
| Microservices from day 1 | Complexity without benefit | Modular monolith |
| MongoDB for relational data | Wrong tool | PostgreSQL with JSONB |
| Kafka for small scale | Overkill | NATS JetStream |
| Redis Cloud (proprietary) | Vendor lock-in | Valkey |
| Custom auth | Security risk | Frame security + Ory |
| REST for service-to-service | Weak contracts | Connect RPC |
| Raw goroutines | Leak risk | Frame workerpool |
| Direct PostgreSQL/NATS/Valkey access | Bypasses observability, pooling, lifecycle | Frame abstractions (`datastore`, `queue`/pub/sub, `cache`) |
| `internal/` for multi-app shared code | Not importable across apps in same module | `pkg/` for shared code across apps |

---

## Architecture Patterns with Stack

### Event-Driven Architecture

```go
// Publisher (Service A)
publisher, _ := svc.QueueManager().GetPublisher("order.created")
publisher.Publish(ctx, &OrderCreatedEvent{OrderID: order.ID}, nil)

// Subscriber (Service B)
frame.WithRegisterSubscriber("order.created", cfg.NATSUrl,
    func(ctx context.Context, msg *pubsub.Message) error {
        var event OrderCreatedEvent
        json.Unmarshal(msg.Body, &event)
        // Process event
        msg.Ack()
        return nil
    },
)
```

### CQRS (When Actually Needed)

```
Write Path:                    Read Path:
Connect RPC → Business →      Connect RPC → Read Model
PostgreSQL (source of truth)  PostgreSQL (optimized views/materialized)
     │                              ▲
     └──── NATS Event ─────────────┘
           (sync read model)
```

### Saga Pattern (Distributed Transactions)

```go
// Use NATS JetStream for saga orchestration
type OrderSaga struct {
    eventsMan events.Manager
}

func (s *OrderSaga) Execute(ctx context.Context, order *Order) error {
    // Step 1: Reserve inventory
    s.eventsMan.Emit(ctx, "inventory.reserve", &ReserveRequest{...})
    
    // Step 2: Process payment (triggered by inventory.reserved event)
    // Step 3: Confirm order (triggered by payment.completed event)
    
    // Compensation handled by failure events
}
```

---

## Database Patterns

### PostgreSQL as Primary Store

```sql
-- Use JSONB for flexible properties
CREATE TABLE profiles (
    id VARCHAR(50) PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    properties JSONB DEFAULT '{}',
    searchable TSVECTOR,  -- Full-text search
    created_at TIMESTAMPTZ DEFAULT NOW(),
    modified_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ  -- Soft delete
);

-- Indexes
CREATE INDEX idx_profiles_tenant ON profiles(tenant_id);
CREATE INDEX idx_profiles_searchable ON profiles USING GIN(searchable);
CREATE INDEX idx_profiles_properties ON profiles USING GIN(properties);
```

### When to Add Read Replicas

- Read:Write ratio > 10:1
- Read latency affecting user experience
- Analytics queries slowing production

### When to Consider Sharding

- Single table > 100M rows with write contention
- Geographic distribution requirements
- Compliance requiring data locality

---

## Caching Strategy

### Valkey Usage Patterns

```go
// Session caching
sessionCache := cache.NewCache[string, *Session](cacheMan.Get("sessions"))
sessionCache.Set(ctx, sessionID, session, 30*time.Minute)

// Rate limiting
func RateLimit(ctx context.Context, key string, limit int, window time.Duration) bool {
    count, _ := cache.Increment(ctx, key, 1)
    if count == 1 {
        cache.Expire(ctx, key, window)
    }
    return count <= int64(limit)
}

// Cache-aside pattern
func GetProfile(ctx context.Context, id string) (*Profile, error) {
    // Try cache
    if cached, found, _ := profileCache.Get(ctx, id); found {
        return cached, nil
    }
    
    // Load from DB
    profile, err := profileRepo.GetByID(ctx, id)
    if err != nil {
        return nil, err
    }
    
    // Cache for next time
    profileCache.Set(ctx, id, profile, 5*time.Minute)
    return profile, nil
}
```

### Cache Invalidation

```go
// Invalidate on write
func (b *profileBusiness) Update(ctx context.Context, profile *Profile) error {
    if err := b.profileRepo.Update(ctx, profile); err != nil {
        return err
    }
    
    // Invalidate cache
    b.profileCache.Delete(ctx, profile.ID)
    
    // Emit event for other services
    b.eventsMan.Emit(ctx, "profile.updated", profile)
    return nil
}
```

---

## Trade-off Analysis Framework

### ADR Template

```markdown
# ADR-[XXX]: [Decision Title]

## Status
Proposed | Accepted | Deprecated

## Context
[Problem and constraints]

## Decision
[What we chose]

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| Default Stack (Frame/PG/NATS/Valkey) | Proven, team knows it | May not fit specific need |
| Alternative | [Benefits] | [Costs] |

## Rationale
[Why - especially if deviating from default stack]

## Consequences
- **Positive**: [Benefits]
- **Negative**: [Costs]
```

### When to Deviate from Default Stack

Document in ADR if choosing:
- Different database (MongoDB, etc.)
- Different queue (Kafka, RabbitMQ)
- Different cache (Memcached, etc.)
- Different language/framework

Required justification:
1. Default stack cannot meet requirement (specify why)
2. Team has expertise in alternative
3. Integration with existing systems requires it
4. Compliance/regulatory requirement

---

## Quality Attributes with Default Stack

| Attribute | How Default Stack Addresses It |
|-----------|-------------------------------|
| **Reliability** | PostgreSQL ACID, NATS JetStream durability |
| **Availability** | PG replicas, NATS clustering, Valkey clustering |
| **Scalability** | Horizontal service scaling, PG read replicas, NATS partitioning |
| **Performance** | Go efficiency, Valkey caching, connection pooling |
| **Security** | Frame security package, Ory Keto, TLS everywhere |
| **Maintainability** | Go simplicity, Frame patterns, three-layer architecture |
| **Observability** | Frame OpenTelemetry integration |

---

## Infrastructure Defaults

### Development

```yaml
# docker-compose.yml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: service_dev
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
    ports:
      - "5432:5432"

  nats:
    image: nats:latest
    command: ["--jetstream", "--store_dir=/data"]
    ports:
      - "4222:4222"
      - "8222:8222"  # Monitoring

  valkey:
    image: valkey/valkey:latest
    ports:
      - "6379:6379"
```

### Production Checklist

- [ ] PostgreSQL with replicas and automated backups
- [ ] NATS cluster (3+ nodes) with JetStream
- [ ] Valkey cluster or sentinel setup
- [ ] TLS for all connections
- [ ] Connection pooling configured
- [ ] Health checks for all dependencies
- [ ] Monitoring and alerting
- [ ] Log aggregation

---

## Validation Checklist

Before finalizing architecture:

- [ ] Using default stack (Frame, PostgreSQL, NATS, Valkey) or justified deviation
- [ ] Connect RPC for APIs
- [ ] Three-layer architecture (handlers → business → repository)
- [ ] Async processing uses appropriate Frame component (workerpool/events/queue)
- [ ] Caching strategy defined (if needed)
- [ ] ADRs written for significant decisions
- [ ] Security reviewed (auth, authz, encryption)
- [ ] Scalability path defined
- [ ] Monitoring and observability planned

---

## Behavioral Principles

1. **Start with default stack** - Frame + PostgreSQL + NATS + Valkey
2. **Modular monolith first** - Extract services only when proven necessary
3. **Connect RPC for APIs** - Type-safe, streaming, browser-compatible
4. **Use Frame components** - Don't reinvent what Frame provides
5. **PostgreSQL for data** - JSONB for flexibility, full-text search built-in
6. **NATS for messaging** - Simple, fast, JetStream for durability
7. **Valkey for caching** - Redis-compatible, open source
8. **Document deviations** - ADR required for non-default choices
9. **Add complexity later** - You can always add; removing is harder
