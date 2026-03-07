---
inclusion: always
---

# Flutter Best Practices

This file supplements Guidelines.md with Flutter/Dart-specific rules. Where both files cover the same topic, this file provides the deeper detail. Guidelines.md remains the primary authority for cross-cutting concerns.

## Architecture & Design Patterns

### Clean Architecture Layers

Follow the established layer structure with strict dependency rules:

- **Data Layer**: Remote/local data sources, models, repository implementations.
- **Domain Layer**: Entities, repository interfaces, use cases (business logic).
- **Presentation Layer**: Pages, widgets, BLoC/Cubit state management.

**Dependency Rule**: Dependencies point inward: Presentation → Domain ← Data.
- Domain layer has ZERO dependencies on other layers.
- Data and Presentation layers depend on Domain abstractions only.

### SOLID Principles

**Single Responsibility**:
- One widget = one responsibility. One class = one reason to change.
- Keep widgets focused and composable. Extract complex logic into separate classes.

**Open/Closed**:
- Use abstractions and interfaces. Extend behavior through composition, not modification.
- Define repository interfaces in domain layer. Implement concrete classes in data layer.

**Liskov Substitution**:
- Subtypes must be substitutable for their base types.
- Implementations must honor interface contracts. Don't break expected behavior in subclasses.

**Interface Segregation**:
- Create small, focused interfaces. Don't force clients to depend on methods they don't use.

**Dependency Inversion**:
- Depend on abstractions, not concretions. Use dependency injection (GetIt).
- High-level modules should not depend on low-level modules. Both depend on abstractions.

### Dependency Injection with GetIt

**Note**: This project currently uses Riverpod providers for DI (per tech.md). GetIt rules below apply for non-Riverpod dependencies (e.g., platform services, third-party SDKs) or if the project adopts GetIt in the future.

**Configuration**:
- Configure all dependencies in `lib/core/di/injection.dart`.
- `registerLazySingleton` for shared instances (repositories, services).
- `registerFactory` for BLoCs/Cubits (new instance per request).
- `registerSingleton` for truly global instances.
- Initialize GetIt in `main()` before `runApp()`.

**Best Practices**:
- Register in order: Core → Data → Domain → Presentation.
- Use interfaces for all registrations.
- Avoid circular dependencies.
- Test dependency graph on app startup.

```dart
// lib/core/di/injection.dart
final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Core services
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  getIt.registerLazySingleton<SecureStorage>(() => SecureStorage());
  
  // Repositories (Singleton)
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt(), getIt()),
  );
  
  // Use cases
  getIt.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(getIt()),
  );
  
  // BLoCs (Factory - new instance each time)
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(getIt()),
  );
}
```

### BLoC/Cubit State Management

**Note**: This project currently uses Riverpod (per tech.md). The BLoC/Cubit rules below apply if BLoC is adopted for specific features. For Riverpod rules, see the next section. Both patterns share the same principles: immutable state, no business logic in widgets, and proper disposal.

**Architecture Rules**:
- One BLoC per feature — keep BLoCs focused on single responsibility.
- Use immutable states (freezed package highly recommended).
- No business logic inside widgets — all logic belongs in BLoC/use case.
- All state changes via BLoC events — never modify state directly.
- Keep BLoC files under 300 lines — split into multiple BLoCs if larger.
- Use Cubit for simple state, BLoC for complex event-driven state.

**State Management**:
- Define clear state classes (Initial, Loading, Success, Error).
- Use sealed classes or freezed for state unions.
- Emit new state objects, never mutate existing state.
- Handle all possible states in UI.
- Provide loading and error states for all async operations.
- Use copyWith for partial state updates.

**Event Handling**:
- One event = one user action or system event.
- Keep events simple, focused, and immutable.
- Use meaningful event names (LoginRequested, not ButtonPressed).
- Document complex event flows.

**BLoC Lifecycle**:
- Close streams and dispose resources in `close()`.
- Cancel ongoing operations when BLoC is closed.
- Use `GetIt.registerFactory` for proper disposal.
- Don't hold references to disposed BLoCs.

### Riverpod State Management

- Use Riverpod with code generation (`riverpod_generator`).
- Keep notifiers focused on single responsibility.
- Use `AsyncNotifier` for async state.
- Dispose resources properly in notifiers.
- Use `ref.watch()` in build methods, `ref.read()` in callbacks.
- Never use `ref.watch()` outside build methods.
- Avoid rebuilding entire screens — use `Consumer` or `ref.watch()` selectively.
- Wrap root widget in `ProviderScope`.

### Naming Conventions

- **PascalCase**: Classes, enums, typedefs, extensions.
- **camelCase**: Variables, methods, parameters, properties.
- **snake_case**: File names (e.g., `auth_notifier.dart`).

**Suffixes**:
- Models: `*Model` (e.g., `UserModel`)
- Notifiers: `*Notifier` (e.g., `AuthNotifier`)
- Use cases: `*UseCase` (e.g., `LoginUseCase`)
- Repositories: `*Repository` (e.g., `AuthRepository`)
- Providers: `*Providers` (e.g., `authProviders`)
- Pages: `*Page` (e.g., `LoginPage`)
- Widgets: Descriptive names (e.g., `DocumentCard`, `SubmissionList`)

## Code Quality

### Dart Language Rules

- Enable null safety in all code.
- Use `?` for nullable types. Use `!` only when absolutely certain value is non-null.
- Prefer `??` operator for default values. Use `?.` for safe navigation.
- Use `const` constructors wherever possible.
- Always use `async`/`await` for asynchronous operations.
- Avoid blocking the UI thread.

### Error Handling

- Use `Either<Failure, Success>` pattern from dartz for error handling in repositories.
- Create custom `Failure` classes for different error types.
- Handle errors gracefully in UI with user-friendly messages.
- Log errors for debugging.
- Show loading states during async operations.
- Provide retry mechanisms for failed operations.
- Catch all unhandled exceptions globally via `FlutterError.onError` and `PlatformDispatcher.instance.onError` — never show a raw stack trace or white screen.

### Feature-Based Organization

- Organize code by feature, not by type.
- Each feature has its own `data/`, `domain/`, and `presentation/` folders.
- Keep related code together for better maintainability.
- Example: `lib/features/auth/`, `lib/features/submission/`
- Never import from another feature's data or presentation layer. Cross-feature communication goes through domain layer or shared providers.

## UI/UX Best Practices

### Widget Composition — Critical Rules

- **One widget per file** — MANDATORY, no exceptions.
- **StatelessWidget only** — except for controllers like TextEditingController.
- **Max 200–300 lines per file** — split if exceeding this limit.
- **Extract sub-widgets aggressively** — create new files for complex sections.
- **NEVER use setState() for business logic** — use BLoC/Cubit instead.
- setState() is ONLY for UI-specific state (animations, form focus, etc.).

### Widget Best Practices

- Break down complex widgets into smaller, reusable widgets.
- Keep build methods small and readable (< 50 lines ideal).
- Extract repeated UI patterns into custom widgets.
- Use `const` constructors wherever possible for performance.
- Avoid deep widget trees — refactor when nesting exceeds 3–4 levels.
- Name widgets descriptively (DocumentCard, not Card1).
- Keep widgets pure — no side effects in build methods.
- All widgets must have a `const key` parameter.

### Responsive & Adaptive Design

- Use `LayoutBuilder` for responsiveness and adaptive layouts.

**Breakpoints**:
- Mobile: < 600px
- Tablet: 600px – 1024px
- Desktop: > 1024px

- Adaptive padding and font scaling based on screen size.
- Orientation-aware layouts — handle portrait and landscape.
- Use `MediaQuery.of(context).size` for screen dimensions.
- Test on multiple screen sizes and orientations.
- Use `Flexible` and `Expanded` appropriately.
- Avoid hardcoded dimensions — use relative sizing.
- Use `AspectRatio` for maintaining proportions.

### Theme & Styling

- All colors from `AppColors`, all text styles from `AppTheme` — no inline styling.
- Bajaj brand colors: primary #003087, secondary #00A3E0 (per tech.md).
- Use `Theme.of(context)` to access theme values.
- Don't hardcode colors or sizes in widgets.
- Maintain consistent spacing and padding.
- Follow Material Design or Cupertino guidelines.

### Accessibility

- Add semantic labels to interactive widgets (`Semantics`, `ExcludeSemantics`).
- Ensure sufficient color contrast (WCAG AA).
- Support screen readers.
- Make touch targets at least 48×48 logical pixels.
- Test with TalkBack (Android) and VoiceOver (iOS).

## Performance Optimization

### Critical Render Path

- Minimize time to first paint.
- Lazy load heavy features and screens.
- Use code splitting for large modules.
- Defer non-critical initialization.
- Minimize widget rebuilds with const and keys.
- Profile with Flutter DevTools regularly.

### List Performance

- Use `ListView.builder()` for long lists — MANDATORY for lists > 20 items.
- Implement pagination for large datasets.
- Use `AutomaticKeepAliveClientMixin` for preserving scroll state.
- Avoid expensive operations in itemBuilder.
- Cache list item heights when possible.
- Use `SliverList` for complex scrolling scenarios.

### Input Optimization

- Debounce search input — wait 300–500ms before triggering search.
- Throttle rapid user actions (button taps, scroll events).
- Cancel previous requests when new input arrives.
- Show loading indicators during debounce period.
- Use `Timer` or `rxdart` for debouncing.

### Image Optimization

- Use WebP or AVIF formats. Compress images before bundling.
- Use appropriate image resolutions for different screen densities.
- Implement lazy loading for images.
- Use `cached_network_image` for network images.
- Provide placeholder images during loading.
- Use `Image.memory` for small images to avoid file I/O.

### UI Patterns

- Use optimistic UI patterns — update UI immediately, sync in background.
- Show immediate feedback for user actions.
- Revert changes if server request fails.
- Queue offline actions for later sync.
- Provide visual feedback for pending operations.

### Build Performance

- Use `const` constructors to reduce rebuilds.
- Avoid expensive operations in build methods.
- Use `RepaintBoundary` for expensive widgets.
- Minimize widget tree depth.
- Profile app performance with Flutter DevTools.

### Memory Management

- Dispose controllers and streams in `dispose()`. No resource leaks.
- Cancel timers and subscriptions.
- Profile memory usage.
- Use weak references when appropriate.

## Navigation

### Go Router

- Use `go_router` for declarative routing — no `Navigator.push` or `onGenerateRoute`.
- Define all routes in a central location.
- Use named routes instead of hardcoded paths.
- Pass parameters through route configuration.
- Handle deep linking properly.
- Implement route guards for authentication.

### Navigation Best Practices

- Use `context.go()` for navigation, `context.pop()` to go back.
- Clear navigation stack when logging out.
- Handle back button properly on Android.
- Preserve state when navigating.

## Data Management

### API Integration (Dio)

- Use Dio for all HTTP requests.
- Configure base URL and default headers.
- Implement interceptors for:
  - Authentication (add JWT tokens).
  - Logging (request/response).
  - Error handling (retry logic).
- Handle network errors gracefully.
- Set appropriate timeouts.

### Local Storage

- Use `flutter_secure_storage` for sensitive data (tokens, passwords) — MANDATORY.
- Use `hive` for structured local data.
- Use `shared_preferences` for simple key-value pairs.
- Never store sensitive data in plain text.
- Clear local data on logout.

### Caching Strategy

**Multi-Layer Caching**: Memory → Disk → Network.

- **Memory cache**: Fast access for frequently used data (in-memory Map, LRU cache).
- **Disk cache**: Persistent storage using Hive or shared_preferences.
- **Network**: Fallback to API when cache misses.

**Cache Management**:
- Set explicit TTL (Time To Live) for all cached data.
- Invalidate cache on mutations — clear stale data after updates.
- Use stale-while-revalidate pattern — show cached data while fetching fresh.
- Implement cache versioning for schema changes.
- Monitor cache hit rates and adjust strategy.
- Clear cache on logout or app updates.
- Log cache hits/misses for monitoring.

```dart
class CacheManager {
  final Map<String, CachedData> _memoryCache = {};
  final HiveBox _diskCache;
  
  Future<T> getData<T>(
    String key,
    Future<T> Function() fetchFn,
    {Duration ttl = const Duration(hours: 1)}
  ) async {
    // 1. Check memory cache
    if (_memoryCache.containsKey(key) && !_isExpired(_memoryCache[key])) {
      return _memoryCache[key].data as T;
    }
    
    // 2. Check disk cache
    final diskData = await _diskCache.get(key);
    if (diskData != null && !_isExpired(diskData)) {
      _memoryCache[key] = diskData;
      return diskData.data as T;
    }
    
    // 3. Fetch from network
    final freshData = await fetchFn();
    final cached = CachedData(freshData, DateTime.now().add(ttl));
    _memoryCache[key] = cached;
    await _diskCache.put(key, cached);
    return freshData;
  }
}
```

## Security

### Authentication & Token Management

- Store tokens securely using `flutter_secure_storage` — MANDATORY.
- Implement token refresh logic automatically.
- Clear tokens on logout.
- Handle expired tokens gracefully.
- Use HTTPS for all API calls.
- Never store tokens in shared_preferences or plain text.

### API Security

- Never hardcode API keys in source code.
- Use environment variables for configuration (`--dart-define`).
- Store secrets in secure storage or environment.
- Implement certificate pinning for production.
- Validate SSL certificates.

### Input Validation & Sanitization

- Validate all user inputs before sending to API.
- Use form validators for all input fields.
- Sanitize inputs before sending to API.
- Show clear validation error messages.
- Prevent injection attacks (SQL, XSS).
- Implement rate limiting for sensitive operations.
- Validate file uploads (type, size, content).

### Sensitive Data Protection

- Never log sensitive information (passwords, tokens, PII).
- Don't store passwords locally — ever.
- Use biometric authentication when available.
- Obfuscate code in release builds.
- Clear sensitive data from memory after use.
- Disable screenshots for sensitive screens.
- Implement session timeout for security.

## Testing & Code Quality

### Unit Tests

- Test business logic in use cases — MANDATORY for all use cases.
- Test repository implementations.
- Mock dependencies using `mockito` or `mocktail`.
- Aim for high code coverage (>80%).
- Test edge cases and error scenarios.
- Test state transitions in BLoCs.
- Use AAA pattern (Arrange, Act, Assert).

### Widget Tests

- Test widget behavior and interactions — test all critical UI flows.
- Use `WidgetTester` for widget testing.
- Test different screen sizes.
- Test accessibility features.
- Mock dependencies in widget tests.
- Test error states and loading states.
- Verify widget tree structure.

### Integration Tests

- Test complete user flows end-to-end.
- Test API integration with mock servers.
- Test navigation flows.
- Run on real devices or emulators.
- Automate integration tests in CI/CD.
- Test offline scenarios.
- Test authentication flows.

### Test Organization

- Widget tests in `test/`, integration tests in `integration_test/`.
- Files mirror source structure with `_test.dart` suffix.

### Code Quality Standards

- Enable strict linting — use `very_good_analysis` or `lint` package.
- Fix all analyzer warnings before committing.
- Use `dart format` for consistent formatting.
- Run `flutter analyze` in CI/CD.

### Logging & Monitoring

- Use `logger` package for structured logging.
- Log at appropriate levels (debug, info, warning, error).
- Don't log sensitive information (tokens, passwords, PII).
- Include context in log messages.
- Use different log levels for debug/release builds.
- Implement crash reporting (Firebase Crashlytics, Sentry).
- Monitor app performance metrics.

## Code Generation

### Build Runner

- Use `build_runner` for code generation.
- Run `flutter pub run build_runner build --delete-conflicting-outputs` after changes.
- Use watch mode during development: `flutter pub run build_runner watch`.
- Commit generated files to version control.
- Keep generated code in sync with source.

### Freezed

- Use `freezed` for immutable data classes.
- Generate `copyWith`, `==`, and `hashCode` automatically.
- Use unions for state management.
- Keep data classes simple and focused.

### JSON Serialization

- Use `json_serializable` for JSON parsing.
- Generate `fromJson` and `toJson` methods.
- Handle nullable fields properly.
- Test serialization/deserialization.

## File Organization

```
lib/
├── core/
│   ├── constants/
│   ├── di/                    # GetIt dependency injection
│   ├── error/
│   ├── network/
│   ├── router/
│   ├── theme/
│   └── utils/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── pages/
│   │       ├── widgets/
│   │       └── providers/
│   └── [other features]/
└── main.dart
```

## Dependency Management

### Pubspec.yaml

- Keep dependencies up to date.
- Use specific version constraints.
- Separate dev dependencies.
- Document why each dependency is needed.
- Minimize dependency count.

### Version Constraints

- Use caret syntax for compatible versions: `^1.0.0`.
- Lock versions for critical dependencies.
- Test after updating dependencies.
- Check for breaking changes in changelogs.

## Platform-Specific Code

### Method Channels

- Use platform channels for native functionality.
- Handle platform-specific errors.
- Provide fallbacks for unsupported platforms.
- Document platform requirements.
- Test on all target platforms.

### Platform Detection

- Use `Platform.isAndroid`, `Platform.isIOS`, etc.
- Use `kIsWeb` for web platform detection.
- Provide platform-specific UI when needed.
- Handle platform differences gracefully.

## App Size Optimization

- Remove unused dependencies.
- Use code splitting for web.
- Optimize assets (compress images).
- Enable tree shaking in release builds.
- Use deferred loading for large features.

## Critical Must Rules

### MUST DO (Non-Negotiable)

✅ **Riverpod for State Management** (per tech.md) — or BLoC if adopted per feature  
✅ **GetIt for non-Riverpod DI** — or Riverpod providers for feature-level DI  
✅ **One Widget Per File** — MANDATORY, no exceptions  
✅ **StatelessWidget Only** — except for controllers  
✅ **Max 300 Lines Per File** — split files that exceed this limit  
✅ **Multi-Layer Caching** — Memory → Disk → Network  
✅ **Optimized Images** — use WebP/AVIF, compress images  
✅ **Loading States** — show loading indicators for all async operations  
✅ **Error Handling** — handle all error cases gracefully  
✅ **Input Validation** — validate all user inputs  
✅ **Secure Storage** — use flutter_secure_storage for sensitive data  
✅ **Environment Variables** — never hardcode API keys or secrets  
✅ **Unit Tests** — write tests for all use cases  
✅ **Strict Linting** — enable and fix all linter warnings

### MUST NOT DO (Forbidden)

❌ **setState() for Business State** — use BLoC/Cubit or Riverpod instead  
❌ **Multiple Widgets Per File** — one widget = one file  
❌ **Files Exceeding 300 Lines** — split into smaller files  
❌ **Business Logic in Widgets** — keep widgets pure, logic in BLoC  
❌ **Hardcoded Secrets** — never commit API keys, tokens, passwords  
❌ **Blocking Operations in Build** — keep build methods fast and pure  
❌ **Ignoring Analyzer Warnings** — fix all warnings before committing  
❌ **Storing Tokens in SharedPreferences** — use flutter_secure_storage  
❌ **Synchronous I/O in UI Thread** — use async/await  
❌ **Deep Widget Nesting** — refactor when exceeding 3–4 levels  
❌ **Hardcoded Strings** — use localization or constants  
❌ **Hardcoded Colors** — use theme colors  
❌ **Skipping Tests** — write tests for critical functionality  
❌ **Committing Debug Code** — remove debug prints and test code

## Code Review Checklist

Before committing Flutter code, verify:

### Architecture & Structure
- [ ] Clean Architecture layers respected (Presentation → Domain ← Data)
- [ ] SOLID principles followed
- [ ] Riverpod or GetIt used for dependency injection
- [ ] Dependencies registered correctly
- [ ] One widget per file (MANDATORY)
- [ ] Files under 300 lines (split if larger)
- [ ] Feature-based organization maintained

### State Management
- [ ] BLoC/Cubit or Riverpod used for ALL business state
- [ ] No setState() for business logic
- [ ] Immutable states (freezed recommended)
- [ ] All state changes via events
- [ ] Loading and error states handled
- [ ] BLoC properly disposed

### Widgets & UI
- [ ] StatelessWidget used (except controllers)
- [ ] Widgets properly composed and reusable
- [ ] Build methods small and readable (< 50 lines)
- [ ] const constructors used where possible
- [ ] No business logic in widgets
- [ ] Responsive design implemented
- [ ] Adaptive layouts for different screen sizes
- [ ] UI is accessible (semantic labels, contrast)

### Performance
- [ ] ListView.builder() used for long lists
- [ ] Images optimized (WebP/AVIF)
- [ ] Search input debounced
- [ ] Lazy loading implemented
- [ ] Optimistic UI patterns used
- [ ] No expensive operations in build methods
- [ ] Pagination implemented for large datasets

### Caching & Data
- [ ] Multi-layer caching implemented (Memory → Disk → Network)
- [ ] Cache TTL set explicitly
- [ ] Cache invalidated on mutations
- [ ] Stale-while-revalidate pattern used

### Security
- [ ] flutter_secure_storage used for tokens
- [ ] No hardcoded API keys or secrets
- [ ] Environment variables used
- [ ] All inputs validated
- [ ] HTTPS used for all API calls
- [ ] No sensitive data logged

### Testing & Quality
- [ ] Unit tests written for use cases
- [ ] Widget tests for critical UI
- [ ] Code formatted (`dart format .`)
- [ ] No analyzer warnings (`flutter analyze`)
- [ ] Strict linting enabled
- [ ] Code coverage acceptable (>80%)

### Navigation & Error Handling
- [ ] Navigation works correctly
- [ ] Error handling in place
- [ ] Loading states shown
- [ ] Error messages user-friendly
- [ ] Offline scenarios handled

## Common Pitfalls to Avoid

- Don't use `setState` in StatelessWidget.
- Don't perform async operations in `initState` without proper handling.
- Don't forget to dispose controllers and streams.
- Don't use `context` after async gaps without checking `mounted`.
- Don't rebuild entire screens unnecessarily.
- Don't ignore analyzer warnings.
- Don't hardcode API URLs or secrets.
- Don't skip error handling.
- Don't forget to test on real devices.
- Don't commit debug code or console logs.
