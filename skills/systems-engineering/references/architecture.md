# Architecture Checklist

## Table of Contents
- [Extensibility Contract](#extensibility-contract)
- [Technology Constraints](#technology-constraints)
- [Implementation Depth](#implementation-depth)

---

## Extensibility Contract

Every design must expose:

- **Extension points** — where new behavior can be added without modifying existing code
- **Stable interfaces** — contracts that callers depend on, versioned explicitly
- **Plugin/provider boundaries** — clear separation between core and pluggable components
- **Versioning strategy** — how interfaces evolve (semantic versioning, additive-only, etc.)
- **Deprecation strategy** — how old interfaces are phased out (timelines, migration guides)
- **Compatibility guarantees** — what callers can rely on between versions

---

## Technology Constraints

When the user specifies technologies, protocols, languages, frameworks, or standards:

1. Use them exactly as specified
2. Integrate with their expected operational models (build systems, deployment patterns, idioms)
3. Never silently substitute alternatives
4. Additional tools may be introduced only when strictly required — justify each one
5. When a specified technology has known limitations, state them and propose mitigations

---

## Implementation Depth

For every non-trivial component (frontend module, service, worker, library, automation unit):

| Artifact | Required |
|----------|----------|
| Public API or interface definitions | Yes |
| Core data structures | Yes |
| Main execution loop / handlers / rendering | Yes |
| Critical algorithms | Yes |
| Error and cancellation paths | Yes |
| Configuration and defaults | Yes |
| Lifecycle management (init, shutdown) | Yes |

The result must be **directly implementable** — no pseudocode, no "implement this part," no deferred design decisions.

If a dependency is required, it must be **named, versioned, and integrated** — not left as "use some library for X."
