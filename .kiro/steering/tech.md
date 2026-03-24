# Technology Stack

## Backend (.NET 8)

### Core Framework
- ASP.NET Core 8 Web API
- Entity Framework Core 8 with SQL Server
- Clean Architecture (Domain, Application, Infrastructure, API layers)

### AI & Azure Services
- **Semantic Kernel**: AI orchestration framework
- **Azure OpenAI GPT-4**: Natural language processing, vision, and document extraction
- **Azure AI Search**: Vector database for semantic search
- **Azure Blob Storage**: Document storage
- **Azure Communication Services**: Email delivery
- **Redis**: Caching layer (optional)

### Testing
- **xUnit**: Unit testing framework
- **FsCheck**: Property-based testing library
- **Moq**: Mocking framework

### Key NuGet Packages
- Microsoft.AspNetCore.Authentication.JwtBearer (8.0.0)
- Swashbuckle.AspNetCore (6.5.0)
- Azure.AI.OpenAI
- MetadataExtractor (for EXIF data)

## Frontend (Flutter)

### Core Framework
- Flutter 3.2+ (cross-platform mobile & web)
- Dart 3.2+

### State Management & Architecture
- **Riverpod**: State management with code generation
- **Clean Architecture**: Feature-based organization (data, domain, presentation layers)

### Key Packages
- **dio**: HTTP client (5.4.0)
- **go_router**: Navigation (13.0.0)
- **flutter_secure_storage**: Secure token storage (9.0.0)
- **hive**: Local caching (2.2.3)
- **fl_chart**: Data visualization (0.65.0)
- **file_picker**: File selection (6.1.1)
- **image_picker**: Camera/gallery access (1.0.5)
- **cached_network_image**: Image caching (3.3.0)
- **equatable**: Value equality (2.0.5)
- **dartz**: Functional programming (Either type) (0.10.1)

### Code Generation
- build_runner (2.4.7)
- riverpod_generator (2.3.9)
- freezed (2.4.6)
- json_serializable (6.7.1)
- hive_generator (2.0.1)

## Common Commands

### Backend

```bash
# Restore dependencies
dotnet restore

# Build solution
dotnet build

# Run API (from backend directory)
dotnet run --project src/BajajDocumentProcessing.API

# Run tests
dotnet test

# Run tests with coverage
dotnet test /p:CollectCoverage=true

# Database migrations (from API project directory)
dotnet ef database update
dotnet ef migrations add <MigrationName>

# Build for release
dotnet build --configuration Release
```
taskkill /F /IM dotnet.exe

API runs on:
- HTTPS: https://localhost:7001
- HTTP: http://localhost:5001
- Swagger UI: https://localhost:7001/swagger

### Frontend

```bash
# Install dependencies
flutter pub get

# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
flutter pub run build_runner watch

# Run app
flutter run

# Run on specific device
flutter run -d chrome
flutter run -d windows

# Run tests
flutter test

# Run integration tests
flutter test integration_test

# Analyze code
flutter analyze

# Format code
dart format .

# Build for release
flutter build apk
flutter build web
flutter build windows
```

## Configuration

### Backend
Configuration in `appsettings.json`:
- Database connection strings
- Azure service endpoints and API keys
- SAP connection details
- JWT settings
- Redis connection string

### Frontend
Configuration in `lib/core/constants/api_constants.dart`:
- Backend API base URL
- Timeout settings
- API endpoints

## Branding Constants

- Primary Color: #003087 (Dark Blue)
- Secondary Color: #00A3E0 (Light Blue)
- Background: #FFFFFF (White)
