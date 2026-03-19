---
name: rebac-authorization
description: "Comprehensive guide for the Relationship-Based Access Control (ReBAC) authorization system built on Ory Keto. Covers the two-plane model (data access vs functional roles), explicit per-namespace service account permissions, Keto tuple builders, OPL namespaces, partition inheritance, middleware, and event-driven tuple management. Use when working on authorization, permissions, access control, Keto tuples, or service bot access in the antinvestor platform."
version: "3.0"
last_updated: "2026-03-15"
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

Authorization operates on **two distinct planes** using Ory Keto as the ReBAC engine:

### Plane 1 — Data Access (`tenancy_access` namespace)
- **Question:** "Can profile X access data in partition B?"
- **Cross-service:** If a profile has access to partition B, that applies in every service
- **Inheritance:** Child partitions inherit membership from parent partitions via subject sets
- **Relations:** `member` (regular users), `service` (service bots)

### Plane 2 — Functional Permissions (per-service namespaces)
- **Question:** "What can profile Z do in service G?"
- **Per-service:** Each service checks permissions in its own namespace
- **Service accounts get explicit per-permission grants** — no blanket access
- **Users get role-based grants** — OPL resolves permissions from role tuples

### Key Design Principles
1. **`profile_id` is the universal identity** — all Keto subjects use `profile_user:profileID`
2. **JWT `sub` = `profile_id`** — for service accounts, the token webhook overrides Hydra's default `sub` (client_id) to `profile_id` via `writeTokenHookResponseWithSubject`
3. **Plane 1 always checked first** — `TenancyAccessChecker` interceptor runs before handler-level functional checks
4. **Least privilege for service accounts** — each SA declares exactly which permissions it needs per namespace

---

## Identity Lifecycle

### Service Account Token Issuance
1. SA calls Hydra with `grant_type=client_credentials`, `client_id`, `client_secret`
2. Hydra calls token enrichment webhook (`handleServiceAccountEnrichment`)
3. Webhook looks up SA via Hydra admin API → extracts `profile_id` from `client.metadata`
4. Sets `roles = ["system_internal"]` (or `["system_external"]`)
5. Calls `writeTokenHookResponseWithSubject(rw, claims, sa.ProfileID)` — **overrides JWT `sub` to `profile_id`**
6. JWT issued: `sub = profileID`, `roles = ["system_internal"]`, `tenant_id`, `partition_id`

### User Token Issuance
1. User completes login → consent flow (`ShowConsentEndpoint`)
2. `buildUserTokenClaims` extracts `LoginEvent` with `profileID`, `tenantID`, `partitionID`, `accessID`
3. Fetches roles from `AccessRole` records → e.g., `["admin"]`
4. JWT: `sub = profileID`, `roles = ["admin"]`, `tenant_id`, `partition_id`

### How `system_internal` Affects Runtime
1. `ClaimsToContext`: calls `SkipTenancyChecksOnClaims` → bypasses DB-level tenancy filters
2. `TenancyAccessChecker.CheckAccess`: switches Keto relation from `"member"` to `"service"`
3. `ClaimsFromContext`: enriches claims from secondary tenancy claims via `EnrichTenancyClaims`

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
| `service_notifications` | Notifications | notification_send/release/search/status_view/status_update, template_manage/view |
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

Tuples written by `AuthzServiceAccountSyncEvent`:
```
tenancy_access:t/p#member           ← profile_user:profileID     (Plane 1)
tenancy_access:t/p#service          ← profile_user:profileID     (Plane 1)
service_profile:t/p#granted_tenant_view     ← profile_user:profileID  (Plane 2)
service_profile:t/p#granted_partition_view  ← profile_user:profileID  (Plane 2)
service_tenancy:t/p#granted_tenant_view     ← profile_user:profileID  (Plane 2)
```

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

## Two-Checker Architecture

### Layer 1 — `TenancyAccessChecker` (Data Access — All Transports)

`CheckAccess(ctx)` auto-selects relation based on caller type:
- Regular users → `tenancy_access:path#member`
- `system_internal` → `tenancy_access:path#service`

Wired as interceptor on all transports (Connect, HTTP, gRPC).

### Layer 2 — `FunctionChecker` (Functional Permissions — Per-Handler)

`Check(ctx, permission)` checks specific permission in the service's namespace.
- Namespace configured at construction: `NewFunctionChecker(auth, "service_profile")`
- Object: `tenantID/partitionID` from claims

### Keto Adapter Subject Format

`toKetoSubject(SubjectRef)`: if `Namespace != ""` → sends Keto `SubjectSet(namespace, id, relation)`. Both checkers set `SubjectRef{Namespace: "profile_user", ID: subjectID}` → becomes `SubjectSet("profile_user", subjectID, "")`.

---

## Complete Request Traces

### Service-to-Service Call
```
1. SA → Hydra (client_credentials) → webhook overrides sub=profileID
2. JWT: {sub: profileID, roles: ["system_internal"], tenant_id, partition_id}
3. Service B: JWT validated → AuthenticationClaims populated
4. TenancyAccessChecker: IsInternalSystem()=true → relation="service"
   → Keto: tenancy_access:t/p#service for profile_user:profileID → ALLOWED
5. FunctionChecker: Check(ctx, "profile_view")
   → Keto: service_profile:t/p#granted_profile_view for profile_user:profileID → ALLOWED
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
| *frame:* `security/authorizer/client.go` | Keto gRPC adapter, `toKetoSubject` |
| *frame:* `security/authorizer/tenancy_permission_checker.go` | TenancyAccessChecker (Plane 1) |
| *frame:* `security/authorizer/function_checker.go` | FunctionChecker (Plane 2) |
| *frame:* `security/interceptors/connect/tenancy_access.go` | Connect interceptor |

---

## Common Tasks

### Granting Explicit Permissions to a Service Account
Set audiences in new format:
```json
{"service_profile": ["profile_view", "partition_view"], "service_tenancy": ["tenant_view"]}
```
Then trigger sync (`/_system/sync/clients`) to rewrite Keto tuples.

### Adding a New Service Namespace
1. Create OPL class following existing patterns (include `granted_*` relations)
2. Service accounts declare the namespace in their audiences
3. The service's OAuth2 audience must match the namespace name

### Adding a New Permission
1. Add constant to `constants.go`
2. Add to appropriate roles in `RolePermissions` map
3. Add `granted_<permission>` relation to OPL namespace classes
4. Wire permission check in handler via FunctionChecker

### Debugging Permission Denied
1. Check claims: `ClaimsFromContext(ctx)` has TenantID, PartitionID, Subject (= profileID)
2. Verify Plane 1: `tenancy_access:path#member` (user) or `#service` (SA) exists
3. Verify Plane 2: `ns:path#granted_<perm>` (SA) or `ns:path#<role>` (user) exists
4. For SAs: check `ParseAudiencePermissions(sa.Audiences)` returns expected permissions
5. For partition inheritance: verify parent→child tuple in `tenancy_access`
6. Query Keto: `wget -qO- 'http://keto-read:4466/relation-tuples?namespace=<ns>&object=<path>'`
