# Models and Repositories Reference

## Table of Contents

1. [BaseModel](#basemodel)
2. [Model Patterns](#model-patterns)
3. [BaseRepository](#baserepository)
4. [Repository Patterns](#repository-patterns)
5. [Anti-Patterns](#anti-patterns)

---

## BaseModel

All database models must embed `data.BaseModel`. Never define ID, TenantID, or timestamp fields manually.

```go
// FORBIDDEN
type Job struct {
    ID        string    `gorm:"column:id;primaryKey"`
    TenantID  string    `gorm:"column:tenant_id"`
    CreatedAt time.Time `gorm:"column:created_at"`
}

// CORRECT
type Job struct {
    data.BaseModel `gorm:"embedded"`
    ProjectID   string    `gorm:"column:project_id;not null"`
    Status      JobStatus `gorm:"column:status;not null"`
}
```

### BaseModel Fields

| Field | Type | Description |
|-------|------|-------------|
| `ID` | `string` | Primary key (auto-generated) |
| `TenantID` | `string` | Multi-tenancy identifier |
| `PartitionID` | `string` | Partition identifier |
| `CreatedAt` | `time.Time` | Creation timestamp |
| `ModifiedAt` | `time.Time` | Last modification timestamp |
| `DeletedAt` | `*time.Time` | Soft delete timestamp (nil if not deleted) |

---

## Model Patterns

### Basic Model

```go
package models

import (
    "github.com/pitabwire/frame/data"
)

type JobStatus string

const (
    JobStatusQueued    JobStatus = "queued"
    JobStatusRunning   JobStatus = "running"
    JobStatusCompleted JobStatus = "completed"
)

type Job struct {
    data.BaseModel `gorm:"embedded"`
    ProjectID   string    `gorm:"column:project_id;not null"`
    Status      JobStatus `gorm:"column:status;not null;default:queued"`
    StartedAt   *time.Time `gorm:"column:started_at"`
    CompletedAt *time.Time `gorm:"column:completed_at"`
}

func (Job) TableName() string { return "jobs" }
```

### Model with State Machine

```go
type Repo struct {
    data.BaseModel `gorm:"embedded"`
    ProjectID string    `gorm:"column:project_id;not null"`
    S3Path    string    `gorm:"column:s3_path;not null"`
    State     RepoState `gorm:"column:state;not null;default:pending"`
}

func (Repo) TableName() string { return "repos" }

func (r *Repo) TransitionTo(state RepoState) error {
    if !ValidRepoTransition(r.State, state) {
        return fmt.Errorf("invalid transition from %s to %s", r.State, state)
    }
    r.State = state
    r.ModifiedAt = time.Now()
    return nil
}
```

---

## BaseRepository

All repositories must use `datastore.BaseRepository[T]` for standard CRUD. Use raw `pool.Pool` only for complex aggregations/joins.

```go
// FORBIDDEN
type jobRepository struct {
    pool pool.Pool
}

// CORRECT
type jobRepository struct {
    datastore.BaseRepository[*models.Job]
}

func NewJobRepository(dbPool pool.Pool) JobRepository {
    ctx := context.Background()
    return &jobRepository{
        BaseRepository: datastore.NewBaseRepository[*models.Job](
            ctx, dbPool, nil,
            func() *models.Job { return &models.Job{} },
        ),
    }
}
```

### BaseRepository Methods

| Method | Description |
|--------|-------------|
| `Create(ctx, entity)` | Insert new record |
| `GetByID(ctx, id)` | Get by primary key |
| `Update(ctx, entity)` | Update existing record |
| `Delete(ctx, id)` | Soft delete by ID |
| `HardDelete(ctx, id)` | Hard delete by ID |
| `List(ctx, query)` | List with query options |
| `Count(ctx, query)` | Count with query options |
| `Pool()` | Access underlying pool for custom queries |

---

## Repository Patterns

### Basic Repository

```go
package repository

type JobRepository interface {
    Create(ctx context.Context, job *models.Job) error
    GetByID(ctx context.Context, jobID string) (*models.Job, error)
    Update(ctx context.Context, job *models.Job) error
    Delete(ctx context.Context, jobID string) error
}

type jobRepository struct {
    datastore.BaseRepository[*models.Job]
}

func NewJobRepository(dbPool pool.Pool) JobRepository {
    ctx := context.Background()
    return &jobRepository{
        BaseRepository: datastore.NewBaseRepository[*models.Job](
            ctx, dbPool, nil,
            func() *models.Job { return &models.Job{} },
        ),
    }
}

func (r *jobRepository) Create(ctx context.Context, job *models.Job) error {
    return r.BaseRepository.Create(ctx, job)
}

func (r *jobRepository) GetByID(ctx context.Context, jobID string) (*models.Job, error) {
    return r.BaseRepository.GetByID(ctx, jobID)
}
```

### Repository with Custom Queries

```go
type JobRepository interface {
    Create(ctx context.Context, job *models.Job) error
    GetByID(ctx context.Context, jobID string) (*models.Job, error)
    GetByIdempotencyKey(ctx context.Context, key string) (*models.Job, error)
    ListByProject(ctx context.Context, projectID string) ([]*models.Job, error)
}

func (r *jobRepository) GetByIdempotencyKey(ctx context.Context, key string) (*models.Job, error) {
    db := r.Pool().DB(ctx, true)
    var job models.Job
    result := db.Where("idempotency_key = ? AND deleted_at IS NULL", key).First(&job)
    if result.Error != nil {
        return nil, fmt.Errorf("get job by idempotency key: %w", result.Error)
    }
    return &job, nil
}
```

### Raw Pool for Complex Queries

Only use raw pool access for aggregations, complex joins, etc.:

```go
type planMediaRepository struct {
    pool pool.Pool
}

func (r *planMediaRepository) TenantStorageUsed(ctx context.Context, tenantID string) (int64, error) {
    db := r.pool.DB(ctx, true)
    var totalBytes *int64
    result := db.Table(models.PlanMedia{}.TableName()).
        Select("COALESCE(SUM(size_bytes), 0)").
        Where("tenant_id = ? AND upload_state = ?", tenantID, string(models.UploadStateConfirmed)).
        Scan(&totalBytes)
    if result.Error != nil {
        return 0, fmt.Errorf("tenant storage used: %w", result.Error)
    }
    return *totalBytes, nil
}
```

---

## SQL Migrations

**One entrypoint: `pool.Migrate(ctx, migrationsDirPath, models...)`** (the crawler wraps it as `repository.Migrate`). In the `DoDatabaseMigrate()` branch of `main` it does, in order: GORM **AutoMigrate** on the supplied `models...`, then **applies the SQL files** under `migrationsDirPath` (default `./migrations/0001`, shipped into the image via a Dockerfile `COPY … /migrations`), tracking applied files in a `migrations` table and running only the unapplied ones. So:

> **AutoMigrate handles models; SQL files in the migrations folder handle everything AutoMigrate can't** (extensions, partial/filtered indexes, raw non-model tables, TimescaleDB hypertables). **Never** put that DDL in a Go helper that runs `db.Exec` (the `FinalizeSchema`/`EnsureServingTables` anti-pattern) — it's invisible, untracked, easy to break (a multi-statement `db.Exec` fails `cannot insert multiple commands into a prepared statement`, 42601), and it kept a service stuck 26 versions behind. Put it in files; let the migrator run it.

Two hard constraints on the files:

- **Migrations run as the application DB role** (never a superuser). Whatever a migration creates is owned by the app role.
- **Frame v1.98+ runs each file as ONE prepared statement** — it cannot contain multiple SQL commands. Keep one statement per file (the prevailing convention: table in one file, each index in its own), or put multi-step logic in a single `DO $$ ... $$` block. Ops that cannot run inside a transaction (`REFRESH MATERIALIZED VIEW CONCURRENTLY`, `CREATE MATERIALIZED VIEW ... WITH (timescaledb.continuous)`) must run at app runtime instead, not in a migration.

### Repeatability: every schema change flows through the migrator, as the app role

The deploy must self-assemble from scratch with **zero manual steps** — starting over (fresh DB) requires nothing by hand. So **every** schema change, including one you want applied "right now", goes into a migration file applied by the migrator as the app role.

**Never `psql -U postgres` (or any superuser) a schema change into a live DB.** The object then ends up owned by `postgres`, and the next migration — run as the app role — fails on `CREATE OR REPLACE` / `ALTER` / `DROP` with `ERROR: must be owner of <obj> (SQLSTATE 42501)`. That stalls the Helm release and can leave it unable to even roll back (the migration hook Job becomes a stalled resource), bouncing the deploy. *Real incident (2026-06): a procedure created live as `postgres` blocked every crawler deploy until ownership was reassigned by hand.* If you genuinely need an immediate effect, apply it **as the app role** (the app's credentials) — or just ship the migration and deploy. The app role cannot take ownership of a superuser-owned object on its own, so there is no in-migration recovery.

### Idempotent + owner-robust DO block

Make every statement re-runnable, and guard object creation so a pre-existing object (any owner) cannot trip the owner check:

```sql
-- 20260610_0131_example.sql — one DO block, applied as the app role
DO $mig$
BEGIN
    IF to_regclass('my_table') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE my_table SET (autovacuum_vacuum_scale_factor = 0)';
    END IF;
    EXECUTE 'DROP INDEX IF EXISTS my_unused_idx';

    -- Functions/procs: a guarded CREATE is owner-robust (skips if it already
    -- exists, whatever the owner). CREATE OR REPLACE keeps content current but
    -- REQUIRES ownership — fine only when the app role ever creates it.
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'my_proc') THEN
        EXECUTE $fn$ CREATE PROCEDURE my_proc(job_id INT, config JSONB)
                     LANGUAGE plpgsql AS $body$ BEGIN /* ... */ END; $body$ $fn$;
    END IF;
END
$mig$;
```

Idempotency cheatsheet: tables/extensions → `IF NOT EXISTS`; indexes → `CREATE INDEX IF NOT EXISTS` / `DROP INDEX IF EXISTS`; TimescaleDB policies/jobs → `if_not_exists => TRUE` or guard on `timescaledb_information.jobs`; functions → `CREATE OR REPLACE` (app-role-owned) or the `IF NOT EXISTS` guard above when out-of-band creation is possible.

---

## Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| Manual `ID string` field | Embed `data.BaseModel` |
| Manual `TenantID string` field | Use `data.BaseModel` |
| Manual `CreatedAt time.Time` | Use `data.BaseModel` |
| Raw SQL in business logic | Create repository method |
| Repository without interface | Define interface + struct |
| Repository returning `any` | Return concrete types |
| `psql -U postgres` a live schema change | Add a migration; the migrator applies it as the app role (consistent ownership, repeatable deploy) |
| Go helper that runs DDL (`FinalizeSchema`-style `db.Exec`) | Put the DDL in a migration file; `pool.Migrate(dir, models)` applies it |
| Read-modify-write mutation reading a replica (`DB(ctx, true)`) | Read the primary (`DB(ctx, false)`) — replica lag can miss a just-created row → silent NotFound |
