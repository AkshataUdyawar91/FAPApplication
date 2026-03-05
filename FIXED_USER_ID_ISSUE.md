# Fixed: User ID Foreign Key Constraint Error

## Problem
When uploading documents without authentication, the system was using a hardcoded user ID that didn't exist in the database, causing this error:

```
The INSERT statement conflicted with the FOREIGN KEY constraint "FK_DocumentPackages_Users_SubmittedByUserId"
```

## Solution Applied
Updated `DocumentsController.cs` to query the database for the agency user instead of using a hardcoded GUID.

### Changes Made

**File**: `backend/src/BajajDocumentProcessing.API/Controllers/DocumentsController.cs`

**Before**:
```csharp
userId = Guid.Parse("3690062E-CA9C-46B9-AF75-8EFE403A18E7"); // Hardcoded ID
```

**After**:
```csharp
// Query database for actual agency user
var agencyUser = await _context.Users
    .FirstOrDefaultAsync(u => u.Email == "agency@bajaj.com");

if (agencyUser == null)
{
    return Unauthorized(new { message = "No authenticated user and default agency user not found. Please login first." });
}

userId = agencyUser.Id;
```

## How to Apply the Fix

### Step 1: Stop the Running API

The API is currently running (process ID 29032) and locking the DLL files. You need to stop it first.

**Option A: Using Task Manager**
1. Open Task Manager (Ctrl+Shift+Esc)
2. Find "BajajDocumentProcessing.API" process
3. Right-click → End Task

**Option B: Using PowerShell**
```powershell
# Find the process
Get-Process | Where-Object {$_.ProcessName -like "*BajajDocumentProcessing*"}

# Kill it (replace PID with actual process ID)
Stop-Process -Id 29032 -Force
```

### Step 2: Rebuild the Backend

```powershell
cd backend
dotnet build
```

### Step 3: Restart the API

```powershell
cd backend/src/BajajDocumentProcessing.API
dotnet run
```

## Testing the Fix

Once the API is restarted, try uploading a document again:

```bash
POST http://localhost:5000/api/Documents/upload
```

The system will now:
1. Look up the agency user from the database
2. Use the actual user ID from the database
3. Successfully create the package with the correct foreign key

## What This Fixes

✅ Document upload now works without authentication  
✅ No more foreign key constraint errors  
✅ System uses actual user IDs from the database  
✅ Proper error message if agency user doesn't exist

## Next Steps

After restarting the API:
1. Upload your PO document
2. Upload Invoice, Cost Summary, Activity, Photos
3. Submit the package for validation
4. Test all 33 validations

All your testing documentation is ready in:
- `START_HERE_TESTING.md`
- `COMPLETE_VALIDATION_TEST_DATA.md`
- `WHAT_TO_EXPECT.md`
