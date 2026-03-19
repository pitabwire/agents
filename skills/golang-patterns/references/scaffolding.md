# Project Scaffolding Reference

## Table of Contents

1. [Frame Blueprint](#frame-blueprint)
2. [Project Structure](#project-structure)
3. [Asset Files](#asset-files)
4. [Required Dependencies](#required-dependencies)
5. [Utility Functions](#utility-functions)

---

## Frame Blueprint

Frame provides a built-in project scaffolding tool called **Blueprint**. Use it to generate new services with the correct structure, boilerplate, and conventions already in place.

### Installation

```bash
go install github.com/pitabwire/frame/cmd/frame@latest
```

### Creating a New Project

```bash
# Basic service
frame blueprint --name my-service --module github.com/org/my-service

# Service with database
frame blueprint --name my-service --module github.com/org/my-service --with-datastore

# Service with full stack (database, cache, queue, auth)
frame blueprint --name my-service --module github.com/org/my-service \
    --with-datastore \
    --with-cache \
    --with-queue \
    --with-auth
```

### What Blueprint Generates

Blueprint creates a complete project with:

```
my-service/
├── apps/
│   └── default/
│       ├── cmd/main.go             # Entry point with frame service setup
│       ├── config/config.go        # Configuration struct with env tags
│       ├── service/
│       │   ├── handlers/           # Connect RPC handler stubs
│       │   ├── business/           # Business logic layer
│       │   ├── repository/         # Data access with BaseRepository
│       │   ├── models/             # Domain models with BaseModel
│       │   └── events/             # Event handler stubs
│       ├── migrations/0001/        # Initial migration directory
│       ├── tests/                  # Integration test suite with BaseTestSuite
│       └── Dockerfile              # Multi-stage build
├── pkg/                            # Shared code directory
├── localization/                   # i18n files
├── .github/workflows/              # CI/CD workflows
├── .golangci.yaml                  # Linter configuration
├── go.mod
├── go.sum
└── Makefile
```

### Blueprint Options

| Flag | Description |
|------|-------------|
| `--name` | Service name (used in frame.WithName) |
| `--module` | Go module path |
| `--with-datastore` | Add PostgreSQL datastore setup |
| `--with-cache` | Add Valkey cache manager |
| `--with-queue` | Add NATS queue pub/sub |
| `--with-auth` | Add OAuth2/OIDC security |
| `--with-events` | Add internal event system |
| `--app-name` | Name of the app directory (default: "default") |

### Adding a New App to an Existing Project

For multi-app projects (monorepo pattern):

```bash
# Add a second service to an existing project
frame blueprint --name worker-service --module github.com/org/my-service \
    --app-name worker \
    --with-datastore \
    --with-queue
```

This creates `apps/worker/` alongside the existing `apps/default/`.

### Post-Blueprint Steps

After generating:

1. Run `go mod tidy` to resolve dependencies
2. Update `.golangci.yaml` local-prefixes with your module path
3. Define your proto/Connect RPC service definitions
4. Implement business logic in the generated stubs
5. Add database migrations in `migrations/0001/`
6. Write tests extending the generated BaseTestSuite

---

## Project Structure

All applications follow this structure:

```
project/
├── apps/
│   ├── default/                    # Primary service
│   │   ├── cmd/main.go             # Entry point
│   │   ├── config/                 # Configuration structs
│   │   ├── service/
│   │   │   ├── handlers/           # Connect RPC handlers
│   │   │   ├── business/           # Business logic
│   │   │   ├── repository/         # Data access layer
│   │   │   ├── models/             # Domain models
│   │   │   └── events/             # Event handlers
│   │   ├── migrations/0001/        # Database migrations
│   │   ├── tests/                  # Integration tests
│   │   └── Dockerfile              # App-specific Dockerfile
│   └── secondary/                  # Additional services (same structure)
├── pkg/                            # Shared code across apps
│   ├── cryptoutil/                 # Encryption utilities
│   ├── dbutil/                     # Database utilities
│   └── errorutil/                  # Error handling
├── localization/                   # i18n files (messages.{lang}.toml)
├── .github/workflows/              # CI/CD workflows
├── .golangci.yaml                  # Linter configuration
├── go.mod
├── go.sum
└── Makefile
```

---

## Asset Files

Copy these files when creating projects manually (without blueprint):

| File | Source |
|------|--------|
| Linter config | `golang-patterns/assets/.golangci.yaml` |
| Dockerfile | `golang-patterns/assets/Dockerfile` |
| Makefile | `golang-patterns/assets/Makefile` |
| Lint workflow | `golang-patterns/assets/workflows/golangci-lint.yml` |
| Test workflow | `golang-patterns/assets/workflows/run_tests.yml` |
| Release workflow | `golang-patterns/assets/workflows/release.yml` |
| Publish workflow | `golang-patterns/assets/workflows/publish-release.yml` |

---

## Required Dependencies

```go
require (
    github.com/pitabwire/frame v0.x.x       // Server framework
    github.com/pitabwire/util v0.x.x        // Utility functions
    github.com/antinvestor/apis v0.x.x      // Shared API definitions (antinvestor ecosystem)
)
```

> For antinvestor ecosystem projects, use `github.com/antinvestor/apis` for shared protos. Standalone projects define protos locally in `proto/`.

---

## Utility Functions

**Always use `github.com/pitabwire/util` for common operations.**

```go
import "github.com/pitabwire/util"

// Logging (always context-aware)
log := util.Log(ctx)
log.Info("message", "key", value)
log.WithError(err).Error("failed")

// ID generation
id := util.IDString()

// Random strings
token := util.RandomAlphaNumericString(32)
code := util.RandomNumericString(6)

// Deferred closing with error logging
defer util.CloseAndLogOnError(ctx, file, "failed to close file")

// Encryption
ciphertext, err := util.EncryptValue(aesKey, []byte(plaintext))
plaintext, err := util.DecryptValue(aesKey, ciphertext)
token := util.ComputeLookupToken(hmacKey, normalizedValue)

// Environment variables
dbURL := util.GetEnv("DATABASE_URL", "postgres://localhost/dev")
```
