# Agency Dashboard Status Labels Updated

## Changes Made

Updated the Agency Dashboard to show clearer status labels that reflect the actual workflow state.

### Status Badge Changes

**Before:**
- `approved` → "Submitted"
- `rejected` → "Draft"
- `under_review` → "On Hold"
- `pending` → "Submitted"

**After:**
- `approved` → "Approved"
- `rejected` → "Rejected"
- `under_review` → "Pending ASM Approval" ✅ (This is what you requested)
- `pending` → "Processing"

### Stats Card Changes

**Before:**
- Card 1: "Pending Requests"
- Card 2: "Approved This Month"
- Card 3: "Total Reimbursed"
- Card 4: "Drafts"

**After:**
- Card 1: "Processing" (packages being extracted/validated/scored)
- Card 2: "Pending ASM Approval" ✅ (packages waiting for ASM review)
- Card 3: "Approved" (approved packages)
- Card 4: "Rejected" (rejected packages)

## Status Mapping

The `_normalizeStatus` function maps backend states to UI states:

### Processing (pending)
- `Uploaded`
- `Extracting`
- `Validating`
- `Scoring`

### Pending ASM Approval (under_review)
- `Validated`
- `Recommending`
- `PendingApproval` ✅ (This is the state after workflow completes)

### Approved
- `Approved`

### Rejected
- `Rejected`
- `ValidationFailed`
- `ReuploadRequested`

## User Experience

When an Agency user submits documents:
1. Status shows "Processing" while AI extracts and validates
2. Status changes to "Pending ASM Approval" when ready for ASM review
3. ASM can then approve or reject the submission
4. Status updates to "Approved" or "Rejected" accordingly

## File Modified
- `frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`

## Testing
1. Run Flutter app: `flutter run -d chrome` (from frontend directory)
2. Login as Agency user
3. View dashboard - packages in `PendingApproval` state should show "Pending ASM Approval"
4. Stats cards should show correct counts for each status

## Date
March 5, 2026 - 8:00 PM
