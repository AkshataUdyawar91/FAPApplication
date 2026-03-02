# Dashboard Display Issue - FIXED

## Problem
Documents uploaded successfully via Swagger but not appearing in Flutter dashboard.

## Root Causes Identified

### 1. API Response Format Mismatch
- **Backend**: Returns paginated response `{ total, page, pageSize, items: [...] }`
- **Flutter**: Was expecting a simple array `[...]`
- **Fix**: Updated `_loadRequests()` to extract `items` from paginated response

### 2. State Name Mismatch
- **Backend**: Uses enum values like `Uploaded`, `PendingApproval`, `Approved`, `Rejected`
- **Flutter**: Was checking for `pending`, `under_review`, `approved`, `rejected`
- **Fix**: Added `_normalizeStatus()` helper to map backend states to UI states

## Changes Made

### File: `frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`

1. **Fixed API Response Parsing**
```dart
// Before: Expected simple array
_requests = List<Map<String, dynamic>>.from(response.data);

// After: Handle paginated response
final data = response.data;
if (data is Map && data.containsKey('items')) {
  _requests = List<Map<String, dynamic>>.from(data['items']);
}
```

2. **Added State Normalization**
```dart
String _normalizeStatus(String backendState) {
  final state = backendState.toLowerCase();
  
  if (state == 'uploaded' || state == 'extracting' || ...) return 'pending';
  if (state == 'validated' || state == 'recommending' || ...) return 'under_review';
  if (state == 'approved') return 'approved';
  if (state == 'rejected' || state == 'validationfailed' || ...) return 'rejected';
  
  return 'pending';
}
```

3. **Updated Stats Calculation**
- Now correctly groups backend states into UI categories
- Pending: Uploaded, Extracting, Validating, Scoring
- Under Review: Validated, Recommending, PendingApproval
- Approved: Approved
- Rejected: Rejected, ValidationFailed, ReuploadRequested

4. **Updated Filter Logic**
- Filter dropdown now works with backend state names
- Search and filter work together correctly

5. **Added Error Handling**
- Added console logging for debugging
- Shows user-friendly error messages via SnackBar

## Backend State Mapping

| Backend State | UI Display |
|--------------|------------|
| Uploaded | Pending |
| Extracting | Pending |
| Validating | Pending |
| Scoring | Pending |
| Validated | Under Review |
| Recommending | Under Review |
| PendingApproval | Under Review |
| Approved | Approved |
| Rejected | Rejected |
| ValidationFailed | Rejected |
| ReuploadRequested | Rejected |

## Testing Steps

1. Restart Flutter app: `flutter run -d chrome`
2. Login with: agency@bajaj.com / Agency@123
3. Navigate to Dashboard
4. Previously uploaded submission should now appear
5. Stats cards should show correct counts
6. Status badges should display correctly
7. Filters should work properly

## Expected Result

The dashboard will now:
- Display all submissions uploaded by the logged-in agency user
- Show correct status badges based on backend state
- Update stats cards with accurate counts
- Allow filtering by status
- Show submission details (ID, date, document count)

## Next Steps

If submissions still don't appear:
1. Check browser console for errors
2. Verify backend is running on http://localhost:5000
3. Check that JWT token is valid
4. Verify user ID in token matches submission's SubmittedByUserId
