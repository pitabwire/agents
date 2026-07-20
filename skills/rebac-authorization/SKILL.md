---
name: rebac-authorization
description: "Comprehensive guide for the Relationship-Based Access Control (ReBAC) authorization system built on Ory Keto. Covers the three-plane model (data access, functional roles, per-resource access), contextual constraints (time/location), explicit per-namespace service account permissions, Keto tuple builders, OPL namespaces with permits, partition inheritance, ResourceAccessChecker, middleware, and event-driven tuple management. Use when working on authorization, permissions, access control, Keto tuples, constraints, or service bot access in the antinvestor platform."
version: "6.3"
last_updated: "2026-07-11"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. New namespaces, roles, or permissions are added to `constants.go`
2. New tuple builder functions are added to `role_mapping.go`
3. The OPL namespace schema changes
4. The middleware permission checks change
5. New authorization planes or access patterns are introduced
6. The subject set composition chain changes
7. Event-driven tuple management patterns change
8. New services are added to audience namespaces
9. The consent flow or token webhook changes
10. Frame library's checkers or claims API changes

**HOW to update:**
1. Edit this file using the Edit tool
2. Increment the `version` field
3. Update `last_updated` to today's date
4. Update the affected section(s) to match current implementation

---

# ReBAC Authorization System

## Activation

Apply this knowledge when:
- Working on authorization, permissions, or access control
- Writing or reviewing Keto tuples or OPL namespaces
- Modifying service bot access patterns
- Working on partition creation, access grants, or role assignments
- Debugging "permission denied" errors
- Adding new services that need authorization

---

## Architecture Overview

Authorization operates on **three distinct planes** using Ory Keto as the ReBAC engine:

### Plane 1 — Data Access (`tenancy_access` namespace)
- **Question:** "Can profile X access data in partition B?"
- **Cross-service:** If a profile has access to partition B, that applies in every service
- **Inheritance:** Child partitions inherit membership from parent partitions via `SubjectSet<tenancy_access, "member">` chains
- **Relations:** `member` (regular users), `service` (service bots)
- **Checker:** `TenancyAccessChecker` — supports constraints via `WithTenancyConstraints()`

### Plane 2 — Functional Permissions (per-service namespaces)
- **Question:** "What can profile Z do in service G?"
- **Per-service:** Each service checks permissions in its own namespace
- **Service accounts get explicit per-permission grants** (`granted_*` tuples) — no blanket access
- **Users get role-based grants** — OPL `permits` resolve permissions from role tuples (owner > admin > operator > member)
- **Checker:** `FunctionChecker` — supports constraints via `WithFunctionConstraints()` and per-permission via `WithFunctionPermissionConstraints()`

### Plane 3 — Resource Access (per-resource namespaces)
- **Question:** "Can profile Y access this specific resource right now?"
- **Per-resource-instance:** Checks individual resource IDs (room, file, etc.)
- **Namespaces:** `chat_room`, `file`, and future resource types
- **OPL permits:** Role hierarchy with computed permissions (e.g., `chat_room` owner > admin > member > viewer)
- **Contextual constraints:** Time-of-day, location, or custom conditions evaluated after Keto check
- **Checker:** `ResourceAccessChecker` — supports `WithConstraints()`, `WithPermissionConstraints()`, `Grant()`, `Revoke()`, `Members()`

### Key Design Principles
1. **JWT `sub` === `profile_id` always** — the acting principal for ReBAC. Never use OAuth `client_id` as a Keto subject.
2. **`client_id` is for login / partition binding only** — identifies which OAuth client (and partition) the token is for, not who is acting.
3. **Hydra wire quirk is not a model exception** — Hydra v26 may leave wire `sub=client_id` for `client_credentials`; token hook still sets `profile_id`; Frame `NormalizeIdentity()` rewrites in-process `Subject` to `profile_id` so checkers see the invariant.
4. **Plane 1 always checked first** — `TenancyAccessChecker` interceptor runs before handler-level functional checks
5. **Least privilege for service accounts** — each SA declares exactly which permissions it needs per namespace
6. **Internal role string is `"internal"`** (Frame `ConstantSystemInternalRole`). SA type/`system_int` scope map to role `"internal"` at token enrichment

Canonical doc: service-authentication `docs/IDENTITY_AND_AUTHORIZATION.md`.

---

## Identity Lifecycle

### Service Account Token Issuance
1. SA calls Hydra with `grant_type=client_credentials`, `client_id` (+ private_key_jwt or secret)
2. Hydra calls token enrichment webhook (`handleServiceAccountEnrichment`)
3. Webhook looks up Hydra client metadata → `profile_id`, `tenant_id`, `partition_id`, `type`
4. Sets `roles = ["internal"]` (or external type) from metadata `type` / scope
5. Returns session extras including **`profile_id` (actor)**, tenancy claims, roles
6. JWT may still have `sub = client_id` (Hydra); **authorization uses `profile_id`**
7. Keto grants for this SA use **subject = `profile_id`** (SA sync + service bot bootstrap)

### User Token Issuance
1. User completes login → consent flow (`ShowConsentEndpoint`)
2. `buildUserTokenClaims` extracts `LoginEvent` with `profileID`, `tenantID`, `partitionID`, `accessID`
3. Fetches roles from `AccessRole` records → e.g., `["admin"]`
4. **Root-tenant admin/owner check** (`isRootAdminOrOwner`): if `tenantID == rootTenantID` AND `partitionID == rootPartitionID` AND roles contain `"owner"` or `"admin"` → appends `"internal"` role
5. JWT: `sub = profileID`, `roles = ["admin", "internal"]`, `tenant_id`, `partition_id`

### Root Tenant Constants (`login_step_4_consent.go`)
| Constant | Value | Purpose |
|----------|-------|---------|
| `rootTenantID` | `c2f4j7au6s7f91uqnojg` | Root tenant for super user detection |
| `rootPartitionID` | `c2f4j7au6s7f91uqnokg` | Root partition for super user detection |

### Super User Bootstrapping (`seed_super_user.go`)
```bash
service-authentication seed-super-user --email user@example.com --environment production
```
Creates profile → access on root partition → assigns `"owner"` role → user gets `"internal"` in JWT on next login.

### How `system_internal` / `internal` Affects Runtime
1. `ClaimsToContext`: calls `SkipTenancyChecksOnClaims` → bypasses DB-level tenancy filters
2. `TenancyAccessChecker.CheckAccess`: switches Keto relation from `"member"` to `"service"`
3. `ClaimsFromContext`: enriches claims from secondary tenancy claims via `EnrichTenancyClaims`

### Cross-Tenant Impersonation (EnrichTenancyClaims)

Users with the `"internal"` role can operate across tenants via header-based context switching:

1. **Frontend** sends `X-Tenant-Id`, `X-Partition-Id`, `X-Access-Id` headers with the target tenant
2. **Frame's `AuthenticationMiddleware`** (all transports: HTTP, Connect, gRPC) calls `EnrichTenancyClaims(ctx, tenantID, partitionID, accessID)` with values from these headers
3. **`EnrichTenancyClaims`** checks `claims.isInternalSystem()` — if false, headers are silently ignored (security: non-internal users cannot override tenant)
4. If internal, stores secondary claims via `util.SetTenancy(ctx, secondaryClaims)`
5. **`ClaimsFromContext`** detects internal user → merges secondary claims → returns enriched claims with overridden `TenantID`, `PartitionID`, `AccessID`
6. All downstream code (`GetTenantID()`, `GetPartitionID()`) transparently receives the target tenant

**BFF (service-thesa) Pattern:** The BFF's `KetoPolicyEvaluator` grants **all capabilities** to users with the `"internal"` role without Keto checks, since they have no Keto tuples on non-root tenants. This is safe because the `"internal"` role is only granted to root-tenant owners/admins.

**CORS requirement:** Gateway and BFF CORS configs must include `X-Tenant-Id`, `X-Partition-Id`, `X-Access-Id` in `allowHeaders`.

**Security invariant:** Regular users cannot inject tenant headers — `EnrichTenancyClaims` is a no-op unless `isInternalSystem()` returns true. Existing security tests verify this (`TestSecurity_TenantIDFromJWT_NotRequestHeader`).

---

## Namespaces and Permissions

### Constants (`apps/tenancy/service/authz/constants.go`)

| Constant | Value | Purpose |
|----------|-------|---------|
| `NamespaceTenancy` | `service_tenancy` | Tenancy service functional permissions |
| `NamespaceTenancyAccess` | `tenancy_access` | Cross-service data access plane |
| `NamespaceProfile` | `profile_user` | Subject namespace for all profiles |

### Service Namespace Inventory

| Namespace | Service | Key Permissions |
|-----------|---------|-----------------|
| `tenancy_access` | Auth/Tenancy | member, service |
| `service_tenancy` | Auth/Tenancy | tenant_manage/view, partition_manage/view, access_manage/view, roles_manage, pages_manage/view, permission_grant |
| `service_profile` | Profile | profile_view/create/update, contacts_manage, roster_manage, devices_manage/view, settings_manage/view |
| `service_payment` | Payment | payment_send/receive, payments_search, payment_status_view/update, reconcile |
| `service_ledger` | Payment | ledger_manage/view, account_manage/view, transaction_create/reverse/update/view |
| `service_notification` | Notifications | notification_send/release/search/status_view/status_update, template_manage/view |
| `service_commerce` | Commerce | shop_create, shops_view |
| `service_trustage` | Trustage | event_ingest, workflow_manage/view, form_definition_manage/view, queue_manage/view |
| `chat_room` | Chat | view, message_send, update, delete, members_manage (per-resource) |
| `file` | Files | view, edit, delete, upload, share (per-resource) |

**Note:** `chat_room`, `chat_message`, `file`, `file_version` use per-resource tuples, not tenant-scoped.

### Roles and Permission Matrix (`constants.go`)

| Permission | Owner | Admin | Member | Service |
|------------|-------|-------|--------|---------|
| `tenant_manage` | Y | - | - | Y |
| `tenant_view` | Y | Y | Y | Y |
| `partition_manage` | Y | Y | - | Y |
| `partition_view` | Y | Y | Y | Y |
| `access_manage` | Y | Y | - | Y |
| `access_view` | Y | Y | - | Y |
| `roles_manage` | Y | Y | - | Y |
| `pages_manage` | Y | Y | - | Y |
| `pages_view` | Y | Y | Y | Y |
| `permission_grant` | Y | Y | - | Y |

---

## Tuple Builder Functions (`role_mapping.go`)

### Layer 1 — Data Access

| Function | Tuple Written |
|----------|---------------|
| `BuildAccessTuple(path, profileID)` | `tenancy_access:path#member ← profile_user:profileID` |
| `BuildServiceAccessTuple(path, profileID)` | `tenancy_access:path#service ← profile_user:profileID` |
| `BuildPartitionInheritanceTuple(parent, child)` | `tenancy_access:child#member ← tenancy_access:parent#member` |
| `BuildServicePartitionInheritanceTuple(parent, child)` | `tenancy_access:child#service ← tenancy_access:parent#service` |

### Layer 2 — Functional Permissions

| Function | Tuple Written |
|----------|---------------|
| `BuildServicePermissionTuples(path, profileID, ns, perms)` | `ns:path#granted_<perm> ← profile_user:profileID` (one per permission) |
| `BuildRoleTuples(path, profileID, role)` | `service_tenancy:path#<role> ← profile_user:profileID` |
| `BuildPermissionTuple(ns, path, perm, profileID)` | `ns:path#granted_<perm> ← profile_user:profileID` |

### Audience Permission Parsing

**`ParseAudiencePermissions(audiences)`** — Extracts per-namespace permission grants. Supports two formats:

| Format | Example | Behavior |
|--------|---------|----------|
| **New (explicit)** | `{"service_profile": ["tenant_view", "partition_view"]}` | Grants only listed permissions |
| **Legacy** | `{"namespaces": ["service_profile"]}` | Grants all `RoleService` permissions (backward compat) |

**`AudienceNamespaces(audiences)`** — Returns sorted namespace list from either format.

**`AllServicePermissions()`** — Returns full `RoleService` permission list (legacy fallback).

### Deprecated

`BuildServiceInheritanceTuples(path, namespaces)` — Legacy blanket bridge: `ns:path#service ← tenancy_access:path#service`. Gives all permissions in a namespace. Replaced by `BuildServicePermissionTuples`.

---

## Service Account Permission Model

### Explicit Permissions (New Architecture)

Each SA declares per-namespace permissions in its `Audiences` field:
```json
{"service_profile": ["tenant_view", "partition_view"], "service_tenancy": ["tenant_view"]}
```

Tuples written by `AuthzServiceAccountSyncEvent` (subject = **profile_id**):
```
tenancy_access:t/p#service                    ← profile_id   (Plane 1)
service_profile:t/p#granted_profile_view      ← profile_id   (Plane 2)
service_profile:t/p#granted_partition_view    ← profile_id   (Plane 2)
service_tenancy:t/p#granted_tenant_view       ← profile_id   (Plane 2)
```

Service bot bootstrap (`EnsureServiceBotTenancyAccess`) writes Plane-1 `#service`
for every SA **profile_id** across all known partitions so restarts self-heal.

### Legacy Format (Backward Compatible)

SAs with `{"namespaces": ["service_profile"]}` get all `RoleService` permissions in each namespace via `AllServicePermissions()`.

---

## Tuple Provisioning Lifecycle

### At Service Account Creation (`business/service_account.go`)
1. `EventKeyAuthzServiceAccountSync` → Plane 1 tuples + explicit Plane 2 permission tuples
2. `provisionAccessAndRoles` → `Access` record + role tuples in `service_tenancy`

### At Service Account Update
Re-emits `EventKeyAuthzServiceAccountSync` to rewrite all tuples.

### At Service Account Removal
Synchronous `authorizer.DeleteTuples`: Plane 1 tuples + all `granted_*` tuples from `ParseAudiencePermissions`.

### At Partition Creation (`events/authz_partition_sync.go`)
If partition has a parent:
- `tenancy_access:child#member ← tenancy_access:parent#member`
- `tenancy_access:child#service ← tenancy_access:parent#service`

### At Access Grant (`business/access.go`)
- `tenancy_access:path#member ← profile_user:profileID`
- Default partition roles via `BuildRoleTuples`

### At Role Assignment (`business/access.go`)
- `service_tenancy:path#<role> ← profile_user:profileID`

---

## Three-Checker Architecture (frame v1.91.0+)

### Layer 1 — `TenancyAccessChecker` (Data Access — All Transports)

`CheckAccess(ctx)` auto-selects relation based on caller type:
- Regular users → `tenancy_access:path#member`
- `system_internal` → `tenancy_access:path#service`

Wired as interceptor on all transports (Connect, HTTP, gRPC).

### Layer 2 — `FunctionAccessInterceptor` (Functional Permissions — Automatic)

**Automatic enforcement from proto annotations.** The `FunctionAccessInterceptor` reads a procedure→permissions map built from proto `method_permissions` and checks each permission via `FunctionChecker` before the handler runs.

```go
sd := profilepb.File_profile_v1_profile_proto.Services().ByName("ProfileService")
procMap := permissions.BuildProcedureMap(sd)
functionChecker := authorizer.NewFunctionChecker(auth, "service_profile")
functionAccessInterceptor := connectInterceptors.NewFunctionAccessInterceptor(functionChecker, procMap)
```

- **No manual `authz.CanXxx()` calls needed** for tenant-level checks
- Resource-level checks (per-room, per-file, per-shop) stay in handlers — interceptor is complementary
- Self-bypass RPCs are excluded from procMap and checked inline with `FunctionChecker.Check()`

### Layer 2 (Legacy) — `FunctionChecker` Direct

`Check(ctx, permission)` checks specific permission in the service's namespace. Used only for:
- Self-bypass inline checks in handlers
- Resource-level checks that the interceptor can't handle

### Layer 3 — `ResourceAccessChecker` (Per-Resource — Handler Level)

Checks access to individual resource instances (rooms, files, etc.):

```go
roomChecker := authorizer.NewResourceAccessChecker(auth, "chat_room",
    authorizer.WithConstraints(
        authorizer.TimeWindowConstraint(9, 17, time.UTC),
    ),
    authorizer.WithPermissionConstraints("delete",
        authorizer.LocationConstraint("office-nairobi"),
    ),
)

// In handler:
err := roomChecker.Check(ctx, roomID, "send_message")

// Or with explicit subject:
err := roomChecker.CheckSubject(ctx, roomID, "manage", subjectID)

// Grant/revoke:
roomChecker.Grant(ctx, roomID, "member", profileID)
roomChecker.Revoke(ctx, roomID, "member", profileID)
```

### Contextual Constraints (All Checkers)

Constraints are evaluated **after** the Keto relation check passes. Available on all three checkers.

**Built-in constraints:**
- `TimeWindowConstraint(startHour, endHour, *time.Location)` — daily time window, midnight wrap supported
- `LocationConstraint(allowed...)` — case-insensitive location allowlist
- `AnyConstraint(a, b, c)` — OR combinator (passes if any sub-constraint passes)

**Constraint options per checker:**
| Checker | Global constraints | Per-permission constraints |
|---------|-------------------|--------------------------|
| `TenancyAccessChecker` | `WithTenancyConstraints()` | — |
| `FunctionChecker` | `WithFunctionConstraints()` | `WithFunctionPermissionConstraints(perm, ...)` |
| `ResourceAccessChecker` | `WithConstraints()` | `WithPermissionConstraints(perm, ...)` |

**Context injection (required by middleware or handler):**
```go
ctx = authorizer.WithCurrentTime(ctx, time.Now())
ctx = authorizer.WithLocation(ctx, "office-nairobi")
```

**Panic recovery:** All constraint evaluation is wrapped in `recover()` — a panicking constraint produces a `PermissionDeniedError`, not a crash.

**Constraint denials are logged** with `denial_source: "constraint"` field to distinguish from Keto denials.

### Keto Adapter Subject Format

`toKetoSubject(SubjectRef)` (frame v2):
- if `Namespace != ""` **and** `Relation != ""` → Keto `SubjectSet(namespace, id, relation)`
- otherwise → Keto bare `SubjectID(id)`

Checkers set `SubjectRef{Namespace: "profile_user", ID: **profileID**}` with empty Relation → bare `subject_id = profile_id`. Grants must use the same profile id.

---

## Complete Request Traces

### Service-to-Service Call
```
1. SA → Hydra (client_credentials) → webhook adds profile_id/roles/tenancy; sub may stay client_id
2. JWT: {sub: "service-authentication", roles: ["internal"], tenant_id, partition_id, profile_id: "d75q…"}
3. Service B: JWT validated → GetProfileID() = "d75q…" (claim wins over sub)
4. TenancyAccessChecker: IsInternalSystem()=true → relation="service"
   → Keto: tenancy_access:t/p#service subject_id=d75q… → ALLOWED
5. FunctionChecker: Check(ctx, "profile_view")
   → Keto: service_profile:t/p#granted_profile_view subject_id=d75q… → ALLOWED
```

### User Request
```
1. User login → consent → JWT: {sub: profileID, roles: ["admin"], tenant_id, partition_id}
2. Service: JWT validated → AuthenticationClaims populated
3. TenancyAccessChecker: IsInternalSystem()=false → relation="member"
   → Keto: tenancy_access:t/p#member for profile_user:profileID → ALLOWED
4. FunctionChecker: Check(ctx, "partition_manage")
   → Keto: service_tenancy:t/p#partition_manage for profile_user:profileID
   → Resolves via admin role tuple → ALLOWED
```

---

## Event-Driven Tuple Management

| Event Key | Handler | Action |
|-----------|---------|--------|
| `authorization.tuple.write` | `TupleWriteEvent` | Writes tuples to Keto |
| `authorization.tuple.delete` | `TupleDeleteEvent` | Deletes tuples from Keto |
| `authorization.service_account.sync` | `AuthzServiceAccountSyncEvent` | Full SA tuple sync (explicit perms) |
| `authorization.partition.sync` | `AuthzPartitionSyncEvent` | Partition inheritance tuples |

---

## Key Files

| File | Purpose |
|------|---------|
| `apps/tenancy/service/authz/constants.go` | Namespace, role, and permission constants |
| `apps/tenancy/service/authz/role_mapping.go` | Tuple builders, `ParseAudiencePermissions`, `AllServicePermissions` |
| `apps/tenancy/service/authz/middleware.go` | Permission check middleware (wraps FunctionChecker) |
| `apps/tenancy/service/events/authz_service_account_sync.go` | SA Keto tuple sync (explicit permissions) |
| `apps/tenancy/service/events/authz_partition_sync.go` | Partition inheritance tuples |
| `apps/tenancy/service/events/authz_tuple.go` | Event-driven tuple write/delete |
| `apps/tenancy/service/business/service_account.go` | SA creation/update/removal, `provisionAccessAndRoles` |
| `apps/tenancy/service/business/access.go` | Access grant/revoke, role assignment |
| `apps/default/service/handlers/webhook.go` | Token enrichment, `writeTokenHookResponseWithSubject` |
| `apps/default/service/handlers/login_step_4_consent.go` | User consent → token claims |
| `keto/namespaces/tenancy.ts` | Production OPL schema |
| *frame:* `security/security_claims.go` | `GetSubject`, `GetProfileID`, `ClaimsFromContext`, `IsInternalSystem` |
| *frame:* `security/authorizer/client.go` | Keto gRPC adapter, `toKetoSubject`, parallelized `BatchCheck` via WorkerPool |
| *frame:* `security/authorizer/tenancy_permission_checker.go` | TenancyAccessChecker (Plane 1), `WithTenancyConstraints()` |
| *frame:* `security/authorizer/function_checker.go` | FunctionChecker (Plane 2), `WithFunctionConstraints()`, `WithFunctionPermissionConstraints()` |
| *frame:* `security/authorizer/resource_access_checker.go` | ResourceAccessChecker (Plane 3), `WithConstraints()`, `WithPermissionConstraints()`, `Grant()`, `Revoke()`, `Members()` |
| *frame:* `security/authorizer/constraints.go` | `AccessConstraint`, `TimeWindowConstraint`, `LocationConstraint`, `AnyConstraint`, context helpers |
| *frame:* `security/interceptors/connect/tenancy_access.go` | Connect tenancy interceptor (Plane 1) |
| *frame:* `security/interceptors/connect/function_access.go` | Connect function access interceptor (Plane 2 — automatic) |
| *frame:* `security/interceptors/httptor/function_access.go` | HTTP function access middleware |
| *frame:* `opl_endpoints.go` | `/_internal/opl/` endpoint serving |
| *common:* `permissions/permissions.go` (`github.com/antinvestor/common`) | `BuildProcedureMap()`, `ForService()`, `ForMethod()` |
| *common:* `tools/generate-opl/main.go` | OPL generator from proto descriptors |
| *common:* `tools/inject-permissions/main.go` | OpenAPI permission injection |
| *common:* `proto/common/v1/permissions.proto` | `ServicePermissions`, `MethodPermissions`, `StandardRole`, `RoleBinding` |
| *per-service:* `proto/{service}/v1/{service}.proto` | Service proto with `service_permissions` + `method_permissions` |
| *per-service:* `apps/{app}/{service}.openapi.yaml` | Generated OpenAPI with `x-required-permissions` |
| *per-service:* `opl/{service}/service_{name}.opl.ts` | Generated Keto OPL (function access — from `generate-opl`) |
| *per-service:* `opl/{service}/{name}_resources.opl.ts` | Hand-authored resource OPL (Plane 3 — chat_room, file, etc.) |

---

## Common Tasks

### Granting Explicit Permissions to a Service Account
Set audiences in new format:
```json
{"service_profile": ["profile_view", "partition_view"], "service_tenancy": ["tenant_view"]}
```
Then trigger sync (`/_system/sync/clients`) to rewrite Keto tuples.

### Adding a New Service Namespace
1. **Define in proto**: Add `service_permissions` with namespace, permissions, and role_bindings to the service proto
2. **Run `generate-opl`**: `buf build proto/<svc> -o /dev/stdout | generate-opl opl/` — generates OPL to standard `opl/` directory
3. **Wire interceptor** (derive namespace from proto, never hardcode):
```go
sd := servicepb.File_service_v1_service_proto.Services().ByName("MyService")
procMap := permissions.BuildProcedureMap(sd)
functionChecker := authorizer.NewFunctionChecker(auth, permissions.ForService(sd).Namespace)
functionAccessInterceptor := connectInterceptors.NewFunctionAccessInterceptor(functionChecker, procMap)
```
4. **Register OPL**: `frame.WithOPL("namespace", oplData)` to serve at `/_internal/opl/`
5. Service accounts declare the namespace in their audiences

### Adding Resource-Level Access (Plane 3)
1. **Create OPL file**: `opl/{name}_resources.opl.ts` with resource namespaces (e.g., `chat_room`, `file`)
2. **Define roles + permits**: owner > admin > member > viewer with computed permissions
3. **Wire checker** in handler:
```go
roomChecker := authorizer.NewResourceAccessChecker(auth, "chat_room")
err := roomChecker.Check(ctx, roomID, "send_message")
```

### Adding a New Permission
1. **Add to proto**: Add permission string to `service_permissions.permissions` and appropriate `role_bindings`
2. **Add to RPC**: Add `method_permissions` to the RPC that requires it
3. **Run `generate-opl`**: Regenerates OPL in `opl/` with new permission
4. **No code changes needed** — interceptor automatically picks up the new permission
5. For self-bypass: `delete(procMap, "/pkg.Svc/Method")` and add inline `checker.Check()` in handler

### OPL Directory Convention
All OPL files live under `opl/{service}/` at the repo root, one subfolder per service namespace:
```
opl/
  chat/
    service_chat.opl.ts          # Generated (Plane 2 functional roles)
    chat_resources.opl.ts        # Hand-authored (Plane 3 per-resource access)
  files/
    file_resources.opl.ts        # Hand-authored (Plane 3)
```
- Generate with: `buf build proto/<svc> -o /dev/stdout | generate-opl opl/<svc>/`
- The `opl-push` workflow recursively collects `*.opl.ts` from `opl/` and pushes to the deployments repo

### Debugging Permission Denied
1. Check claims: `GetProfileID()`, TenantID, PartitionID — actor must be **profile_id**
2. Verify Plane 1: `tenancy_access:path#member` (user) or `#service` (SA) for that **profile_id**
3. Verify Plane 2: `ns:path#granted_<perm>` (SA) or `ns:path#<role>` (user) for that profile
4. If the error text shows a **client_id** (e.g. `service-authentication`), Frame is still using JWT `sub` — upgrade frame so checkers use `GetProfileID()`; do **not** re-key Keto to client_id
5. Confirm token extras include `profile_id` and role `"internal"` for SAs
6. For partition inheritance: verify parent→child tuple in `tenancy_access`
7. Query Keto: `wget -qO- 'http://keto-read:4466/relation-tuples?namespace=<ns>&object=<path>'`
8. Canonical identity rules: service-authentication `docs/IDENTITY_AND_AUTHORIZATION.md`
