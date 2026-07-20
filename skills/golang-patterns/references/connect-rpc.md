# Connect RPC Reference

## Table of Contents

1. [API Structure](#api-structure)
2. [Importing APIs](#importing-apis)
3. [Implementing Handlers](#implementing-handlers)
4. [Server Streaming](#server-streaming)
5. [Registering Handlers](#registering-handlers)
6. [Creating Clients](#creating-clients)
7. [Error Codes](#error-codes)
8. [REST Endpoints](#rest-endpoints)

---

## API Structure

Each service repo owns its proto definitions. Shared types live in `github.com/antinvestor/common`. Go clients are BSR-generated.

**Per-service repo structure:**
```
service-profile/
├── proto/                          # Proto source (owned by this service)
│   ├── buf.yaml                    # name: buf.build/antinvestor/profile
│   ├── buf.gen.yaml
│   └── profile/v1/profile.proto
├── apps/
│   ├── default/
│   │   ├── cmd/main.go
│   │   ├── profile.openapi.yaml    # Generated OpenAPI (git-committed)
│   │   └── service_profile.opl.ts  # Generated OPL (git-committed)
│   └── devices/
├── sdk/dart/profile/v1/            # Generated Dart SDK
└── Makefile                        # Standardized (from common/templates/)
```

**Shared common types:**
```
github.com/antinvestor/common/      # Go module
├── connection/                     # Client connection helpers
├── interceptors/                   # Auth, partition interceptors
├── permissions/                    # Permission extraction from proto
├── v1/                             # Generated proto Go code (common types)
└── tools/                          # inject-permissions, generate-opl
```

**Go clients come from BSR** — no local generation:
```go
import (
    // BSR-generated (auto-published when proto is pushed)
    "buf.build/gen/go/antinvestor/profile/connectrpc/go/profile/v1/profilev1connect"
    profilepb "buf.build/gen/go/antinvestor/profile/protocolbuffers/go/profile/v1"
)
```

---

## Importing APIs

```go
import (
    "connectrpc.com/connect"

    // API types
    profilev1 "github.com/antinvestor/apis/go/profile/v1"
    notificationv1 "github.com/antinvestor/apis/go/notification/v1"

    // Connect clients/handlers
    "github.com/antinvestor/apis/go/profile/v1/profilev1connect"
    "github.com/antinvestor/apis/go/notification/v1/notificationv1connect"
)
```

---

## Implementing Handlers

```go
package handlers

type ProfileServer struct {
    Service         *frame.Service
    profileBusiness business.ProfileBusiness
    profilev1connect.UnimplementedProfileServiceHandler
}

func NewProfileServer(svc *frame.Service, biz business.ProfileBusiness) *ProfileServer {
    return &ProfileServer{
        Service:         svc,
        profileBusiness: biz,
    }
}

// Unary RPC
func (s *ProfileServer) GetById(ctx context.Context,
    req *connect.Request[profilev1.GetByIdRequest]) (*connect.Response[profilev1.GetByIdResponse], error) {

    log := util.Log(ctx)
    log.Debug("getting profile", "id", req.Msg.GetId())

    profile, err := s.profileBusiness.GetByID(ctx, req.Msg.GetId())
    if err != nil {
        if frame.ErrorIsNotFound(err) {
            return nil, connect.NewError(connect.CodeNotFound, err)
        }
        log.WithError(err).Error("failed to get profile")
        return nil, connect.NewError(connect.CodeInternal, err)
    }

    return connect.NewResponse(&profilev1.GetByIdResponse{
        Data: profile.ToAPI(),
    }), nil
}
```

---

## Server Streaming

```go
func (s *ProfileServer) Search(ctx context.Context,
    req *connect.Request[profilev1.SearchRequest],
    stream *connect.ServerStream[profilev1.SearchResponse]) error {

    log := util.Log(ctx)
    log.Info("searching profiles", "query", req.Msg.GetQuery())

    results, err := s.profileBusiness.Search(ctx, req.Msg)
    if err != nil {
        log.WithError(err).Error("search failed")
        return connect.NewError(connect.CodeInternal, err)
    }

    count := 0
    for {
        result, ok := results.ReadResult(ctx)
        if !ok {
            log.Info("search completed", "results_count", count)
            return nil
        }
        if result.IsError() {
            return connect.NewError(connect.CodeInternal, result.Error())
        }

        for _, profile := range result.Item() {
            count++
            if err := stream.Send(&profilev1.SearchResponse{
                Data: []*profilev1.ProfileObject{profile.ToAPI()},
            }); err != nil {
                return err
            }
        }
    }
}
```

---

## Registering Handlers

```go
func main() {
    ctx := context.Background()

    cfg, err := config.LoadWithOIDC[appconfig.Config](ctx)
    if err != nil {
        util.Log(ctx).WithError(err).Fatal("failed to load configuration")
    }

    ctx, svc := frame.NewServiceWithContext(ctx,
        frame.WithName("profile-service"),
        frame.WithConfig(&cfg),
        frame.WithRegisterServerOauth2Client(),
        frame.WithDatastore(),
    )

    // Initialize layers
    dbPool := svc.DatastoreManager().GetPool(ctx, datastore.DefaultPoolName)
    profileRepo := repository.NewProfileRepository(ctx, dbPool, svc.WorkManager())
    profileBiz := business.NewProfileBusiness(&cfg, profileRepo, svc.EventsManager())

    // Connect handler with authentication
    securityMan := svc.SecurityManager()
    authenticator := securityMan.GetAuthenticator(ctx)
    interceptors, _ := connectInterceptors.DefaultList(ctx, authenticator)

    profileServer := handlers.NewProfileServer(svc, profileBiz)
    _, connectHandler := profilev1connect.NewProfileServiceHandler(
        profileServer,
        connect.WithInterceptors(interceptors...),
    )

    mux := http.NewServeMux()
    mux.Handle(profilev1connect.NewProfileServiceHandler(profileServer))

    svc.Init(ctx, frame.WithHTTPHandler(mux))

    if err := svc.Run(ctx, cfg.ServerPort); err != nil {
        util.Log(ctx).WithError(err).Fatal("failed to run service")
    }
}
```

---

## Creating Clients

```go
// Client constructor
func NewNotificationClient(httpClient *http.Client, baseURL string) notificationv1connect.NotificationServiceClient {
    return notificationv1connect.NewNotificationServiceClient(httpClient, baseURL)
}

// Usage in business layer
type profileBusiness struct {
    notificationCli notificationv1connect.NotificationServiceClient
}

func (b *profileBusiness) CreateWithWelcome(ctx context.Context, req *profilev1.CreateRequest) (*models.Profile, error) {
    log := util.Log(ctx)

    profile, err := b.profileRepo.Create(ctx, profileFromRequest(req))
    if err != nil {
        return nil, fmt.Errorf("create profile: %w", err)
    }

    // Call notification service
    _, err = b.notificationCli.Send(ctx, connect.NewRequest(&notificationv1.SendRequest{
        Recipient: profile.Email,
        Template:  "welcome",
    }))
    if err != nil {
        log.WithError(err).Warn("failed to send welcome notification") // Best-effort
    }

    return profile, nil
}
```

---

## Error Codes

| Situation | Code |
|-----------|------|
| Resource not found | `connect.CodeNotFound` |
| Invalid input | `connect.CodeInvalidArgument` |
| Authentication required | `connect.CodeUnauthenticated` |
| Permission denied | `connect.CodePermissionDenied` |
| Already exists | `connect.CodeAlreadyExists` |
| Precondition failed | `connect.CodeFailedPrecondition` |
| Internal error | `connect.CodeInternal` |
| Unavailable | `connect.CodeUnavailable` |

---

## REST Endpoints

For cases requiring REST (webhooks, public APIs):

```go
func (s *ProfileServer) NewSecureRouterV1() *http.ServeMux {
    mux := http.NewServeMux()
    mux.HandleFunc("/user/info", s.RestUserInfo)
    mux.HandleFunc("/user/relations", s.RestListRelationships)
    return mux
}

func (s *ProfileServer) RestUserInfo(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    log := util.Log(ctx)

    claims := security.ClaimsFromContext(ctx)
    if claims == nil {
        http.Error(w, "unauthorized", http.StatusUnauthorized)
        return
    }

    profile, err := s.profileBusiness.GetBySubject(ctx, claims.GetSubject())
    if err != nil {
        log.WithError(err).Error("failed to get user info")
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(profile.ToAPI())
}
```
