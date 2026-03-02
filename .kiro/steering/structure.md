# Project Structure

## Repository Layout

```
bajaj-document-processing/
├── backend/                    # .NET 8 Web API
├── frontend/                   # Flutter application
├── .kiro/                      # Kiro configuration
│   ├── specs/                  # Feature specifications
│   └── steering/               # Steering documents
└── README.md                   # Project documentation
```

## Backend Structure (Clean Architecture)

```
backend/
├── BajajDocumentProcessing.sln              # Solution file
├── src/
│   ├── BajajDocumentProcessing.API/         # Web API layer (entry point)
│   │   ├── Controllers/                     # API endpoints
│   │   │   ├── AuthController.cs
│   │   │   ├── DocumentsController.cs
│   │   │   ├── SubmissionsController.cs
│   │   │   ├── AnalyticsController.cs
│   │   │   ├── ChatController.cs
│   │   │   └── NotificationsController.cs
│   │   ├── Middleware/                      # Custom middleware
│   │   │   └── AuditLoggingMiddleware.cs
│   │   ├── Program.cs                       # App configuration & DI
│   │   └── appsettings.json                 # Configuration
│   │
│   ├── BajajDocumentProcessing.Application/ # Application layer
│   │   ├── Common/
│   │   │   └── Interfaces/                  # Service interfaces
│   │   │       ├── IDocumentAgent.cs
│   │   │       ├── IValidationAgent.cs
│   │   │       ├── IConfidenceScoreService.cs
│   │   │       ├── IRecommendationAgent.cs
│   │   │       ├── IEmailAgent.cs
│   │   │       ├── IAnalyticsAgent.cs
│   │   │       ├── INotificationAgent.cs
│   │   │       ├── IChatService.cs
│   │   │       └── ... (other interfaces)
│   │   └── DTOs/                            # Data transfer objects
│   │       ├── Auth/
│   │       ├── Documents/
│   │       └── Notifications/
│   │
│   ├── BajajDocumentProcessing.Domain/      # Domain layer (core business)
│   │   ├── Entities/                        # Domain entities
│   │   │   ├── User.cs
│   │   │   ├── Document.cs
│   │   │   ├── DocumentPackage.cs
│   │   │   ├── ValidationResult.cs
│   │   │   ├── ConfidenceScore.cs
│   │   │   ├── Recommendation.cs
│   │   │   ├── Notification.cs
│   │   │   ├── Conversation.cs
│   │   │   ├── ConversationMessage.cs
│   │   │   └── AuditLog.cs
│   │   ├── Enums/                           # Domain enumerations
│   │   │   ├── DocumentType.cs
│   │   │   ├── PackageState.cs
│   │   │   ├── UserRole.cs
│   │   │   ├── NotificationType.cs
│   │   │   └── RecommendationType.cs
│   │   └── Common/
│   │       └── BaseEntity.cs                # Base entity with Id, timestamps
│   │
│   └── BajajDocumentProcessing.Infrastructure/ # Infrastructure layer
│       ├── Persistence/                     # Database
│       │   ├── ApplicationDbContext.cs
│       │   ├── ApplicationDbContextSeed.cs
│       │   └── Configurations/              # EF Core configurations
│       ├── Services/                        # Service implementations
│       │   ├── DocumentAgent.cs
│       │   ├── ValidationAgent.cs
│       │   ├── ConfidenceScoreService.cs
│       │   ├── RecommendationAgent.cs
│       │   ├── EmailAgent.cs
│       │   ├── AnalyticsAgent.cs
│       │   ├── NotificationAgent.cs
│       │   ├── ChatService.cs
│       │   ├── AuthService.cs
│       │   ├── DocumentService.cs
│       │   ├── WorkflowOrchestrator.cs
│       │   └── Plugins/                     # Semantic Kernel plugins
│       ├── Resilience/
│       │   └── ResiliencePolicies.cs        # Retry/circuit breaker policies
│       └── DependencyInjection.cs           # Infrastructure DI registration
│
└── tests/
    └── BajajDocumentProcessing.Tests/       # Test project
        ├── API/                             # API tests
        ├── Domain/
        │   └── Properties/                  # Domain property-based tests
        └── Infrastructure/
            ├── *Tests.cs                    # Unit tests
            └── Properties/                  # Property-based tests
                ├── ConfidenceScoreProperties.cs
                ├── DocumentClassificationProperties.cs
                ├── PasswordHashingProperties.cs
                └── ... (other PBT tests)
```

## Frontend Structure (Clean Architecture)

```
frontend/
├── lib/
│   ├── main.dart                            # App entry point
│   ├── core/                                # Core functionality
│   │   ├── constants/
│   │   │   └── api_constants.dart           # API configuration
│   │   ├── error/
│   │   │   └── failures.dart                # Error handling
│   │   ├── network/
│   │   │   └── dio_client.dart              # HTTP client setup
│   │   ├── router/                          # Navigation configuration
│   │   ├── theme/
│   │   │   ├── app_colors.dart              # Bajaj brand colors
│   │   │   └── app_theme.dart               # Theme configuration
│   │   └── utils/
│   │       └── either.dart                  # Either type for error handling
│   │
│   └── features/                            # Feature modules
│       ├── auth/                            # Authentication feature
│       │   ├── data/
│       │   │   ├── datasources/
│       │   │   │   ├── auth_remote_datasource.dart
│       │   │   │   └── auth_local_datasource.dart
│       │   │   ├── models/
│       │   │   │   └── user_model.dart
│       │   │   └── repositories/
│       │   │       └── auth_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   └── user.dart
│       │   │   ├── repositories/
│       │   │   │   └── auth_repository.dart
│       │   │   └── usecases/
│       │   │       ├── login_usecase.dart
│       │   │       └── logout_usecase.dart
│       │   └── presentation/
│       │       ├── pages/
│       │       │   └── login_page.dart
│       │       └── providers/
│       │           ├── auth_notifier.dart
│       │           └── auth_providers.dart
│       │
│       ├── submission/                      # Document submission
│       ├── approval/                        # Approval workflow
│       ├── analytics/                       # Analytics dashboard
│       ├── chat/                            # Chat assistant
│       └── [other features follow same pattern]
│
├── test/                                    # Tests
│   └── widget_test.dart
├── pubspec.yaml                             # Dependencies
└── analysis_options.yaml                    # Linter configuration
```

## Architecture Patterns

### Backend (Clean Architecture)

**Dependency Flow**: API → Application → Domain ← Infrastructure

- **Domain Layer**: Pure business logic, no dependencies
- **Application Layer**: Use cases and interfaces, depends only on Domain
- **Infrastructure Layer**: External concerns (DB, Azure services), implements Application interfaces
- **API Layer**: Controllers and middleware, orchestrates everything

### Frontend (Clean Architecture)

**Dependency Flow**: Presentation → Domain ← Data

Each feature follows:
- **Data Layer**: API calls, models, repository implementations
- **Domain Layer**: Entities, repository interfaces, use cases
- **Presentation Layer**: UI (pages, widgets), state management (Riverpod notifiers)

## Naming Conventions

### Backend (C#)
- **PascalCase**: Classes, methods, properties, public fields
- **camelCase**: Private fields (with `_` prefix), local variables, parameters
- **Interfaces**: Prefix with `I` (e.g., `IDocumentAgent`)
- **Async methods**: Suffix with `Async` (e.g., `ClassifyAsync`)
- **DTOs**: Suffix with `Request`, `Response`, or `Data` (e.g., `LoginRequest`, `POData`)

### Frontend (Dart)
- **PascalCase**: Classes, enums, typedefs
- **camelCase**: Variables, methods, parameters, properties
- **snake_case**: File names (e.g., `auth_notifier.dart`)
- **Suffixes**: 
  - Models: `*Model` (e.g., `UserModel`)
  - Notifiers: `*Notifier` (e.g., `AuthNotifier`)
  - Use cases: `*UseCase` (e.g., `LoginUseCase`)
  - Repositories: `*Repository` (e.g., `AuthRepository`)
  - Providers: `*Providers` (e.g., `authProviders`)

## Testing Organization

### Backend
- Unit tests alongside property-based tests
- Property tests in `Properties/` subdirectories
- Test class names match implementation: `*Tests.cs` or `*Properties.cs`
- Property tests validate requirements with comments linking to spec

### Frontend
- Widget tests in `test/` directory
- Integration tests in `integration_test/` directory
- Test files mirror source structure with `_test.dart` suffix
