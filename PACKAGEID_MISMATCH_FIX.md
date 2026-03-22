# PackageId Mismatch Fix

## Problem Identified

**Draft ID**: `0608f7dc-d95d-47dd-be7f-9f30d5b26e06`  
**Invoice saved with PackageId**: `6e4008b4-ed7f-4f61-90e9-415fc6c1a63f`

### Root Cause

When user selected a PO from the dropdown, the code was overwriting `_currentPackageId` with the **PO's packageId** instead of keeping the **draft submission ID**.

```dart
// WRONG CODE (line 1503)
setState(() {
  _selectedPO = po;
  _currentPackageId = po['packageId']?.toString();  // ❌ Overwrites draft ID!
  _poSearchController.clear();
});
```

This caused invoices to be saved to the PO's old package instead of the new draft submission.

## Solution Applied ✅

### 1. Initialize _currentPackageId from widget.submissionId
```dart
if (_isEditMode) {
  _currentPackageId = widget.submissionId;
  _loadExistingSubmission();
} else if (widget.submissionId != null) {
  // New submission with draft ID provided
  _currentPackageId = widget.submissionId;  // ✅ Set draft ID
}
```

### 2. Don't Overwrite _currentPackageId When Selecting PO
```dart
setState(() {
  _selectedPO = po;
  // ✅ Keep using draft submission ID
  // The PO will be linked via SelectedPOId in the package
  _poSearchController.clear();
});
```

## How It Works Now

### Flow:
1. User clicks "New Submission"
   - Backend creates draft: `0608f7dc-d95d-47dd-be7f-9f30d5b26e06`
   - Frontend navigates with `submissionId: 0608f7dc-...`

2. Frontend initializes:
   - `_currentPackageId = widget.submissionId` (draft ID)
   - This ID stays constant throughout the session

3. User selects PO from dropdown:
   - `_selectedPO = po` (stores PO data)
   - `_currentPackageId` remains unchanged (still draft ID)
   - Backend will link PO via `package.SelectedPOId`

4. User uploads invoice:
   - Sends `packageId: _currentPackageId` (draft ID)
   - Invoice saved to correct package: `0608f7dc-...`

## Database Relationships

```
DocumentPackages (Draft)
├─ Id: 0608f7dc-d95d-47dd-be7f-9f30d5b26e06
├─ SelectedPOId: <selected_po_id>  ← Links to existing PO
└─ State: Draft

Invoices (New)
├─ Id: <new_guid>
├─ PackageId: 0608f7dc-d95d-47dd-be7f-9f30d5b26e06  ✅ Correct!
├─ POId: <selected_po_id>  ← Links to same PO
└─ InvoiceNumber: ...

POs (Existing - from dropdown)
├─ Id: <selected_po_id>
├─ PackageId: 6e4008b4-ed7f-4f61-90e9-415fc6c1a63f  ← Old package
└─ PONumber: ...
```

## Key Points

1. **Draft submission ID is sacred** - Never overwrite `_currentPackageId` after it's set from `widget.submissionId`

2. **PO selection is just a reference** - Selecting a PO from dropdown doesn't change which package we're working on

3. **Backend handles PO linking** - The extract API finds the PO via `package.SelectedPOId` or searches for PO in the current package

4. **One draft = One packageId** - All documents uploaded in a session should use the same draft packageId

## Testing

After this fix:

```sql
-- Check invoice is in correct package
SELECT 
    i.Id as InvoiceId,
    i.PackageId,
    i.POId,
    i.InvoiceNumber,
    p.Id as PackageId,
    p.State as PackageState,
    p.SubmissionNumber
FROM Invoices i
JOIN DocumentPackages p ON i.PackageId = p.Id
WHERE p.Id = '0608f7dc-d95d-47dd-be7f-9f30d5b26e06';

-- Should return invoice with matching PackageId
```

## Before vs After

### Before (Wrong):
```
1. Draft created: 0608f7dc-...
2. User selects PO (from package 6e4008b4-...)
3. _currentPackageId = 6e4008b4-...  ❌ Overwritten!
4. Invoice saved to: 6e4008b4-...  ❌ Wrong package!
```

### After (Correct):
```
1. Draft created: 0608f7dc-...
2. _currentPackageId = 0608f7dc-...  ✅ Set once
3. User selects PO (from package 6e4008b4-...)
4. _currentPackageId = 0608f7dc-...  ✅ Unchanged!
5. Invoice saved to: 0608f7dc-...  ✅ Correct package!
```

## Related Files Changed

1. `frontend/lib/features/submission/presentation/pages/agency_upload_page.dart`
   - Line ~98: Initialize `_currentPackageId` from `widget.submissionId`
   - Line ~1503: Remove line that overwrites `_currentPackageId` with PO's packageId
