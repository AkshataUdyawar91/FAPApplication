# Status Labels Corrected - RA Shows "Rejected" Not "Rejected by RA"

## Issue Fixed

When RA rejects a request, the status label should be:
- **Agency**: "Rejected by RA"
- **ASM**: "Rejected by RA"
- **RA**: "Rejected" (not "Rejected by RA")

## Changes Made

### 1. Requirements Updated

**requirements.md - Requirement 25**:
- ✅ Updated table: RA shows "Rejected" for rejected requests
- ✅ Updated AC12: RA sees "Pending", "Approved", "Rejected" (removed "Rejected by RA")

### 2. Design Updated

**design.md - Design for Requirement 25**:
- ✅ Updated Status Display Labels table: RejectedByRA → RA shows "Rejected"

### 3. Frontend Implementation

**HQ Review Detail Page** (`hq_review_detail_page.dart`):
```dart
// RA role status labels
if (normalizedState == 'rejectedbyhq' || normalizedState == 'rejectedbyra' || normalizedState == 'rejected') {
  backgroundColor = const Color(0xFFFEE2E2);
  textColor = const Color(0xFFEF4444);
  displayText = 'Rejected';  // RA sees just "Rejected"
}
```

**HQ Review Page** (`hq_review_page.dart`):
```dart
case 'rejected':
  label = 'Rejected';  // RA sees just "Rejected"
```

## Final Status Label Matrix

| PackageState    | Agency Label       | ASM Label       | RA Label       |
|-----------------|--------------------|-----------------| ---------------|
| Extracting      | Extracting         | —               | —              |
| PendingWithASM  | Pending with ASM   | Pending         | —              |
| PendingWithRA   | Pending with RA    | Pending with RA | Pending        |
| Approved        | Approved           | Approved        | Approved       |
| RejectedByASM   | Rejected by ASM    | Rejected        | —              |
| RejectedByRA    | Rejected by RA     | Rejected by RA  | **Rejected**   |

## Rationale

Each role sees status labels from their perspective:
- **Agency** needs to know WHO rejected (ASM or RA)
- **ASM** needs to know WHO rejected (themselves or RA)
- **RA** just needs to know they rejected it (no need to say "by RA" to themselves)

This follows standard UX patterns where users don't need to be told about their own actions in third person.

## Files Modified

1. `.kiro/specs/bajaj-document-processing-system/requirements.md`
2. `.kiro/specs/bajaj-document-processing-system/design.md`
3. `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`
4. `frontend/lib/features/approval/presentation/pages/hq_review_page.dart`
5. `SIMPLIFIED_STATUS_FLOW_COMPLETE.md`

## Testing

- [ ] RA rejects a request → RA sees "Rejected"
- [ ] RA rejects a request → Agency sees "Rejected by RA"
- [ ] RA rejects a request → ASM sees "Rejected by RA"
- [ ] RA views pending requests → sees "Pending" (not "Pending HQ/RA Review")
- [ ] RA views approved requests → sees "Approved"

✅ All status labels now correctly reflect role-based perspectives!
