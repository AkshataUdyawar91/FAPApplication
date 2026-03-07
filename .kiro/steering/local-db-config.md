# Local Database Configuration

## SQL Server Instance
- **Server**: `localhost\SQLEXPRESS` (NOT SQLEXPRESS01)
- **Database**: `BajajDocumentProcessing`
- **Authentication**: Windows Authentication (Trusted Connection)

## Connection String
```
Server=localhost\SQLEXPRESS;Database=BajajDocumentProcessing;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=true
```

## Important Notes
- The database with actual data (26+ submissions) is on `SQLEXPRESS`, not `SQLEXPRESS01`
- Always use `localhost\SQLEXPRESS` in connection strings
- The `ResubmissionCount` and `HQResubmissionCount` columns were added manually to this database

## If Connection Issues Occur After Git Pull
If the connection string gets overwritten, update these files:
1. `backend/src/BajajDocumentProcessing.API/appsettings.json`
2. `backend/src/BajajDocumentProcessing.API/appsettings.Development.json`

Change `SQLEXPRESS01` to `SQLEXPRESS` in the connection string.
