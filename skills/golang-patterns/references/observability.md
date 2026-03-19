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

Frame provides OpenTelemetry integration automatically.

```go
import "github.com/pitabwire/frame/telemetry"

func (b *profileBusiness) ProcessOrder(ctx context.Context, order *Order) error {
    ctx, span := telemetry.StartSpan(ctx, "ProcessOrder")
    defer span.End()

    span.SetAttributes(
        attribute.String("order.id", order.ID),
        attribute.Int("order.item_count", len(order.Items)),
    )

    if err := b.validateOrder(ctx, order); err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, "validation failed")
        return err
    }

    span.SetStatus(codes.Ok, "")
    return nil
}
```

---

## Metrics

```go
func (b *profileBusiness) Create(ctx context.Context, req *CreateRequest) (*Profile, error) {
    start := time.Now()
    defer func() {
        telemetry.RecordDuration(ctx, "profile.create.duration", time.Since(start))
    }()

    telemetry.IncrementCounter(ctx, "profile.create.total")

    profile, err := b.profileRepo.Create(ctx, req)
    if err != nil {
        telemetry.IncrementCounter(ctx, "profile.create.errors")
        return nil, err
    }
    return profile, nil
}
```

---

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
