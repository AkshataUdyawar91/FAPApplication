# Bajaj Document Processing System - Backend API

.NET 8 Web API with Clean Architecture for the Bajaj Document Processing System.

## Architecture

The backend follows Clean Architecture principles with clear separation of concerns:

```
src/
├── BajajDocumentProcessing.API/           # Web API layer
│   ├── Controllers/                       # API controllers
│   ├── Middleware/                        # Custom middleware
│   └── Program.cs                         # App configuration
├── BajajDocumentProcessing.Application/   # Application layer
│   ├── Common/                            # Shared application code
│   ├── Services/                          # Application services
│   └── DTOs/                              # Data transfer objects
├── BajajDocumentProcessing.Domain/        # Domain layer
│   ├── Entities/                          # Domain entities
│   ├── Enums/                             # Domain enumerations
│   ├── Interfaces/                        # Domain interfaces
│   └── Common/                            # Shared domain code
└── BajajDocumentProcessing.Infrastructure/ # Infrastructure layer
    ├── Persistence/                       # Database context
    ├── Services/                          # External services
    └── DependencyInjection.cs            # DI configuration
```

## Features

- Document classification and extraction (Azure Document Intelligence)
- Cross-document validation with SAP integration
- Confidence scoring and recommendations (Semantic Kernel + Azure OpenAI)
- Email notifications (Azure Communication Services)
- Analytics with AI narratives
- Conversational AI chat assistant (Semantic Kernel + Vector Database)
- Role-based access control (Agency, ASM, HQ)

## Prerequisites

- .NET 8 SDK
- SQL Server (LocalDB or full instance)
- Azure account with configured services:
  - Azure OpenAI
  - Azure Document Intelligence
  - Azure Blob Storage
  - Azure AI Search
  - Azure Communication Services
- Redis (optional, for caching)

## Getting Started

### 1. Configure Azure Services

Update `appsettings.json` with your Azure service credentials:

```json
{
  "AzureServices": {
    "OpenAI": {
      "Endpoint": "your-endpoint",
      "ApiKey": "your-key",
      "DeploymentName": "gpt-4"
    },
    // ... other services
  }
}
```

### 2. Database Setup

```bash
# Navigate to the API project
cd src/BajajDocumentProcessing.API

# Run migrations (will be created in Task 2)
dotnet ef database update
```

### 3. Run the API

```bash
dotnet run --project src/BajajDocumentProcessing.API
```

The API will be available at `https://localhost:7001` and `http://localhost:5001`.

### 4. View API Documentation

Navigate to `https://localhost:7001/swagger` to view the Swagger UI.

## Running Tests

```bash
# Run all tests
dotnet test

# Run with coverage
dotnet test /p:CollectCoverage=true
```

## Project Structure

### Domain Layer
- Contains business entities and domain logic
- No dependencies on other layers
- Pure C# with no framework dependencies

### Application Layer
- Contains application business rules
- Defines interfaces for infrastructure
- Depends only on Domain layer

### Infrastructure Layer
- Implements interfaces defined in Application layer
- Contains database context, external service clients
- Depends on Application and Domain layers

### API Layer
- Entry point for the application
- Contains controllers and middleware
- Depends on all other layers

## Key Technologies

- **ASP.NET Core 8**: Web API framework
- **Entity Framework Core 8**: ORM for database access
- **Semantic Kernel**: AI orchestration framework
- **Azure OpenAI**: GPT-4 for AI capabilities
- **Azure Document Intelligence**: Document extraction
- **Azure AI Search**: Vector database for semantic search
- **xUnit + FsCheck**: Testing framework with property-based testing
