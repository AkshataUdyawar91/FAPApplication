# Troubleshooting 500 Internal Server Error

## Error
Flutter app is getting HTTP 500 error when calling `/api/submissions`

## Steps to Diagnose

### 1. Check API Console Logs
Look at the terminal where the API is running. You should see error details like:
```
fail: BajajDocumentProcessing.API.Controllers.SubmissionsController[0]
      Error listing submissions
      System.NullReferenceException: Object reference not set to an instance of an object
```

### 2. Test API Directly with curl
```cmd
curl -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}"
```

Copy the token from the response, then:
```cmd
curl -X GET http://localhost:5000/api/submissions -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### 3. Common Causes

#### A. Database Connection Issue
**Check**: Is SQL Server running?
```cmd
sqlcmd -S localhost -Q "SELECT @@VERSION"
```

#### B. Missing Database Tables
**Check**: Run migrations
```cmd
cd backend
dotnet ef database update --project src\BajajDocumentProcessing.Infrastructure --startup-project src\BajajDocumentProcessing.API
```

#### C. No Users in Database
**Check**: Verify users exist
```sql
SELECT * FROM Users WHERE Email IN ('agency@bajaj.com', 'asm@bajaj.com', 'hq@bajaj.com')
```

If no users, run:
```sql
-- Run CREATE_USERS.sql script
```

#### D. Missing Configuration
**Check**: `appsettings.Development.json` has correct connection string
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=BajajDocumentProcessing;Trusted_Connection=True;TrustServerCertificate=True;"
  }
}
```

### 4. Quick Fix: Restart API
```cmd
# Stop the API (Ctrl+C in the API terminal)
# Then restart
cd backend
dotnet run --project src\BajajDocumentProcessing.API
```

### 5. Enable Detailed Errors
In `appsettings.Development.json`, add:
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Debug",
      "Microsoft.EntityFrameworkCore": "Debug"
    }
  }
}
```

Then restart the API and try again. You'll see detailed SQL queries and error messages.

### 6. Test with Swagger
Navigate to: `http://localhost:5000/swagger`

Try the `/api/submissions` endpoint from Swagger UI to see the exact error response.

## Most Likely Causes (in order)

1. **Users don't exist in database** - Run CREATE_USERS.sql
2. **Database not migrated** - Run `dotnet ef database update`
3. **SQL Server not running** - Start SQL Server
4. **Wrong connection string** - Check appsettings.Development.json
5. **API not running in Development mode** - Set `ASPNETCORE_ENVIRONMENT=Development`

## Quick Test Script

Run this to test the API:
```cmd
REM Test health endpoint
curl http://localhost:5000/api/health

REM Test login
curl -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}"
```

If login fails, users don't exist. If login succeeds but submissions fails, there's a database query issue.

## Next Steps

1. Check the API console for the actual error message
2. Share the error message to get specific help
3. Verify database connection and migrations
4. Ensure users exist in the database
