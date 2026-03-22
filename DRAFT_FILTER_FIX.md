# Draft Submissions Filter Fix

## Issue
Draft submissions were appearing in the main submissions list (GET /api/submissions), which should only show completed/submitted packages.

## Root Cause
The `ListSubmissions` endpoint was querying all `DocumentPackages` without filtering by state, so draft submissions (State = 'Draft') were included in the results.

## Solution ✅

Added filter to exclude draft submissions from the list query.

### File Modified
`backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

### Change Made

**Before**:
```csharp
var query = _context.DocumentPackages
    .Include(p => p.PO)
    .Include(p => p.Invoices)
    .Include(p => p.ConfidenceScore)
    .Include(p => p.Teams.Where(c => !c.IsDeleted))
        .ThenInclude(c => c.Photos.Where(ph => !ph.IsDeleted))
    .AsSplitQuery()
    .AsQueryable();
```

**After**:
```csharp
var query = _context.DocumentPackages
    .Include(p => p.PO)
    .Include(p => p.Invoices)
    .Include(p => p.ConfidenceScore)
    .Include(p => p.Teams.Where(c => !c.IsDeleted))
        .ThenInclude(c => c.Photos.Where(ph => !ph.IsDeleted))
    .AsSplitQuery()
    .Where(p => p.State != PackageState.Draft) // ✅ Exclude draft submissions
    .AsQueryable();
```

## Impact

### Before Fix ❌
```
GET /api/submissions
Returns:
- Draft submissions (State = 'Draft')
- Uploaded submissions (State = 'Uploaded')
- Pending submissions (State = 'PendingCH', 'PendingRA')
- Approved/Rejected submissions
```

### After Fix ✅
```
GET /api/submissions
Returns:
- Uploaded submissions (State = 'Uploaded')
- Pending submissions (State = 'PendingCH', 'PendingRA')
- Approved/Rejected submissions
- CHRejected/RARejected submissions

Excludes:
- Draft submissions (State = 'Draft') ✅
```

## Draft Submission Lifecycle

```
1. User clicks "New Submission"
   └─> POST /api/submissions/draft
       └─> Creates package with State = 'Draft'
       └─> Returns submissionId

2. User uploads documents
   └─> Documents linked to draft submission
   └─> State remains 'Draft'

3. User completes and submits
   └─> POST /api/submissions/{id}/process-async
       └─> State changes from 'Draft' to 'Uploaded'
       └─> Submission now appears in main list ✅

4. Draft abandoned (user navigates away)
   └─> State remains 'Draft'
   └─> Never appears in main list ✅
```

## Testing

### Test 1: Verify Draft Not in List

**Steps**:
1. Create draft submission
2. Call GET /api/submissions
3. Verify draft is NOT in the list

**SQL Query**:
```sql
-- Check draft submissions exist
SELECT Id, State, SubmissionNumber, CreatedAt
FROM DocumentPackages
WHERE State = 'Draft'
ORDER BY CreatedAt DESC

-- Verify they don't appear in list query
SELECT Id, State, SubmissionNumber, CreatedAt
FROM DocumentPackages
WHERE State != 'Draft'
ORDER BY CreatedAt DESC
```

### Test 2: Verify Submitted Packages Appear

**Steps**:
1. Create draft submission
2. Upload documents
3. Submit the package (State changes to 'Uploaded')
4. Call GET /api/submissions
5. Verify submission NOW appears in the list

**Expected**:
- Draft: NOT in list
- After submission: IN list

### Test 3: Check All States

**SQL Query**:
```sql
-- Count submissions by state
SELECT 
    State,
    COUNT(*) AS Count
FROM DocumentPackages
WHERE IsDeleted = 0
GROUP BY State
ORDER BY State

-- Verify list endpoint excludes only Draft
SELECT 
    State,
    COUNT(*) AS Count,
    CASE 
        WHEN State = 'Draft' THEN 'Excluded ❌'
        ELSE 'Included ✅'
    END AS ListStatus
FROM DocumentPackages
WHERE IsDeleted = 0
GROUP BY State
```

## API Behavior

### GET /api/submissions

**Query Parameters**:
- `state` (optional) - Filter by specific state
- `page` (default: 1) - Page number
- `pageSize` (default: 20, max: 100) - Items per page

**Response**:
```json
{
  "total": 25,
  "page": 1,
  "pageSize": 20,
  "items": [
    {
      "id": "guid",
      "state": "Uploaded",  // Never "Draft"
      "submissionNumber": "SUB-2024-001",
      "createdAt": "2024-03-21T...",
      "documentCount": 5,
      "invoiceNumber": "INV-001",
      "invoiceAmount": 11800.00,
      "poNumber": "PO-001",
      "poAmount": 50000.00,
      "overallConfidence": 0.95
    }
    // ... more submissions (no drafts)
  ]
}
```

### GET /api/submissions/{id}

**Behavior**: 
- Works for ALL states including Draft
- Used during upload process to load draft data
- No filter applied (intentional)

## Role-Based Filtering

The draft filter applies to ALL roles:

### Agency Users
```csharp
query = query
    .Where(p => p.State != PackageState.Draft)  // No drafts
    .Where(p => p.AgencyId == agencyId);        // Only their agency
```

### ASM Users
```csharp
query = query
    .Where(p => p.State != PackageState.Draft)  // No drafts
    .Where(p => assignedStates.Contains(p.ActivityState)); // Only assigned states
```

### RA Users
```csharp
query = query
    .Where(p => p.State != PackageState.Draft)  // No drafts
    .Where(p => assignedStates.Contains(p.ActivityState)); // Only assigned states
```

### HQ Users
```csharp
query = query
    .Where(p => p.State != PackageState.Draft); // No drafts, all submissions
```

## Benefits

✅ **Clean Dashboard** - Only shows actual submissions, not work-in-progress  
✅ **No Confusion** - Users don't see incomplete drafts in their list  
✅ **Proper Workflow** - Drafts are internal state, not visible externally  
✅ **Consistent Behavior** - All roles see only submitted packages  
✅ **Performance** - Fewer records to query and return  

## Edge Cases Handled

### Abandoned Drafts
- User creates draft but never submits
- Draft remains in database with State = 'Draft'
- Never appears in any list
- Can be cleaned up with periodic job if needed

### Multiple Drafts
- User can have multiple drafts (one per session)
- None appear in main list
- Each has unique ID
- Only submitted ones appear

### Draft to Submitted Transition
- Draft created: State = 'Draft' (not in list)
- Documents uploaded: State = 'Draft' (not in list)
- Submission processed: State = 'Uploaded' (NOW in list ✅)

## Verification Queries

### Check Draft Filter Working
```sql
-- This should return 0 if filter is working
SELECT COUNT(*) AS DraftsInList
FROM DocumentPackages
WHERE State = 'Draft'
AND IsDeleted = 0
-- If this returns > 0, drafts are leaking into list
```

### Compare Draft vs Non-Draft Counts
```sql
SELECT 
    CASE WHEN State = 'Draft' THEN 'Draft' ELSE 'Non-Draft' END AS Category,
    COUNT(*) AS Count
FROM DocumentPackages
WHERE IsDeleted = 0
GROUP BY CASE WHEN State = 'Draft' THEN 'Draft' ELSE 'Non-Draft' END
```

### List All Non-Draft States
```sql
SELECT DISTINCT State
FROM DocumentPackages
WHERE State != 'Draft'
AND IsDeleted = 0
ORDER BY State
-- Expected: Uploaded, PendingCH, PendingRA, Approved, CHRejected, RARejected
```

## Status

✅ **Fix Applied**  
✅ **Backend Restarting**  
✅ **Ready for Testing**  

## Testing Checklist

- [ ] Create draft submission
- [ ] Verify draft NOT in GET /api/submissions
- [ ] Upload documents to draft
- [ ] Verify still NOT in list
- [ ] Submit the draft (process-async)
- [ ] Verify NOW appears in list
- [ ] Check all roles see correct submissions
- [ ] Verify no drafts in any user's list

---

**File Modified**: 1  
**Lines Changed**: 1  
**Breaking Changes**: None  
**Backward Compatible**: Yes  
**Impact**: Positive - cleaner UI, better UX
