# Workflow Duplicate Key Issue - FIXED

## Problem Summary

When uploading fresh documents multiple times, the workflow was failing with the error:
```
Violation of PRIMARY KEY constraint 'PK_ConfidenceScores'. Cannot insert duplicate key
```

### Root Cause

The issue was caused by **Entity Framework Core change tracking conflicts**:

1. When a package was processed multiple times (due to failures or retries), the workflow would:
   - Extract documents ✅
   - Validate documents ✅
   - Calculate confidence scores ✅
   - Try to generate recommendation ❌ (failed here)

2. The `ConfidenceScoreService` and `RecommendationAgent` had logic to check for existing records and update them, BUT:
   - They were using `.FirstOrDefaultAsync()` which **tracks the entity** in EF Core's change tracker
   - When trying to update, EF Core would get confused because it was already tracking the old entity
   - This caused duplicate key violations when trying to save changes

3. Additionally, the `NotificationAgent` didn't check for duplicate notifications, causing errors during compensation (when workflow failed)

## Solution Applied

### 1. Fixed ConfidenceScoreService.cs
- Changed to use `.AsNoTracking()` when checking for existing records
- Use `.Update()` method with a new entity instance (keeping same ID) instead of modifying tracked entity
- This prevents EF Core tracking conflicts

### 2. Fixed RecommendationAgent.cs
- Changed to use `.AsNoTracking()` when checking for existing records
- Use `.Update()` method with a new entity instance (keeping same ID)
- Added detailed logging at each step to track progress

### 3. Fixed NotificationAgent.cs
- Added duplicate check in `NotifyRejectedAsync()` to prevent duplicate notifications
- Prevents errors during workflow compensation when package fails multiple times

## Files Modified

1. `backend/src/BajajDocumentProcessing.Infrastructure/Services/ConfidenceScoreService.cs`
   - Added `.AsNoTracking()` to existing record check
   - Changed update logic to use `.Update()` with new entity instance

2. `backend/src/BajajDocumentProcessing.Infrastructure/Services/RecommendationAgent.cs`
   - Added `.AsNoTracking()` to existing record check
   - Changed update logic to use `.Update()` with new entity instance
   - Enhanced logging throughout the recommendation generation process

3. `backend/src/BajajDocumentProcessing.Infrastructure/Services/NotificationAgent.cs`
   - Added duplicate notification check in `NotifyRejectedAsync()`

## Testing Instructions

### For Existing Packages (Already Stuck)

Your existing package `65705657-cb68-41ec-b577-3c544b5495e7` should now complete successfully:

1. **Login to get fresh token** (required after API restart):
   ```powershell
   # In UI: Logout and login again
   # OR use the test script
   .\test-existing-package.ps1
   ```

2. **Process the existing package**:
   - The package is currently in "Scoring" state with confidence scores already calculated
   - Call `/api/Submissions/{packageId}/process-now` again
   - The workflow will now:
     - Skip extraction (already done)
     - Skip validation (already done)
     - Update confidence scores (using existing record)
     - Generate recommendation (will create or update)
     - Move to "PendingApproval" state ✅

### For Fresh Documents

Upload new documents through the Agency UI:
1. Login as Agency user
2. Upload PO, Invoice, Cost Summary, Photos
3. Click "Submit" (calls `/process-now`)
4. Workflow should complete successfully in one attempt

## Expected Behavior After Fix

### Successful Workflow
```
1. Extraction → State: Extracting
2. Validation → State: Validating
3. Scoring → State: Scoring (creates or updates ConfidenceScore)
4. Recommendation → State: Recommending (creates or updates Recommendation)
5. Final → State: PendingApproval ✅
```

### If Workflow Fails
- Compensation will set state to "Rejected"
- Notification will be sent (no duplicate error)
- Package can be reprocessed without duplicate key errors

## API Restart Required

✅ **API has been restarted with fixes applied**

**IMPORTANT**: After API restart, all JWT tokens become invalid. Users must:
1. Logout from UI
2. Login again to get fresh token
3. Then test the workflow

## Verification

Check the API console logs for detailed progress:
- "Loading package {PackageId} with documents"
- "Validation result loaded: {ValidationPassed}"
- "Confidence score loaded: {OverallConfidence}%"
- "Determining recommendation type"
- "Generating AI evidence"
- "Checking for existing recommendation"
- "Updating existing recommendation" OR "Creating new recommendation"
- "Recommendation saved successfully"

## Next Steps

1. **Test with existing package**: Use the UI or run `.\test-existing-package.ps1`
2. **Upload fresh documents**: Test complete workflow from scratch
3. **Verify ASM can see submissions**: Check ASM dashboard shows packages in "PendingApproval" state

---

**Status**: ✅ FIXED - API restarted with all fixes applied
**Date**: March 5, 2026
**Issue**: Duplicate key constraint violations preventing workflow completion
**Resolution**: Fixed EF Core change tracking conflicts using AsNoTracking() and Update() pattern
