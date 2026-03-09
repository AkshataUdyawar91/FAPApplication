# Campaign Fields - Manual Database Migration

## Issue
The automated migration script encountered an SSL certificate error. You need to run the migration manually.

## Solution - Run This SQL Command

Open **SQL Server Management Studio (SSMS)** or run this command in a **Command Prompt**:

### Option 1: Using Command Prompt
```cmd
sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -Q "ALTER TABLE DocumentPackages ADD CampaignStartDate DATETIME2 NULL, CampaignEndDate DATETIME2 NULL, CampaignWorkingDays INT NULL"
```

### Option 2: Using SQL Server Management Studio (SSMS)
1. Open SSMS
2. Connect to `localhost\SQLEXPRESS`
3. Select database: `BajajDocumentProcessing`
4. Run this SQL:

```sql
ALTER TABLE DocumentPackages 
ADD 
    CampaignStartDate DATETIME2 NULL,
    CampaignEndDate DATETIME2 NULL,
    CampaignWorkingDays INT NULL;
```

## Verify Migration

After running the migration, verify the columns were added:

```sql
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'DocumentPackages' 
  AND COLUMN_NAME IN ('CampaignStartDate', 'CampaignEndDate', 'CampaignWorkingDays');
```

### Expected Result:
```
COLUMN_NAME           DATA_TYPE    IS_NULLABLE
CampaignStartDate     datetime2    YES
CampaignEndDate       datetime2    YES
CampaignWorkingDays   int          YES
```

## If Columns Already Exist

If you get an error saying "Column names in each table must be unique", the columns already exist. You can verify with:

```sql
SELECT TOP 1 
    Id,
    CampaignStartDate,
    CampaignEndDate,
    CampaignWorkingDays,
    State
FROM DocumentPackages
ORDER BY CreatedAt DESC;
```

## Next Steps

Once the migration is complete:

1. ✅ Database schema updated
2. ✅ Frontend code ready (campaign_details_section.dart)
3. ✅ Backend code ready (DocumentPackage.cs, Controllers updated)
4. ✅ Ready to test!

## Test the Feature

1. Run the backend:
   ```cmd
   cd backend\src\BajajDocumentProcessing.API
   dotnet run
   ```

2. Run the frontend:
   ```cmd
   cd frontend
   flutter run -d chrome
   ```

3. Navigate to agency upload page → Step 3
4. Enter campaign dates
5. Complete submission
6. Check database to verify campaign data was saved

## Troubleshooting

### Error: "Cannot find the object 'DocumentPackages'"
- The table doesn't exist yet
- Run the full database setup first: `setup-database-complete.bat`

### Error: "Column names in each table must be unique"
- Columns already exist
- No action needed, proceed to testing

### Error: "SSL Provider: The certificate chain was issued by an authority that is not trusted"
- Add `-C` flag to sqlcmd command (Trust Server Certificate)
- Or use SSMS instead

## Summary

The campaign details feature is fully implemented in code. You just need to add 3 columns to the database, then you're ready to test!

**Quick Command** (run in Command Prompt):
```cmd
sqlcmd -S localhost\SQLEXPRESS -d BajajDocumentProcessing -E -C -Q "ALTER TABLE DocumentPackages ADD CampaignStartDate DATETIME2 NULL, CampaignEndDate DATETIME2 NULL, CampaignWorkingDays INT NULL"
```

That's it! 🎉
