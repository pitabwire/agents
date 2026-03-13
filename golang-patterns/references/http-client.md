# HTTP Client Reference

## The Rule

**Never create `http.Client` directly or use `http.DefaultClient`.** Always use frame's HTTP client manager.

```go
// FORBIDDEN
client := &http.Client{Timeout: 30 * time.Second}
resp, err := http.DefaultClient.Do(req)

// CORRECT
httpClient := svc.HTTPClientManager().Client(ctx)
resp, err := httpClient.Do(req)
```

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
import "github.com/pitabwire/frame/client"

httpClient := client.NewHTTPClient(ctx,
    client.WithHTTPTimeout(30 * time.Second),
    client.WithHTTPRetryPolicy(&client.RetryPolicy{
        MaxRetries: 3,
        Backoff:    time.Second,
    }),
    client.WithHTTPTraceRequests(),
)
```
