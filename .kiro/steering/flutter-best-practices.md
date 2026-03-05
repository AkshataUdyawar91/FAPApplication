---
inclusion: auto
fileMatchPattern: '**/*.dart'
---

# Flutter Best Practices Guide

This guide establishes best practices for Flutter development using Clean Architecture, SOLID principles, and BLoC pattern with adaptive screen design.

## Architecture Principles

### Clean Architecture Layers

**Data Layer** (Outermost)
- Remote/Local data sources
- Models with JSON serialization
- Repository implementations
- Depends on Domain layer

**Domain Layer** (Core)
- Entities (business objects)
- Repository interfaces
- Use cases (business logic)
- No dependencies on other layers

**Presentation Layer** (UI)
- Pages and widgets
- BLoC/Cubit state management
- Depends on Domain layer only

### Dependency Rule
Dependencies point inward: Presentation → Domain ← Data

## SOLID Principles in Flutter

### Single Responsibility Principle
- One widget = one responsibility
- Separate business logic (BLoC) from UI (widgets)
- Use cases handle single operations

```dart
// Good: Single responsibility
class LoginUseCase {
  Future<Either<Failure, User>> call(String email, String password);
}

// Bad: Multiple responsibilities
class AuthManager {
  Future<User> login();
  Future<void> logout();
  Future<User> register();
  Future<void> resetPassword();
}
```

### Open/Closed Principle
- Use abstract classes/interfaces for extensibility
- Sealed classes for state management

```dart
// Good: Open for extension
abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
}

class AuthRepositoryImpl implements AuthRepository {
  // Implementation
}
```

### Liskov Substitution Principle
- Subtypes must be substitutable for base types
- Use interfaces for dependency injection

### Interface Segregation Principle
- Small, focused interfaces
- Don't force implementations to depend on unused methods

```dart
// Good: Focused interfaces
abstract class AuthDataSource {
  Future<UserModel> login(String email, String password);
}

abstract class TokenStorage {
  Future<void> saveToken(String token);
  Future<String?> getToken();
}
```

### Dependency Inversion Principle
- Depend on abstractions, not concretions
- Use dependency injection with GetIt service locator

```dart
// Good: Depends on abstraction
class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase(this.repository);
}
```

## Dependency Injection with GetIt

### Setup GetIt Service Locator

```dart
// lib/core/di/injection.dart
import 'package:get_it/get_it.dart';

final sl = GetIt.instance; // Service Locator

Future<void> initializeDependencies() async {
  // External dependencies
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));

  // BLoCs - Register as factories (new instance each time)
  sl.registerFactory(() => AuthBloc(
    loginUseCase: sl(),
    logoutUseCase: sl(),
  ));
}
```

### Initialize in main.dart

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection
  await initializeDependencies();
  
  runApp(const MyApp());
}
```

### Using GetIt in Widgets

```dart
// Access dependencies using sl()
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<AuthBloc>(),
      child: const LoginView(),
    );
  }
}
```

### GetIt Registration Types

```dart
// Singleton: Single instance throughout app lifecycle
sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());

// Factory: New instance every time
sl.registerFactory<AuthBloc>(() => AuthBloc());

// Singleton with async initialization
sl.registerSingletonAsync<Database>(() async {
  final db = await openDatabase();
  return db;
});
```

## BLoC Pattern Best Practices

### State Management Structure

```dart
// States: Use sealed classes with freezed
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(User user) = _Authenticated;
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.error(String message) = _Error;
}

// Events: Use sealed classes
@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.loginRequested(String email, String password) = _LoginRequested;
  const factory AuthEvent.logoutRequested() = _LogoutRequested;
}

// BLoC: Handle events and emit states
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  
  AuthBloc(this.loginUseCase) : super(const AuthState.initial()) {
    on<_LoginRequested>(_onLoginRequested);
  }
  
  Future<void> _onLoginRequested(
    _LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    final result = await loginUseCase(event.email, event.password);
    result.fold(
      (failure) => emit(AuthState.error(failure.message)),
      (user) => emit(AuthState.authenticated(user)),
    );
  }
}
```

### BLoC Guidelines

1. **One BLoC per feature**: Don't share BLoCs across unrelated features
2. **Immutable states**: Use freezed for immutability
3. **Single source of truth**: BLoC holds the state
4. **No business logic in widgets**: Keep widgets dumb
5. **Use GetIt for DI**: Inject BLoCs through service locator
6. **BLoC files must be under 300 lines**: Split into multiple files if needed

```dart
// Register BLoC in GetIt
sl.registerFactory(() => AuthBloc(
  loginUseCase: sl(),
  logoutUseCase: sl(),
));

// Widget usage with BlocProvider
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<AuthBloc>(),
      child: const LoginView(),
    );
  }
}

// Separate view widget in its own file
// lib/features/auth/presentation/pages/login_view.dart
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return state.when(
          initial: () => const LoginForm(),
          loading: () => const LoadingIndicator(),
          authenticated: (user) => const HomePage(),
          error: (message) => ErrorDisplay(message: message),
        );
      },
    );
  }
}
```

## Adaptive Screen Design

### Responsive Layout Strategy

Use a breakpoint-based approach for different screen sizes:

```dart
// Screen size breakpoints
class ScreenBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

// Responsive helper
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ScreenBreakpoints.desktop) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= ScreenBreakpoints.tablet) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}
```

### Adaptive Widget Sizing

```dart
// Use MediaQuery for adaptive sizing
class AdaptiveContainer extends StatelessWidget {
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < ScreenBreakpoints.mobile;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : size.width * 0.1,
      ),
      child: child,
    );
  }
}

// Adaptive text sizing
class AdaptiveText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scaleFactor = size.width < ScreenBreakpoints.mobile ? 0.9 : 1.0;
    
    return Text(
      text,
      style: (baseStyle ?? Theme.of(context).textTheme.bodyLarge)
          ?.copyWith(fontSize: (baseStyle?.fontSize ?? 16) * scaleFactor),
    );
  }
}
```

### Grid and List Layouts

```dart
// Adaptive grid
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= ScreenBreakpoints.desktop
            ? 4
            : constraints.maxWidth >= ScreenBreakpoints.tablet
                ? 3
                : 2;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: children,
        );
      },
    );
  }
}
```

### Orientation Handling

```dart
class OrientationAwareWidget extends StatelessWidget {
  final Widget portrait;
  final Widget landscape;

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    
    return orientation == Orientation.portrait ? portrait : landscape;
  }
}
```

## Code Organization

### Feature-Based Structure

```
lib/
├── core/
│   ├── constants/
│   ├── di/
│   │   └── injection.dart          # GetIt service locator setup
│   ├── error/
│   ├── network/
│   ├── theme/
│   └── utils/
└── features/
    └── feature_name/
        ├── data/
        │   ├── datasources/
        │   ├── models/
        │   └── repositories/
        ├── domain/
        │   ├── entities/
        │   ├── repositories/
        │   └── usecases/
        └── presentation/
            ├── bloc/
            ├── pages/
            └── widgets/              # Each widget in separate file
```

### File Size Constraints

**CRITICAL RULE**: Every file MUST be between 200-300 lines maximum.

- If a file exceeds 300 lines, split it into multiple files
- Extract widgets into separate files
- Break down large classes into smaller, focused classes
- Use composition over large monolithic files

### File Naming Conventions

- **snake_case** for all file names
- Suffix patterns:
  - `*_page.dart` - Full screen pages
  - `*_widget.dart` - Reusable widgets (ONE widget per file)
  - `*_bloc.dart` - BLoC classes
  - `*_event.dart` - Event classes
  - `*_state.dart` - State classes
  - `*_model.dart` - Data models
  - `*_entity.dart` - Domain entities
  - `*_repository.dart` - Repository interfaces/implementations
  - `*_datasource.dart` - Data sources
  - `*_usecase.dart` - Use cases

## Widget Best Practices

### CRITICAL WIDGET RULES

1. **ONE WIDGET PER FILE**: Every widget must be in its own separate file
2. **STATELESS ONLY**: All widgets MUST be StatelessWidget (state managed by BLoC)
3. **MAX 200-300 LINES**: Each widget file must not exceed 300 lines
4. **EXTRACT EARLY**: Extract sub-widgets into separate files when approaching 200 lines

### Widget File Organization

```dart
// lib/features/auth/presentation/widgets/user_avatar.dart
class UserAvatar extends StatelessWidget {
  final User user;
  
  const UserAvatar({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundImage: NetworkImage(user.avatarUrl),
    );
  }
}

// lib/features/auth/presentation/widgets/user_name.dart
class UserName extends StatelessWidget {
  final User user;
  
  const UserName({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      user.name,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

// lib/features/auth/presentation/widgets/user_email.dart
class UserEmail extends StatelessWidget {
  final User user;
  
  const UserEmail({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      user.email,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

// lib/features/auth/presentation/widgets/user_card.dart
class UserCard extends StatelessWidget {
  final User user;

  const UserCard({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          UserAvatar(user: user),
          UserName(user: user),
          UserEmail(user: user),
        ],
      ),
    );
  }
}
```

### Why StatelessWidget Only?

```dart
// Good: Stateless widget with BLoC for state
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<AuthBloc>(),
      child: const LoginView(),
    );
  }
}

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return state.when(
          initial: () => const LoginForm(),
          loading: () => const LoadingIndicator(),
          authenticated: (user) => const HomePage(),
          error: (message) => ErrorDisplay(message: message),
        );
      },
    );
  }
}

// ❌ BAD: StatefulWidget with setState() for business logic
class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoading = false; // ❌ State should be in BLoC
  String? errorMessage;   // ❌ State should be in BLoC
  
  // ❌ Business logic should be in BLoC/UseCase
  void login() async {
    setState(() => isLoading = true); // ❌ NEVER use setState()
    try {
      // ❌ API calls in widget
      final user = await authService.login();
      setState(() => isLoading = false); // ❌ FORBIDDEN
    } catch (e) {
      setState(() {  // ❌ FORBIDDEN
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }
}
```

### When StatefulWidget is Acceptable

Only use StatefulWidget for:
- Animation controllers
- Text editing controllers
- Scroll controllers
- Focus nodes
- Form keys

**CRITICAL**: Even with StatefulWidget, NEVER use `setState()` for business logic or app state.

```dart
// Acceptable: Managing controllers only
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NO setState() calls here - all state managed by BLoC
    return LoginFormContent(
      emailController: _emailController,
      passwordController: _passwordController,
    );
  }
}

// Extract the actual form UI to a separate StatelessWidget file
// lib/features/auth/presentation/widgets/login_form_content.dart
class LoginFormContent extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;

  const LoginFormContent({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EmailTextField(controller: emailController),
        PasswordTextField(controller: passwordController),
        LoginButton(
          emailController: emailController,
          passwordController: passwordController,
        ),
      ],
    );
  }
}
```

### FORBIDDEN: setState() for State Management

```dart
// ❌ NEVER DO THIS - setState() for business logic
class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String? _errorMessage;
  User? _user;

  void _login() async {
    setState(() => _isLoading = true); // ❌ FORBIDDEN
    
    try {
      final user = await authService.login();
      setState(() {  // ❌ FORBIDDEN
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {  // ❌ FORBIDDEN
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
}

// ✅ CORRECT - Use BLoC for all state management
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<AuthBloc>(),
      child: const LoginView(),
    );
  }
}

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return state.when(
          loading: () => const LoadingIndicator(),
          authenticated: (user) => HomePage(user: user),
          error: (message) => ErrorDisplay(message: message),
          initial: () => const LoginForm(),
        );
      },
    );
  }
}
```

### Extract Widgets Aggressively

```dart
// When a widget file approaches 200 lines, extract sub-widgets

// Before: Single file with 250 lines
class DocumentCard extends StatelessWidget {
  // 250 lines of nested widgets
}

// After: Split into multiple files

// lib/features/documents/presentation/widgets/document_card.dart (50 lines)
class DocumentCard extends StatelessWidget {
  final Document document;

  const DocumentCard({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          DocumentHeader(document: document),
          DocumentContent(document: document),
          DocumentFooter(document: document),
        ],
      ),
    );
  }
}

// lib/features/documents/presentation/widgets/document_header.dart (60 lines)
class DocumentHeader extends StatelessWidget {
  final Document document;

  const DocumentHeader({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DocumentIcon(type: document.type),
        DocumentTitle(title: document.title),
        DocumentStatus(status: document.status),
      ],
    );
  }
}

// lib/features/documents/presentation/widgets/document_content.dart (70 lines)
class DocumentContent extends StatelessWidget {
  final Document document;

  const DocumentContent({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DocumentDescription(description: document.description),
        DocumentMetadata(document: document),
      ],
    );
  }
}

// lib/features/documents/presentation/widgets/document_footer.dart (70 lines)
class DocumentFooter extends StatelessWidget {
  final Document document;

  const DocumentFooter({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DocumentDate(date: document.createdAt),
        DocumentActions(document: document),
      ],
    );
  }
}
```

### Const Constructors

Always use const constructors for better performance:

```dart
// Good: Const constructor
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/logo.png');
  }
}

// Usage with const
const AppLogo() // Widget won't rebuild unnecessarily
```

### Avoid Unnecessary Rebuilds

```dart
// Use const constructors
const Text('Hello');

// Use keys for list items
ListView.builder(
  itemBuilder: (context, index) {
    return ListTile(
      key: ValueKey(items[index].id),
      title: Text(items[index].name),
    );
  },
);

// Separate stateful logic
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const StaticHeader(), // Won't rebuild
        DynamicContent(), // Only this rebuilds
      ],
    );
  }
}

// Use BlocBuilder with buildWhen to control rebuilds
BlocBuilder<CounterBloc, CounterState>(
  buildWhen: (previous, current) {
    // Only rebuild when count changes, not on every state change
    return previous.count != current.count;
  },
  builder: (context, state) {
    return Text('Count: ${state.count}');
  },
);
```

## Error Handling

### Use Either Type

```dart
// Define failures
abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

// Use Either in repositories
abstract class AuthRepository {
  Future<Either<Failure, User>> login(String email, String password);
}

// Handle in use cases
class LoginUseCase {
  final AuthRepository repository;

  Future<Either<Failure, User>> call(String email, String password) async {
    try {
      return await repository.login(email, password);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

// Handle in BLoC
result.fold(
  (failure) => emit(AuthState.error(failure.message)),
  (user) => emit(AuthState.authenticated(user)),
);
```

## Caching Strategy

### Multi-Layer Caching

```dart
// 1. Memory cache (fastest, volatile)
// 2. Disk cache (persistent, slower)
// 3. Network (slowest, always fresh)

class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentRemoteDataSource remoteDataSource;
  final DocumentLocalDataSource localDataSource;
  final MemoryCache memoryCache;

  @override
  Future<Either<Failure, List<Document>>> getDocuments() async {
    try {
      // Check memory cache first
      final cached = memoryCache.get<List<Document>>('documents');
      if (cached != null && !_isStale(cached)) {
        return Right(cached.data);
      }

      // Check disk cache
      try {
        final local = await localDataSource.getDocuments();
        if (local.isNotEmpty && !_isStale(local.first)) {
          memoryCache.set('documents', local, ttl: Duration(minutes: 5));
          return Right(local);
        }
      } catch (_) {
        // Disk cache miss, continue to network
      }

      // Fetch from network
      final remote = await remoteDataSource.getDocuments();
      
      // Update caches
      await localDataSource.cacheDocuments(remote);
      memoryCache.set('documents', remote, ttl: Duration(minutes: 5));
      
      return Right(remote);
    } on ServerException catch (e) {
      // Return stale cache on network error
      try {
        final stale = await localDataSource.getDocuments();
        if (stale.isNotEmpty) {
          return Right(stale); // Stale data better than no data
        }
      } catch (_) {}
      
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  bool _isStale(dynamic data) {
    // Check if data is older than TTL
    if (data is CachedData) {
      return DateTime.now().difference(data.timestamp) > 
        const Duration(minutes: 5);
    }
    return false;
  }
}

// Memory cache implementation
class MemoryCache {
  final Map<String, CachedData> _cache = {};

  T? get<T>(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    
    if (DateTime.now().isAfter(cached.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    
    return cached.data as T;
  }

  void set<T>(String key, T data, {required Duration ttl}) {
    _cache[key] = CachedData(
      data: data,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void clear() => _cache.clear();
  void remove(String key) => _cache.remove(key);
}

class CachedData<T> {
  final T data;
  final DateTime timestamp;
  final DateTime expiresAt;

  CachedData({
    required this.data,
    required this.timestamp,
    required this.expiresAt,
  });
}
```

### Cache Invalidation

```dart
// Invalidate cache on mutations
class UpdateDocumentUseCase {
  final DocumentRepository repository;
  final MemoryCache memoryCache;

  Future<Either<Failure, Document>> call(Document document) async {
    final result = await repository.updateDocument(document);
    
    return result.fold(
      (failure) => Left(failure),
      (updatedDoc) {
        // Invalidate related caches
        memoryCache.remove('documents');
        memoryCache.remove('document_${updatedDoc.id}');
        return Right(updatedDoc);
      },
    );
  }
}

// Time-based invalidation with explicit TTL
class CacheConfig {
  static const Duration shortTtl = Duration(minutes: 5);
  static const Duration mediumTtl = Duration(hours: 1);
  static const Duration longTtl = Duration(days: 1);
}

// Pre-warm cache for critical data
class AppInitializer {
  final DocumentRepository documentRepository;
  final MemoryCache memoryCache;

  Future<void> initialize() async {
    // Pre-fetch and cache critical data
    final result = await documentRepository.getDocuments();
    result.fold(
      (_) {}, // Ignore errors during pre-warming
      (docs) => memoryCache.set(
        'documents',
        docs,
        ttl: CacheConfig.mediumTtl,
      ),
    );
  }
}
```

### Stale-While-Revalidate Pattern

```dart
// Show stale data immediately, fetch fresh in background
class DocumentBloc extends Bloc<DocumentEvent, DocumentState> {
  final GetDocumentsUseCase getDocumentsUseCase;

  DocumentBloc(this.getDocumentsUseCase) : super(const DocumentState.initial()) {
    on<_LoadDocuments>(_onLoadDocuments);
  }

  Future<void> _onLoadDocuments(
    _LoadDocuments event,
    Emitter<DocumentState> emit,
  ) async {
    // Show cached data immediately if available
    final cached = await getDocumentsUseCase.getCached();
    cached.fold(
      (_) => emit(const DocumentState.loading()),
      (docs) => emit(DocumentState.loaded(docs, isStale: true)),
    );

    // Fetch fresh data in background
    final fresh = await getDocumentsUseCase();
    fresh.fold(
      (failure) {
        // Keep showing stale data on error
        if (state is! _Loaded) {
          emit(DocumentState.error(failure.message));
        }
      },
      (docs) => emit(DocumentState.loaded(docs, isStale: false)),
    );
  }
}
```

## Performance Optimization

### Critical Render Path

```dart
// Minimize render-blocking operations
// Use async initialization for heavy operations
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const HomePage();
          }
          return const SplashScreen(); // Show while loading
        },
      ),
    );
  }
}

// Code splitting with lazy loading
// Load heavy features only when needed
void navigateToHeavyFeature(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const HeavyFeaturePage(),
    ),
  );
}
```

### Image Optimization

```dart
// Use cached network images with proper sizing
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => const ShimmerPlaceholder(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  memCacheWidth: 400, // Resize for memory efficiency
  memCacheHeight: 400,
  maxWidthDiskCache: 800,
  maxHeightDiskCache: 800,
);

// Use appropriate image formats
// - AVIF/WebP for web (best compression)
// - PNG for transparency
// - JPEG for photos

// Responsive images with correct dimensions
Image.network(
  url,
  width: MediaQuery.of(context).size.width,
  height: 200,
  fit: BoxFit.cover,
  cacheWidth: (MediaQuery.of(context).size.width * 
    MediaQuery.of(context).devicePixelRatio).round(),
);
```

### List Performance

```dart
// Use ListView.builder for long lists (lazy loading)
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
  // Add caching for better performance
  addAutomaticKeepAlives: true,
  cacheExtent: 100, // Preload items 100 pixels ahead
);

// Use ListView.separated for dividers
ListView.separated(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
  separatorBuilder: (context, index) => const Divider(),
);

// For very large lists, use AutomaticKeepAliveClientMixin
class ItemWidget extends StatefulWidget {
  final Item item;
  const ItemWidget(this.item, {super.key});

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> 
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return ListTile(title: Text(widget.item.name));
  }
}
```

### Interaction Performance

```dart
// Debounce search input to reduce API calls
class SearchField extends StatefulWidget {
  const SearchField({super.key});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  Timer? _debounce;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // Trigger search after 300ms of no typing
      context.read<SearchBloc>().add(SearchEvent.query(_controller.text));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}

// Throttle button taps to prevent double-submission
class ThrottledButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const ThrottledButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  State<ThrottledButton> createState() => _ThrottledButtonState();
}

class _ThrottledButtonState extends State<ThrottledButton> {
  bool _isThrottled = false;

  void _handlePress() {
    if (_isThrottled) return;
    
    setState(() => _isThrottled = true);
    widget.onPressed();
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isThrottled = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isThrottled ? null : _handlePress,
      child: widget.child,
    );
  }
}
```

### Perceived Speed (Optimistic UI)

```dart
// Show skeleton/placeholder while loading
class DocumentList extends StatelessWidget {
  const DocumentList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentBloc, DocumentState>(
      builder: (context, state) {
        return state.when(
          loading: () => const SkeletonList(), // Show skeleton
          loaded: (docs) => ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) => DocumentCard(docs[i]),
          ),
          error: (msg) => ErrorDisplay(message: msg),
        );
      },
    );
  }
}

// Optimistic UI for low-risk operations
void likeDocument(BuildContext context, Document doc) {
  // Update UI immediately (optimistic)
  context.read<DocumentBloc>().add(
    DocumentEvent.likeOptimistic(doc.id),
  );
  
  // Then sync with server
  context.read<DocumentBloc>().add(
    DocumentEvent.likeSync(doc.id),
  );
}

// Show progress for long operations (>1s)
class UploadButton extends StatelessWidget {
  const UploadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UploadBloc, UploadState>(
      builder: (context, state) {
        return state.when(
          idle: () => ElevatedButton(
            onPressed: () => context.read<UploadBloc>().add(
              const UploadEvent.start(),
            ),
            child: const Text('Upload'),
          ),
          uploading: (progress) => Column(
            children: [
              LinearProgressIndicator(value: progress),
              Text('${(progress * 100).toInt()}%'),
            ],
          ),
          completed: () => const Icon(Icons.check_circle),
          error: (msg) => Text('Error: $msg'),
        );
      },
    );
  }
}
```

### Network Optimization

```dart
// Configure Dio for optimal performance
Dio createDioClient() {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept-Encoding': 'gzip, br', // Enable compression
    },
  ));

  // Add interceptors for caching
  dio.interceptors.add(DioCacheInterceptor(
    options: CacheOptions(
      store: MemCacheStore(),
      policy: CachePolicy.request,
      maxStale: const Duration(days: 7),
    ),
  ));

  return dio;
}

// Prefetch on hover for likely routes (web)
class NavigationLink extends StatelessWidget {
  final String route;
  final Widget child;

  const NavigationLink({
    super.key,
    required this.route,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        // Prefetch data for this route
        context.read<PrefetchBloc>().add(
          PrefetchEvent.route(route),
        );
      },
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: child,
      ),
    );
  }
}
```

## Testing Guidelines

### Unit Tests

```dart
// Test use cases
void main() {
  late LoginUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = LoginUseCase(mockRepository);
  });

  test('should return User when login is successful', () async {
    // Arrange
    when(mockRepository.login(any, any))
        .thenAnswer((_) async => Right(tUser));

    // Act
    final result = await useCase('email', 'password');

    // Assert
    expect(result, Right(tUser));
    verify(mockRepository.login('email', 'password'));
  });
}
```

### Widget Tests

```dart
void main() {
  testWidgets('LoginPage shows error message on failure', (tester) async {
    // Arrange
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authBlocProvider.overrideWith((ref) => MockAuthBloc()),
        ],
        child: MaterialApp(home: LoginPage()),
      ),
    );

    // Act
    await tester.enterText(find.byType(TextField).first, 'email');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Login failed'), findsOneWidget);
  });
}
```

## Accessibility

### Semantic Labels

```dart
// Add semantic labels for screen readers
Semantics(
  label: 'Submit button',
  button: true,
  child: ElevatedButton(
    onPressed: onSubmit,
    child: Text('Submit'),
  ),
);

// Use semantic widgets
IconButton(
  icon: Icon(Icons.search),
  tooltip: 'Search', // Provides accessibility label
  onPressed: onSearch,
);
```

### Color Contrast

```dart
// Ensure sufficient contrast ratios
// WCAG AA: 4.5:1 for normal text, 3:1 for large text
const primaryColor = Color(0xFF003087); // Dark blue
const textColor = Color(0xFFFFFFFF); // White (high contrast)
```

## Code Quality

### Linting

Enable strict linting in `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - always_declare_return_types
    - always_use_package_imports
    - avoid_print
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_locals
    - require_trailing_commas
    - sort_constructors_first
    - sort_unnamed_constructors_first
    - use_key_in_widget_constructors
```

### Code Comments

```dart
// Document public APIs
/// Authenticates a user with email and password.
///
/// Returns [Right<User>] on success or [Left<Failure>] on error.
/// Throws [NetworkException] if network is unavailable.
Future<Either<Failure, User>> login(String email, String password);

// Use TODO comments for future work
// TODO(username): Implement biometric authentication

// Use FIXME for known issues
// FIXME: Handle edge case when user has no profile picture
```

## Security Best Practices

### Secure Storage

```dart
// Use flutter_secure_storage for sensitive data
final storage = FlutterSecureStorage();

// Store tokens securely
await storage.write(key: 'auth_token', value: token);

// Never store sensitive data in SharedPreferences
// Bad: await prefs.setString('password', password);
```

### API Keys

```dart
// Use environment variables for API keys
// Never commit API keys to version control

// Load from environment
const apiKey = String.fromEnvironment('API_KEY');

// Or use a config file (add to .gitignore)
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );
}
```

## File Size Management Strategy

### Splitting Large Files

When a file approaches 250 lines, split it:

**BLoC Files:**
```
auth_bloc.dart (280 lines) →
  ├── auth_bloc.dart (100 lines) - BLoC class
  ├── auth_event.dart (80 lines) - Events
  └── auth_state.dart (100 lines) - States
```

**Page Files:**
```
login_page.dart (320 lines) →
  ├── login_page.dart (50 lines) - Page scaffold with BlocProvider
  ├── login_view.dart (80 lines) - Main view with BlocBuilder
  ├── login_form.dart (90 lines) - Form with controllers
  └── widgets/
      ├── email_text_field.dart (30 lines)
      ├── password_text_field.dart (30 lines)
      └── login_button.dart (40 lines)
```

**Repository Files:**
```
auth_repository_impl.dart (350 lines) →
  ├── auth_repository_impl.dart (200 lines) - Main implementation
  └── auth_repository_helpers.dart (150 lines) - Helper methods
```

### Line Count Monitoring

```bash
# Check line counts in a directory
find lib/features/auth -name "*.dart" -exec wc -l {} \;

# Find files exceeding 300 lines
find lib -name "*.dart" -exec wc -l {} \; | awk '$1 > 300'
```

## Performance & UX Checklist

### Release Gates (Every Change)
- [ ] **Performance impact defined**: Declares impact on latency/error SLOs or "no-impact"
- [ ] **Perf tests in CI**: Baseline + p95/p99 budgets for hot paths; fail on regression
- [ ] **Security scans pass**: SAST/DAST clean; SBOM produced; provenance signed

### Performance
- [ ] **Critical render path optimized**: Minimize render-blocking; code-split; lazy-load
- [ ] **Images optimized**: AVIF/WebP, responsive sizing, proper dimensions, CDN cached
- [ ] **Interactions <100ms**: Debounce/throttle inputs; prefetch on hover
- [ ] **Perceived speed**: Skeletons/placeholders, optimistic UI, progress indicators
- [ ] **Caching strategy**: Multi-layer (memory → disk → network) with explicit TTL
- [ ] **Cache invalidation**: Clear on mutations; stale-while-revalidate pattern
- [ ] **List performance**: ListView.builder for long lists; proper caching

### Code Hygiene
- [ ] **GetIt is configured** for dependency injection in `lib/core/di/injection.dart`
- [ ] **Every widget is StatelessWidget** (except for controller management)
- [ ] **NO setState() calls for app/business state** - only BLoC manages state
- [ ] **One widget per file** - no multiple widgets in a single file
- [ ] **Every file is 200-300 lines maximum** - split if exceeding
- [ ] Clean Architecture layers are properly separated
- [ ] SOLID principles are followed
- [ ] BLoC pattern is used for ALL state management
- [ ] Error handling uses Either type
- [ ] Code is organized by feature
- [ ] Widgets are small and composable
- [ ] Const constructors are used where possible
- [ ] No business logic in widgets
- [ ] All state changes go through BLoC events

### Beautiful UX
- [ ] **Obvious primary action**: Minimal steps for happy path
- [ ] **Instant feedback**: Micro-interactions on tap; optimistic updates
- [ ] **Accessible by default**: Keyboard flows, focus management, contrast
- [ ] **Widgets are adaptive**: Responsive to different screen sizes
- [ ] **Error recovery**: Clear error messages with recovery guidance

### Security & Runtime
- [ ] **Sensitive data stored securely**: flutter_secure_storage for tokens
- [ ] **API keys not hardcoded**: Use environment variables
- [ ] **TLS configured**: Prefer TLS 1.3, fallback to 1.2
- [ ] **Rate limiting handled**: Respect X-RateLimit-* headers
- [ ] **Input validation**: Sanitize all user inputs

### Testing & Observability
- [ ] **Tests written**: Unit tests for business logic; widget tests for UI
- [ ] **Linting rules enabled**: Auto-format + lint in CI
- [ ] **Logging configured**: Structured logs for errors and key events
- [ ] **Performance monitoring**: Track p95/p99 latency for critical flows

## Critical Rules Summary

### MUST DO:
1. ✅ Use GetIt for dependency injection
2. ✅ One widget per file
3. ✅ All widgets are StatelessWidget (state in BLoC)
4. ✅ Maximum 200-300 lines per file
5. ✅ Extract sub-widgets into separate files aggressively
6. ✅ All state management through BLoC pattern
7. ✅ Use const constructors everywhere possible
8. ✅ Implement multi-layer caching (memory → disk → network)
9. ✅ Optimize images (AVIF/WebP, proper sizing, CDN)
10. ✅ Show loading states (skeletons, progress indicators)
11. ✅ Debounce/throttle user inputs
12. ✅ Handle stale data gracefully
13. ✅ Invalidate cache on mutations

### MUST NOT DO:
1. ❌ Multiple widgets in one file
2. ❌ StatefulWidget for business logic
3. ❌ Files exceeding 300 lines
4. ❌ State management in widgets
5. ❌ Direct instantiation (use GetIt instead)
6. ❌ **NEVER use setState() for app/business state**
7. ❌ Store state in widget classes (use BLoC)
8. ❌ Business logic in widgets (belongs in use cases/BLoC)
9. ❌ Render-blocking operations in build()
10. ❌ Unoptimized images or missing cache
11. ❌ Ignore stale data scenarios
12. ❌ Hardcode API keys or secrets
