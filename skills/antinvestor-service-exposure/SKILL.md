---
name: antinvestor-service-exposure
description: Standards and workflow for exposing Antinvestor services via Gateway API and unified APIs in the service_deployments repo (HTTPRoute composition, DNS policy, and exceptions).
---

# Antinvestor Service Exposure

Use this skill when adding, removing, or modifying public service exposure in the Antinvestor cluster. The goal is consistent, secure exposure through the Gateway API with clear DNS policy and minimal surface area.

## Principles

- Public access is through the Gateway API, not per-service DNS.
- Per-service `DNSEndpoint` generation stays disabled unless explicitly required.
- Prefer path-based HTTPRoutes on `api.stawi.{org,dev,im}` for public APIs.
- Exceptions are authentication (`accounts.stawi.org`) and OAuth2 (`oauth2.stawi.org`).

## Canonical Locations

- Unified API DNS: `manifests/namespaces/gateway/unified-api/unified-api-dns-*.yaml`
- Gateway config: `manifests/namespaces/gateway/gateway-config/`
- Service releases (Colony): `manifests/namespaces/**/service-*.yaml`
- Colony chart: `/home/j/code/antinvestor/charts/charts/colony`

## Exposure Workflow

1. **Decide the hostname and path**  
   For public APIs, use:
   - Hostnames: `api.stawi.org`, `api.stawi.dev`, `api.stawi.im`
   - Path prefixes per service (e.g., `/profile`, `/payment`)

2. **Configure HTTPRoute on the service HelmRelease**  
   In the service HelmRelease values:
   - Set `gateway.enabled: true` and `gateway.type: http`
   - Set `gateway.hostnames` to `api.stawi.*`
   - Define `gateway.httpRoute.rules` for the path prefix, URL rewrite, CORS, and backendRef

3. **Disable per-service DNS**  
   Set `externalDNS.enabled: false` in the service HelmRelease.

4. **Leave unified API DNS in gateway namespace**  
   Keep `unified-api-dns-stawi-*.yaml` as the DNS entry points.

5. **Exceptions**  
   - Authentication service: allow `accounts.stawi.org` plus tenancy key routes under `api.stawi.*`
   - OAuth2 service: keep `oauth2.stawi.org` route/DNS

## HTTPRoute Customization

The Colony chart supports:
- `gateway.httpRoute.rules` for custom rule arrays
- `gateway.httpRoute.hostnames` to override hostnames
- `gateway.httpRoute.spec` for full spec overrides

Use `rules` for standard path-based APIs. Use `spec` only when you need full control (filters, matches, parentRefs, etc.).

## Default CORS Guidance

For public admin APIs, use allowOrigins:
- `https://admin.stawi.org`
- `https://admin.stawi.dev`
- `https://admin-dev.stawi.dev`
- `https://admin-dev.stawi.org`
- `http://localhost:5173`

For public unauthenticated swagger or key endpoints, `allowOrigins: ["*"]` is acceptable when cookies are not used.

## Safety Checks

- No duplicate `PathPrefix "/"` on the same hostname across multiple services.
- `externalDNS.enabled` is `false` unless explicitly requested.
- Backends referenced in HTTPRoutes exist in the same namespace as the service.
*** End Patch"}}
