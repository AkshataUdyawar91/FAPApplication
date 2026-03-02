# ASM View Issue - FIXED

## Problem
ASM users couldn't see submissions uploaded by agency users.

## Root Causes Identified

### 1. Same API Response Parsing Issue
- ASM review page had the same paginated response parsing issue as agency dashboard
- **Fix**: Updated to extract `items` from paginated response

### 2. Wrong Field Names
- ASM page was looking for fields that don't exist: `agencyName`, `totalAmount`, `confidenceScore`, `aiRecommendation`
- **Fix**: Updated to use actual backend fields: `id`, `state`, `createdAt`, `updatedAt`, `documentCount`

### 3. State Mapping Issue
- ASM page was checking for `status` field with values like `asm-review`, `approved`, `rejected`
- Backend returns `state` field with values like `PendingApproval`, `Approved`, `Rejected`
- **Fix**: Added `_normalizeStatus()` helper to map backend states to UI states

### 4. Workflow State Issue (Critical)
- Submissions start in `Uploaded` state
- ASM should only see submissions in `PendingApproval` state
- Workflow orchestrator moves submissions through states: Uploaded → Extracting → Validating → Scoring → Recommending → PendingApproval
- Without Azure services configured, workflow fails and submissions stay in `Uploaded` state
- **Fix**: Added temporary endpoint to manually move submissions to `PendingApproval` for testing

## Changes Made

### File: `frontend/lib/features/approval/presentation/pages/asm_review_page.dart`

1. **Fixed API Response Parsing**
```dart
final data = response.data;
if (data is Map && data.containsKey('items')) {
  _documents = List<Map<String, dynamic>>.from(data['items']);
}
```

2. **Added State Normalization**
```dart
String _normalizeStatus(String backendState) {
  if (state == 'pendingapproval') return 'asm-review';
  if (state == 'approved') return 'approved';
  if (state == 'rejected' || ...) return 'rejected';
  return 'processing'; // Don't show to ASM
}
```

3. **Updated Document Card**
- Removed non-existent fields (agencyName, totalAmount, confidenceScore, aiRecommendation)
- Added actual fields (id, documentCount, createdAt, updatedAt)
- Fixed status badge to use normalized status

4. **Updated Stats Calculation**
- Now correctly counts submissions by backend state
- Filters out submissions still in processing

5. **Updated Filter Logic**
- Filters out submissions in "processing" state
- Only shows PendingApproval, Approved, and Rejected submissions

### File: `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

Added temporary testing endpoint:

```csharp
[HttpPatch("{id}/move-to-pending")]
[Authorize]
public async Task<IActionResult> MoveToPendingApproval(Guid id, ...)
```

This endpoint allows manually moving a submission from `Uploaded` to `PendingApproval` state for testing without Azure services.

## Testing Steps

### Step 1: Move Submission to PendingApproval (via Swagger)

1. Open Swagger: http://localhost:5000/swagger
2. Authorize with agency token
3. Find the submission ID from GET /api/submissions
4. Call PATCH /api/submissions/{id}/move-to-pending with the submission ID
5. Verify response shows `"state": "PendingApproval"`

### Step 2: Login as ASM and View Submissions

1. Restart Flutter app if needed
2. Login with ASM credentials: asm@bajaj.com / ASM@123
3. ASM review page should now show the submission
4. Stats cards should show 1 in "Pending Review"
5. Submission card should display with "Pending Review" badge

## Backend State Flow

### Normal Flow (with Azure services):
```
Uploaded → Extracting → Validating → Scoring → Recommending → PendingApproval
```

### Testing Flow (without Azure services):
```
Uploaded → [Manual API call] → PendingApproval
```

## ASM Visibility Rules

ASM users can see submissions in these states:
- **PendingApproval**: Shows as "Pending Review" (can approve/reject)
- **Approved**: Shows as "Approved" (view only)
- **Rejected**: Shows as "Rejected" (view only)

ASM users CANNOT see submissions in these states:
- Uploaded, Extracting, Validating, Scoring, Recommending (still processing)
- ValidationFailed (system error)

## API Endpoint for Testing

**Endpoint**: `PATCH /api/submissions/{id}/move-to-pending`

**Authorization**: Bearer token (any authenticated user)

**Purpose**: Manually move submission from Uploaded to PendingApproval state

**Request**: No body required

**Response**:
```json
{
  "id": "guid",
  "state": "PendingApproval"
}
```

**Restrictions**:
- Only works for submissions in `Uploaded` state
- Returns 400 error if submission is in any other state

## Next Steps

Once Azure services are configured:
1. Remove the `/move-to-pending` endpoint (it's only for testing)
2. Workflow orchestrator will automatically process submissions
3. Submissions will move through all states automatically
4. ASM will see submissions when they reach PendingApproval

## Login Credentials

- **Agency**: agency@bajaj.com / Agency@123
- **ASM**: asm@bajaj.com / ASM@123
- **HQ**: hq@bajaj.com / HQ@123
