# Azure Synapse Firewall Configuration Required ⚠️

## Current Issue

The backend is running on `http://localhost:5000`, but **all API endpoints that require database access are failing** with 500 Internal Server Error.

**Root Cause**: Azure Synapse firewall is blocking your IP address.

**Error**: `Cannot open server 'balsynwsdev' requested by the login. Client with IP address is not allowed to access the server.` (Error 40615)

## Affected Endpoints

All endpoints that query the database will fail:

- ❌ `/api/auth/login` - Cannot query Users table
- ❌ `/api/documents/upload` - Cannot save to database
- ❌ `/api/submissions` - Cannot query submissions
- ❌ `/api/analytics` - Cannot query analytics data
- ✅ `/swagger` - Works (no database needed)
- ✅ Health checks - Work (no database needed)

## Fix Required: Add Firewall Rule

### Option 1: Azure Portal (Recommended - 2 minutes)

1. **Open Azure Portal**: https://portal.azure.com
2. **Search** for "balsynwsdev" in the top search bar
3. **Click** on your Synapse workspace
4. **Navigate** to "Networking" (under Security in left menu)
5. **Click** "+ Add client IP" button (this adds your current IP automatically)
6. **Click** "Save"
7. **Wait** 1-2 minutes for the rule to propagate
8. **Restart** the backend application

### Option 2: Azure CLI (If you have Azure CLI installed)

```bash
# Get your current IP
curl ifconfig.me

# Add firewall rule
az synapse workspace firewall-rule create \
  --name "DevelopmentMachine" \
  --workspace-name balsynwsdev \
  --resource-group <your-resource-group-name> \
  --start-ip-address <your-ip> \
  --end-ip-address <your-ip>
```

### Option 3: Allow All Azure Services (Quick but less secure)

1. In Azure Portal → Synapse workspace → Networking
2. Toggle **"Allow Azure services and resources to access this workspace"** to ON
3. Click **Save**

## After Adding Firewall Rule

### 1. Restart the Backend

Stop the current process (Ctrl+C) and restart:

```bash
cd backend
dotnet run --project src/BajajDocumentProcessing.API
```

### 2. Verify Database Connection

Look for this in the console output:

```
info: Microsoft.EntityFrameworkCore.Database.Command[20101]
      Executed DbCommand (165ms) [Parameters=[], CommandType='Text', CommandTimeout='30']
      SELECT CASE
          WHEN EXISTS (
              SELECT 1 FROM [Users] AS [u]
              WHERE [u].[IsDeleted] = CAST(0 AS bit)) THEN CAST(1 AS bit)
          ELSE CAST(0 AS bit)
      END
```

If you see this, the database connection is working!

### 3. Test Login via Swagger

1. Open `http://localhost:5000/swagger`
2. Expand `/api/auth/login`
3. Click "Try it out"
4. Enter:
   ```json
   {
     "email": "agency@bajaj.com",
     "password": "Password123!"
   }
   ```
5. Click "Execute"
6. Should return a JWT token (200 OK)

## Expected Behavior After Fix

### Successful Login Response

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "email": "agency@bajaj.com",
  "fullName": "Agency User",
  "role": 1,
  "expiresAt": "2026-03-03T09:30:00Z"
}
```

### Database Tables Created

The application will automatically:
1. ✅ Create all required tables
2. ✅ Set up relationships and indexes
3. ✅ Seed test users (agency, asm, hq)

## Verify Tables Were Created

Connect to Azure Synapse using Azure Data Studio or SSMS:

```sql
-- Check tables
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- Check seeded users
SELECT Id, Email, FullName, Role, IsDeleted
FROM Users
WHERE IsDeleted = 0;
```

Expected users:
- `agency@bajaj.com` (Role: Agency)
- `asm@bajaj.com` (Role: ASM)
- `hq@bajaj.com` (Role: HQ)

## Troubleshooting

### Still Getting 500 Error After Adding Firewall Rule

1. **Wait 2-3 minutes** - Firewall rules take time to propagate
2. **Restart the backend** - Connection pool may be cached
3. **Check firewall rule** - Verify it was saved in Azure Portal
4. **Check your IP** - Your IP may have changed (use `curl ifconfig.me`)

### "Login failed for user 'deloitte03'"

- Verify username and password in `appsettings.json`
- Check if SQL authentication is enabled on the server
- Verify the user has permissions on the database

### Tables Not Created

1. Check console for migration errors
2. Manually run: `dotnet ef database update` from API project directory
3. Verify user has CREATE TABLE permissions

### Connection Timeout

- Check if Synapse workspace is running (not paused)
- Verify server name: `balsynwsdev.sql.azuresynapse.net`
- Check internet connectivity

## Alternative: Use Local SQL Server (Temporary)

If you can't access Azure Synapse immediately, you can temporarily use local SQL Server:

### Update appsettings.json

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost\\SQLEXPRESS;Database=BajajDocumentProcessing;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
  }
}
```

### Run Migrations

```bash
cd backend/src/BajajDocumentProcessing.API
dotnet ef database update
```

This will create the database locally and seed test users.

## Summary

**Problem**: Azure Synapse firewall blocking connection
**Solution**: Add your IP to firewall rules in Azure Portal
**Time**: 2-3 minutes
**Impact**: All database-dependent endpoints will work after fix

---

## Quick Steps

1. Azure Portal → Search "balsynwsdev"
2. Networking → Add client IP
3. Save and wait 2 minutes
4. Restart backend
5. Test login at `http://localhost:5000/swagger`

---

**Current Status**: ⚠️ Backend running but database access blocked. Add firewall rule to proceed.
