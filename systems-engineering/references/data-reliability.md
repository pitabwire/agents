# Data & Reliability Checklist

## Table of Contents
- [State Ownership](#state-ownership)
- [Failure and Fault Model](#failure-and-fault-model)
- [Concurrency and Scalability](#concurrency-and-scalability)

---

## State Ownership

For every form of state (browser state, caches, files, memory structures, model artifacts, database records, queues):

| Property | Must Define |
|----------|-------------|
| Owner | Which component owns this state exclusively |
| Lifecycle | Created when, destroyed when, migrated how |
| Storage medium | Memory, disk, database, cache, object store, browser storage |
| Schema / structure | Exact shape, types, constraints |
| Read/write patterns | Who reads, who writes, frequency, size |
| Consistency guarantees | Strong, eventual, read-your-writes, causal |
| Recovery strategy | How to rebuild if lost or corrupted |

**No implicit or undocumented state is allowed.** If state exists, it must appear in the data design.

---

## Failure and Fault Model

Define explicit system behavior for each failure mode:

### Failure Modes to Address

| Failure | Required Response |
|---------|------------------|
| Network failures | Timeouts, circuit breakers, retry with backoff |
| Process/runtime crashes | State recovery, work-in-progress handling |
| Partial execution | Atomicity boundaries, compensation logic |
| Retries and duplicates | Idempotency mechanisms (keys, dedup, conditional writes) |
| Concurrent conflicts | Conflict detection, resolution strategy (last-write-wins, merge, reject) |
| Dependency outages | Degraded mode, fallbacks, health checks |
| Storage unavailability | Queue/buffer, retry, alert, manual recovery path |
| Storage corruption | Checksums, validation on read, rebuild from source of truth |

### Required Mechanisms

- **Retry strategy**: Maximum attempts, backoff algorithm, jitter, which errors are retryable
- **Idempotency**: How duplicate operations are detected and handled
- **Rollback/compensation**: How partial work is undone when a step fails
- **Circuit breaking**: How cascading failures are prevented
- **Timeout propagation**: How deadlines flow through the call chain

---

## Concurrency and Scalability

For every major component:

### Classification

| Property | Options |
|----------|---------|
| Stateless or stateful | Stateless preferred; if stateful, define state affinity |
| Horizontal scaling | How instances are added (replicas, sharding, partitioning) |
| Vertical scaling | Resource limits, when vertical is appropriate |

### Required Definitions

- **Concurrency limits** — max parallel operations per instance and globally
- **Backpressure** — what happens when load exceeds capacity (reject, queue, shed, throttle)
- **Queueing/buffering** — where work accumulates, depth limits, overflow behavior
- **Ordering guarantees** — whether order matters, how it is preserved under concurrency
- **Resource bounds** — memory, connections, file descriptors, goroutines/threads

### Scaling Decision Framework

```
Is the component stateless?
  YES → Horizontal replicas behind load balancer
  NO  → Does state partition naturally?
    YES → Shard by partition key
    NO  → Single-writer with read replicas, or leader election
```
