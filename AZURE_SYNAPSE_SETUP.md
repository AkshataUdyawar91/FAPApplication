# Azure Synapse Database Setup Guide

## Current Configuration

**Server**: `balsynwsdev.sql.azuresynapse.net`
**Database**: `Balsynwsdev`
**Username**: `deloitte03`
**Password**: `D&el3ite%$`

## Step 1: Configure Firewall Rules ⚠️ REQUIRED

### Why This is Needed
Azure Synapse blocks all external connections by default. You must add your IP address to the firewall rules.

### How to Add Firewall Rule

#### Method 1: Azure Portal (Easiest)
1. Open https://portal.azure.com
2. Search for "balsynwsdev" in the top search bar
3. Click on your Synapse workspace
4. In the left menu, click **Networking** (under Security)
5. Click **+ Add client IP** button
6. Click **Save**
7. Wait 1-2 minutes for changes to apply

#### Method 2: Azure CLI
```bash
# First, get your current IP
curl ifconfig.me

# Then add the firewall rule
az synapse workspace firewall-rule create \
  --name "DevelopmentMachine" \
  --workspace-name balsynwsdev \
  --resource-group <your-resource-group-name> \
  --start-ip-address <your-ip> \
  --end-ip-address <your-ip>
```

#### Method 3: Allow All Azure Services
1. In Azure Portal → Synapse workspace → Networking
2. Toggle **Allow Azure services and resources to access this workspace** to ON
3. Click **Save**

## Step 2: Run Database Migrations

Once firewall is configured, the application will automatically:
1. Create all required tables
2. Set up relationships and indexes
3. Seed initial test users

### Manual Migration (if needed)

If you need to run migrations manually:

```bash
cd backend/src/BajajDocumentProcessing.API

# Check current migration status
dotnet ef migrations list

# Apply migrations to Azure Synapse
dotnet ef database update

# If you need to create a new migration
dotnet ef migrations add <MigrationName>
```

## Step 3: Verify Database Setup

### Check Tables Were Created

Connect to Azure Synapse using:
- Azure Data Studio
- SQL Server Management Studio (SSMS)
- Azure Portal Query Editor

Run this query to verify tables:
```sql
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
```

Expected tables:
- Users
- DocumentPackages
- Documents
- ValidationResults
- ConfidenceScores
- Recommendations
- Notifications
- Conversations
- ConversationMessages
- AuditLogs

### Check Seeded Users

```sql
SELECT Id, Email, FullName, Role, IsDeleted
FROM Users
WHERE IsDeleted = 0;
```

Expected users:
- `agency@bajaj.com` (Role: Agency)
- `asm@bajaj.com` (Role: ASM)
- `hq@bajaj.com` (Role: HQ)

All with password: `Password123!`

## Step 4: Test Connection

### From Application
1. Restart the backend if it's running
2. Check the console output for successful database connection
3. Look for: "Application started. Press Ctrl+C to shut down."
4. No errors about firewall or connection should appear

### From Swagger
1. Open http://localhost:5000/swagger
2. Try the `/api/auth/login` endpoint
3. Use credentials: `agency@bajaj.com` / `Password123!`
4. Should return a JWT token

## Troubleshooting

### Error: "Cannot open server 'balsynwsdev'"
**Solution**: Add your IP to firewall rules (see Step 1)

### Error: "Login failed for user 'deloitte03'"
**Solutions**:
- Verify username and password are correct
- Check if SQL authentication is enabled
- Verify the user has permissions on the database

### Error: "Database 'Balsynwsdev' does not exist"
**Solutions**:
- Verify database name spelling
- Check if database exists in Azure Portal
- Create database if needed

### Error: "The server was not found or was not accessible"
**Solutions**:
- Check internet connectivity
- Verify server name: `balsynwsdev.sql.azuresynapse.net`
- Check if Synapse workspace is running (not paused)

### Tables Not Created
**Solutions**:
1. Check migration status: `dotnet ef migrations list`
2. Manually run: `dotnet ef database update`
3. Check user has CREATE TABLE permissions

### Seeded Users Not Found
**Solutions**:
1. Check if seeding completed (look for errors in console)
2. Manually run seeding:
```csharp
// In Program.cs, the seeding code runs automatically
// If it failed, restart the application
```

## Connection String Format

The connection string in `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=balsynwsdev.sql.azuresynapse.net;Database=Balsynwsdev;User ID=deloitte03;Password=D&el3ite%$;MultipleActiveResultSets=true;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30"
  }
}
```

**Important Notes**:
- `Encrypt=True`: Required for Azure SQL
- `TrustServerCertificate=False`: Validates SSL certificate
- `MultipleActiveResultSets=true`: Allows multiple queries simultaneously
- `Connection Timeout=30`: 30 seconds timeout

## Security Best Practices

### For Production

1. **Use Azure Key Vault** for connection strings
2. **Use Managed Identity** instead of SQL authentication
3. **Restrict firewall rules** to specific IP ranges
4. **Enable Advanced Threat Protection**
5. **Set up audit logging**
6. **Use separate databases** for dev/staging/production

### Connection String with Key Vault

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "@Microsoft.KeyVault(SecretUri=https://your-keyvault.vault.azure.net/secrets/DatabaseConnectionString/)"
  }
}
```

## Performance Considerations

### Azure Synapse Pricing Tiers
- **Serverless**: Pay per query (good for dev/test)
- **Dedicated SQL Pool**: Reserved capacity (good for production)

### Optimize for Synapse
- Use appropriate data types
- Create indexes on frequently queried columns
- Consider partitioning for large tables
- Use columnstore indexes for analytics queries

## Monitoring

### Check Database Performance
1. Azure Portal → Synapse workspace → Monitoring
2. View query performance
3. Check resource utilization
4. Set up alerts for failures

### Application Insights
Consider integrating Application Insights for:
- Query performance tracking
- Error monitoring
- Dependency tracking

---

## Quick Reference

**Firewall Rule**: Azure Portal → Synapse → Networking → Add client IP
**Migration**: `dotnet ef database update`
**Test Login**: `agency@bajaj.com` / `Password123!`
**Swagger**: http://localhost:5000/swagger

---

**Status**: ⚠️ Firewall configuration required before database can be accessed
