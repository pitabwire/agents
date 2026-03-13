---
name: rebac-authorization
description: "Comprehensive guide for the Relationship-Based Access Control (ReBAC) authorization system built on Ory Keto. Covers the two-plane model (data access vs functional roles), Keto subject set composition, tuple builders, OPL namespaces, service bot access, partition inheritance, middleware, and event-driven tuple management. Use when working on authorization, permissions, access control, Keto tuples, or service bot access in the antinvestor platform."
version: "2.1"
last_updated: "2026-03-06"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. New namespaces, roles, or permissions are added to `constants.go`
2. New tuple builder functions are added to `role_mapping.go`
3. The OPL namespace schema changes (`keto/namespaces/tenancy.ts`)
4. The middleware permission checks change
5. New authorization planes or access patterns are introduced
6. The subject set composition chain changes (e.g., service bot resolution)
7. Event-driven tuple management patterns change (`events/authz_tuple.go`)
8. New services are added to `AllServiceNamespaces`
9. The consent flow's tuple provisioning logic changes
10. Frame library's `TenancyAccessChecker` or `security.Authorizer` API changes

**HOW to update:**
1. Edit this file at `~/.claude/skills/rebac-authorization/SKILL.md` using the Edit tool
2. Increment the `version` field in the frontmatter (e.g., "1.0" -> "1.1")
3. Update `last_updated` to today's date (YYYY-MM-DD)
4. Update the affected section(s) to match current implementation
5. Do NOT remove the self-update protocol section

**WHEN NOT to update:**
- Temporary debugging changes or experiments
- Changes to files outside the authorization system (handlers, business logic unrelated to authz)

---

# ReBAC Authorization System

## Activation

Apply this knowledge when:
- Working on authorization, permissions, or access control
- Writing or reviewing Keto tuples or OPL namespaces
- Modifying service bot access patterns
- Working on partition creation, access grants, or role assignments
- Debugging "permission denied" errors in the tenancy service
- Adding new services that need authorization

---

## Architecture Overview

Authorization operates on **two distinct planes** using Ory Keto as the ReBAC engine:

### Plane 1 — Data Access (`tenancy_access` namespace)
- **Question:** "Can profile X access data in partition B?"
- **Cross-service:** If a profile has access to partition B, that applies in every service
- **Inheritance:** Child partitions inherit membership from parent partitions via subject sets
- **Namespace:** `tenancy_access`

### Plane 2 — Functional Roles (per-service namespaces)
- **Question:** "What can profile Z do in service G?"
- **Per-service:** Each service independently assigns roles and permissions
- **No cross-partition inheritance:** Roles are scoped to a tenant, not inherited across partitions
- **Namespaces:** `service_tenancy`, `service_payment`, `service_ledger`, etc.

### Key Design Principle
Namespace names match OAuth2 audience names exactly (e.g., `service_tenancy`, `service_profile`). This eliminates the need for audience-to-namespace conversion.

---

## Critical Constraint: Keto v1alpha2 Does NOT Evaluate OPL Permits

The Keto v1alpha2 gRPC API only resolves tuples and subject sets — it does **not** evaluate the `permits` block in OPL. This means:

1. **Permissions must be materialized as tuples** — each role assignment writes both the role tuple AND all permission tuples
2. **Subject set composition** is the only way to grant transitive access
3. The OPL `permits` block exists for documentation and future Keto versions, but has no runtime effect with v1alpha2

This is why `RolePermissions` exists and why `BuildRoleTuples` writes N+1 tuples per namespace (1 role + N permissions).

---

## Namespaces

### Constants (`apps/tenancy/service/authz/constants.go`)

| Constant | Value | Purpose |
|----------|-------|---------|
| `NamespaceTenancy` | `service_tenancy` | Tenancy service's functional permissions |
| `NamespaceTenancyAccess` | `tenancy_access` | Cross-service data access plane |
| `NamespaceProfile` | `default/profile` | Subject namespace for user profiles |

### Service Namespaces (`AllServiceNamespaces`)

All per-service namespaces that receive role/permission tuples:
- `service_tenancy`
- `service_payment`
- `service_ledger`
- `service_commerce`
- `service_trustage`
- `service_notifications`
- `service_profile`
- `service_devices`

**Convention:** Namespace names = OAuth2 audience names. When adding a new service, add its audience name to `AllServiceNamespaces`.

---

## Roles and Permissions

### Roles (`constants.go`)

| Role | Constant | Description |
|------|----------|-------------|
| `owner` | `RoleOwner` | Full control including tenant management |
| `admin` | `RoleAdmin` | Everything except tenant management |
| `member` | `RoleMember` | View-only access |
| `service` | `RoleService` | Full access for service bots (same as owner) |

### Permissions (`constants.go`)

| Permission | Owner | Admin | Member | Service |
|------------|-------|-------|--------|---------|
| `manage_tenant` | Y | - | - | Y |
| `view_tenant` | Y | Y | Y | Y |
| `manage_partition` | Y | Y | - | Y |
| `view_partition` | Y | Y | Y | Y |
| `manage_access` | Y | Y | - | Y |
| `view_access` | Y | Y | - | Y |
| `manage_roles` | Y | Y | - | Y |
| `manage_pages` | Y | Y | - | Y |
| `view_pages` | Y | Y | Y | Y |
| `grant_permission` | Y | Y | - | Y |

The `RolePermissions` map in `role_mapping.go` materializes this table.

---

## Tuple Builder Functions (`role_mapping.go`)

### `BuildRoleTuples(tenantID, profileID, role)` — User Role Assignment
Writes role + all permission tuples across **all service namespaces**.
Used when a user is assigned a role (e.g., admin) for a tenant.

**Tuple count:** `len(AllServiceNamespaces) * (1 + len(permissions))`

### `BuildPermissionTuple(namespace, tenantID, permission, profileID)` — Direct Permission Grant
Single permission grant in a specific namespace. Used for fine-grained access without a role.

### `BuildAccessTuple(tenancyPath, profileID)` — Data Access Grant (Plane 1)
Writes `tenancy_access:tenantID/partitionID#member@profile:profileID`.
Grants the profile data access to the partition across all services.

### `BuildPartitionInheritanceTuple(parentPath, childPath)` — Partition Hierarchy
Writes a subject set tuple: `tenancy_access:childPath#member@(tenancy_access:parentPath#member)`.
Anyone with access to the parent automatically gets access to the child. Keto resolves transitively.

### `BuildServiceAccessTuple(tenancyPath, profileID)` — Service Bot Access
Writes `tenancy_access:path#service@profile:botID`.
Marks a profile as a service account for the given tenancy path.

### `BuildServiceInheritanceTuples(tenancyPath, namespaces)` — Service Bot Bridge Tuples
Creates the subject set chain for service bots. For each namespace:
1. **Cross-namespace bridge:** `ns:path#service ← tenancy_access:path#service`
2. **Permission bridges:** `ns:path#perm ← ns:path#service` (for each service permission)

**When to call:**
- At **partition creation**: pass `AllServiceNamespaces` to cover all services
- At **consent time**: pass `requestedAudiences` (audience names = namespace names)

---

## Service Bot Subject Set Resolution Chain

Service bots get access through Keto composition — no code-level bypass:

```
botID
  → tenancy_access:path#service     (BuildServiceAccessTuple — per bot, at consent)
    → ns:path#service               (cross-namespace bridge — per partition, at creation)
      → ns:path#manage_tenant       (permission bridge — per partition, at creation)
      → ns:path#view_tenant
      → ns:path#manage_partition
      → ... (all service permissions)
```

**Security property:** Even if a bad actor manipulates tuples, they still can't gain access unless the full chain exists. The OPL structure constrains what's possible.

**No self-healing:** If bridge tuples are missing, access is denied. Missing tuples indicate misconfiguration. There is no middleware-level fallback.

---

## Partition Hierarchy Inheritance (Plane 1 Only)

When a child partition is created with a parent:
1. `BuildPartitionInheritanceTuple(parentPath, childPath)` creates a subject set tuple
2. All members of the parent automatically become members of the child
3. Keto resolves this transitively (grandparent → parent → child)
4. This only affects Plane 1 (data access) — Plane 2 roles are NOT inherited

**Emitted at:** `business/partition.go:CreatePartition` when `request.GetParentId() != ""`

---

## Tuple Provisioning Lifecycle

### At Partition Creation (`business/partition.go`)
1. Service inheritance bridge tuples for all namespaces (`BuildServiceInheritanceTuples(path, AllServiceNamespaces)`)
2. Partition inheritance tuple if parent exists (`BuildPartitionInheritanceTuple`)

### At Consent Time — Service Bots (`handlers/login_step_4_consent.go`)
1. Data access tuple (`BuildAccessTuple`)
2. Service access tuple (`BuildServiceAccessTuple`)
3. Bridge tuples for requested audiences (`BuildServiceInheritanceTuples(path, requestedAudiences)`)

### At Access Grant (`business/access.go:CreateAccess`)
1. Data access tuple (`BuildAccessTuple`)

### At Role Assignment (`business/access.go:CreateAccessRole`)
1. Role + permission tuples across all namespaces (`BuildRoleTuples`)

### At Access/Role Removal
1. Corresponding delete events are emitted

---

## Event-Driven Tuple Management (`events/authz_tuple.go`)

Tuples are written/deleted asynchronously via the event system:

| Event Key | Handler | Action |
|-----------|---------|--------|
| `authorization.tuple.write` | `TupleWriteEvent` | Writes tuples to Keto |
| `authorization.tuple.delete` | `TupleDeleteEvent` | Deletes tuples from Keto |

**Payload format:** `TuplePayload` with `[]TupleData` (JSON-serializable).
Supports subject sets via `SubjectRelation` field (maps to `security.SubjectRef.Relation`).

**Helper functions:**
- `TuplesToPayload(tuples)` — converts `[]security.RelationTuple` to event payload
- `payloadToTuples(payload)` — converts back

---

## Two-Checker Architecture

Authorization is enforced by two independent checkers from the frame library:

### Layer 1 — `TenancyAccessChecker` (Data Access — All Transports)

**Location:** `frame/security/authorizer/tenancy_permission_checker.go`

`CheckAccess(ctx)` auto-selects relation based on caller type:
- Regular users: checks `tenancy_access:path#member`
- `system_internal` callers: checks `tenancy_access:path#service`
- Checks namespace: `tenancy_access`
- Object ID: `tenantID/partitionID` (from claims)

**Interceptors for all transports (all in frame):**

| Transport | File | Function |
|-----------|------|----------|
| Connect | `interceptors/connect/tenancy_access.go` | `NewTenancyAccessInterceptor(checker)` |
| HTTP | `interceptors/httptor/tenancy_access.go` | `TenancyAccessMiddleware(next, checker)` |
| gRPC (unary) | `interceptors/grpc/tenancy_access.go` | `UnaryTenancyAccessInterceptor(checker)` |
| gRPC (stream) | `interceptors/grpc/tenancy_access.go` | `StreamTenancyAccessInterceptor(checker)` |

**Error mapping per transport:**

| Transport | Helper | Invalid claims | Permission denied | Other |
|-----------|--------|---------------|-------------------|-------|
| Connect | `ToConnectError` | `CodeUnauthenticated` | `CodePermissionDenied` | `CodeInternal` |
| HTTP | `ToHTTPStatusCode` | `401 Unauthorized` | `403 Forbidden` | `500 Internal` |
| gRPC | `ToGrpcError` | `codes.Unauthenticated` | `codes.PermissionDenied` | `codes.Internal` |

**Setup in `cmd/main.go` (tenancy service):**
```go
checker := authorizer.NewTenancyAccessChecker(sm.GetAuthorizer(ctx), authz.NamespaceTenancyAccess)

// Connect
connectInterceptors.NewTenancyAccessInterceptor(checker)

// HTTP
securityhttp.TenancyAccessMiddleware(handler, checker)
```

### Layer 2 — `FunctionChecker` (Functional Permissions — Per-Handler)

**Location:** `frame/security/authorizer/function_checker.go`
**Wrapper:** `apps/tenancy/service/authz/middleware.go`

Called manually in handlers via `authz.Middleware` methods. Each handler calls the appropriate permission check.

- `Check(ctx, permission)` checks specific permission in the service's namespace
- Checks namespace: `service_tenancy` (or whatever `objectNamespace` is configured)
- Object ID: `tenantID/partitionID` (from claims)

**Available checks:**
- `CanManageTenant`, `CanViewTenant`
- `CanManagePartition`, `CanViewPartition`
- `CanManageAccess`, `CanManageRoles`
- `CanManagePages`, `CanViewPages`
- `CanGrantPermission`

All checks resolve through Keto — there are no code-level bypasses.

**Current tenancy endpoint mapping:**
- Tenant read endpoints use `tenant_view`; mutations use `tenant_manage`
- Partition read endpoints use `partition_view`; mutations use `partition_manage`
- Access read endpoints use `access_manage`; mutations use `access_manage`
- Page read endpoints use `pages_view`; mutations use `pages_manage`
- Client and service-account read endpoints use `partition_view`
- Client and service-account create/update/delete endpoints use `permission_grant`
- Internal HTTP endpoints under `/_system/` must enforce `system_internal` explicitly in handler code

---

## OPL Namespace Schema (`keto/namespaces/tenancy.ts`)

### `tenancy_access` — Data Access Plane
```typescript
class tenancy_access implements Namespace {
  related: {
    member: (default_profile | tenancy_access)[]  // subject sets for partition inheritance
    service: default_profile[]                      // service bot marker
  }
}
```

### `service_tenancy` — Functional Roles
```typescript
class service_tenancy implements Namespace {
  related: {
    owner: default_profile[]
    admin: default_profile[]
    member: default_profile[]
    service: (default_profile | tenancy_access)[]   // subject sets for bot bridging

    // Permission relations accept subject sets for service role bridging
    manage_tenant: (default_profile | service_tenancy)[]
    view_tenant: (default_profile | service_tenancy)[]
    // ... all other permissions follow same pattern
  }
}
```

**Why permissions accept `service_tenancy` subject sets:** This enables the permission bridge pattern where `ns:path#perm ← ns:path#service` is a subject set reference back to the same namespace.

---

## Testing

### Unit Tests (`authz/role_mapping_test.go`)
Test tuple builder functions — no Docker required.

### Integration Tests (`authz/middleware_test.go`)
Real Keto container via `testketo.NewWithOpts()`. Tests:
- **FunctionChecker (Layer 2):** Owner, admin, member permission boundaries; direct permission grants; missing claims/tenant error cases
- **TenancyAccessChecker (Layer 1):** Member access allowed, service bot access allowed, no-tuple denied
- **Full two-layer:** Service bot via subject sets (both layers checked explicitly)

**Test Keto only has `service_tenancy` namespace** — tests use `seedServiceBridgeTuples` helper to write tenancy-specific bridge tuples manually (avoids writing to service_payment etc. which don't exist in test Keto).

---

## Key Files

| File | Purpose |
|------|---------|
| `apps/tenancy/service/authz/constants.go` | Namespace, role, and permission constants |
| `apps/tenancy/service/authz/role_mapping.go` | Tuple builder functions and `AllServiceNamespaces` |
| `apps/tenancy/service/authz/middleware.go` | Permission check middleware (wraps FunctionChecker) |
| `apps/tenancy/service/events/authz_tuple.go` | Event-driven tuple write/delete |
| `apps/tenancy/service/events/authz_partition_sync.go` | Bridge + inheritance tuples on partition sync |
| `apps/tenancy/service/business/partition.go` | Partition creation → emits authz sync event |
| `apps/tenancy/service/business/access.go` | Access grant/revoke → access + role tuples |
| `apps/default/service/handlers/login_step_4_consent.go` | Consent → service bot tuples |
| `keto/namespaces/tenancy.ts` | Production OPL schema |
| `apps/tenancy/tests/testketo/keto.go` | Test Keto container with embedded OPL |
| *frame:* `security/authorizer/function_checker.go` | FunctionChecker — per-handler permission checks |
| *frame:* `security/authorizer/tenancy_permission_checker.go` | TenancyAccessChecker — data access checks |
| *frame:* `security/interceptors/connect/tenancy_access.go` | Connect interceptor wrapping TenancyAccessChecker |

---

## Common Tasks

### Adding a New Service Namespace
1. Add `"service_<name>"` to `AllServiceNamespaces` in `role_mapping.go`
2. Add OPL class to `keto/namespaces/tenancy.ts` (copy `service_tenancy` pattern, adjust relations)
3. Add OPL class to test Keto in `testketo/keto.go` if integration tests need it
4. The service's OAuth2 audience must be `service_<name>` to match

### Adding a New Permission
1. Add constant to `constants.go`
2. Add to appropriate roles in `RolePermissions` map
3. Add relation to OPL namespace classes (both production and test)
4. Add `Can<Permission>` method to `Middleware` interface and implementation
5. Wire permission check in the gRPC handler

### Adding a New Role
1. Add constant to `constants.go`
2. Add permissions mapping to `RolePermissions`
3. Add relation to OPL namespace classes
4. Update OPL `permits` block if using newer Keto versions

### Debugging Permission Denied
1. Check claims are set: `security.ClaimsFromContext(ctx)` has TenantID, PartitionID, Subject
2. Verify tenancy path: `tenantID/partitionID` must match tuple objects
3. Check tuple exists in Keto: `auth.Check(ctx, req)` with correct namespace
4. For service bots: verify all three levels of the subject set chain exist
5. For partition inheritance: verify parent→child tuple exists in `tenancy_access`
