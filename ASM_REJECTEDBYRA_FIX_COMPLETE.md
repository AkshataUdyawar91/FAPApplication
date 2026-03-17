# ASM RejectedByRA Workflow Fix - Complete

## Issue
When RA rejects a submission (RejectedByRA state), ASM could not see any action buttons to handle the rejection. The workflow was incomplete.

## User Requirement
"As a principal engineer I need to update the workflow when RA rejects the request goes to ASM, ASM can view the rejection comments, edit and resubmit or send it back to agency."

## Solution Implemented

### 1. Frontend Changes

#### `asm_review_detail_page.dart`
✅ **Updated `_isSubmissionActionable()` method**
- Added `rejectedbyra` state to the list of actionable states
- Now returns true for: `pendingapproval`, `pendingasmapproval`, `rejectedbyhq`, `rejectedbyra`

✅ **Added `_isRejectedByRA()` helper method**
- Returns true when state is `rejectedbyhq` or `rejectedbyra`
- Used to hide normal approve/reject buttons in header when RA has rejected

✅ **Updated header section logic**
- Normal approve/reject buttons only show for pending states
- For RejectedByRA state, actions are in the HQRejectionSection widget instead

✅ **Updated `_buildStatusBadge()` method**
- Added proper status badge for ASM role:
  - `pendingasmapproval` → "Pending"
  - `asmapproved` or `pendinghqapproval` → "Pending with RA"
  - `rejectedbyhq` or `rejectedbyra` → "Rejected by RA"
  - `rejectedbyasm` or `rejected` → "Rejected"

✅ **Added `_showSendBackToAgencyDialog()` method**
- Shows dialog with reason input (10-500 characters validation)
- Calls `_sendBackToAgency()` on confirmation

✅ **Added `_sendBackToAgency()` method**
- Calls `PATCH /api/submissions/{id}/send-back-to-agency` endpoint
- Sends `{'Reason': reason}` (capital R to match backend DTO)
- Updates local state immediately after success
- Shows success message and navigates back

✅ **Updated `_resubmitToHQ()` method**
- Added `_isProcessing` state management
- Changed field name from `'notes'` to `'Notes'` (capital N)
- Updates local state immediately after success
- Proper error handling with try/catch/finally

✅ **Updated HQRejectionSection call**
- Added `onSendBackToAgency: _showSendBackToAgencyDialog` callback

#### `hq_rejection_section.dart`
✅ **Updated action buttons**
- Changed from single "Send Back to Agency" button to TWO buttons side-by-side:
  1. "Resubmit to RA" (blue, primary action)
  2. "Send Back to Agency" (orange, secondary action)

✅ **Updated info text**
- Changed from "Please review RA feedback and send back to Agency for corrections"
- To: "You can resubmit to RA with corrections or send back to Agency for major revisions"

### 2. Backend Verification
✅ **Endpoint exists**: `PATCH /api/submissions/{id}/send-back-to-agency`
- Located in `SubmissionsController.cs`
- Requires ASM role
- Accepts `RejectSubmissionRequest` with `Reason` field (capital R)
- Changes state from RejectedByRA → RejectedByASM
- Clears HQ review fields
- Preserves ASM notes with "Sent back to Agency: {reason}"

✅ **Endpoint exists**: `PATCH /api/submissions/{id}/resubmit-to-hq`
- Already implemented and working
- Accepts notes explaining what was addressed

### 3. Requirements Updated
✅ **requirements.md - Requirement 25**
- Updated AC15: ASM now has TWO action buttons (not just one)
- Added AC16: ASM can resubmit to RA after corrections
- Updated workflow step 5 description to clarify both options:
  - Resubmit to RA: for minor corrections
  - Send Back to Agency: for major revisions

## Workflow Summary

When RA rejects a submission (RejectedByRA state):

1. **ASM sees**:
   - Status badge: "Rejected by RA"
   - Red rejection section with RA's rejection reason
   - TWO action buttons:
     - "Resubmit to RA" → Opens dialog for notes, calls `/resubmit-to-hq`, moves to PendingWithRA
     - "Send Back to Agency" → Opens dialog for reason, calls `/send-back-to-agency`, moves to RejectedByASM

2. **Agency sees** (if ASM sends back):
   - Status: "Rejected by ASM"
   - ASM rejection reason (includes "Sent back to Agency: {reason}")
   - Can edit and resubmit to ASM

3. **RA sees**:
   - Status: "Rejected" (not "Rejected by RA")
   - If ASM resubmits, status changes to "Pending" again

## Testing Checklist

- [ ] ASM can see RejectedByRA submissions in review list
- [ ] ASM detail page shows "Rejected by RA" status badge
- [ ] Red rejection section displays RA's rejection reason
- [ ] "Resubmit to RA" button opens dialog and accepts notes
- [ ] Resubmit to RA changes status to "Pending with RA" immediately
- [ ] "Send Back to Agency" button opens dialog and requires reason (10-500 chars)
- [ ] Send back to agency changes status to "Rejected by ASM" immediately
- [ ] Agency can see "Rejected by ASM" with ASM's reason
- [ ] Agency can resubmit after ASM sends back
- [ ] Normal approve/reject buttons do NOT show in header for RejectedByRA state

## Files Modified

### Frontend (2 files)
1. `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`
   - Updated `_isSubmissionActionable()` to include RejectedByRA
   - Added `_isRejectedByRA()` helper
   - Updated header section logic to hide buttons for RejectedByRA
   - Updated `_buildStatusBadge()` with proper ASM labels
   - Added `_showSendBackToAgencyDialog()` and `_sendBackToAgency()`
   - Updated `_resubmitToHQ()` with proper state management
   - Updated HQRejectionSection call with callback

2. `frontend/lib/features/approval/presentation/widgets/hq_rejection_section.dart`
   - Changed to show TWO buttons side-by-side
   - Updated info text to reflect both options

### Specifications (1 file)
3. `.kiro/specs/bajaj-document-processing-system/requirements.md`
   - Updated Requirement 25, AC15 and AC16
   - Updated workflow step 5 description

## Status
✅ **COMPLETE** - ASM can now handle RA rejections with two options: resubmit to RA or send back to Agency.
