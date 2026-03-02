# Database Migration Instructions

## Prerequisites

Ensure you have the following installed:
- .NET 8 SDK
- SQL Server (LocalDB or full instance)
- Entity Framework Core tools

## Install EF Core Tools (if not already installed)

```bash
dotnet tool install --global dotnet-ef
```

## Create Initial Migration

From the `backend` directory, run:

```bash
dotnet ef migrations add InitialCreate --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
```

This will create a migration in `src/BajajDocumentProcessing.Infrastructure/Migrations/`

## Apply Migration to Database

```bash
dotnet ef database update --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
```

This will:
1. Create the database if it doesn't exist
2. Apply all pending migrations
3. Seed initial test data (3 users with different roles)

## Verify Database Creation

You can verify the database was created successfully by:

1. **Using SQL Server Management Studio (SSMS)**:
   - Connect to `(localdb)\mssqllocaldb`
   - Look for database named `BajajDocumentProcessing`

2. **Using Visual Studio SQL Server Object Explorer**:
   - View > SQL Server Object Explorer
   - Expand (localdb)\mssqllocaldb
   - Find BajajDocumentProcessing database

3. **Using dotnet ef**:
   ```bash
   dotnet ef database list --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
   ```

## Test Data

The database will be seeded with 3 test users:

| Email | Password | Role | Full Name |
|-------|----------|------|-----------|
| agency@bajaj.com | Password123! | Agency | Agency User |
| asm@bajaj.com | Password123! | ASM | ASM User |
| hq@bajaj.com | Password123! | HQ | HQ User |

## Database Schema

The following tables will be created:

- **Users**: System users with roles
- **DocumentPackages**: Document submission packages
- **Documents**: Individual documents (PO, Invoice, etc.)
- **ValidationResults**: Validation results for packages
- **ConfidenceScores**: Confidence scores for packages
- **Recommendations**: AI-generated recommendations
- **Notifications**: In-app notifications
- **AuditLogs**: Audit trail for user actions

## Troubleshooting

### Connection String Issues

If you encounter connection issues, update the connection string in `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=BajajDocumentProcessing;Trusted_Connection=True;MultipleActiveResultSets=true"
  }
}
```

For a full SQL Server instance:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=BajajDocumentProcessing;User Id=sa;Password=YourPassword;TrustServerCertificate=True"
  }
}
```

### Migration Already Exists

If you see "A migration named 'InitialCreate' already exists", you can:

1. Remove the existing migration:
   ```bash
   dotnet ef migrations remove --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
   ```

2. Or use a different name:
   ```bash
   dotnet ef migrations add InitialCreate_v2 --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
   ```

### Database Already Exists

If the database already exists and you want to start fresh:

```bash
dotnet ef database drop --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
dotnet ef database update --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API
```

## Next Steps

After successfully creating and seeding the database:

1. Run the API:
   ```bash
   dotnet run --project src/BajajDocumentProcessing.API
   ```

2. Navigate to Swagger UI:
   - https://localhost:7001/swagger

3. Test the database connection by implementing authentication endpoints (Task 3)
