# Duplicate Key Error - Final Fix Applied

## Problem Summary
Packages were getting stuck in "Scoring" state with duplicate key constraint violations when reprocessing. The error occurred because Entity Framework Core was trying to INSERT new records instead of UPDATE existing ones.

## Root Cause
The previous fix used `.AsNoTracking()` followed by `.Update()` with a new entity instance. This approach doesn't work correctly in EF Core because:
1. `.AsNoTracking()` tells EF Core not to track the entity
2. Creating a new entity instance with the same ID and calling `.Update()` causes EF Core to treat it as a new entity
3. EF Core generates an INSERT statement instead of UPDATE, causing duplicate key errors

## Solution Applied

### Changed Approach: Load with Tracking, Modify, Save
Instead of creating new entity instances, we now:
1. Load existing entities WITH tracking (remove `.AsNoTracking()`)
2. Modify the properties of the tracked entity
3. Save changes (EF Core automatically generates UPDATE statements)

### Files Modified

#### 1. ConfidenceScoreService.cs
**Before:**
```csharp
var existingScore = await _context.ConfidenceScores
    .AsNoTracking()  // ❌ No tracking
    .FirstOrDefaultAsync(cs => cs.PackageId == packageId, cancellationToken);

if (existingScore != null)
{
    confidenceScore = new ConfidenceScore { ... };  // ❌ New instance
    _context.ConfidenceScores.Update(confidenceScore);  // ❌ Generates INSERT
}
```

**After:**
```csharp
var existingScore = await _context.ConfidenceScores
    .FirstOrDefaultAsync(cs => cs.PackageId == packageId, cancellationToken);  // ✅ WITH tracking

if (existingScore != null)
{
    existingScore.PoConfidence = poConfidence;  // ✅ Modify tracked entity
    existingScore.InvoiceConfidence = invoiceConfidence;
    // ... update other properties
    confidenceScore = existingScore;  // ✅ Return tracked entity
}
// No explicit Update() call needed - EF Core tracks changes automatically
```

#### 2. RecommendationAgent.cs
Applied same fix - load with tracking, modify properties, save.

#### 3. WorkflowOrchestrator.cs
- **ExecuteValidationStepAsync**: Added check for existing ValidationResult, update if exists
- **ExecuteScoringStepAsync**: Removed duplicate `Add()` call (service handles it)
- **ExecuteRecommendationStepAsync**: Removed duplicate `Add()` call (service handles it)

## How EF Core Change Tracking Works

### With Tracking (Correct Approach)
```csharp
var entity = await context.Entities.FirstOrDefaultAsync(e => e.Id == id);
// EF Core tracks this entity in memory

entity.Property = newValue;  // EF Core detects this change
await context.SaveChangesAsync();  // Generates UPDATE statement
```

### Without Tracking (Previous Broken Approach)
```csharp
var entity = await context.Entities.AsNoTracking().FirstOrDefaultAsync(e => e.Id == id);
// EF Core does NOT track this entity

var newEntity = new Entity { Id = entity.Id, ... };  // New instance
context.Entities.Update(newEntity);  // EF Core thinks this is a new entity
await context.SaveChangesAsync();  // Generates INSERT (duplicate key error!)
```

## Testing Instructions

### 1. Restart API
```powershell
# Stop current API process (Ctrl+C)
cd backend
$env:ASPNETCORE_ENVIRONMENT = "Development"
dotnet run --project src/BajajDocumentProcessing.API
```

### 2. Test with Existing Package
Use the HTML test page to reprocess package `48c7854b-fca6-41e7-84e8-3075c880d536`:

1. Open `test-workflow.html` in browser
2. Click "Login" button
3. Click "Process Package" button
4. Wait 30-60 seconds
5. Click "Check Status" button

### Expected Results
- ✅ Package should complete successfully
- ✅ State should be "PendingApproval" (not "Rejected" or "Scoring")
- ✅ Recommendation should be present
- ✅ No duplicate key errors in API logs
- ✅ SQL logs should show UPDATE statements, not INSERT

### What to Look For in Logs
```
✅ GOOD - UPDATE statement:
UPDATE [ConfidenceScores] SET [PoConfidence] = @p0, [InvoiceConfidence] = @p1, ...
WHERE [Id] = @p10

❌ BAD - INSERT statement (old behavior):
INSERT INTO [ConfidenceScores] ([Id], [PackageId], ...)
```

## Benefits of This Fix

1. **Idempotent**: Can reprocess packages multiple times without errors
2. **Preserves CreatedAt**: Original creation timestamp is maintained
3. **Proper EF Core Usage**: Uses change tracking as designed
4. **No Duplicate Records**: Updates existing records instead of creating new ones
5. **Cleaner Code**: No need for manual `.Update()` calls

## Related Issues Fixed
- Packages stuck in "Scoring" state
- Duplicate key constraint violations
- Workflow compensation triggering incorrectly
- Unable to reprocess failed packages

## Date
March 5, 2026 - 7:30 PM
