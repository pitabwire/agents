# Observability Reference

## Table of Contents

1. [Logging](#logging)
2. [Tracing](#tracing)
3. [Metrics](#metrics)
4. [Configuration](#configuration)

---

## Logging

**Always use `util.Log(ctx)`.** Never use `log.Println()`, `log.Fatalf()`, `slog`, or `fmt.Println()`.

### Basic Usage

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

log.Debug("processing item", "item_id", itemID, "step", "validation")
log.Info("request processed", "duration_ms", duration.Milliseconds())
log.Warn("retry attempt", "attempt", 3, "max_attempts", 5)
log.WithError(err).Error("operation failed", "operation", "create_profile")
```

### Structured Fields

```go
log.WithField("user_id", userID).Info("user action")

log.WithFields(map[string]any{
    "order_id":   orderID,
    "total":      total,
    "item_count": len(items),
}).Info("order placed")
```

### Main Function

```go
func main() {
    ctx := context.Background()

    cfg, err := config.LoadWithOIDC[appconfig.Config](ctx)
    if err != nil {
        util.Log(ctx).WithError(err).Fatal("failed to load configuration")
    }

    ctx, svc := frame.NewServiceWithContext(ctx, ...)
    defer svc.Stop(ctx)

    log := svc.Log(ctx)
    log.Info("service initialized")
}
```

---

## Tracing

Frame provides OpenTelemetry integration automatically at the transport layer.
For Connect RPC servers, add `otelconnect.NewInterceptor()` to the interceptor
chain. For business-level spans, use a package tracer:

```go
import (
    "github.com/pitabwire/frame/telemetry"
)

// observability/metrics.go — one per app
var tracer = telemetry.NewTracer("service_name")

func (b *orderBusiness) ProcessOrder(ctx context.Context, order *Order) (err error) {
    ctx, span := tracer.Start(ctx, "ProcessOrder")
    defer func() { tracer.End(ctx, span, err) }()

    span.SetAttributes(attribute.String("order.id", order.ID))
    ...
}
```

`Tracer.End(ctx, span, err)` records the error and sets span status automatically.

## Metrics

Use `telemetry.NewBusinessMetrics(pkg)` to build instruments once at startup
(the OTel SDK dedupes by name). Measurements are tenant-scoped automatically
via context claims. Group instruments in a per-app `observability` or
`metrics` package (see apps/default/service/metrics in service-payment and
apps/geolocation/service/observability in service-profile):

```go
type Metrics struct {
    accepted telemetry.Counter
    latency  telemetry.Histogram
    volume   telemetry.FloatCounter
}

func NewMetrics() *Metrics {
    bm := telemetry.NewBusinessMetrics("service_name")
    return &Metrics{
        accepted: bm.Counter("service_name/orders/accepted", "Accepted orders"),
        latency:  bm.Histogram("service_name/orders/latency", "Order processing latency"),
        volume:   bm.FloatCounter("service_name/orders/value_total", "Order value in major units"),
    }
}
```

## Configuration

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
