# Audit Checklist & Evaluation Criteria

Detailed criteria for each of the 10 audit sections. Use this as the evaluation framework when conducting the audit.

## 1. Requirements Checklist

Build an explicit checklist of all required features and guarantees derived from the requirements.

For each checklist item:
- State: **IMPLEMENTED** / **PARTIAL** / **MISSING**
- Cite exactly what in the design or code supports the conclusion
- For PARTIAL: specify what is present and what is absent
- For MISSING: specify what was expected and where it should exist

Format:
```
| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Feature X   | IMPLEMENTED | `service.go:142` handles X via ... |
| 2 | Feature Y   | PARTIAL | Queue consumer exists but no DLQ configured |
| 3 | Feature Z   | MISSING | No code or config references Z |
```

## 2. Implicit Assumptions

Identify all unstated assumptions. For each assumption, state the risk if it is violated.

Categories to examine:
- **Network**: Reliable? Low latency? No partitions? MTU assumptions?
- **Data size**: Max payload, max rows, max concurrent connections?
- **Latency**: Timeout values, SLA expectations, tail latency tolerance?
- **Failure**: What fails silently? What throws? What retries?
- **Trust**: Which inputs are trusted? Which callers are authenticated? Internal vs external boundaries?
- **Ordering**: Are events assumed ordered? What happens on reorder?
- **Time**: Clock synchronization? Timezone handling? Leap seconds? TTL correctness?
- **Concurrency**: Thread safety? Lock contention? Shared mutable state?

Format:
```
- **Assumption**: [what is assumed]
  - **Evidence**: [where this assumption is embedded]
  - **Risk if violated**: [what breaks and how]
```

## 3. Scalability Limits & Bottlenecks

For each resource dimension, identify the limiting factor, its current capacity, and what happens when exceeded.

Dimensions:
- **CPU**: Hot loops, serialization/deserialization, crypto, compression, GC pressure
- **Memory**: Unbounded caches, large object allocation, connection pooling, buffer sizes
- **Network**: Bandwidth, connection limits, DNS resolution, TLS handshake overhead
- **Storage**: IOPS, disk space, write amplification, compaction, WAL growth
- **Queues/Brokers**: Partition count, consumer lag, backpressure, message size limits
- **External dependencies**: Rate limits, quota, SLAs, timeout cascades

Format:
```
- **Resource**: [dimension]
  - **Bottleneck**: [specific component or path]
  - **Current limit**: [measured or estimated]
  - **Failure mode when exceeded**: [what happens]
  - **Mitigation**: [if any exists in current design]
```

## 4. Failure Modes & Recovery

For each failure mode, describe the system's current behavior and whether recovery is automatic, manual, or absent.

Failure modes to examine:
- **Process crash**: Does the system recover state? Is there data loss on crash? Incomplete writes?
- **Partial failure**: One of N replicas fails. One downstream is down. One disk is full.
- **Network partition**: Split-brain scenarios. Stale reads. Duplicate writes.
- **Downstream slowness**: Timeout handling. Circuit breaking. Backpressure propagation.
- **Duplicate delivery**: At-least-once semantics. Idempotency keys. Deduplication windows.
- **Replays**: What happens if an old message is replayed? If a job runs twice?
- **Out-of-order events**: Sequence gaps. Causal ordering violations. Version conflicts.

Format:
```
- **Failure mode**: [scenario]
  - **Current behavior**: [what the system does now]
  - **Recovery**: AUTOMATIC / MANUAL / NONE
  - **Data impact**: [data loss, corruption, inconsistency risk]
  - **Severity**: CRITICAL / HIGH / MEDIUM / LOW
```

## 5. Data Integrity & Consistency

Examine all data mutation paths for correctness guarantees.

Areas to examine:
- **Race conditions**: Concurrent writes to the same entity. Check-then-act patterns. TOCTOU bugs.
- **Idempotency**: Are writes safe to retry? Are idempotency keys used? What is the deduplication window?
- **Transactional boundaries**: Are multi-step operations atomic? What happens if step 2 of 3 fails? Are distributed transactions used correctly?
- **Retry safety**: Are retried operations safe? Do they cause duplicate side effects (emails, charges, notifications)?
- **Schema evolution**: Backward/forward compatibility. Migration safety. Zero-downtime schema changes.

Format:
```
- **Risk**: [specific risk description]
  - **Location**: [file:line or component]
  - **Trigger**: [how this manifests in production]
  - **Current mitigation**: [if any]
  - **Severity**: CRITICAL / HIGH / MEDIUM / LOW
```

## 6. Security & Isolation

Evaluate all trust boundaries, authentication, and authorization.

Areas to examine:
- **Authentication (authn)**: How are callers identified? Token validation? Session management? Key rotation?
- **Authorization (authz)**: How are permissions enforced? RBAC/ABAC? Are checks at the correct layer? Can they be bypassed?
- **Tenant isolation**: Can tenant A access tenant B's data? Are queries properly scoped? Are caches isolated?
- **Secrets management**: Are secrets in code, env vars, or a vault? Rotation policy? Exposure in logs?
- **Privilege escalation**: Can a low-privilege user gain elevated access? Are admin endpoints protected?
- **Data exfiltration**: Can data leak through logs, error messages, debug endpoints, or side channels?
- **Input validation**: SQL injection, XSS, command injection, path traversal, SSRF, deserialization attacks.

Format:
```
- **Finding**: [specific security issue]
  - **Attack vector**: [how an attacker exploits this]
  - **Impact**: [what the attacker gains]
  - **Location**: [file:line or component]
  - **Severity**: CRITICAL / HIGH / MEDIUM / LOW
```

## 7. Operational Gaps

Verify the system can be operated, debugged, and maintained in production.

Areas to examine:
- **Observability**: Structured logging? Log levels? Correlation IDs? Request tracing?
- **Metrics**: RED metrics (Rate, Errors, Duration)? Business metrics? SLI/SLO definitions?
- **Tracing**: Distributed tracing? Span propagation? Trace sampling?
- **Alerting**: Alert definitions? Runbooks? Escalation policies? Alert fatigue risk?
- **Deployment safety**: Canary/blue-green? Health checks? Readiness/liveness probes? Graceful shutdown?
- **Rollback**: Can the previous version be restored? Database migration rollback? Feature flags?
- **Migrations**: Zero-downtime migrations? Backward-compatible schema changes? Data backfill strategy?

Format:
```
- **Gap**: [what is missing or insufficient]
  - **Impact**: [operational consequence]
  - **When it matters**: [scenario where this gap causes pain]
  - **Severity**: CRITICAL / HIGH / MEDIUM / LOW
```

## 8. Critical Issues Summary

For every finding rated CRITICAL or HIGH from sections 1-7, produce:

```
### Issue [N]: [Title]

**Section**: [which audit section]
**Severity**: CRITICAL / HIGH
**Production impact**: [concrete description of what goes wrong]
**Trigger scenario**: [specific load, failure, or sequence that surfaces this]
**Proposed fix**: [concrete architectural or implementation-level change]
**Effort estimate**: [S/M/L]
```

## 9. Production Readiness Verdict

State one of:
- **READY** - System can be deployed to production under stated requirements
- **CONDITIONALLY READY** - System can be deployed with specific mitigations or constraints documented
- **NOT READY** - System has blocking issues that must be resolved before deployment

Justify the verdict by referencing the findings above.

## 10. Minimum Changes for Production Readiness

If verdict is NOT READY or CONDITIONALLY READY, list the minimum changes required, ordered by priority:

```
| Priority | Change | Blocks | Effort | Section Reference |
|----------|--------|--------|--------|-------------------|
| P0 (blocking) | ... | Deploy | S/M/L | Issue #N |
| P1 (high)     | ... | Scale  | S/M/L | Issue #N |
| P2 (medium)   | ... | Ops    | S/M/L | Issue #N |
```

Distinguish between:
- **P0**: Must fix before any production traffic
- **P1**: Must fix before scaling beyond initial launch
- **P2**: Should fix within first production quarter
