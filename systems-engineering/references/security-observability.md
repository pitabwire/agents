# Security & Observability Checklist

## Table of Contents
- [Security Model](#security-model)
- [Observability (OpenTelemetry)](#observability-opentelemetry)

---

## Security Model

### Required Definitions

| Area | Must Define |
|------|-------------|
| **Authentication** | Mechanism (OIDC, mTLS, API keys, tokens), where verified, session lifecycle |
| **Authorization** | Rules (RBAC, ABAC, policy engine), enforcement points, default-deny |
| **Identity propagation** | How identity flows across service boundaries (headers, tokens, context) |
| **Secret handling** | Storage (vault, env, sealed secrets), rotation strategy, access audit |
| **Privilege scope** | Minimum permissions per component (least privilege) |
| **Trust boundaries** | Where trust changes (external→internal, tenant→system, user→admin) |

### Attack Surface Analysis

Identify and mitigate:

| Surface | Common Threats | Required Mitigations |
|---------|---------------|---------------------|
| User input | Injection, XSS, CSRF | Input validation, output encoding, CSRF tokens |
| APIs | Auth bypass, rate abuse, data leaks | Auth middleware, rate limiting, response filtering |
| Storage | Unauthorized access, data exfiltration | Encryption at rest, access controls, audit logging |
| Dependencies | Supply chain, known CVEs | Pinned versions, vulnerability scanning |
| Secrets | Leakage in logs/manifests/env | Dedicated secret store, scrubbing, rotation |
| Network | MITM, lateral movement | TLS everywhere, network policies, segmentation |

### Principles

- Fail closed (deny by default)
- Validate at trust boundaries, not deep in business logic
- Secrets never in source control, logs, error messages, or API responses
- Credential scope matches the operation (no wildcard permissions)
- Every destructive or sensitive operation has an audit trail

---

## Observability (OpenTelemetry)

**All telemetry must use OpenTelemetry. No proprietary or incompatible telemetry systems.**

### Required Instrumentation

#### Traces

| Requirement | Detail |
|-------------|--------|
| Context propagation | W3C Trace Context across all boundaries (HTTP, gRPC, queues) |
| Span structure | One span per logical operation; nest child spans for sub-operations |
| Span attributes | Operation name, input parameters (non-sensitive), result status |
| Error recording | `span.RecordError(err)` + `span.SetStatus(codes.Error, msg)` |
| Cross-service | Trace ID propagated through headers, queue metadata, async jobs |

Critical workflows to trace (at minimum):
- Request ingestion → processing → response
- Queue publish → consume → process → acknowledge
- External dependency calls (DB, cache, APIs, object storage)

#### Metrics

| Metric Type | Examples |
|-------------|---------|
| Counters | Requests total, errors total, items processed |
| Histograms | Request duration, queue wait time, payload size |
| Gauges | Active connections, queue depth, cache size |

Define **SLO indicators**:
- Availability: success rate over time window
- Latency: p50, p95, p99 of critical paths
- Error budget: acceptable error rate per period

#### Structured Logs

| Requirement | Detail |
|-------------|--------|
| Format | Structured (JSON), not plaintext |
| Correlation | Include trace_id, span_id in every log entry |
| Levels | ERROR (broken), WARN (degraded), INFO (operational), DEBUG (diagnostic) |
| Sensitive data | Never log secrets, tokens, PII, or full request bodies |

#### Service/Resource Attributes

Every telemetry signal must include:
- `service.name`
- `service.version`
- `deployment.environment`
- `service.instance.id` (for multi-instance disambiguation)

### Instrumentation Placement

```
Interaction Plane:
  → Trace: incoming request span (root or child of upstream)
  → Metric: request count, latency histogram
  → Log: request received, response sent

Execution Plane:
  → Trace: business operation spans
  → Metric: operation duration, error count
  → Log: operation start, completion, failure

Data Plane:
  → Trace: DB/cache/storage operation spans
  → Metric: query duration, connection pool usage
  → Log: slow queries, connection errors

Integration Plane:
  → Trace: external call spans (with propagated context)
  → Metric: external call duration, error rate, retry count
  → Log: external call failures, timeouts
```
