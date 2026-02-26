---
name: flutter-patterns
description: Production-grade Flutter patterns for building scalable, offline-first, resource-efficient applications with clean architecture, Riverpod 3.0 state management, and Drift database.
version: "1.0"
last_updated: "2026-02-26"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. Flutter SDK major version changes affect recommended patterns
2. Drift, Riverpod, or ConnectRPC APIs change significantly
3. Clean architecture conventions evolve (new layer patterns, naming)
4. Offline-first or sync patterns change
5. OpenID Connect or authentication patterns change
6. New anti-patterns are discovered in production

**HOW to update:**
1. Edit this file at `~/.agents/skills/flutter-patterns/SKILL.md` using the Edit tool
2. Increment the `version` field in the frontmatter (e.g., "1.0" -> "1.1")
3. Update `last_updated` to today's date (YYYY-MM-DD)
4. Update the affected section(s) to match current best practices
5. Do NOT remove the self-update protocol section

**WHEN NOT to update:**
- Project-specific customizations that don't represent universal pattern changes
- Minor dependency patch versions that don't affect patterns

---

# Flutter Development Patterns

## Activation

Apply these patterns when building, reviewing, or refactoring Flutter applications. Default to:
- **Offline-first architecture** with Drift database as single source of truth
- **Riverpod 3.0** for state management
- **ConnectRPC** for API connectivity (type-safe, streaming support)
- **OpenID Connect** for authentication with secure token management

---

## Project Structure

All applications follow feature-first clean architecture:

```
lib/
├── main.dart                       # App entry point
├── app/
│   ├── app.dart                    # MaterialApp configuration
│   ├── router.dart                 # GoRouter configuration
│   └── providers.dart              # Root ProviderScope setup
├── core/
│   ├── config/
│   │   ├── env_config.dart         # Environment configuration
│   │   └── api_config.dart         # API endpoints, OAuth settings
│   ├── auth/
│   │   ├── auth_service.dart       # OpenID Connect authentication
│   │   ├── token_manager.dart      # Token storage and refresh
│   │   ├── token_refresh_coordinator.dart  # Centralized refresh logic
│   │   ├── token_refresh_lock.dart # Prevents concurrent refreshes
│   │   ├── shared_token_service.dart # Foreground/background token access
│   │   └── platform/               # Platform-specific OAuth (mobile/desktop/web)
│   ├── database/
│   │   ├── app_database.dart       # Drift database definition
│   │   ├── app_database.g.dart     # Generated code
│   │   └── daos/                   # Data Access Objects
│   ├── networking/
│   │   ├── client.dart             # ConnectRPC client factory
│   │   ├── certificate_pinning.dart # TLS certificate pinning
│   │   └── interceptors/           # Auth, logging, retry interceptors
│   ├── sync/
│   │   ├── sync_engine.dart        # Real-time sync with streaming
│   │   └── sync_queue.dart         # Offline operation queue
│   ├── providers/                  # Global providers
│   ├── extensions/                 # Dart/Flutter extensions
│   ├── utils/
│   │   └── jwt_utils.dart          # JWT parsing and validation
│   └── theme/
│       ├── app_theme.dart          # ThemeData configuration
│       ├── color_schemes.dart      # Light/dark ColorScheme
│       └── typography.dart         # TextTheme definitions
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── platform/           # Platform-specific auth
│   │   └── presentation/
│   │       ├── providers/
│   │       └── screens/
│   └── {feature}/
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── {feature}_local_source.dart
│       │   │   └── {feature}_remote_source.dart
│       │   ├── models/             # API/DB models with JSON serialization
│       │   └── repositories/       # Repository implementations
│       ├── domain/
│       │   ├── entities/           # Domain entities (@freezed)
│       │   ├── repositories/       # Abstract repository interfaces
│       │   └── usecases/           # Business logic use cases
│       └── presentation/
│           ├── providers/          # Feature-specific Riverpod providers
│           ├── screens/            # Full-page widgets
│           └── widgets/            # Reusable UI components
├── shared/
│   ├── widgets/                    # App-wide reusable widgets
│   ├── providers/                  # Cross-feature providers
│   └── models/                     # Shared domain models
└── l10n/
    ├── app_en.arb                  # English translations
    └── app_localizations.dart      # Generated localizations
```

---

## Required Dependencies

```yaml
name: app_name
description: App description
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.5.0 <4.0.0'
  flutter: '>=3.24.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0

  # Database
  drift: ^2.22.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0

  # ConnectRPC & Networking
  connectrpc: ^1.0.0
  http: ^1.2.0
  connectivity_plus: ^6.1.0

  # Authentication
  openid_client: ^0.4.0
  flutter_secure_storage: ^9.2.0
  app_links: ^7.0.0              # Deep link handling for OAuth
  url_launcher: ^6.3.0           # Launch browser for OAuth

  # Navigation
  go_router: ^14.6.0

  # Data Classes
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

  # Background Tasks
  workmanager: ^0.5.0

  # Utilities
  intl: ^0.19.0
  collection: ^1.18.0
  equatable: ^2.0.0
  uuid: ^4.5.0
  logger: ^2.5.0
  crypto: ^3.0.0                 # For certificate pinning

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  # Code Generation
  build_runner: ^2.4.0
  riverpod_generator: ^3.0.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  drift_dev: ^2.22.0

  # Linting
  flutter_lints: ^5.0.0
  riverpod_lint: ^3.0.0
  custom_lint: ^0.7.0

  # Testing
  mocktail: ^1.0.0

flutter:
  uses-material-design: true
  generate: true
```

---

## Offline-First Architecture

### Core Principle

**Local database is the single source of truth.** All UI reads from local storage. Network syncs happen in the background.

```
┌─────────────────────────────────────────────────────────────────┐
│                           UI Layer                               │
│  (ConsumerWidget watches providers that expose database streams) │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Repository Layer                            │
│  - Exposes Stream<T> from local database (single source)         │
│  - Sync methods write to remote → then update local              │
│  - Conflict resolution with timestamps/versions                  │
└─────────────────────────────────────────────────────────────────┘
                    │                           │
                    ▼                           ▼
┌──────────────────────────────┐  ┌────────────────────────────────┐
│       Local Data Source       │  │      Remote Data Source        │
│  (Drift database + DAOs)      │  │  (Dio API client)              │
└──────────────────────────────┘  └────────────────────────────────┘
```

### Repository Pattern

```dart
// domain/repositories/task_repository.dart
abstract class TaskRepository {
  /// Stream of all tasks - always from local database
  Stream<List<Task>> watchTasks();
  
  /// Get single task by ID
  Future<Task?> getTask(String id);
  
  /// Create task locally, queue for sync
  Future<Task> createTask(TaskCreate data);
  
  /// Update task locally, queue for sync
  Future<Task> updateTask(String id, TaskUpdate data);
  
  /// Delete task locally, queue for sync
  Future<void> deleteTask(String id);
  
  /// Sync pending changes with server
  Future<SyncResult> syncPendingChanges();
  
  /// Pull latest from server and merge
  Future<void> refreshFromRemote();
}

// data/repositories/task_repository_impl.dart
class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalSource _localSource;
  final TaskRemoteSource _remoteSource;
  final SyncQueueDao _syncQueue;
  final ConnectivityProvider _connectivity;

  TaskRepositoryImpl({
    required TaskLocalSource localSource,
    required TaskRemoteSource remoteSource,
    required SyncQueueDao syncQueue,
    required ConnectivityProvider connectivity,
  })  : _localSource = localSource,
        _remoteSource = remoteSource,
        _syncQueue = syncQueue,
        _connectivity = connectivity;

  @override
  Stream<List<Task>> watchTasks() {
    // Always stream from local - this is the source of truth
    return _localSource.watchAllTasks();
  }

  @override
  Future<Task> createTask(TaskCreate data) async {
    // Generate client-side ID for offline support
    final task = Task(
      id: const Uuid().v4(),
      title: data.title,
      description: data.description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    // Write to local database immediately
    await _localSource.insertTask(task);

    // Queue for background sync
    await _syncQueue.enqueue(SyncJob(
      id: const Uuid().v4(),
      entityType: 'task',
      entityId: task.id,
      operation: SyncOperation.create,
      payload: task.toJson(),
      createdAt: DateTime.now(),
    ));

    // Attempt immediate sync if online
    if (await _connectivity.isConnected) {
      unawaited(_syncSingleTask(task));
    }

    return task;
  }

  @override
  Future<SyncResult> syncPendingChanges() async {
    if (!await _connectivity.isConnected) {
      return SyncResult.offline();
    }

    final pendingJobs = await _syncQueue.getPendingJobs();
    var synced = 0;
    var failed = 0;
    final errors = <SyncError>[];

    for (final job in pendingJobs) {
      try {
        await _processJob(job);
        await _syncQueue.markCompleted(job.id);
        synced++;
      } catch (e, stack) {
        failed++;
        errors.add(SyncError(job: job, error: e, stackTrace: stack));
        await _syncQueue.incrementRetry(job.id);
      }
    }

    return SyncResult(synced: synced, failed: failed, errors: errors);
  }

  Future<void> _processJob(SyncJob job) async {
    switch (job.operation) {
      case SyncOperation.create:
        await _remoteSource.createTask(TaskModel.fromJson(job.payload));
      case SyncOperation.update:
        await _remoteSource.updateTask(job.entityId, TaskModel.fromJson(job.payload));
      case SyncOperation.delete:
        await _remoteSource.deleteTask(job.entityId);
    }

    // Mark as synced in local DB
    await _localSource.updateSyncStatus(job.entityId, SyncStatus.synced);
  }

  @override
  Future<void> refreshFromRemote() async {
    if (!await _connectivity.isConnected) return;

    final remoteTasks = await _remoteSource.fetchAllTasks();
    final localTasks = await _localSource.getAllTasks();

    for (final remote in remoteTasks) {
      final local = localTasks.firstWhereOrNull((t) => t.id == remote.id);
      
      if (local == null) {
        // New from server - insert
        await _localSource.insertTask(remote.toEntity().copyWith(
          syncStatus: SyncStatus.synced,
        ));
      } else if (local.syncStatus == SyncStatus.synced) {
        // No local changes - safe to overwrite
        await _localSource.updateTask(remote.toEntity().copyWith(
          syncStatus: SyncStatus.synced,
        ));
      } else {
        // Conflict - resolve using timestamps
        await _resolveConflict(local, remote);
      }
    }
  }

  Future<void> _resolveConflict(Task local, TaskModel remote) async {
    // Last-write-wins strategy (can be customized)
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      await _localSource.updateTask(remote.toEntity().copyWith(
        syncStatus: SyncStatus.synced,
      ));
    }
    // Otherwise keep local version, it will sync on next push
  }
}
```

### Sync Queue Table (Drift)

```dart
// core/database/tables/sync_queue.dart
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get operation => intEnum<SyncOperation>()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttempt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

enum SyncOperation { create, update, delete }
```

### Background Sync with WorkManager

```dart
// core/services/background_sync_service.dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'syncTask') {
      final container = ProviderContainer();
      try {
        final syncService = container.read(syncServiceProvider);
        await syncService.syncAll();
        return true;
      } finally {
        container.dispose();
      }
    }
    return false;
  });
}

class BackgroundSyncService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  }

  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      'periodicSync',
      'syncTask',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      initialDelay: const Duration(seconds: 10),
    );
  }

  static Future<void> triggerImmediateSync() async {
    await Workmanager().registerOneOffTask(
      'immediateSync-${DateTime.now().millisecondsSinceEpoch}',
      'syncTask',
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
```

---

## Drift Database Setup

### Database Definition

```dart
// core/database/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Tables
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncStatus => intEnum<SyncStatus>().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Database class
@DriftDatabase(tables: [Tasks, Categories, SyncQueue], daos: [TasksDao, CategoriesDao, SyncQueueDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // For testing
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(tasks, tasks.syncStatus);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        
        if (details.wasCreated) {
          // Seed default data
          await into(categories).insert(CategoriesCompanion.insert(
            id: const Uuid().v4(),
            name: 'General',
            color: 0xFF6200EE,
          ));
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_database.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

### Data Access Objects (DAOs)

```dart
// core/database/daos/tasks_dao.dart
part of '../app_database.dart';

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  // Streams for reactive UI
  Stream<List<Task>> watchAllTasks() {
    return (select(tasks)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<Task>> watchTasksByCategory(String categoryId) {
    return (select(tasks)
      ..where((t) => t.categoryId.equals(categoryId))
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .watch();
  }

  Stream<Task?> watchTask(String id) {
    return (select(tasks)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  // CRUD operations
  Future<void> insertTask(TasksCompanion task) => into(tasks).insert(task);

  Future<void> updateTask(TasksCompanion task) =>
      (update(tasks)..where((t) => t.id.equals(task.id.value)))
          .write(task);

  Future<void> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  // Sync operations
  Future<List<Task>> getPendingSyncTasks() {
    return (select(tasks)
      ..where((t) => t.syncStatus.equals(SyncStatus.pending.index)))
        .get();
  }

  Future<void> updateSyncStatus(String id, SyncStatus status) {
    return (update(tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(syncStatus: Value(status)));
  }

  // Batch operations
  Future<void> insertAll(List<TasksCompanion> taskList) async {
    await batch((b) {
      b.insertAll(tasks, taskList, mode: InsertMode.insertOrReplace);
    });
  }
}
```

### Database Provider

```dart
// core/providers/database_provider.dart
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
}

@riverpod
TasksDao tasksDao(Ref ref) {
  return ref.watch(appDatabaseProvider).tasksDao;
}

@riverpod
CategoriesDao categoriesDao(Ref ref) {
  return ref.watch(appDatabaseProvider).categoriesDao;
}
```

---

## ConnectRPC API Connectivity

**ConnectRPC is the default protocol for all API communication.** It provides type-safe, streaming-capable RPC with protobuf serialization.

### API Configuration

```dart
// core/config/api_config.dart
class ApiConfig {
  // OAuth2 configuration (from --dart-define or environment)
  static const String oauth2IssuerUrl = String.fromEnvironment(
    'OAUTH2_ISSUER_URL',
    defaultValue: 'https://oauth2.example.com',
  );
  static const String oauth2ClientId = String.fromEnvironment(
    'OAUTH2_CLIENT_ID',
    defaultValue: 'app-client-id',
  );

  // Service endpoints
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.example.com',
  );
  static const String chatBaseUrl = String.fromEnvironment(
    'CHAT_URL',
    defaultValue: 'https://chat.example.com',
  );

  // Connection settings (optimized for low-resource devices)
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration idleTimeout = Duration(seconds: 120);
}
```

### ConnectRPC Client Factory

```dart
// core/networking/client.dart
import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http.dart' as connect_http;
import 'package:connectrpc/protocol/connect.dart' as connect_protocol;
import 'package:connectrpc/protobuf.dart' as connect_protobuf;

/// Creates a transport factory with certificate pinning
typedef CreateTransportFn = connect.Transport Function(
  Uri baseUrl,
  List<connect.Interceptor> interceptors,
);

CreateTransportFn createTransportFactory(CertificatePinning pinning) {
  return (Uri baseUrl, List<connect.Interceptor> interceptors) {
    final httpClient = pinning.createPinnedHttpClient();
    return connect_protocol.Transport(
      baseUrl: baseUrl.toString(),
      codec: const connect_protobuf.ProtoCodec(),
      httpClient: connect_http.createHttpClient(httpClient),
      interceptors: interceptors,
    );
  };
}

/// Token refresh callback type
typedef TokenRefreshCallback = Future<String> Function(String? refreshToken);

/// Service client provider example
@riverpod
Future<TaskServiceClient> taskServiceClient(Ref ref) async {
  final tokenManager = ref.watch(tokenManagerProvider);
  final onTokenRefresh = ref.watch(tokenRefreshCallbackProvider);
  final certificatePinning = ref.watch(certificatePinningProvider);

  await tokenManager.initialize();

  return newTaskServiceClient(
    createTransport: createTransportFactory(certificatePinning),
    endpoint: ApiConfig.apiBaseUrl,
    tokenManager: tokenManager,
    onTokenRefresh: onTokenRefresh,
  );
}
```

### Certificate Pinning

```dart
// core/networking/certificate_pinning.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class CertificatePinning {
  /// SHA-256 hashes of pinned certificates per domain
  /// Multiple pins per domain support certificate rotation
  final Map<String, List<String>> _pinnedHashes = {
    'api.example.com': [
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // Primary
      'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // Backup
    ],
  };

  /// Create an HTTP client with certificate pinning enabled
  HttpClient createPinnedHttpClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = ApiConfig.connectionTimeout
      ..idleTimeout = ApiConfig.idleTimeout
      ..maxConnectionsPerHost = 4
      ..autoUncompress = true;

    httpClient.badCertificateCallback = _validateCertificate;
    return httpClient;
  }

  bool _validateCertificate(X509Certificate cert, String host, int port) {
    // Allow all in debug mode for localhost/test hosts
    if (kDebugMode && _shouldBypassPinning(host)) {
      return true;
    }

    final pins = _pinnedHashes[host];
    if (pins == null || pins.isEmpty) {
      return kDebugMode; // Allow unknown hosts only in debug
    }

    // Calculate SHA-256 hash of certificate DER encoding
    final certHash = _calculateCertificateHash(cert);
    if (certHash == null) return false;

    return pins.contains(certHash);
  }

  String? _calculateCertificateHash(X509Certificate certificate) {
    try {
      final derBytes = certificate.der;
      final digest = sha256.convert(derBytes);
      return base64.encode(digest.bytes);
    } catch (e) {
      return null;
    }
  }

  bool _shouldBypassPinning(String host) =>
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host.endsWith('.local') ||
      host.endsWith('.test');
}

@riverpod
CertificatePinning certificatePinning(Ref ref) => CertificatePinning();
```

---

## OpenID Connect Authentication

### Platform-Specific OAuth Flow (RFC 8252)

**Mobile (iOS/Android):** Uses custom URL scheme with deep linking
**Desktop (Windows/macOS/Linux):** Uses loopback interface with local HTTP server
**Web:** Uses browser redirect with localStorage state

### Auth Service

```dart
// core/auth/auth_service.dart
class AuthService {
  final FlutterSecureStorage _storage;
  final AuthPlatform _platform;
  Client? _client;

  static const _scopes = ['openid', 'profile', 'email', 'offline_access'];

  AuthService({
    required FlutterSecureStorage storage,
    required AuthPlatform platform,
  })  : _storage = storage,
        _platform = platform;

  Future<void> initialize() async {
    final issuer = await Issuer.discover(Uri.parse(ApiConfig.oauth2IssuerUrl));
    _client = Client(issuer, ApiConfig.oauth2ClientId);
    await _platform.initialize(_client!);
  }

  Future<bool> login() async {
    final tokenResponse = await _platform.authenticate(_scopes);
    if (tokenResponse == null) return false;

    await _saveTokens(tokenResponse);
    return true;
  }

  Future<void> _saveTokens(TokenResponse token) async {
    await _storage.write(key: 'access_token', value: token.accessToken);
    await _storage.write(key: 'refresh_token', value: token.refreshToken);
    if (token.idToken != null) {
      await _storage.write(
        key: 'id_token',
        value: token.idToken.toCompactSerialization(),
      );
    }

    final expiresAt = token.expiresAt ?? DateTime.now().add(Duration(hours: 1));
    await _storage.write(
      key: 'token_expires_at',
      value: expiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

  Future<bool> isTokenExpired({Duration buffer = const Duration(minutes: 2)}) async {
    final expiresAtStr = await _storage.read(key: 'token_expires_at');
    if (expiresAtStr == null) return true;

    try {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtStr));
      return DateTime.now().isAfter(expiresAt.subtract(buffer));
    } catch (_) {
      return true;
    }
  }

  Future<Duration?> getTimeUntilRefreshNeeded() async {
    final expiresAtStr = await _storage.read(key: 'token_expires_at');
    if (expiresAtStr == null) return null;

    try {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtStr));
      const refreshBuffer = Duration(minutes: 5);
      final refreshAt = expiresAt.subtract(refreshBuffer);

      if (DateTime.now().isAfter(refreshAt)) return Duration.zero;
      return refreshAt.difference(DateTime.now());
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Refresh token with result classification
  Future<TokenRefreshResult> refreshTokenWithResult() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      return TokenRefreshResult.permanentError('No refresh token');
    }

    try {
      final credential = _client!.createCredential(
        accessToken: await getAccessToken(),
        refreshToken: refreshToken,
      );

      final newCredential = await credential
          .getTokenResponse(true)
          .timeout(const Duration(seconds: 30));

      if (newCredential.accessToken == null) {
        return TokenRefreshResult.permanentError('Empty access token');
      }

      await _saveTokens(newCredential);
      return TokenRefreshResult.success(newCredential.accessToken!);
    } on TimeoutException {
      return TokenRefreshResult.transientError('Refresh timed out');
    } catch (e) {
      return _classifyRefreshError(e.toString());
    }
  }

  /// Conservative error classification - only logout on truly permanent errors
  TokenRefreshResult _classifyRefreshError(String error) {
    final errorStr = error.toLowerCase();

    // Transient patterns - definitely NOT permanent
    const transientPatterns = [
      'timeout', 'connection refused', 'connection reset',
      'network is unreachable', 'host not found', 'dns',
      '5xx', '500', '502', '503', '504', '429',
      'temporarily unavailable', 'try again',
    ];

    for (final pattern in transientPatterns) {
      if (errorStr.contains(pattern)) {
        return TokenRefreshResult.transientError(error);
      }
    }

    // OAuth2 permanent error codes (RFC 6749)
    const permanentErrors = [
      'invalid_grant', 'invalid_client',
      'unauthorized_client', 'access_denied',
    ];

    for (final err in permanentErrors) {
      if (errorStr.contains(err)) {
        return TokenRefreshResult.permanentError(error);
      }
    }

    // Default to transient - better to retry than incorrectly logout
    return TokenRefreshResult.transientError(error);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'id_token');
    await _storage.delete(key: 'token_expires_at');
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
```

### Mobile OAuth Platform (iOS/Android)

```dart
// core/auth/platform/auth_platform_mobile.dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

const String _customScheme = 'com.example.app';
const String _customHost = 'sso';

class AuthPlatformMobile implements AuthPlatform {
  Client? _client;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  Completer<TokenResponse>? _authCompleter;

  @override
  Future<void> initialize(Client client) async {
    _client = client;
  }

  @override
  Future<TokenResponse?> authenticate(List<String> scopes) async {
    if (_client == null) throw StateError('Not initialized');

    final redirectUri = Uri.parse('$_customScheme://$_customHost/redirect');
    final flow = Flow.authorizationCodeWithPKCE(_client!)
      ..scopes.addAll(scopes)
      ..redirectUri = redirectUri;

    _authCompleter = Completer<TokenResponse>();

    // Listen for deep links
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) async {
      if (uri.scheme != _customScheme || uri.host != _customHost) return;

      // Check for OAuth error
      final error = uri.queryParameters['error'];
      if (error != null) {
        _authCompleter?.completeError(Exception('OAuth error: $error'));
        return;
      }

      // Exchange code for tokens
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      if (code == null) {
        _authCompleter?.completeError(Exception('Missing authorization code'));
        return;
      }

      try {
        final credential = await flow.callback({
          'code': code,
          if (state != null) 'state': state,
        });
        final tokenResponse = await credential.getTokenResponse();
        _authCompleter?.complete(tokenResponse);
      } catch (e) {
        _authCompleter?.completeError(e);
      }
    });

    // Launch browser with auth URL
    final authUri = flow.authenticationUri;
    if (!await launchUrl(authUri, mode: LaunchMode.externalApplication)) {
      _linkSubscription?.cancel();
      return null;
    }

    try {
      return await _authCompleter!.future.timeout(const Duration(minutes: 5));
    } finally {
      _linkSubscription?.cancel();
    }
  }
}
```

### Desktop OAuth Platform (Windows/macOS/Linux)

```dart
// core/auth/platform/auth_platform_desktop.dart
import 'dart:async';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class AuthPlatformDesktop implements AuthPlatform {
  Client? _client;
  HttpServer? _server;
  static const int _callbackPort = 5170;

  @override
  Future<void> initialize(Client client) async {
    _client = client;
  }

  @override
  Future<TokenResponse?> authenticate(List<String> scopes) async {
    if (_client == null) throw StateError('Not initialized');

    final redirectUri = Uri.parse('http://localhost:$_callbackPort');
    final flow = Flow.authorizationCodeWithPKCE(_client!)
      ..scopes.addAll(scopes)
      ..redirectUri = redirectUri;

    final completer = Completer<TokenResponse>();

    // Start local server to receive callback
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _callbackPort);

    _server!.listen((request) async {
      final error = request.uri.queryParameters['error'];
      if (error != null) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Authentication error: $error');
        await request.response.close();
        completer.completeError(Exception('OAuth error: $error'));
        return;
      }

      final code = request.uri.queryParameters['code'];
      final state = request.uri.queryParameters['state'];

      // Return success HTML page
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(_successHtml);
      await request.response.close();

      try {
        final credential = await flow.callback({
          'code': code,
          if (state != null) 'state': state,
        });
        final tokenResponse = await credential.getTokenResponse();
        completer.complete(tokenResponse);
      } catch (e) {
        completer.completeError(e);
      }
    });

    // Launch browser
    await launchUrl(flow.authenticationUri, mode: LaunchMode.externalApplication);

    try {
      return await completer.future.timeout(const Duration(minutes: 5));
    } finally {
      await _server?.close();
    }
  }

  static const _successHtml = '''
<!DOCTYPE html>
<html>
<head><title>Authentication Successful</title></head>
<body style="font-family: system-ui; text-align: center; padding: 50px;">
  <h1>Authentication Successful</h1>
  <p>You can close this window and return to the app.</p>
</body>
</html>
''';
}
```

---

## Token Management Architecture

### Token Refresh Coordinator (Single Source of Truth)

```dart
// core/auth/token_refresh_coordinator.dart
class TokenRefreshCoordinator {
  final AuthRepository _authRepo;
  final TokenRefreshLock _refreshLock;
  TokenManager? _tokenManager;
  final _eventController = StreamController<TokenRefreshEvent>.broadcast();

  TokenRefreshCoordinator({
    required AuthRepository authRepo,
    required TokenRefreshLock refreshLock,
  })  : _authRepo = authRepo,
        _refreshLock = refreshLock;

  void setTokenManager(TokenManager manager) => _tokenManager = manager;

  /// Perform coordinated token refresh
  /// - Acquires lock to prevent concurrent refreshes
  /// - Updates TokenManager cache after success
  Future<TokenRefreshCoordinatorResult> refresh({required String source}) async {
    _emitEvent(TokenRefreshEventType.started, source);

    try {
      final result = await _refreshLock.acquireAndRefresh(() async {
        final refreshResult = await _authRepo.refreshTokenWithResult();

        if (!refreshResult.isSuccess) {
          return TokenRefreshCoordinatorResult(
            success: false,
            result: refreshResult.isPermanent
                ? TokenRefreshResultType.permanentError
                : TokenRefreshResultType.transientError,
            error: refreshResult.error,
          );
        }

        // Get new token from storage
        final newToken = await _authRepo.getAccessToken();
        if (newToken == null) {
          return TokenRefreshCoordinatorResult(
            success: false,
            result: TokenRefreshResultType.transientError,
            error: 'No token after refresh',
          );
        }

        // Update in-memory cache
        await _tokenManager?.setAccessToken(newToken);

        _emitEvent(TokenRefreshEventType.succeeded, source);
        return TokenRefreshCoordinatorResult(
          success: true,
          result: TokenRefreshResultType.success,
          accessToken: newToken,
        );
      });

      // Another refresh was in progress
      if (result == null) {
        _emitEvent(TokenRefreshEventType.waitingForConcurrent, source);
        final token = await _authRepo.getAccessToken();
        await _tokenManager?.setAccessToken(token);
        return TokenRefreshCoordinatorResult(
          success: true,
          result: TokenRefreshResultType.success,
          accessToken: token,
          wasHandledByAnotherCaller: true,
        );
      }

      return result;
    } catch (e) {
      _emitEvent(TokenRefreshEventType.transientError, source, error: e.toString());
      return TokenRefreshCoordinatorResult(
        success: false,
        result: TokenRefreshResultType.transientError,
        error: e.toString(),
      );
    }
  }

  Stream<TokenRefreshEvent> get events => _eventController.stream;
  void dispose() => _eventController.close();
}

@riverpod
TokenRefreshCoordinator tokenRefreshCoordinator(Ref ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final refreshLock = ref.watch(tokenRefreshLockProvider);
  final coordinator = TokenRefreshCoordinator(
    authRepo: authRepo,
    refreshLock: refreshLock,
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
}
```

### Token Refresh Lock (Prevents Concurrent Refreshes)

```dart
// core/auth/token_refresh_lock.dart
class TokenRefreshLock {
  Completer<void>? _refreshCompleter;
  bool _isRefreshing = false;

  bool get isRefreshing => _isRefreshing;

  /// Acquire lock and execute refresh
  /// Returns null if another refresh was in progress (caller should use cached result)
  Future<T?> acquireAndRefresh<T>(Future<T> Function() refreshCallback) async {
    if (_isRefreshing && _refreshCompleter != null) {
      await _refreshCompleter!.future;
      return null; // Another refresh handled it
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<void>();

    try {
      return await refreshCallback();
    } finally {
      _isRefreshing = false;
      _refreshCompleter?.complete();
      _refreshCompleter = null;
    }
  }
}

@riverpod
TokenRefreshLock tokenRefreshLock(Ref ref) => TokenRefreshLock();
```

### Shared Token Service (Foreground & Background Access)

```dart
// core/auth/shared_token_service.dart
/// Provides unified token access for both foreground (Riverpod) and
/// background (WorkManager) contexts
class SharedTokenService {
  static final instance = SharedTokenService._();
  SharedTokenService._();

  final _storage = const FlutterSecureStorage();
  TokenManager? _tokenManager;
  AuthService? _backgroundAuthService;

  static const _expiryBuffer = Duration(minutes: 2);

  bool get isInForeground => _tokenManager != null;

  void setTokenManager(TokenManager manager) => _tokenManager = manager;
  void clearTokenManager() => _tokenManager = null;

  /// Get access token - handles both foreground and background contexts
  Future<String?> getAccessToken({
    bool ensureValid = true,
    bool tryRefresh = true,
  }) async {
    // Foreground: use TokenManager for coordinated refresh
    if (_tokenManager != null && tryRefresh) {
      if (ensureValid) {
        return _tokenManager!.ensureValidToken();
      }
      return _tokenManager!.accessToken;
    }

    // Background: read from secure storage
    final token = await _storage.read(key: 'access_token');
    if (token == null) return null;

    final isExpired = JwtUtils.isTokenExpired(token, bufferDuration: _expiryBuffer);

    if (!isExpired) return token;
    if (!ensureValid) return token;
    if (!tryRefresh) return null;

    // Attempt background refresh
    final result = await refreshTokenInBackground();
    return result.success ? result.accessToken : null;
  }

  Future<BackgroundRefreshResult> refreshTokenInBackground() async {
    _backgroundAuthService ??= AuthService(
      storage: _storage,
      platform: _createPlatformAuthenticator(),
    );

    try {
      final result = await _backgroundAuthService!.refreshTokenWithResult();

      if (result.isSuccess) {
        final newToken = await _storage.read(key: 'access_token');

        // Update foreground cache if available
        if (_tokenManager != null && newToken != null) {
          await _tokenManager!.setAccessToken(newToken);
        }

        return BackgroundRefreshResult(success: true, accessToken: newToken);
      }

      return BackgroundRefreshResult(
        success: false,
        isPermanent: result.isPermanent,
        error: result.error,
      );
    } catch (e) {
      return BackgroundRefreshResult(success: false, error: e.toString());
    }
  }

  Future<bool> hasValidToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return false;
    return !JwtUtils.isTokenExpired(token, bufferDuration: _expiryBuffer);
  }
}
```

### Proactive Token Refresh Service

```dart
// core/auth/token_refresh_service.dart
class TokenRefreshService {
  final AuthRepository _authRepository;
  final TokenRefreshCoordinator _coordinator;
  final Future<void> Function() _onLogoutNeeded;

  Timer? _refreshTimer;
  Timer? _scheduledRefreshTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  int _consecutiveFailures = 0;
  bool _isWaitingForConnectivity = false;

  static const _maxConsecutiveFailures = 10;
  static const _baseRetryDelay = Duration(seconds: 5);
  static const _maxRetryDelay = Duration(minutes: 5);
  static const _fallbackCheckInterval = Duration(seconds: 30);

  void start() {
    stop();
    _scheduleNextRefresh();

    // Fallback periodic check
    _refreshTimer = Timer.periodic(_fallbackCheckInterval, (_) => _checkAndRefresh());

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    _checkAndRefresh();
  }

  Future<void> _scheduleNextRefresh() async {
    _scheduledRefreshTimer?.cancel();

    final timeUntilRefresh = await _authRepository.getTimeUntilRefreshNeeded();
    if (timeUntilRefresh == null || timeUntilRefresh <= Duration.zero) {
      _checkAndRefresh();
      return;
    }

    _scheduledRefreshTimer = Timer(timeUntilRefresh, _checkAndRefresh);
  }

  Future<void> _checkAndRefresh() async {
    final isLoggedIn = await _authRepository.isLoggedIn();
    if (!isLoggedIn) {
      stop();
      return;
    }

    final isExpired = await _authRepository.isTokenExpired();
    if (!isExpired) {
      await _scheduleNextRefresh();
      return;
    }

    final result = await _coordinator.refresh(source: 'TokenRefreshService');
    await _handleRefreshResult(result);
  }

  Future<void> _handleRefreshResult(TokenRefreshCoordinatorResult result) async {
    if (result.success) {
      _consecutiveFailures = 0;
      await _scheduleNextRefresh();
      return;
    }

    if (result.result == TokenRefreshResultType.permanentError) {
      // Force re-login on permanent error
      await _onLogoutNeeded();
      stop();
      return;
    }

    // Transient error - retry with exponential backoff
    _consecutiveFailures++;
    final retryDelay = _calculateRetryDelay(_consecutiveFailures);

    _scheduledRefreshTimer?.cancel();
    _scheduledRefreshTimer = Timer(retryDelay, _checkAndRefresh);
  }

  Duration _calculateRetryDelay(int failureCount) {
    final exponentialDelay = _baseRetryDelay * (1 << (failureCount - 1));
    final cappedDelay = exponentialDelay > _maxRetryDelay
        ? _maxRetryDelay
        : exponentialDelay;

    // Add jitter (±20%)
    final jitterMs = (cappedDelay.inMilliseconds * 0.2 *
            (DateTime.now().millisecond / 500 - 1))
        .toInt();

    return Duration(milliseconds: cappedDelay.inMilliseconds + jitterMs);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    if (hasConnection && _isWaitingForConnectivity) {
      _isWaitingForConnectivity = false;
      _checkAndRefresh();
    }
  }

  void stop() {
    _refreshTimer?.cancel();
    _scheduledRefreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    _consecutiveFailures = 0;
    _isWaitingForConnectivity = false;
  }
}

@riverpod
TokenRefreshService tokenRefreshService(Ref ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final coordinator = ref.watch(tokenRefreshCoordinatorProvider);

  final service = TokenRefreshService(
    authRepository,
    coordinator,
    () async {
      await authRepository.logout();
      ref.invalidate(authStateProvider);
    },
  );

  ref.onDispose(service.stop);
  return service;
}
```

### JWT Utilities

```dart
// core/utils/jwt_utils.dart
class JwtUtils {
  /// Decode JWT claims without verification
  static Map<String, dynamic>? getClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Get token expiry from 'exp' claim
  static DateTime? getTokenExpiry(String token) {
    final claims = getClaims(token);
    if (claims == null) return null;

    final exp = claims['exp'];
    if (exp is! int) return null;

    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }

  /// Check if token is expired (with buffer)
  static bool isTokenExpired(String token, {Duration bufferDuration = Duration.zero}) {
    final expiry = getTokenExpiry(token);
    if (expiry == null) return true;

    return DateTime.now().isAfter(expiry.subtract(bufferDuration));
  }

  /// Get time until token expires
  static Duration? getTimeUntilExpiry(String token) {
    final expiry = getTokenExpiry(token);
    if (expiry == null) return null;

    final now = DateTime.now();
    if (now.isAfter(expiry)) return Duration.zero;

    return expiry.difference(now);
  }
}
```

### Auth State Provider

```dart
// features/auth/presentation/providers/auth_state_provider.dart
enum AuthState { authenticated, unauthenticated, loading }

@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  Future<AuthState> build() async {
    final authRepo = ref.watch(authRepositoryProvider);
    final isLoggedIn = await authRepo.isLoggedIn();

    if (isLoggedIn) {
      final result = await authRepo.ensureValidAccessTokenWithStatus();

      if (result.token != null) {
        return AuthState.authenticated;
      }

      // Only logout on permanent failure
      if (result.needsRelogin) {
        return AuthState.unauthenticated;
      }

      // Transient error - keep session active
      return AuthState.authenticated;
    }

    return AuthState.unauthenticated;
  }

  Future<void> login() async {
    state = const AsyncValue.loading();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.login();

      if (!ref.mounted) return;

      final isLoggedIn = await authRepo.isLoggedIn();
      if (!isLoggedIn) {
        state = const AsyncValue.data(AuthState.unauthenticated);
        return;
      }

      // Reload TokenManager cache after login
      final tokenManager = ref.read(tokenManagerProvider);
      await tokenManager.initialize();

      // Start proactive token refresh
      ref.read(tokenRefreshServiceProvider).start();

      state = const AsyncValue.data(AuthState.authenticated);
    } catch (e, stack) {
      if (ref.mounted) {
        state = AsyncValue.error(e, stack);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final tokenManager = ref.read(tokenManagerProvider);

      ref.read(tokenRefreshServiceProvider).stop();
      await authRepo.logout();
      await tokenManager.clearTokens();

      if (!ref.mounted) return;
      state = const AsyncValue.data(AuthState.unauthenticated);
    } catch (e, stack) {
      if (ref.mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }
}
```

---

## Riverpod 3.0 Patterns

### Provider Organization

```dart
// features/tasks/presentation/providers/tasks_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tasks_providers.g.dart';

/// Repository provider - single instance
@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) {
  return TaskRepositoryImpl(
    localSource: ref.watch(taskLocalSourceProvider),
    remoteSource: ref.watch(taskRemoteSourceProvider),
    syncQueue: ref.watch(syncQueueDaoProvider),
    connectivity: ref.watch(connectivityProvider),
  );
}

/// Stream of all tasks - reactive from database
@riverpod
Stream<List<Task>> tasks(Ref ref) {
  return ref.watch(taskRepositoryProvider).watchTasks();
}

/// Single task by ID
@riverpod
Stream<Task?> taskById(Ref ref, String taskId) {
  return ref.watch(taskRepositoryProvider).watchTask(taskId);
}

/// Filtered tasks
@riverpod
Stream<List<Task>> filteredTasks(Ref ref, TaskFilter filter) {
  return ref.watch(tasksProvider.stream).map((tasks) {
    return tasks.where((task) {
      if (filter.showCompleted == false && task.isCompleted) return false;
      if (filter.categoryId != null && task.categoryId != filter.categoryId) return false;
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        return task.title.toLowerCase().contains(query) ||
            (task.description?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();
  });
}

/// Task list controller with mutations
@riverpod
class TaskListController extends _$TaskListController {
  @override
  FutureOr<void> build() {}

  Future<void> createTask(TaskCreate data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).createTask(data);
    });
  }

  Future<void> toggleComplete(String taskId) async {
    final task = await ref.read(taskRepositoryProvider).getTask(taskId);
    if (task == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).updateTask(
        taskId,
        TaskUpdate(isCompleted: !task.isCompleted),
      );
    });
  }

  Future<void> deleteTask(String taskId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).deleteTask(taskId);
    });
  }

  Future<void> syncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).syncPendingChanges();
      await ref.read(taskRepositoryProvider).refreshFromRemote();
    });
  }
}

/// Filter state
@riverpod
class TaskFilterNotifier extends _$TaskFilterNotifier {
  @override
  TaskFilter build() => const TaskFilter();

  void setShowCompleted(bool show) {
    state = state.copyWith(showCompleted: show);
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(categoryId: categoryId);
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = const TaskFilter();
  }
}
```

### Ref.mounted Pattern

```dart
@riverpod
class AuthController extends _$AuthController {
  @override
  AuthState build() => const AuthState.initial();

  Future<void> login(String email, String password) async {
    state = const AuthState.loading();

    try {
      final user = await ref.read(authRepositoryProvider).login(email, password);
      
      // Always check mounted after async operations
      if (!ref.mounted) return;
      
      state = AuthState.authenticated(user);
    } catch (e, stack) {
      if (!ref.mounted) return;
      state = AuthState.error(e.toString());
    }
  }
}
```

### Connectivity-Aware Providers

```dart
@Riverpod(keepAlive: true)
class ConnectivityNotifier extends _$ConnectivityNotifier {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  ConnectivityState build() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      state = ConnectivityState(
        isConnected: isConnected,
        type: results.firstOrNull ?? ConnectivityResult.none,
      );

      // Trigger sync when coming back online
      if (isConnected && !state.isConnected) {
        ref.read(syncServiceProvider).syncAll();
      }
    });

    ref.onDispose(() => _subscription?.cancel());

    return const ConnectivityState(isConnected: true, type: ConnectivityResult.wifi);
  }
}

@riverpod
bool isOnline(Ref ref) {
  return ref.watch(connectivityNotifierProvider).isConnected;
}
```

---

## Material 3 Theming

### Theme Configuration

```dart
// core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF6750A4);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      
      // Typography
      textTheme: _textTheme,
      
      // AppBar - flat M3 style
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      
      // Cards - tonal elevation
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: colorScheme.surfaceContainerLow,
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      
      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
  );
}
```

### Theme Provider

```dart
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    _loadSavedTheme();
    return ThemeMode.system;
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved != null) {
      state = ThemeMode.values.byName(saved);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
```

---

## Performance Optimization

### Widget Optimization Rules

```dart
// 1. Use const constructors everywhere possible
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});  // const constructor
  final Task task;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),  // const EdgeInsets
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),  // const widgets
            Text(task.description ?? ''),
          ],
        ),
      ),
    );
  }
}

// 2. Push Consumer/watch as deep as possible
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      // Only this part rebuilds when tasks change
      body: Consumer(
        builder: (context, ref, child) {
          final tasksAsync = ref.watch(tasksProvider);
          return tasksAsync.when(
            data: (tasks) => TaskListView(tasks: tasks),
            loading: () => const LoadingIndicator(),
            error: (e, _) => ErrorView(error: e),
          );
        },
      ),
      // FAB doesn't rebuild when tasks change
      floatingActionButton: const AddTaskFAB(),
    );
  }
}

// 3. Use ListView.builder for long lists
class TaskListView extends StatelessWidget {
  const TaskListView({super.key, required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasks.length,
      // Use itemExtent when items have fixed height
      itemExtent: 80,
      itemBuilder: (context, index) => TaskCard(task: tasks[index]),
    );
  }
}

// 4. Extract callback functions
class TaskCheckbox extends ConsumerWidget {
  const TaskCheckbox({super.key, required this.taskId, required this.isCompleted});
  final String taskId;
  final bool isCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Checkbox(
      value: isCompleted,
      // Use ref.read in callbacks, not ref.watch
      onChanged: (_) => ref.read(taskListControllerProvider.notifier).toggleComplete(taskId),
    );
  }
}
```

### Memory Management

```dart
// 1. Dispose controllers in StatefulWidgets
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _searchController,
      focusNode: _focusNode,
      onChanged: (query) => ref.read(taskFilterNotifierProvider.notifier).setSearchQuery(query),
    );
  }
}

// 2. Use ref.onDispose for provider cleanup
@riverpod
class WebSocketNotifier extends _$WebSocketNotifier {
  WebSocketChannel? _channel;

  @override
  Stream<Message> build() {
    _channel = WebSocketChannel.connect(Uri.parse('wss://api.example.com/ws'));

    ref.onDispose(() {
      _channel?.sink.close();
    });

    return _channel!.stream.map((data) => Message.fromJson(jsonDecode(data)));
  }
}

// 3. Image optimization
class OptimizedImage extends StatelessWidget {
  const OptimizedImage({super.key, required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      // Resize in memory to target size
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).toInt(),
      cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).toInt(),
      // Placeholder while loading
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: child,
        );
      },
      // Error placeholder
      errorBuilder: (context, error, stack) => Icon(
        Icons.broken_image_outlined,
        size: size,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
```

### Avoid Expensive Operations in Build

```dart
// BAD: Computing in build
class BadExample extends StatelessWidget {
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    // This runs every rebuild!
    final sortedItems = items.toList()..sort((a, b) => a.name.compareTo(b.name));
    final total = items.fold(0.0, (sum, item) => sum + item.price);
    
    return Column(children: [
      Text('Total: $total'),
      for (final item in sortedItems) ItemWidget(item: item),
    ]);
  }
}

// GOOD: Use select or compute in provider
@riverpod
List<Item> sortedItems(Ref ref) {
  final items = ref.watch(itemsProvider);
  return items.toList()..sort((a, b) => a.name.compareTo(b.name));
}

@riverpod
double itemsTotal(Ref ref) {
  final items = ref.watch(itemsProvider);
  return items.fold(0.0, (sum, item) => sum + item.price);
}

class GoodExample extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortedItems = ref.watch(sortedItemsProvider);
    final total = ref.watch(itemsTotalProvider);

    return Column(children: [
      Text('Total: $total'),
      for (final item in sortedItems) ItemWidget(item: item),
    ]);
  }
}
```

---

## Domain Models with Freezed

```dart
// domain/entities/task.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    String? description,
    @Default(false) bool isCompleted,
    DateTime? dueDate,
    String? categoryId,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(SyncStatus.pending) SyncStatus syncStatus,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

@freezed
class TaskCreate with _$TaskCreate {
  const factory TaskCreate({
    required String title,
    String? description,
    DateTime? dueDate,
    String? categoryId,
  }) = _TaskCreate;
}

@freezed
class TaskUpdate with _$TaskUpdate {
  const factory TaskUpdate({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    String? categoryId,
  }) = _TaskUpdate;
}

@freezed
class TaskFilter with _$TaskFilter {
  const factory TaskFilter({
    @Default(true) bool showCompleted,
    String? categoryId,
    String? searchQuery,
  }) = _TaskFilter;
}

enum SyncStatus { pending, syncing, synced, error }
```

---

## Navigation with GoRouter

```dart
// app/router.dart
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(ref.watch(authStateProvider.stream)),
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.isAuthenticated ?? false;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TasksScreen(),
            ),
            routes: [
              GoRoute(
                path: 'task/:taskId',
                builder: (context, state) => TaskDetailScreen(
                  taskId: state.pathParameters['taskId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/categories',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CategoriesScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
}

// Refresh stream for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

---

## Testing

### Unit Testing Providers

```dart
void main() {
  group('TaskRepository', () {
    late ProviderContainer container;
    late MockTaskLocalSource mockLocalSource;
    late MockTaskRemoteSource mockRemoteSource;

    setUp(() {
      mockLocalSource = MockTaskLocalSource();
      mockRemoteSource = MockTaskRemoteSource();

      container = ProviderContainer(
        overrides: [
          taskLocalSourceProvider.overrideWithValue(mockLocalSource),
          taskRemoteSourceProvider.overrideWithValue(mockRemoteSource),
          connectivityProvider.overrideWith((_) => true),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('createTask inserts locally and queues sync', () async {
      final taskCreate = TaskCreate(title: 'Test Task');

      when(() => mockLocalSource.insertTask(any()))
          .thenAnswer((_) async {});

      final repo = container.read(taskRepositoryProvider);
      final task = await repo.createTask(taskCreate);

      expect(task.title, 'Test Task');
      expect(task.syncStatus, SyncStatus.pending);

      verify(() => mockLocalSource.insertTask(any())).called(1);
    });

    test('watchTasks streams from local source', () async {
      final tasks = [
        Task(id: '1', title: 'Task 1', createdAt: DateTime.now(), updatedAt: DateTime.now()),
        Task(id: '2', title: 'Task 2', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ];

      when(() => mockLocalSource.watchAllTasks())
          .thenAnswer((_) => Stream.value(tasks));

      final repo = container.read(taskRepositoryProvider);
      final result = await repo.watchTasks().first;

      expect(result.length, 2);
      expect(result[0].title, 'Task 1');
    });
  });
}
```

### Widget Testing

```dart
void main() {
  group('TaskCard', () {
    testWidgets('displays task title and description', (tester) async {
      final task = Task(
        id: '1',
        title: 'Test Task',
        description: 'Test description',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: TaskCard(task: task)),
          ),
        ),
      );

      expect(find.text('Test Task'), findsOneWidget);
      expect(find.text('Test description'), findsOneWidget);
    });

    testWidgets('checkbox toggles completion', (tester) async {
      final task = Task(
        id: '1',
        title: 'Test Task',
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mockController = MockTaskListController();
      when(() => mockController.toggleComplete('1')).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListControllerProvider.overrideWith(() => mockController),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: TaskCard(task: task)),
          ),
        ),
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      verify(() => mockController.toggleComplete('1')).called(1);
    });
  });
}
```

### Integration Testing with Drift

```dart
void main() {
  group('TasksDao Integration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('insertTask and watchAllTasks', () async {
      final dao = db.tasksDao;

      final task = TasksCompanion.insert(
        id: '1',
        title: 'Test Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dao.insertTask(task);

      final stream = dao.watchAllTasks();
      final tasks = await stream.first;

      expect(tasks.length, 1);
      expect(tasks.first.title, 'Test Task');
    });

    test('sync status updates', () async {
      final dao = db.tasksDao;

      await dao.insertTask(TasksCompanion.insert(
        id: '1',
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: Value(SyncStatus.pending),
      ));

      await dao.updateSyncStatus('1', SyncStatus.synced);

      final task = await (db.select(db.tasks)..where((t) => t.id.equals('1'))).getSingle();
      expect(task.syncStatus, SyncStatus.synced);
    });
  });
}
```

---

## Code Generation Commands

```bash
# Generate all (Riverpod, Freezed, Drift, JSON)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch --delete-conflicting-outputs

# Generate localizations
flutter gen-l10n

# Clean and regenerate
dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs
```

---

## Deprecated API Migration

**Never use deprecated APIs.** When encountering deprecated code, migrate immediately to the modern equivalent.

### Common Deprecations

| Deprecated | Modern Replacement | Notes |
|------------|-------------------|-------|
| `Color.withValues(alpha: 0.5)` | `Color.withOpacity(0.5)` | `withValues` is deprecated |
| `Color.opacity` | `Color.a` | Direct alpha access |
| `Theme.of(context).accentColor` | `Theme.of(context).colorScheme.secondary` | Material 3 |
| `FlatButton` | `TextButton` | Material 3 buttons |
| `RaisedButton` | `ElevatedButton` | Material 3 buttons |
| `OutlineButton` | `OutlinedButton` | Material 3 buttons |
| `Scaffold.of(context).showSnackBar` | `ScaffoldMessenger.of(context).showSnackBar` | Context-free snackbars |
| `WillPopScope` | `PopScope` | Predictive back gesture |
| `Navigator.of(context).pushNamed` | `context.go()` / `context.push()` | GoRouter navigation |
| `MediaQuery.of(context).size` | `MediaQuery.sizeOf(context)` | Optimized rebuilds |
| `MediaQuery.of(context).padding` | `MediaQuery.paddingOf(context)` | Optimized rebuilds |
| `StateNotifierProvider` | `NotifierProvider` | Riverpod 3.0 |
| `StateProvider` | `NotifierProvider` | Riverpod 3.0 |
| `ChangeNotifierProvider` | `NotifierProvider` | Riverpod 3.0 |

### Migration Examples

```dart
// ❌ Deprecated
final fadedColor = primaryColor.withValues(alpha: 0.15);
final size = MediaQuery.of(context).size;

// ✅ Modern
final fadedColor = primaryColor.withOpacity(0.15);
final size = MediaQuery.sizeOf(context);
```

### Dialog/Wizard Step Pattern

**Never use integers for multi-step dialog state.** Use enums for type-safety and readability.

```dart
// ❌ Bad - Integer steps are error-prone and hard to read
class _AddTaskDialogState extends State<AddTaskDialog> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      0 => _buildTitleStep(),
      1 => _buildDetailsStep(),
      2 => _buildConfirmStep(),
      _ => const SizedBox.shrink(),
    };
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);  // Easy to mess up bounds
    }
  }
}

// ✅ Good - Enum steps are self-documenting and type-safe
enum AddTaskStep { title, details, confirm }

class _AddTaskDialogState extends State<AddTaskDialog> {
  AddTaskStep _step = AddTaskStep.title;

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      AddTaskStep.title => _buildTitleStep(),
      AddTaskStep.details => _buildDetailsStep(),
      AddTaskStep.confirm => _buildConfirmStep(),
    };  // Exhaustive - compiler catches missing cases
  }

  void _next() {
    setState(() {
      _step = switch (_step) {
        AddTaskStep.title => AddTaskStep.details,
        AddTaskStep.details => AddTaskStep.confirm,
        AddTaskStep.confirm => AddTaskStep.confirm,
      };
    });
  }

  void _back() {
    setState(() {
      _step = switch (_step) {
        AddTaskStep.title => AddTaskStep.title,
        AddTaskStep.details => AddTaskStep.title,
        AddTaskStep.confirm => AddTaskStep.details,
      };
    });
  }

  bool get _canGoBack => _step != AddTaskStep.title;
  bool get _isLastStep => _step == AddTaskStep.confirm;
}
```

```dart
// ✅ Even better - Enum with extension for navigation logic
enum OnboardingStep { welcome, permissions, profile, complete }

extension OnboardingStepX on OnboardingStep {
  OnboardingStep? get next => switch (this) {
    OnboardingStep.welcome => OnboardingStep.permissions,
    OnboardingStep.permissions => OnboardingStep.profile,
    OnboardingStep.profile => OnboardingStep.complete,
    OnboardingStep.complete => null,
  };

  OnboardingStep? get previous => switch (this) {
    OnboardingStep.welcome => null,
    OnboardingStep.permissions => OnboardingStep.welcome,
    OnboardingStep.profile => OnboardingStep.permissions,
    OnboardingStep.complete => OnboardingStep.profile,
  };

  bool get isFirst => this == OnboardingStep.welcome;
  bool get isLast => this == OnboardingStep.complete;
  
  int get stepNumber => index + 1;
  int get totalSteps => OnboardingStep.values.length;
  
  String get title => switch (this) {
    OnboardingStep.welcome => 'Welcome',
    OnboardingStep.permissions => 'Permissions',
    OnboardingStep.profile => 'Your Profile',
    OnboardingStep.complete => 'All Set!',
  };
}

// Usage in widget
class _OnboardingScreenState extends State<OnboardingScreen> {
  OnboardingStep _step = OnboardingStep.welcome;

  void _next() {
    final next = _step.next;
    if (next != null) {
      setState(() => _step = next);
    } else {
      _completeOnboarding();
    }
  }

  void _back() {
    final previous = _step.previous;
    if (previous != null) {
      setState(() => _step = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step.title),
        leading: _step.isFirst 
            ? null 
            : BackButton(onPressed: _back),
      ),
      body: switch (_step) {
        OnboardingStep.welcome => const WelcomeContent(),
        OnboardingStep.permissions => const PermissionsContent(),
        OnboardingStep.profile => const ProfileContent(),
        OnboardingStep.complete => const CompleteContent(),
      },
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: _step.stepNumber / _step.totalSteps,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _next,
                child: Text(_step.isLast ? 'Get Started' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

```dart
// ❌ Deprecated - WillPopScope
WillPopScope(
  onWillPop: () async {
    return await _confirmExit();
  },
  child: Scaffold(...),
)

// ✅ Modern - PopScope with canPop
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop) return;
    final shouldPop = await _confirmExit();
    if (shouldPop && context.mounted) {
      Navigator.of(context).pop();
    }
  },
  child: Scaffold(...),
)
```

```dart
// ❌ Deprecated Riverpod
final counterProvider = StateProvider<int>((ref) => 0);
final userProvider = StateNotifierProvider<UserNotifier, User>(...);

// ✅ Modern Riverpod 3.0
@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;
  void increment() => state++;
}
```

### Detecting Deprecated APIs

```yaml
# analysis_options.yaml
analyzer:
  errors:
    deprecated_member_use: warning
    deprecated_member_use_from_same_package: warning
  language:
    strict-casts: true
    strict-raw-types: true

linter:
  rules:
    - deprecated_consistency
    - avoid_deprecated_api_calls
```

---

## Error Handling Strategy

### Philosophy

Balance three competing concerns:
1. **User Experience** - Show actionable, non-technical messages
2. **Debugging** - Capture full context for developers
3. **Monitoring** - Track patterns without noise

### Error Classification

```dart
// core/errors/app_error.dart
sealed class AppError {
  String get userMessage;
  String get technicalMessage;
  bool get isRecoverable;
  bool get shouldReport;
}

/// User-caused errors - don't report to monitoring
class ValidationError extends AppError {
  final String field;
  final String reason;
  
  ValidationError({required this.field, required this.reason});
  
  @override
  String get userMessage => reason;
  
  @override
  String get technicalMessage => 'Validation failed: $field - $reason';
  
  @override
  bool get isRecoverable => true;
  
  @override
  bool get shouldReport => false; // User error, not a bug
}

/// Expected failures - report only if persistent
class NetworkError extends AppError {
  final int? statusCode;
  final String? endpoint;
  final Duration? retryAfter;
  
  NetworkError({this.statusCode, this.endpoint, this.retryAfter});
  
  @override
  String get userMessage => 'Connection issue. Please check your network.';
  
  @override
  String get technicalMessage => 
      'Network error: $statusCode on $endpoint';
  
  @override
  bool get isRecoverable => true;
  
  @override
  bool get shouldReport => false; // Report only after N retries fail
}

/// Unexpected failures - always report
class UnexpectedError extends AppError {
  final Object error;
  final StackTrace stackTrace;
  final String? context;
  
  UnexpectedError(this.error, this.stackTrace, {this.context});
  
  @override
  String get userMessage => 'Something went wrong. Please try again.';
  
  @override
  String get technicalMessage => '$context: $error';
  
  @override
  bool get isRecoverable => false;
  
  @override
  bool get shouldReport => true; // Always report unexpected errors
}

/// Business rule violations - don't report
class BusinessError extends AppError {
  final String code;
  final String message;
  
  BusinessError({required this.code, required this.message});
  
  @override
  String get userMessage => message;
  
  @override
  String get technicalMessage => 'Business error [$code]: $message';
  
  @override
  bool get isRecoverable => true;
  
  @override
  bool get shouldReport => false; // Expected business logic
}
```

### Error Handler Service

```dart
// core/errors/error_handler.dart
class ErrorHandler {
  final ErrorReporter _reporter;
  final AppLogger _logger;
  
  ErrorHandler({
    required ErrorReporter reporter,
    required AppLogger logger,
  })  : _reporter = reporter,
        _logger = logger;

  /// Handle error with appropriate logging and reporting
  AppError handle(Object error, StackTrace stack, {String? context}) {
    final appError = _classify(error, stack, context: context);
    
    // Always log for debugging
    if (appError.shouldReport) {
      _logger.error(
        appError.technicalMessage,
        error: error,
        stackTrace: stack,
      );
    } else {
      _logger.debug(appError.technicalMessage);
    }
    
    // Report to monitoring only when appropriate
    if (appError.shouldReport) {
      _reporter.report(
        error: error,
        stackTrace: stack,
        context: context,
        severity: appError.isRecoverable ? Severity.warning : Severity.error,
      );
    }
    
    return appError;
  }

  AppError _classify(Object error, StackTrace stack, {String? context}) {
    // Network errors
    if (error is SocketException || error is TimeoutException) {
      return NetworkError(endpoint: context);
    }
    
    // HTTP errors
    if (error is HttpException) {
      final statusCode = _extractStatusCode(error);
      
      // Client errors (4xx) - usually not bugs
      if (statusCode != null && statusCode >= 400 && statusCode < 500) {
        if (statusCode == 401 || statusCode == 403) {
          return AuthError(statusCode: statusCode);
        }
        if (statusCode == 404) {
          return NotFoundError(resource: context);
        }
        if (statusCode == 422) {
          return ValidationError(field: 'request', reason: error.message);
        }
        return BusinessError(code: 'HTTP_$statusCode', message: error.message);
      }
      
      // Server errors (5xx) - may be bugs, report after retries
      if (statusCode != null && statusCode >= 500) {
        return NetworkError(statusCode: statusCode, endpoint: context);
      }
    }
    
    // ConnectRPC errors
    if (error is ConnectException) {
      return _classifyConnectError(error, context);
    }
    
    // Token errors
    if (error is TokenRefreshPermanentException) {
      return AuthError(statusCode: 401, isPermanent: true);
    }
    
    // Database errors
    if (error is DriftException) {
      return UnexpectedError(error, stack, context: 'Database: $context');
    }
    
    // Fallback - unexpected error, always report
    return UnexpectedError(error, stack, context: context);
  }

  AppError _classifyConnectError(ConnectException error, String? context) {
    switch (error.code) {
      case Code.invalidArgument:
      case Code.failedPrecondition:
        return ValidationError(
          field: context ?? 'request',
          reason: error.message,
        );
      case Code.notFound:
        return NotFoundError(resource: context);
      case Code.permissionDenied:
      case Code.unauthenticated:
        return AuthError(statusCode: 403);
      case Code.unavailable:
      case Code.deadlineExceeded:
        return NetworkError(endpoint: context);
      case Code.resourceExhausted:
        return NetworkError(
          endpoint: context,
          retryAfter: const Duration(seconds: 30),
        );
      default:
        return UnexpectedError(error, StackTrace.current, context: context);
    }
  }
}

@riverpod
ErrorHandler errorHandler(Ref ref) {
  return ErrorHandler(
    reporter: ref.watch(errorReporterProvider),
    logger: ref.watch(loggerProvider),
  );
}
```

### UI Error Display

```dart
// shared/widgets/error_display.dart
class ErrorDisplay extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;

  const ErrorDisplay({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(error),
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              error.userMessage,  // Always show user-friendly message
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (error.isRecoverable && onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AppError error) => switch (error) {
    NetworkError() => Icons.wifi_off_rounded,
    AuthError() => Icons.lock_outline_rounded,
    NotFoundError() => Icons.search_off_rounded,
    ValidationError() => Icons.warning_amber_rounded,
    _ => Icons.error_outline_rounded,
  };
}
```

### Provider Error Handling Pattern

```dart
@riverpod
class TaskListController extends _$TaskListController {
  @override
  FutureOr<void> build() {}

  Future<void> createTask(TaskCreate data) async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(taskRepositoryProvider).createTask(data);
      } catch (e, stack) {
        // Classify and handle error
        final error = ref.read(errorHandlerProvider).handle(
          e, stack,
          context: 'createTask',
        );
        
        // Re-throw as AppError for UI handling
        throw error;
      }
    });
  }
}

// In UI
ref.listen(taskListControllerProvider, (prev, next) {
  next.whenOrNull(
    error: (error, _) {
      if (error is AppError) {
        // Show user-friendly message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.userMessage)),
        );
      }
    },
  );
});
```

### Error Reporting Thresholds

```dart
// core/errors/error_reporter.dart
class ErrorReporter {
  final Map<String, _ErrorTracker> _trackers = {};
  
  static const _reportThreshold = 3;  // Report after 3 occurrences
  static const _windowDuration = Duration(minutes: 5);

  /// Report error only if it exceeds threshold in time window
  /// Prevents noise from transient issues
  void reportWithThreshold(
    String errorKey,
    Object error,
    StackTrace stack, {
    String? context,
  }) {
    final tracker = _trackers.putIfAbsent(
      errorKey,
      () => _ErrorTracker(),
    );
    
    tracker.record();
    
    // Only report if threshold exceeded in time window
    if (tracker.countInWindow(_windowDuration) >= _reportThreshold) {
      _sendToMonitoring(error, stack, context: context);
      tracker.reset();
    }
  }

  /// Always report - for unexpected errors
  void reportImmediately(
    Object error,
    StackTrace stack, {
    String? context,
    Severity severity = Severity.error,
  }) {
    _sendToMonitoring(error, stack, context: context, severity: severity);
  }

  void _sendToMonitoring(
    Object error,
    StackTrace stack, {
    String? context,
    Severity severity = Severity.error,
  }) {
    // Send to Sentry, Crashlytics, etc.
    // Include: error, stack, context, user ID, app version, device info
  }
}

class _ErrorTracker {
  final List<DateTime> _occurrences = [];
  
  void record() => _occurrences.add(DateTime.now());
  
  int countInWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    _occurrences.removeWhere((t) => t.isBefore(cutoff));
    return _occurrences.length;
  }
  
  void reset() => _occurrences.clear();
}
```

### Logging Levels

```dart
// core/logging/app_logger.dart
class AppLogger {
  /// Debug - Development only, verbose
  /// Not sent to monitoring
  void debug(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      log('DEBUG: $message', data: data);
    }
  }
  
  /// Info - Significant events (login, sync complete)
  /// Sent to monitoring as breadcrumbs
  void info(String message, {Map<String, dynamic>? data}) {
    log('INFO: $message', data: data);
    _addBreadcrumb(message, data: data);
  }
  
  /// Warning - Recoverable issues (retry needed, fallback used)
  /// Sent to monitoring with context
  void warning(String message, {Object? error, Map<String, dynamic>? data}) {
    log('WARN: $message', error: error, data: data);
    _addBreadcrumb(message, level: 'warning', data: data);
  }
  
  /// Error - Failures requiring investigation
  /// Sent to monitoring immediately
  void error(
    String message, {
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
  }) {
    log('ERROR: $message', error: error, stackTrace: stackTrace, data: data);
    _reportError(error, stackTrace, message: message, data: data);
  }
}
```

### What NOT to Show Users

| Error Type | Show to User | Log | Report to Monitoring |
|------------|--------------|-----|---------------------|
| Validation (empty field) | ✅ Specific field error | Debug | ❌ |
| Network timeout | ✅ "Connection issue" | Debug | ❌ (unless persistent) |
| 401 Unauthorized | ✅ Redirect to login | Info | ❌ |
| 404 Not Found | ✅ "Item not found" | Debug | ❌ |
| 500 Server Error | ✅ "Something went wrong" | Warning | ✅ After retries fail |
| Database corruption | ✅ "Please reinstall" | Error | ✅ Immediately |
| Null pointer / crash | ✅ "Something went wrong" | Error | ✅ Immediately |
| Rate limited | ✅ "Please wait" | Info | ❌ |
| Offline operation queued | ✅ "Saved, will sync" | Debug | ❌ |

---

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| Fetch from network on every screen load | Stream from local database, sync in background |
| Store sync state in memory | Persist sync queue to database |
| Use `setState` for shared state | Use Riverpod providers |
| Create providers inside widgets | Define providers at top-level |
| Use `ref.watch` in callbacks | Use `ref.read` in callbacks |
| Wrap entire screen in Consumer | Push Consumer deep to minimize rebuilds |
| Use manual JSON parsing | Use `json_serializable` with Freezed |
| Hard-code colors and sizes | Use Theme and ColorScheme |
| Load full-size images | Resize with `cacheWidth`/`cacheHeight` |
| Use `ListView` for long lists | Use `ListView.builder` with `itemExtent` |
| Forget to dispose controllers | Always dispose in `dispose()` |
| Skip const constructors | Use `const` everywhere possible |
| Nest navigation deeply | Use GoRouter with declarative routes |
| Test with mocked database | Test with real in-memory Drift database |
| Use REST/Dio for service APIs | Use ConnectRPC for type-safe RPC |
| Store tokens in SharedPreferences | Use FlutterSecureStorage |
| Refresh tokens on every API call | Use proactive background refresh |
| Force logout on any token error | Classify errors (transient vs permanent) |
| Multiple concurrent token refreshes | Use TokenRefreshLock mutex |
| Hardcode OAuth credentials | Use `--dart-define` environment config |
| Skip certificate pinning | Pin certificates for all API domains |
| Separate foreground/background auth | Use SharedTokenService for unified access |
| Use deprecated APIs (`withValues`) | Use modern APIs (`withOpacity`) |
| Use `int _step` for wizard/dialog state | Use enums with exhaustive switch |
| Show technical errors to users | Show user-friendly messages via `AppError.userMessage` |
| Report all errors to monitoring | Classify errors, report only unexpected ones |
| Catch and swallow errors silently | Always log, classify, and handle appropriately |
| Show stack traces in production | Log stack traces, show generic message to user |

---

## Checklist Before Committing

- [ ] All providers use `@riverpod` annotation
- [ ] All models use `@freezed` annotation
- [ ] Database streams used for reactive UI
- [ ] Sync queue persists pending operations
- [ ] `const` constructors used where possible
- [ ] Consumer widgets pushed deep in tree
- [ ] `ref.read` used in callbacks, `ref.watch` in build
- [ ] Controllers disposed in StatefulWidgets
- [ ] Images optimized with `cacheWidth`/`cacheHeight`
- [ ] `ListView.builder` used for long lists
- [ ] Theme colors from `ColorScheme`, not hard-coded
- [ ] ConnectRPC clients use certificate pinning
- [ ] Token refresh uses coordinator (no direct refresh calls)
- [ ] Auth errors classified as transient vs permanent
- [ ] Tokens stored in FlutterSecureStorage
- [ ] OAuth config uses `--dart-define` (no hardcoded secrets)
- [ ] No deprecated APIs used (`withValues` → `withOpacity`)
- [ ] Dialog/wizard steps use enums, not integers
- [ ] Errors classified (ValidationError, NetworkError, UnexpectedError)
- [ ] User-facing errors show `userMessage`, not technical details
- [ ] Unexpected errors reported to monitoring immediately
- [ ] Expected errors (network, validation) not reported as bugs
- [ ] Tests cover providers, widgets, and database DAOs
- [ ] Code generation complete: `dart run build_runner build`
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes

---

## Quick Reference

| Need | Use |
|------|-----|
| State management | Riverpod 3.0 with `@riverpod` |
| Local database | Drift with DAOs |
| API connectivity | ConnectRPC with certificate pinning |
| API data models | Freezed + json_serializable (+ protobuf) |
| Authentication | OpenID Connect with PKCE |
| Token storage | FlutterSecureStorage |
| Token refresh | TokenRefreshCoordinator + TokenRefreshService |
| Background token access | SharedTokenService |
| Navigation | GoRouter |
| Background sync | WorkManager |
| Connectivity | connectivity_plus |
| Theming | Material 3 with `ColorScheme.fromSeed()` |
| Immutable state | Freezed `@freezed` |
| Async patterns | `AsyncValue.when()` |
| Lists | `ListView.builder` with `itemExtent` |
| Images | `Image.network` with `cacheWidth`/`cacheHeight` |
| Tests (unit) | `ProviderContainer` with overrides |
| Tests (widget) | `ProviderScope` with overrides |
| Tests (database) | In-memory Drift database |

## Security Checklist

- [ ] Certificate pinning configured for all API domains
- [ ] Tokens stored in FlutterSecureStorage (not SharedPreferences)
- [ ] OAuth uses Authorization Code Flow with PKCE
- [ ] Custom URL scheme registered for mobile deep links
- [ ] Token expiry checked with 2-minute buffer
- [ ] Refresh errors classified (transient vs permanent)
- [ ] No hardcoded credentials (use `--dart-define`)
- [ ] Background refresh uses SharedTokenService

## Related Topics

riverpod-state-management | drift-database | clean-architecture | material-design-3 | offline-first | connectrpc | openid-connect | token-management | error-handling | deprecated-api-migration
