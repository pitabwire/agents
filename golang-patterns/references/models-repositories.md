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

## Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| Manual `ID string` field | Embed `data.BaseModel` |
| Manual `TenantID string` field | Use `data.BaseModel` |
| Manual `CreatedAt time.Time` | Use `data.BaseModel` |
| Raw SQL in business logic | Create repository method |
| Repository without interface | Define interface + struct |
| Repository returning `any` | Return concrete types |
