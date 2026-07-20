# Permissions & Authorization Reference

## Table of Contents

1. [Proto Permission Annotations](#proto-permission-annotations)
2. [FunctionAccessInterceptor Wiring](#functionaccessinterceptor-wiring)
3. [Self-Bypass Pattern](#self-bypass-pattern)
4. [Resource-Level Checks](#resource-level-checks)
5. [OPL Serving](#opl-serving)
6. [Adding a New Service](#adding-a-new-service)
7. [Adding a New RPC](#adding-a-new-rpc)

---

## Proto Permission Annotations

**Every proto service MUST declare permissions.** This is the single source of truth for authorization, OPL generation, and OpenAPI extensions.

### Service-Level Declaration

```proto
import "common/v1/permissions.proto";

service MyService {
  option (common.v1.service_permissions) = {
    namespace: "service_myservice"
    permissions: [
      "resource_view",
      "resource_create",
      "resource_manage"
    ]
    role_bindings: [
      {role: ROLE_OWNER, permissions: ["resource_view", "resource_create", "resource_manage"]},
      {role: ROLE_ADMIN, permissions: ["resource_view", "resource_create", "resource_manage"]},
      {role: ROLE_OPERATOR, permissions: ["resource_view", "resource_create"]},
      {role: ROLE_VIEWER, permissions: ["resource_view"]},
      {role: ROLE_MEMBER, permissions: ["resource_view"]},
      {role: ROLE_SERVICE, permissions: ["resource_view", "resource_create", "resource_manage"]}
    ]
  };
```

### Method-Level Declaration

```proto
  rpc GetResource(GetResourceRequest) returns (GetResourceResponse) {
    option idempotency_level = NO_SIDE_EFFECTS;
    option (common.v1.method_permissions) = {
      permissions: ["resource_view"]
    };
    option (gnostic.openapi.v3.operation) = { ... };
  };
```

### Naming Convention

Permissions follow `{resource}_{verb}` pattern:
- Verbs: `view`, `create`, `update`, `delete`, `manage`, `search`, `send`, `receive`, `release`, `ingest`
- Examples: `profile_view`, `profile_create`, `contact_manage`, `notification_send`

### StandardRole Enum

```proto
ROLE_OWNER     // Full access
ROLE_ADMIN     // Near-full access
ROLE_OPERATOR  // Operational access (view + some writes)
ROLE_VIEWER    // Read-only
ROLE_MEMBER    // Minimal read access
ROLE_SERVICE   // Service-to-service (typically same as OWNER)
```

---

## FunctionAccessInterceptor Wiring

**Every Frame-based Connect RPC service MUST wire the FunctionAccessInterceptor.** This replaces manual `authz.CanXxx()` calls in handlers.

### Standard Pattern (no self-bypass)

**CRITICAL: Never hardcode the namespace string.** Always derive it from the proto descriptor via `permissions.ForService(sd).Namespace`. This prevents namespace mismatches between code and OPL.

```go
import (
    "github.com/antinvestor/common/permissions"
    myservicev1 "buf.build/gen/go/antinvestor/myservice/protocolbuffers/go/myservice/v1"
    connectInterceptors "github.com/pitabwire/frame/security/interceptors/connect"
    "github.com/pitabwire/frame/security/authorizer"
)

func setupConnectServer(ctx context.Context, svc *frame.Service) http.Handler {
    securityMan := svc.SecurityManager()
    auth := securityMan.GetAuthorizer(ctx)

    // Tenancy access (Plane 1)
    tenancyAccessChecker := authorizer.NewTenancyAccessChecker(auth, "tenancy_access")
    tenancyAccessInterceptor := connectInterceptors.NewTenancyAccessInterceptor(tenancyAccessChecker)

    // Functional access (Plane 2) — namespace derived from proto, never hardcoded
    sd := myservicepb.File_myservice_v1_myservice_proto.Services().ByName("MyService")
    procMap := permissions.BuildProcedureMap(sd)
    functionChecker := authorizer.NewFunctionChecker(auth, permissions.ForService(sd).Namespace)
    functionAccessInterceptor := connectInterceptors.NewFunctionAccessInterceptor(functionChecker, procMap)

    // Build interceptor chain
    defaultInterceptorList, err := connectInterceptors.DefaultList(
        ctx, securityMan.GetAuthenticator(ctx),
        tenancyAccessInterceptor,
        functionAccessInterceptor,
    )
    // ... register handler with interceptors
}
```

### Multiple Services in One App

```go
// Merge procedure maps from multiple service descriptors
procMap := permissions.BuildProcedureMap(sd1)
for k, v := range permissions.BuildProcedureMap(sd2) {
    procMap[k] = v
}
```

### Local Protos (not in apis repo)

For services with protos defined locally (e.g., lender, trustage), use the local generated descriptor:
```go
import myservicepb "github.com/org/myservice/gen/go/myservice/v1"

sd := myservicepb.File_proto_myservice_v1_myservice_proto.Services().ByName("MyService")
```

For services with BSR-generated protos:
```go
import myservicepb "buf.build/gen/go/org/myservice/protocolbuffers/go/myservice/v1"

sd := myservicepb.File_myservice_v1_myservice_proto.Services().ByName("MyService")
```

---

## Self-Bypass Pattern

For RPCs where a user can access their OWN resource without the permission (e.g., viewing own profile), **exclude those RPCs from the procedure map** and check inline:

```go
// Exclude self-bypass RPCs from auto-enforcement
delete(procMap, "/profile.v1.ProfileService/GetById")
delete(procMap, "/profile.v1.ProfileService/Update")

// In handler: inline self-bypass check
func (s *Server) GetById(ctx context.Context, req *connect.Request[...]) (...) {
    claims := security.ClaimsFromContext(ctx)
    if sub, _ := claims.GetSubject(); sub != req.Msg.GetId() {
        if err := s.checker.Check(ctx, "profile_view"); err != nil {
            return nil, authorizer.ToConnectError(err)
        }
    }
    // ... business logic
}
```

The handler struct holds `checker *authorizer.FunctionChecker` for self-bypass RPCs.

---

## Resource-Level Checks (Plane 3)

For services with per-resource authorization (chat rooms, files, shops), use `ResourceAccessChecker`. The interceptor handles tenant + function checks automatically; the handler adds resource-instance checks:

```go
// Setup:
roomChecker := authorizer.NewResourceAccessChecker(auth, "chat_room",
    authorizer.WithConstraints(
        authorizer.TimeWindowConstraint(9, 17, time.UTC),  // optional
    ),
    authorizer.WithPermissionConstraints("delete",
        authorizer.LocationConstraint("office-nairobi"),   // optional per-permission
    ),
)

// In handler — check access to a specific resource instance:
func (mb *MessageBusiness) GetHistory(ctx context.Context, roomID string) {
    if err := mb.roomChecker.Check(ctx, roomID, "read"); err != nil {
        return nil, err
    }
    // ... business logic
}

// Grant/revoke in business layer:
mb.roomChecker.Grant(ctx, roomID, "member", profileID)
mb.roomChecker.Revoke(ctx, roomID, "member", profileID)
```

---

## OPL Directory Convention

OPL files are organized under `opl/{service}/` at the repo root, one subfolder per namespace:

```
opl/
  chat/
    service_chat.opl.ts          # Generated (Plane 2 — functional roles/permits)
    chat_resources.opl.ts        # Hand-authored (Plane 3 — chat_room, chat_message)
  files/
    file_resources.opl.ts        # Hand-authored (Plane 3 — file, file_version)
```

Generate with: `buf build proto/<svc> -o /dev/stdout | generate-opl opl/<svc>/`

The `opl-push` workflow recursively collects `*.opl.ts` from `opl/` and pushes to the deployments repo.

---

## OPL Serving

Register embedded OPL files for Frame's `/_internal/opl/` endpoint:

```go
oplData, _ := os.ReadFile("opl/service_myservice.opl.ts")
serviceOptions := []frame.Option{
    frame.WithHTTPHandler(connectHandler),
    frame.WithOPL("service_myservice", oplData),
}
```

---

## Adding a New Service

1. **Define proto** with `service_permissions` and `method_permissions` on every RPC
2. **Generate OPL**: `buf build proto/<svc> -o /dev/stdout | generate-opl opl/`
3. **Wire interceptor** — derive namespace from proto, never hardcode:
```go
sd := myservicepb.File_myservice_v1_myservice_proto.Services().ByName("MyService")
procMap := permissions.BuildProcedureMap(sd)
functionChecker := authorizer.NewFunctionChecker(auth, permissions.ForService(sd).Namespace)
```
4. **Register OPL** via `frame.WithOPL()`
5. **No manual `authz.CanXxx()` calls needed** — interceptor handles it
6. For resource-level access (Plane 3), create `opl/{name}_resources.opl.ts` and use `ResourceAccessChecker`

---

## Adding a New RPC

1. Add `method_permissions` to the new RPC in the proto
2. If the permission is new, add it to `service_permissions.permissions` and appropriate `role_bindings`
3. Run `generate-opl` to regenerate OPL in `opl/`
4. The interceptor automatically picks up the new RPC — no code changes needed
5. If the RPC needs self-bypass: `delete(procMap, "/package.Service/NewRPC")` and add inline check

---

## BFF / HTTP Service Capability Bypass for Internal Users

For BFF services that resolve capabilities via Keto `BatchCheck` (e.g., service-thesa), internal role users (root-tenant owners/admins) have no Keto tuples on non-root tenants. The BFF must grant all capabilities without Keto checks for these users.

### Pattern

```go
const InternalSystemRole = "internal"

func (e *PolicyEvaluator) ResolveCapabilities(ctx context.Context, rctx *RequestContext) (CapabilitySet, error) {
    // Internal users get all capabilities — they have no Keto tuples
    // on non-root tenants, but are trusted system-level administrators.
    if rctx.HasRole(InternalSystemRole) {
        caps := make(CapabilitySet, len(e.checks))
        for _, chk := range e.checks {
            caps[chk.Capability] = true
        }
        return caps, nil
    }

    // Regular users: check Keto via BatchCheck
    // ...
}
```

### When to use
- HTTP/BFF services that eagerly resolve all capabilities for navigation/UI rendering
- Services where capabilities are checked client-side (show/hide UI elements) rather than enforced per-RPC

### When NOT to use
- Connect RPC services with `FunctionAccessInterceptor` — the interceptor handles permission checks per-RPC automatically
- Services where `TenancyAccessChecker` + `FunctionChecker` are wired as interceptors — Frame already handles `isInternalSystem()` via relation switching (`"member"` → `"service"`)

### CORS requirement
BFF CORS config must include `X-Tenant-Id`, `X-Partition-Id`, `X-Access-Id` in `AllowedHeaders` for cross-tenant header injection to work.
