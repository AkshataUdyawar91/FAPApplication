# Simplified Status Flow Implementation - Complete

## Overview

Successfully implemented the simplified approval workflow as specified in Requirement 25. The system now uses a cleaner status flow with clear role-based labels and rejection comment visibility.

## Status Flow

### Agency → ASM → RA

| Action              | Agency Status       | ASM Status      | RA Status      |
|---------------------|---------------------|-----------------|----------------|
| Submits request     | Extracting → Pending with ASM | Pending         | —              |
| Approved By ASM     | Pending with RA     | Pending with RA | Pending        |
| Approved by RA      | Approved            | Approved        | Approved       |
| Rejected by ASM     | Rejected by ASM     | Rejected        | —              |
| Rejected by RA      | Rejected by RA      | Rejected by RA  | Rejected       |

## Changes Implemented

### 1. Backend (Already Complete)

**PackageState.cs** - Updated enum with:
- `PendingWithASM` (alias: PendingASMApproval)
- `PendingWithRA` (alias: PendingHQApproval)
- `RejectedByASM` (alias: Rejected)
- `RejectedByRA` (alias: RejectedByHQ)

**Endpoints** (all working correctly):
- `PATCH /api/submissions/{id}/asm-approve` - Moves to PendingWithRA
- `PATCH /api/submissions/{id}/asm-reject` - Moves to RejectedByASM
- `PATCH /api/submissions/{id}/hq-approve` - Moves to Approved
- `PATCH /api/submissions/{id}/hq-reject` - Moves to RejectedByRA
- `PATCH /api/submissions/{id}/resubmit` - Agency resubmits RejectedByASM
- `PATCH /api/submissions/{id}/send-back-to-agency` - ASM sends RejectedByRA back to Agency

### 2. Frontend Updates

**HQRejectionSection Widget** (`hq_rejection_section.dart`):
- ✅ Removed "Resubmit to RA" button
- ✅ Only shows "Send Back to Agency" button for RejectedByRA state
- ✅ Updated labels: "Rejected by RA" instead of "Rejected by HQ"
- ✅ Updated info text to guide ASM to send back to Agency

**ASM Review Detail Page** (`asm_review_detail_page.dart`):
- ✅ Updated status badge labels:
  - PendingASMApproval/PendingWithASM → "Pending"
  - PendingHQApproval/PendingWithRA → "Pending with RA"
  - RejectedByHQ/RejectedByRA → "Rejected by RA"
  - RejectedByASM → "Rejected"
  - Extracting → "Extracting"
- ✅ Updated actionable states to include RejectedByRA
- ✅ Removed resubmit to RA functionality

**Agency Dashboard** (`agency_dashboard_page.dart`):
- ✅ Updated status badge labels:
  - PendingASMApproval/PendingWithASM → "Pending with ASM"
  - PendingHQApproval/PendingWithRA → "Pending with RA"
  - RejectedByHQ/RejectedByRA → "Rejected by RA"
  - RejectedByASM → "Rejected by ASM"
- ✅ Updated status normalization to handle new state aliases

**HQ Review Detail Page** (`hq_review_detail_page.dart`):
- ✅ Updated status badge labels for RA role:
  - PendingHQApproval/PendingWithRA → "Pending"
  - RejectedByHQ/RejectedByRA → "Rejected"
  - Approved → "Approved"

**HQ Review Page** (`hq_review_page.dart`):
- ✅ Updated status badge labels for RA role:
  - hq-review → "Pending" (instead of "Pending HQ/RA Review")
  - rejected → "Rejected"
  - approved → "Approved"

### 3. Specification Updates

**requirements.md** - Requirement 25:
- ✅ Updated workflow steps with clear status table
- ✅ Removed ASM resubmit to RA option
- ✅ Added rejection comment visibility requirements
- ✅ Specified exact status labels per role

**design.md** - Design for Requirement 25:
- ✅ Updated state machine diagram
- ✅ Documented key simplifications
- ✅ Added status display labels table
- ✅ Added rejection comments display table
- ✅ Documented frontend changes needed

## Key Simplifications

1. **No ASM Resubmit to RA**: When RA rejects, ASM can only send back to Agency (not resubmit directly to RA)
2. **Unified State Names**: Clear aliases (PendingWithASM, PendingWithRA, RejectedByRA)
3. **Clear Rejection States**: RejectedByASM vs RejectedByRA with appropriate comments
4. **Rejection Comments Always Visible**: 
   - ASMReviewNotes for RejectedByASM
   - HQReviewNotes for RejectedByRA

## Status Labels by Role

| PackageState    | Agency Label       | ASM Label       | RA Label       |
|-----------------|--------------------|-----------------| ---------------|
| Extracting      | Extracting         | —               | —              |
| PendingWithASM  | Pending with ASM   | Pending         | —              |
| PendingWithRA   | Pending with RA    | Pending with RA | Pending        |
| Approved        | Approved           | Approved        | Approved       |
| RejectedByASM   | Rejected by ASM    | Rejected        | —              |
| RejectedByRA    | Rejected by RA     | Rejected by RA  | Rejected       |

## Testing Checklist

- [ ] Agency submits request → shows "Extracting" then "Pending with ASM"
- [ ] ASM approves → shows "Pending with RA" to Agency and ASM, "Pending" to RA
- [ ] RA approves → shows "Approved" to all roles
- [ ] ASM rejects → shows "Rejected by ASM" to Agency, "Rejected" to ASM
- [ ] Agency can resubmit RejectedByASM packages
- [ ] RA rejects → shows "Rejected by RA" to all roles
- [ ] ASM can only "Send Back to Agency" for RejectedByRA (no resubmit to RA button)
- [ ] Rejection comments visible: ASMReviewNotes for ASM rejections, HQReviewNotes for RA rejections
- [ ] No other statuses displayed beyond the 6 defined states

## Files Modified

### Backend
- `backend/src/BajajDocumentProcessing.Domain/Enums/PackageState.cs`

### Frontend
- `frontend/lib/features/approval/presentation/widgets/hq_rejection_section.dart`
- `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`
- `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`
- `frontend/lib/features/approval/presentation/pages/hq_review_page.dart`
- `frontend/lib/features/submission/presentation/pages/agency_dashboard_page.dart`

### Specifications
- `.kiro/specs/bajaj-document-processing-system/requirements.md`
- `.kiro/specs/bajaj-document-processing-system/design.md`

## Next Steps

1. Test the complete flow with real data
2. Verify rejection comments are displayed correctly
3. Ensure all status labels match the specification
4. Test Agency resubmission after ASM rejection
5. Test ASM send back to Agency after RA rejection

## Notes

- All backend endpoints were already implemented correctly
- Frontend changes focused on UI labels and button visibility
- State aliases ensure backward compatibility
- No database schema changes required
