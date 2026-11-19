# HTTP Client Reference

## The Rule

**Never create `http.Client` directly or use `http.DefaultClient`.** Always use Frame's HTTP client APIs (`client.NewHTTPClient`, `svc.HTTPClientManager().Client(ctx)`, or `github.com/antinvestor/common/connection` for S2S Connect clients).

```go
// FORBIDDEN
cli := &http.Client{Timeout: 30 * time.Second}
resp, err := http.DefaultClient.Do(req)

// CORRECT — shared service client
httpClient := svc.HTTPClientManager().Client(ctx)
resp, err := httpClient.Do(req)

// CORRECT — purpose-built client with a fixed timeout at construction
httpClient := client.NewHTTPClient(ctx,
    client.WithHTTPTimeout(2*time.Second),
    client.WithHTTPNoAuth(), // external APIs that must not attach service OAuth
)
```

---

## Timeouts: set once on the client (MANDATORY)

**Deadlines belong on the HTTP client (or Connect transport), not on every call site.**

| Do | Don't |
|----|--------|
| `client.WithHTTPTimeout(2*time.Second)` when constructing the client | `context.WithTimeout(ctx, 120*time.Millisecond)` before each Hydra/RPC hop |
| Pass `req.Context()` / parent `ctx` into client methods | Nest `hydraCtx`, `profileCtx`, `tenCtx` budgets around every call |
| Soft-fail optional work in **control flow** (`if err != nil { log; continue }`) | Invent `latency_budgets.go` / per-step “p99 budget” constants for every branch |
| One shared client per peer class (Hydra admin, Hydra public, external IdP, S2S) | Per-request ad-hoc clients with different timeouts |

### Why

Per-call `context.WithTimeout` micro-budgets:

- Drift out of sync with real peer latency and produce false hard-fails (user error pages).
- Duplicate Frame/common client defaults and retry policy.
- Scatter magic durations across handlers and force endless “raise this budget” churn.
- Fight the client: a 2s HTTP client still dies at 120ms if the context is cancelled first.

### Correct pattern

```go
// construction (init / NewServer / setupXxxClient) — single place
const hydraAdminHTTPTimeout = 2 * time.Second

hydraHTTP := client.NewHTTPClient(context.Background(),
    client.WithHTTPTimeout(hydraAdminHTTPTimeout),
)
hydraCli := hydra.NewDefaultHydra(hydraHTTP, adminURL)

// handler / business — no WithTimeout around the hop
func (h *Server) Login(w http.ResponseWriter, r *http.Request) error {
    ctx := r.Context()
    loginReq, err := h.hydra.GetLoginRequest(ctx, challenge)
    if err != nil {
        // map client timeout / network errors to user-facing copy if needed
        return err
    }
    // optional step: soft-fail without inventing a sub-budget
    if err := h.maybeEnrich(ctx, loginReq); err != nil {
        util.Log(ctx).WithError(err).Warn("optional enrich failed; continuing")
    }
    return nil
}
```

### Acceptable exceptions (rare)

Use `context.WithTimeout` only when the deadline is **not** an outbound peer hop:

1. **Process lifetime / jobs** — migration job overall deadline, test suite wall clock.
2. **In-process work with no client** — e.g. local compute that must not run forever (still prefer design over budgets).

Do **not** use handler-level budgets to “meet p99 SLO”. Measure and fix the slow peer, cache, or soft-fail the optional step.

### Forbidden: cancel then ignore (`WithoutCancel`)

```go
// NEVER — create (or inherit) a cancellable ctx and then strip cancellation
ctx, cancel := context.WithTimeout(parent, 25*time.Second)
defer cancel()
work(context.WithoutCancel(ctx))

// NEVER — “detached budget” to paper over push/HTTP deadlines
work(context.WithTimeout(context.WithoutCancel(parent), 2*time.Minute))
```

That pattern continues work after the caller believes it stopped. It races retries, hides overloads, and must not appear in handlers or event code.

| Need | Correct approach |
|------|------------------|
| Queue work needs time | Frame push timeout = 0 (v2.0.8+); no event budgets |
| Optional side effect after cancel | Soft-skip if `ctx.Err() != nil` |
| Long-lived HTTP client at init | `client.NewHTTPClient(context.Background(), …)` for **construction only** |

### OAuth2 / external IdP

`oauth2.Config.Exchange` and `oidc.NewProvider` use `http.DefaultClient` unless the context carries `oauth2.HTTPClient`. Inject a timed Frame client once at provider setup:

```go
idpHTTP := client.NewHTTPClient(ctx,
    client.WithHTTPTimeout(5*time.Second),
    client.WithHTTPNoAuth(),
)
ctx = context.WithValue(ctx, oauth2.HTTPClient, idpHTTP)
token, err := cfg.Exchange(ctx, code, ...)
```

### Connect / `common` S2S clients

Prefer `connection.NewServiceClient` / Frame HTTP manager. Configure timeout via the shared HTTP client options path (`options.WithHTTPTimeout` / Frame `WithHTTPTimeout`) at construction — not per RPC in the handler.

Frame default HTTP timeout is **30s** if unset. For hot interactive paths (login, token hooks), construct a **dedicated** client with a tighter timeout rather than wrapping every call.

---

## Pattern 1: Webhook Senders / External API Calls

Accept an `HTTPClient` interface for testability:

```go
type HTTPClient interface {
    Do(req *http.Request) (*http.Response, error)
}

type HTTPWebhookSender struct {
    client HTTPClient
}

func NewHTTPWebhookSender(client HTTPClient) *HTTPWebhookSender {
    if client == nil {
        panic("HTTP client is required")
    }
    return &HTTPWebhookSender{client: client}
}
```

In `main.go`:

```go
httpClient := svc.HTTPClientManager().Client(ctx)
webhook := business.NewHTTPWebhookSender(httpClient)
```

---

## Pattern 2: Connect RPC Clients

All Connect RPC client constructors accept `*http.Client` as first parameter:

```go
func NewBuildServiceClient(httpClient *http.Client, baseURL string, opts ...Option) buildv1connect.BuildServiceClient {
    return buildv1connect.NewBuildServiceClient(httpClient, baseURL, connect.WithInterceptors(cfg.getInterceptors()...))
}

// Preferred: use manager directly
func BuildServiceClientFromManager(ctx context.Context, clientManager interface{ Client(ctx context.Context) *http.Client }, baseURL string) buildv1connect.BuildServiceClient {
    return NewBuildServiceClient(clientManager.Client(ctx), baseURL)
}
```

In `main.go`:

```go
apiClient := client.NewRunnerServiceClient(
    svc.HTTPClientManager().Client(ctx),
    cfg.APIEndpoint,
)
```

---

## Pattern 3: Custom HTTP Client Options

```go
import "github.com/pitabwire/frame/v2/client"

httpClient := client.NewHTTPClient(ctx,
    client.WithHTTPTimeout(2*time.Second),
    client.WithHTTPNoAuth(),
    client.WithHTTPTraceRequests(),
)
```

Frame applies a default retry policy when none is set. Prefer that over hand-rolled retry loops in handlers.

---

## Anti-pattern: latency budget maps

**Forbidden** as a design approach for production handlers:

```go
// DO NOT — per-branch micro-budgets
const (
    loginHydraTimeout      = 120 * time.Millisecond
    loginSubmitProfileTimeout = 400 * time.Millisecond
    consentDeviceTimeout   = 200 * time.Millisecond
)

hydraCtx, cancel := context.WithTimeout(ctx, loginHydraTimeout)
defer cancel()
_, err := hydra.GetLoginRequest(hydraCtx, challenge)
```

**Do instead:** one client timeout constant next to client construction; soft-fail optional steps; keep strong paths on the request context.

See also production example: `service-authentication` `apps/default/service/handlers/client_timeouts.go` (client construction only; no per-call budgets).
