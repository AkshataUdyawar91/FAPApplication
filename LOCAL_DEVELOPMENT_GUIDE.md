# Local Development Guide
## Running Bajaj Document Processing System on Your Machine

Quick guide to run the application locally for development and testing.

---

## Prerequisites

### Required Software
- ✅ .NET 8 SDK - https://dotnet.microsoft.com/download/dotnet/8.0
- ✅ SQL Server LocalDB (comes with Visual Studio) or SQL Server Express
- ✅ Flutter SDK - https://flutter.dev/docs/get-started/install
- ✅ Git
- ✅ Visual Studio Code or Visual Studio 2022

### Optional (for full features)
- Azure OpenAI access (for AI features)
- Gmail account (for email notifications)

---

## Quick Start (Minimal Setup)

### Step 1: Clone Repository

```bash
git clone <your-repo-url>
cd bajaj-document-processing
```

### Step 2: Configure Backend

Create `backend/src/BajajDocumentProcessing.API/appsettings.Development.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=BajajDocumentProcessing;Trusted_Connection=True;MultipleActiveResultSets=true"
  },
  "Jwt": {
    "SecretKey": "YourSuperSecretKeyThatIsAtLeast32CharactersLong!",
    "Issuer": "BajajDocumentProcessing",
    "Audience": "BajajDocumentProcessing",
    "ExpiryMinutes": 30
  },
  "FileStorage": {
    "Type": "Local",
    "LocalPath": "C:\\BajajDocuments",
    "MaxFileSizeMB": 10
  },
  "AzureOpenAI": {
    "Endpoint": "https://your-resource.openai.azure.com/",
    "ApiKey": "your-api-key-here",
    "DeploymentName": "gpt-4",
    "VisionDeploymentName": "gpt-4-vision",
    "EmbeddingDeploymentName": "text-embedding-ada-002"
  },
  "Email": {
    "Provider": "SMTP",
    "SmtpHost": "smtp.gmail.com",
    "SmtpPort": 587,
    "SmtpUsername": "your-email@gmail.com",
    "SmtpPassword": "your-app-password",
    "FromEmail": "noreply@bajaj.com",
    "EnableSsl": true
  },
  "SAP": {
    "BaseUrl": "https://mock-sap-api.com",
    "Username": "test",
    "Password": "test"
  }
}
```

**Note:** For Linux/Mac, change `LocalPath` to `/tmp/BajajDocuments`

### Step 3: Create Document Storage Folder

**Windows:**
```cmd
mkdir C:\BajajDocuments
```

**Linux/Mac:**
```bash
mkdir -p /tmp/BajajDocuments
```

### Step 4: Setup Database

```bash
cd backend

# Restore packages
dotnet restore

# Create database and run migrations
dotnet ef database update --project src/BajajDocumentProcessing.API
```

If you don't have `dotnet ef` installed:
```bash
dotnet tool install --global dotnet-ef
```

### Step 5: Run Backend

```bash
cd backend/src/BajajDocumentProcessing.API

# Run the API
dotnet run
```

Backend will start at:
- HTTPS: https://localhost:7001
- HTTP: http://localhost:5001
- Swagger: https://localhost:7001/swagger

### Step 6: Configure Frontend

Edit `frontend/lib/core/constants/api_constants.dart`:

```dart
class ApiConstants {
  static const String API_BASE_URL = 'http://localhost:5001';
  static const int TIMEOUT_SECONDS = 30;
  
  // Endpoints
  static const String LOGIN = '/api/auth/login';
  static const String REFRESH_TOKEN = '/api/auth/refresh';
  static const String UPLOAD_DOCUMENT = '/api/documents/upload';
  static const String GET_SUBMISSIONS = '/api/submissions';
  static const String GET_PACKAGE = '/api/submissions';
  static const String APPROVE_PACKAGE = '/api/submissions';
  static const String REJECT_PACKAGE = '/api/submissions';
  static const String GET_ANALYTICS = '/api/analytics/kpis';
  static const String CHAT_MESSAGE = '/api/chat/message';
  static const String GET_NOTIFICATIONS = '/api/notifications';
}
```

### Step 7: Run Frontend

```bash
cd frontend

# Get dependencies
flutter pub get

# Run on Chrome (recommended for development)
flutter run -d chrome

# Or run on Windows
flutter run -d windows

# Or run on your connected device
flutter run
```

---

## Testing the Application

### Step 1: Create Test User

The database seed should create default users. If not, you can create one manually:

```bash
# Connect to database
sqlcmd -S "(localdb)\mssqllocaldb" -d BajajDocumentProcessing
```

```sql
-- Create test users
INSERT INTO Users (Id, Username, Email, PasswordHash, Role, CreatedAt, UpdatedAt)
VALUES 
  (NEWID(), 'agency1', 'agency@test.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYILSWowO0S', 0, GETDATE(), GETDATE()),
  (NEWID(), 'asm1', 'asm@test.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYILSWowO0S', 1, GETDATE(), GETDATE()),
  (NEWID(), 'hq1', 'hq@test.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYILSWowO0S', 2, GETDATE(), GETDATE());
GO
```

**Default password for all users:** `Password123!`

### Step 2: Login

1. Open frontend (http://localhost:port or Chrome window)
2. Login with:
   - **Agency User:** `agency1` / `Password123!`
   - **ASM User:** `asm1` / `Password123!`
   - **HQ User:** `hq1` / `Password123!`

### Step 3: Test Features

**As Agency User:**
- Upload documents (PO, Invoice, Cost Summary, Photos)
- View submission status

**As ASM User:**
- View pending submissions
- Review validation results
- Approve/Reject submissions

**As HQ User:**
- View analytics dashboard
- Use chat assistant
- View notifications

---

## Running Without Azure OpenAI (Mock Mode)

If you don't have Azure OpenAI access yet, you can run in mock mode:

### Option 1: Mock Service Implementation

Create `backend/src/BajajDocumentProcessing.Infrastructure/Services/MockOpenAIService.cs`:

```csharp
public class MockOpenAIService : IDocumentAgent
{
    public Task<string> ClassifyDocumentAsync(byte[] fileBytes, string fileName)
    {
        // Mock classification based on filename
        if (fileName.Contains("PO", StringComparison.OrdinalIgnoreCase))
            return Task.FromResult("PurchaseOrder");
        if (fileName.Contains("Invoice", StringComparison.OrdinalIgnoreCase))
            return Task.FromResult("Invoice");
        if (fileName.Contains("Cost", StringComparison.OrdinalIgnoreCase))
            return Task.FromResult("CostSummary");
        if (fileName.Contains(".jpg") || fileName.Contains(".png"))
            return Task.FromResult("Photo");
        
        return Task.FromResult("AdditionalDocument");
    }
    
    public Task<Dictionary<string, object>> ExtractDataAsync(byte[] fileBytes, string documentType)
    {
        // Return mock extracted data
        return Task.FromResult(new Dictionary<string, object>
        {
            ["documentNumber"] = "MOCK-" + Guid.NewGuid().ToString().Substring(0, 8),
            ["date"] = DateTime.Now.ToString("yyyy-MM-dd"),
            ["amount"] = 10000.00,
            ["vendor"] = "Mock Vendor Ltd",
            ["confidence"] = 0.85
        });
    }
}
```

Register in `Program.cs`:
```csharp
// Comment out real service
// builder.Services.AddScoped<IDocumentAgent, DocumentAgent>();

// Use mock service
builder.Services.AddScoped<IDocumentAgent, MockOpenAIService>();
```

---

## Common Issues & Solutions

### Issue 1: Database Connection Failed

**Error:** `Cannot connect to (localdb)\mssqllocaldb`

**Solution:**
```bash
# Check if LocalDB is installed
sqllocaldb info

# If not installed, install SQL Server Express
# Download from: https://www.microsoft.com/sql-server/sql-server-downloads

# Or use SQL Server Express connection string:
"Server=localhost\\SQLEXPRESS;Database=BajajDocumentProcessing;Trusted_Connection=True;"
```

### Issue 2: Port Already in Use

**Error:** `Address already in use`

**Solution:**
```bash
# Change port in launchSettings.json
# Or kill process using the port

# Windows
netstat -ano | findstr :5001
taskkill /PID <process-id> /F

# Linux/Mac
lsof -ti:5001 | xargs kill -9
```

### Issue 3: CORS Error in Frontend

**Error:** `Access to XMLHttpRequest blocked by CORS policy`

**Solution:**
Add to `Program.cs`:
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", builder =>
    {
        builder.AllowAnyOrigin()
               .AllowAnyMethod()
               .AllowAnyHeader();
    });
});

// After app.UseRouting()
app.UseCors("AllowAll");
```

### Issue 4: Flutter Build Errors

**Error:** Various build errors

**Solution:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Issue 5: SSL Certificate Error

**Error:** `The SSL connection could not be established`

**Solution:**
Use HTTP instead of HTTPS for local development:
```dart
static const String API_BASE_URL = 'http://localhost:5001';
```

---

## Development Workflow

### Backend Development

```bash
# Watch mode (auto-restart on changes)
dotnet watch run --project src/BajajDocumentProcessing.API

# Run tests
dotnet test

# Run specific test
dotnet test --filter "FullyQualifiedName~DocumentAgentTests"

# Check code coverage
dotnet test /p:CollectCoverage=true
```

### Frontend Development

```bash
# Hot reload (automatic)
flutter run -d chrome

# Run tests
flutter test

# Run specific test
flutter test test/features/auth/login_test.dart

# Analyze code
flutter analyze

# Format code
dart format .
```

### Database Changes

```bash
# Create new migration
dotnet ef migrations add MigrationName --project src/BajajDocumentProcessing.API

# Update database
dotnet ef database update --project src/BajajDocumentProcessing.API

# Rollback migration
dotnet ef database update PreviousMigrationName --project src/BajajDocumentProcessing.API

# Remove last migration
dotnet ef migrations remove --project src/BajajDocumentProcessing.API
```

---

## IDE Setup

### Visual Studio Code

**Recommended Extensions:**
- C# Dev Kit
- Flutter
- Dart
- REST Client
- SQLTools

**Launch Configuration (.vscode/launch.json):**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Backend API",
      "type": "coreclr",
      "request": "launch",
      "preLaunchTask": "build",
      "program": "${workspaceFolder}/backend/src/BajajDocumentProcessing.API/bin/Debug/net8.0/BajajDocumentProcessing.API.dll",
      "args": [],
      "cwd": "${workspaceFolder}/backend/src/BajajDocumentProcessing.API",
      "env": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    {
      "name": "Flutter",
      "type": "dart",
      "request": "launch",
      "program": "${workspaceFolder}/frontend/lib/main.dart"
    }
  ]
}
```

### Visual Studio 2022

1. Open `backend/BajajDocumentProcessing.sln`
2. Set `BajajDocumentProcessing.API` as startup project
3. Press F5 to run
4. Swagger UI opens automatically

---

## Quick Test Commands

```bash
# Test backend health
curl http://localhost:5001/health

# Test login
curl -X POST http://localhost:5001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"agency1","password":"Password123!"}'

# Test with token
curl http://localhost:5001/api/submissions \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## Next Steps

1. ✅ Get Azure OpenAI access for full AI features
2. ✅ Configure Gmail SMTP for email notifications
3. ✅ Set up SAP connection (if available)
4. ✅ Test all user workflows
5. ✅ Review and customize business logic
6. ✅ Add more test data
7. ✅ Deploy to VM when ready

---

## Support

For issues:
1. Check logs in console output
2. Review `appsettings.Development.json` configuration
3. Verify all services are running
4. Check database connection
5. Refer to troubleshooting section above

Happy coding! 🚀
