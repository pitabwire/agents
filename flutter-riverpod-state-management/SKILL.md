---
name: flutter-riverpod-state-management
description: Reactive state management using Riverpod 3.0 with code generation for Flutter apps. Use when building Flutter applications with Riverpod for state management, dependency injection, or reactive patterns.
version: "1.0"
last_updated: "2026-02-26"
self_updating: true
---

> **SELF-UPDATING SKILL** — This document MUST be kept accurate. Follow the update protocol below.

## Self-Update Protocol

**WHEN to update this file** (using the Edit tool on this SKILL.md):
1. Riverpod major version changes (3.x to 4.x)
2. Code generation patterns or annotations change
3. New provider types, mutation patterns, or persistence APIs are added
4. Freezed or build_runner conventions change
5. Anti-patterns list needs updating based on new features
6. Required dependency versions change significantly

**HOW to update:**
1. Edit this file at `~/.agents/skills/flutter-riverpod-state-management/SKILL.md` using the Edit tool
2. Increment the `version` field in the frontmatter (e.g., "1.0" → "1.1")
3. Update `last_updated` to today's date (YYYY-MM-DD)
4. Update the affected section(s) to match current best practices
5. Do NOT remove the self-update protocol section

**WHEN NOT to update:**
- Project-specific provider patterns
- Minor patch version bumps that don't affect API

# Riverpod 3.0 State Management

## **Priority: P0 (CRITICAL)**

Type-safe, compile-time safe reactive state management using `riverpod` and `riverpod_generator`.

## Structure

```text
lib/
├── core/
│   ├── providers/       # Global providers (dio, storage, config)
│   └── extensions/      # Ref and AsyncValue extensions
├── features/
│   └── user/
│       ├── data/        # Repositories, data sources
│       ├── domain/      # Models (@freezed), business logic
│       └── presentation/
│           ├── providers/   # Feature-specific providers
│           └── widgets/     # ConsumerWidget/HookConsumerWidget
└── shared/
    └── providers/       # Cross-feature shared providers
```

## Implementation Guidelines

- **Generator First**: Use `@riverpod` annotations exclusively. Avoid manual `Provider` definitions.
- **Immutability**: Maintain immutable states. Use `Freezed` for all state models.
- **Unified Notifier**: Use `Notifier` and `AsyncNotifier` (no more AutoDispose/Family variants).
- **Provider Methods**:
  - `ref.watch()`: Use inside `build()` to rebuild on changes.
  - `ref.listen()`: Use for side-effects (navigation, dialogs, toasts).
  - `ref.read()`: Use ONLY in callbacks (onPressed, onTap).
- **Ref.mounted**: Always check `ref.mounted` after async operations before updating state.
- **Architecture**: Enforce 3-layer separation (Data → Domain → Presentation).
- **Linting**: Enable `riverpod_lint` and `custom_lint` for dependency cycle detection.

## Provider Types (Riverpod 3.0)

### Simple Providers

```dart
@riverpod
String greeting(Ref ref) {
  return 'Hello, World!';
}

// Usage
final greeting = ref.watch(greetingProvider);
```

### Notifier (Synchronous State)

```dart
@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
  void decrement() => state--;
}

// Usage
final count = ref.watch(counterProvider);
ref.read(counterProvider.notifier).increment();
```

### AsyncNotifier (Async State)

```dart
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  Future<User> build() async {
    return await ref.watch(userRepositoryProvider).fetchCurrentUser();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => 
      ref.read(userRepositoryProvider).fetchCurrentUser()
    );
  }

  Future<void> updateProfile(String name) async {
    final previous = state;
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      final updated = await ref.read(userRepositoryProvider).updateUser(name);
      return updated;
    });

    // Revert on failure
    if (state.hasError) {
      state = previous;
    }
  }
}

// Usage with exhaustive pattern matching (sealed AsyncValue)
ref.watch(userNotifierProvider).when(
  data: (user) => UserProfile(user: user),
  loading: () => const LoadingIndicator(),
  error: (err, stack) => ErrorDisplay(error: err),
);
```

### Family Providers (Parameterized)

```dart
@riverpod
Future<User> userById(Ref ref, String userId) async {
  return await ref.watch(userRepositoryProvider).getUser(userId);
}

// Usage
final user = ref.watch(userByIdProvider('user-123'));
```

### KeepAlive Providers

```dart
@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  Settings build() {
    return const Settings.defaults();
  }
}
```

## Mutations (Riverpod 3.0 - Experimental)

Mutations track side-effect lifecycles (loading, success, error, idle):

```dart
@riverpod
class TodosNotifier extends _$TodosNotifier {
  @override
  Future<List<Todo>> build() async {
    return await ref.watch(todoRepositoryProvider).fetchAll();
  }

  @mutation
  Future<void> addTodo(String title) async {
    await ref.read(todoRepositoryProvider).create(title);
    ref.invalidateSelf();
  }

  @mutation
  Future<void> deleteTodo(String id) async {
    await ref.read(todoRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

// UI reacts to mutation state
final addMutation = ref.watch(todosNotifierProvider.addTodo);
addMutation.when(
  idle: () => const AddButton(),
  pending: () => const CircularProgressIndicator(),
  error: (err, _) => ErrorButton(error: err),
  success: (_) => const SuccessIndicator(),
);
```

## Offline Persistence (Experimental)

```dart
@riverpod
class TodosNotifier extends _$TodosNotifier with Persistable {
  @override
  Future<List<Todo>> build() async {
    await persist(
      ref.watch(storageProvider.future),
      key: 'todos',
      options: const StorageOptions(
        cacheTime: StorageCacheTime.days(7),
      ),
      encode: jsonEncode,
      decode: (json) => (jsonDecode(json) as List)
          .map((e) => Todo.fromJson(e))
          .toList(),
    ).future;

    return state.value ?? [];
  }
}
```

## Automatic Retry Configuration

```dart
// Disable globally
ProviderScope(
  retry: (retryCount, error) => null,
  child: MyApp(),
)

// Custom retry per provider
@Riverpod(retry: customRetry)
Future<Data> myData(Ref ref) async => fetchData();

Duration? customRetry(int retryCount, Object error) {
  if (error is NetworkException && retryCount < 3) {
    return Duration(seconds: retryCount * 2);
  }
  return null; // Stop retrying
}
```

## Dependency Injection Pattern

```dart
// Abstract repository
abstract class UserRepository {
  Future<User> getUser(String id);
  Future<User> updateUser(User user);
}

// Implementation
class UserRepositoryImpl implements UserRepository {
  final Dio _dio;
  UserRepositoryImpl(this._dio);

  @override
  Future<User> getUser(String id) async {
    final response = await _dio.get('/users/$id');
    return User.fromJson(response.data);
  }

  @override
  Future<User> updateUser(User user) async {
    final response = await _dio.put('/users/${user.id}', data: user.toJson());
    return User.fromJson(response.data);
  }
}

// Repository provider
@riverpod
UserRepository userRepository(Ref ref) {
  final dio = ref.watch(dioProvider);
  return UserRepositoryImpl(dio);
}

// Service using repository
@riverpod
class AuthService extends _$AuthService {
  @override
  AuthState build() => const AuthState.initial();

  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    try {
      final user = await ref.read(userRepositoryProvider).login(email, password);
      if (!ref.mounted) return; // Check mounted before state update
      state = AuthState.authenticated(user);
    } catch (e) {
      if (!ref.mounted) return;
      state = AuthState.error(e.toString());
    }
  }
}
```

## State Models with Freezed

```dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(User user) = AuthAuthenticated;
  const factory AuthState.error(String message) = AuthError;
}

// Usage with pattern matching
final authState = ref.watch(authServiceProvider);
switch (authState) {
  AuthInitial() => const LoginScreen(),
  AuthLoading() => const LoadingScreen(),
  AuthAuthenticated(:final user) => HomeScreen(user: user),
  AuthError(:final message) => ErrorScreen(message: message),
}
```

## UI Integration

```dart
class UserScreen extends ConsumerWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for side effects (toasts, navigation)
    ref.listen(authServiceProvider, (previous, next) {
      switch (next) {
        case AuthError(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        case AuthAuthenticated():
          Navigator.of(context).pushReplacementNamed('/home');
        default:
          break;
      }
    });

    // Watch for rebuilds
    final userAsync = ref.watch(userNotifierProvider);

    return Scaffold(
      body: userAsync.when(
        data: (user) => UserProfile(user: user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(userNotifierProvider),
        ),
      ),
    );
  }
}
```

## Weak Listeners (Prevent Auto-Dispose Blocking)

```dart
// Weak listener doesn't keep the provider alive
ref.listen(
  analyticsProvider,
  (_, event) => logEvent(event),
  weak: true,
);
```

## Testing (Riverpod 3.0)

```dart
void main() {
  test('counter increments', () {
    final container = ProviderContainer.test();
    // Container auto-disposes after test

    expect(container.read(counterProvider), 0);
    container.read(counterProvider.notifier).increment();
    expect(container.read(counterProvider), 1);
  });

  test('mock notifier build method only', () {
    final container = ProviderContainer.test(
      overrides: [
        // Only mock the build method, keep other methods intact
        counterProvider.overrideWithBuild((ref) => 42),
      ],
    );

    expect(container.read(counterProvider), 42);
    container.read(counterProvider.notifier).increment();
    expect(container.read(counterProvider), 43);
  });

  test('async provider with mock repository', () async {
    final container = ProviderContainer.test(
      overrides: [
        userRepositoryProvider.overrideWithValue(MockUserRepository()),
      ],
    );

    final user = await container.read(userNotifierProvider.future);
    expect(user.name, 'Mock User');
  });

  testWidgets('widget test with container access', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProvider.overrideWithValue(AsyncData(mockUser)),
        ],
        child: const MyApp(),
      ),
    );

    // Access container directly from tester
    final container = tester.container();
    container.read(counterProvider.notifier).increment();
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });
}
```

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Perform side-effects in `build()` | Use mutations or separate methods |
| Pass `BuildContext` to Notifiers | Use `ref.listen()` in widgets |
| Create providers locally in widgets | Keep providers global/top-level |
| Mutate state directly (`state.list.add()`) | Assign new state (`state = [...state, item]`) |
| Forget `ref.onDispose()` for subscriptions | Clean up streams/timers in `onDispose` |
| Update state after async without checking `mounted` | Always check `ref.mounted` first |
| Use legacy providers (`StateProvider`) | Use `Notifier`/`AsyncNotifier` |
| Ignore `ProviderException` wrapping | Catch and extract original error |

## Required Dependencies (Riverpod 3.0)

```yaml
dependencies:
  flutter_riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0

dev_dependencies:
  riverpod_generator: ^3.0.0
  build_runner: ^2.4.0
  riverpod_lint: ^3.0.0
  custom_lint: ^0.7.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0

# Optional: Offline persistence
dependencies:
  riverpod_sqflite: ^1.0.0
```

## Code Generation

```bash
# Generate providers and freezed models
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch --delete-conflicting-outputs
```

## Related Topics

flutter-patterns | layer-based-clean-architecture | dependency-injection | testing | freezed-models
