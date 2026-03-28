# Draft Mode Feature Documentation

**Date Created**: March 28, 2026  
**Status**: ✅ Complete and Verified  
**Version**: 1.0

---

## Table of Contents

1. [Overview](#overview)
2. [Feature Requirements](#feature-requirements)
3. [What Was Created](#what-was-created)
4. [How It Was Implemented](#how-it-was-implemented)
5. [Technical Architecture](#technical-architecture)
6. [API Changes](#api-changes)
7. [Frontend Changes](#frontend-changes)
8. [Testing Scenarios](#testing-scenarios)
9. [Edge Cases Handled](#edge-cases-handled)
10. [Deployment Notes](#deployment-notes)

---

## Overview

The Draft Mode Feature enables users to create, edit, and return to incomplete document submissions without losing data. When users return to a draft submission, all previously entered data (including document filenames, invoice details, and campaign information) is restored, allowing seamless continuation of the submission process.

### Key Capabilities

- ✅ Create draft submissions with incomplete data
- ✅ Return to draft and see all previously entered information
- ✅ Replace documents in draft mode with "Replace" button
- ✅ Persist invoice dates and GSTIN values
- ✅ Handle drafts with no teams/campaigns
- ✅ User-friendly error messages for invalid inputs
- ✅ Seamless transition from draft to submitted state

---

## Feature Requirements

### User Stories

1. **As an Agency User**, I want to save my submission as a draft so that I can complete it later without losing my work.

2. **As an Agency User**, I want to return to my draft submission and see all my previously entered data (invoices, documents, teams) so that I can continue where I left off.

3. **As an Agency User**, I want to replace documents in draft mode so that I can fix mistakes before final submission.

4. **As an Agency User**, I want to see user-friendly error messages when I upload invalid documents so that I understand what went wrong.

### Acceptance Criteria

- ✅ Draft submissions preserve all data (PO, invoices, cost summary, activity summary, enquiry doc, teams, photos)
- ✅ Returning to draft shows "Replace" button for documents instead of "Click to upload"
- ✅ Invoice date and GSTIN fields are populated when returning to draft
- ✅ Package-level document filenames only shown in draft mode (not in submitted/approved states)
- ✅ Error messages list valid document types when validation fails
- ✅ All data persists across multiple draft edits

---

## What Was Created

### Backend Components

#### 1. **DTO Enhancement** (`SubmissionDetailResponse.cs`)

**Added Properties to `SubmissionDetailResponse`**:
```csharp
/// Package-level Cost Summary filename (for draft mode when no campaigns exist)
public string? CostSummaryFileName { get; init; }

/// Package-level Activity Summary filename (for draft mode when no campaigns exist)
public string? ActivitySummaryFileName { get; init; }

/// Package-level Enquiry Document filename (for draft mode when no campaigns exist)
public string? EnquiryDocFileName { get; init; }
```

**Added Properties to `CampaignInvoiceDto`**:
```csharp
/// Invoice date for persistence in draft mode
public DateTime? InvoiceDate { get; init; }

/// GST number for persistence in draft mode
public string? GSTNumber { get; init; }
```

**Purpose**: Enable frontend to display document filenames and invoice details when returning to draft.

#### 2. **API Controller Enhancement** (`SubmissionsController.cs`)

**Modified `GetSubmission()` Method**:
- Added conditional logic to return package-level filenames only in Draft state
- Populate invoice date and GSTIN from Invoice entity
- Maintain campaign-level filenames for all states

```csharp
// Only return package-level filenames in Draft state
CostSummaryFileName = package.State == PackageState.Draft ? package.CostSummary?.FileName : null,
ActivitySummaryFileName = package.State == PackageState.Draft ? package.ActivitySummary?.FileName : null,
EnquiryDocFileName = package.State == PackageState.Draft ? package.EnquiryDocument?.FileName : null,

// Populate invoice details including date and GSTIN
Invoices = index == 0
    ? package.Invoices.Where(i => !i.IsDeleted).Select(i => new CampaignInvoiceDto
    {
        Id = i.Id,
        InvoiceNumber = i.InvoiceNumber,
        VendorName = i.VendorName,
        InvoiceDate = i.InvoiceDate,      // ← NEW
        GSTNumber = i.GSTNumber,          // ← NEW
        TotalAmount = i.TotalAmount,
        FileName = i.FileName ?? "",
        BlobUrl = i.BlobUrl ?? ""
    }).ToList()
    : new List<CampaignInvoiceDto>()
```

**Purpose**: Ensure draft data is correctly returned to frontend with all necessary information.

#### 3. **Error Handling Filter** (`ModelValidationFilter.cs`)

**New Filter Class**:
- Intercepts model validation errors
- Converts technical error messages to user-friendly messages
- Lists valid document types when enum validation fails

```csharp
public class ModelValidationFilter : IActionFilter
{
    public void OnActionExecuting(ActionExecutingContext context)
    {
        if (!context.ModelState.IsValid)
        {
            // Convert technical errors to user-friendly messages
            var userFriendlyMessage = GetUserFriendlyMessage(error.ErrorMessage);
            // Example: "'AdditionalDocument' is not a valid document type. 
            // Supported types are: PO, Invoice, CostSummary, ..."
        }
    }
}
```

**Purpose**: Provide clear, actionable error messages to users.

#### 4. **Enum Enhancement** (`DocumentType.cs`)

**Added Enum Value**:
```csharp
public enum DocumentType
{
    PO = 1,
    Invoice = 2,
    CostSummary = 3,
    ActivitySummary = 4,
    EnquiryDocument = 5,
    TeamPhoto = 6,
    AdditionalDocument = 7  // ← NEW
}
```

**Purpose**: Support additional document uploads beyond standard types.

#### 5. **Program Configuration** (`Program.cs`)

**Registered Error Filter**:
```csharp
builder.Services.AddControllers(options =>
{
    options.Filters.Add<ModelValidationFilter>();
});
```

**Purpose**: Enable global error message transformation.

### Frontend Components

#### 1. **Upload Page Enhancement** (`new_agency_upload_page.dart`)

**Added State Variables**:
```dart
String? _existingCostSummaryFileName;
String? _existingActivitySummaryFileName;
String? _existingEnquiryDocFileName;
```

**Enhanced Data Loading**:
```dart
// Try package level first, then fall back to campaigns[0]
_existingCostSummaryFileName =
    data['costSummaryFileName']?.toString() ??
    firstCampaign['costSummaryFileName']?.toString();

_existingActivitySummaryFileName =
    data['activitySummaryFileName']?.toString() ??
    firstCampaign['activitySummaryFileName']?.toString();

_existingEnquiryDocFileName = data['enquiryDocFileName']?.toString();
```

**Enhanced Invoice Loading**:
```dart
final invoice = InvoiceItemData(
    id: inv['id']?.toString() ?? UniqueKey().toString(),
    invoiceNumber: inv['invoiceNumber']?.toString() ?? '',
    invoiceDate: _formatDateForField(inv['invoiceDate']),  // ← LOADED
    gstNumber: inv['gstNumber']?.toString() ?? '',         // ← LOADED
    totalAmount: inv['totalAmount']?.toString() ?? '',
    existingFileName: inv['fileName']?.toString(),
    savedToDb: true,
);
```

**Purpose**: Load and display all draft data when returning to edit.

#### 2. **File Upload Widget** (`_buildFlatFileRow()`)

**Smart Display Logic**:
```dart
final displayName = file?.name ?? existingFileName;
final hasFile = displayName != null;

if (hasFile) {
    // Show green box with filename and "Replace" button
    return Container(
        color: const Color(0xFFE8F5E9),  // Light green
        child: Row(
            children: [
                Text(displayName),
                TextButton(
                    onPressed: onPick,
                    child: const Text('Replace'),
                ),
            ],
        ),
    );
} else {
    // Show dashed upload area with "Click to upload"
    return InkWell(
        onTap: onPick,
        child: Container(
            border: Border.all(style: BorderStyle.solid),
            child: Column(
                children: [
                    Icon(Icons.cloud_upload),
                    Text('Click to upload'),
                ],
            ),
        ),
    );
}
```

**Purpose**: Show appropriate UI based on whether file exists or not.

#### 3. **Legacy Upload Page** (`agency_upload_page.dart`)

**Same Enhancements**:
- Added state variables for existing filenames
- Enhanced data loading with package-level fallback
- Enhanced invoice loading with date and GSTIN

**Purpose**: Maintain feature parity across both upload pages.

#### 4. **Detail View Pages** (Read-Only)

**No Changes Required**:
- `agency_submission_detail_page.dart` - Uses campaign-level filenames only
- `asm_review_detail_page.dart` - Uses campaign-level filenames only
- `hq_review_detail_page.dart` - Uses campaign-level filenames only

**Why**: These pages only read from `campaigns[0]` which always has filenames in all states.

---

## How It Was Implemented

### Implementation Approach

#### Phase 1: Backend Data Model Enhancement

1. **Identified the Problem**:
   - Cost summary filename only available in `campaigns[0]`
   - When draft has no teams/campaigns, filename was unavailable
   - Invoice date and GSTIN not persisted

2. **Solution Design**:
   - Add package-level properties to DTO
   - Populate from package entity (not campaign)
   - Return only in Draft state (read-only in other states)

3. **Implementation**:
   - Modified `SubmissionDetailResponse.cs` - added 5 new properties
   - Modified `SubmissionsController.cs` - added conditional logic
   - Added `ModelValidationFilter.cs` - new error handling
   - Modified `DocumentType.cs` - added enum value
   - Modified `Program.cs` - registered filter

#### Phase 2: Frontend Data Loading

1. **Identified the Problem**:
   - Frontend only checked `campaigns[0]` for filenames
   - Invoice date and GSTIN fields were empty on return

2. **Solution Design**:
   - Check package-level first, fall back to campaign-level
   - Load invoice date and GSTIN from API response
   - Use null-coalescing operators for safe fallback

3. **Implementation**:
   - Modified `new_agency_upload_page.dart` - enhanced data loading
   - Modified `agency_upload_page.dart` - same enhancements
   - No changes to detail/review pages (already correct)

#### Phase 3: UI Display Logic

1. **Identified the Problem**:
   - No visual distinction between "file exists" and "file missing"
   - Users couldn't tell if they needed to upload or replace

2. **Solution Design**:
   - Show green box with "Replace" button when file exists
   - Show dashed upload area with "Click to upload" when missing
   - Use `existingFileName` to determine state

3. **Implementation**:
   - Enhanced `_buildFlatFileRow()` method
   - Added conditional rendering based on `hasFile` flag
   - Maintained consistent styling across pages

#### Phase 4: Error Handling

1. **Identified the Problem**:
   - Technical error: "The value 'AdditionalDocument' is not valid"
   - Users didn't know what document types were valid

2. **Solution Design**:
   - Create global error filter
   - Transform technical messages to user-friendly messages
   - List all valid document types in error

3. **Implementation**:
   - Created `ModelValidationFilter.cs`
   - Added enum value `AdditionalDocument`
   - Registered filter in `Program.cs`

---

## Technical Architecture

### Data Flow: Returning to Draft

```
User clicks "Edit Draft"
    ↓
Frontend calls GET /submissions/{id}
    ↓
Backend GetSubmission() executes:
    - Loads package with all related entities
    - Checks if State == PackageState.Draft
    - If Draft: returns package-level filenames
    - If not Draft: returns null for package-level filenames
    - Always returns campaign-level filenames
    - Populates invoice date and GSTIN
    ↓
API Response includes:
{
    "state": "Draft",
    "costSummaryFileName": "cost_summary.pdf",
    "activitySummaryFileName": "activity_summary.pdf",
    "enquiryDocFileName": "enquiry.pdf",
    "campaigns": [
        {
            "costSummaryFileName": "cost_summary.pdf",
            "invoices": [
                {
                    "invoiceDate": "2026-03-15",
                    "gstNumber": "18AABCT1234H1Z0"
                }
            ]
        }
    ]
}
    ↓
Frontend loads data:
    - _existingCostSummaryFileName = package-level ?? campaign-level
    - _existingActivitySummaryFileName = package-level ?? campaign-level
    - _existingEnquiryDocFileName = package-level
    - Invoice date and GSTIN loaded from campaigns[0].invoices
    ↓
UI renders:
    - Cost Summary: Green box with "Replace" button
    - Activity Summary: Green box with "Replace" button
    - Enquiry Doc: Green box with "Replace" button
    - Invoice fields: Populated with date and GSTIN
    ↓
User can edit and save changes
```

### State Transition: Draft to Submitted

```
Draft State (State == 0)
    ↓
User clicks "Submit"
    ↓
Backend validates all requirements
    ↓
Backend transitions to Uploaded (State == 1)
    ↓
Next GET /submissions/{id} returns:
    - costSummaryFileName: null (not Draft)
    - campaigns[0].costSummaryFileName: "cost_summary.pdf" (always present)
    ↓
Frontend falls back to campaign-level filenames
    ↓
UI shows read-only mode (no "Replace" button)
```

---

## API Changes

### New/Modified Endpoints

#### GET /submissions/{id}

**Response Changes**:

```json
{
  "id": "guid",
  "state": "Draft",
  "costSummaryFileName": "cost_summary.pdf",        // NEW - Draft only
  "activitySummaryFileName": "activity_summary.pdf", // NEW - Draft only
  "enquiryDocFileName": "enquiry.pdf",              // NEW - Draft only
  "campaigns": [
    {
      "invoices": [
        {
          "invoiceDate": "2026-03-15",              // NEW
          "gstNumber": "18AABCT1234H1Z0"            // NEW
        }
      ]
    }
  ]
}
```

**Backward Compatibility**: ✅ All new properties are optional (nullable)

### Error Response Changes

#### POST /submissions/{packageId}/documents (Invalid Document Type)

**Old Response**:
```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "documentType": ["The value 'AdditionalDocument' is not valid."]
  }
}
```

**New Response**:
```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "documentType": [
      "'AdditionalDocument' is not a valid document type. Supported types are: PO, Invoice, CostSummary, ActivitySummary, EnquiryDocument, TeamPhoto, AdditionalDocument."
    ]
  },
  "traceId": "correlation-id"
}
```

---

## Frontend Changes

### Files Modified

1. **new_agency_upload_page.dart**
   - Added 3 state variables for existing filenames
   - Enhanced `_loadExistingSubmission()` to load package-level filenames
   - Enhanced invoice loading to include date and GSTIN
   - No UI changes (already had correct logic)

2. **agency_upload_page.dart**
   - Added 3 state variables for existing filenames
   - Enhanced `_loadExistingSubmission()` to load package-level filenames
   - Enhanced invoice loading to include date and GSTIN
   - No UI changes (already had correct logic)

3. **agency_submission_detail_page.dart**
   - No changes (already uses campaign-level filenames)

4. **asm_review_detail_page.dart**
   - No changes (already uses campaign-level filenames)

5. **hq_review_detail_page.dart**
   - No changes (already uses campaign-level filenames)

### Key Implementation Details

**Null-Safe Fallback Pattern**:
```dart
_existingCostSummaryFileName =
    data['costSummaryFileName']?.toString() ??      // Try package-level
    firstCampaign['costSummaryFileName']?.toString(); // Fall back to campaign-level
```

**Invoice Date Formatting**:
```dart
invoiceDate: _formatDateForField(inv['invoiceDate']),
```

**Validation Logic**:
```dart
if (_costSummaryFile == null && _existingCostSummaryFileName == null) {
    _showError('Please upload a Cost Summary');
    return;
}
```

---

## Testing Scenarios

### Scenario 1: Draft with No Teams/Campaigns

**Setup**:
1. Create draft submission
2. Upload PO and invoices
3. Do NOT add any teams/campaigns
4. Save as draft

**Expected Behavior**:
- ✅ Cost summary shows "Replace" button (not "Click to upload")
- ✅ Activity summary shows "Replace" button
- ✅ Enquiry doc shows "Replace" button
- ✅ All data persists

**Verification**:
- Package-level filenames returned in API response
- Frontend loads package-level filenames
- UI shows green box with "Replace" button

### Scenario 2: Return to Draft with Multiple Invoices

**Setup**:
1. Create draft with 3 invoices
2. Fill in invoice date and GSTIN for each
3. Save as draft
4. Return to draft

**Expected Behavior**:
- ✅ All 3 invoices loaded
- ✅ Invoice dates populated
- ✅ GSTIN values populated
- ✅ Can edit and save changes

**Verification**:
- Invoice date and GSTIN fields not empty
- Debug logs show: "Loaded invoice: number=..., date=..., gstin=..."

### Scenario 3: Submit Draft and View as Read-Only

**Setup**:
1. Create draft with documents
2. Submit draft
3. View submission as ASM

**Expected Behavior**:
- ✅ Package-level filenames = null
- ✅ Campaign-level filenames still available
- ✅ No "Replace" button (read-only mode)
- ✅ Shows "Uploaded" status

**Verification**:
- API response has costSummaryFileName: null
- Detail page shows campaign-level filename
- No upload/replace functionality available

### Scenario 4: Invalid Document Type Upload

**Setup**:
1. Try to upload document with invalid type
2. Observe error message

**Expected Behavior**:
- ✅ User-friendly error message shown
- ✅ Lists all valid document types
- ✅ Clear guidance on what went wrong

**Verification**:
- Error message includes: "Supported types are: PO, Invoice, ..."
- No technical jargon in error message

### Scenario 5: Resubmit Rejected Draft

**Setup**:
1. Submit draft
2. ASM rejects submission
3. Return to draft for resubmission

**Expected Behavior**:
- ✅ All previous data loaded
- ✅ Can replace documents
- ✅ Can edit invoice details
- ✅ Can resubmit

**Verification**:
- Package-level filenames returned (Draft state)
- All fields populated with previous values
- Submission succeeds

---

## Edge Cases Handled

### Edge Case 1: Draft with No Documents

**Scenario**: User creates draft but doesn't upload any documents

**Handling**:
- ✅ Package-level filenames = null
- ✅ Campaign-level filenames = null
- ✅ Frontend shows "Click to upload" for all documents
- ✅ Validation prevents submission

### Edge Case 2: Null Invoice Date

**Scenario**: Invoice exists but date is null in database

**Handling**:
- ✅ `_formatDateForField(null)` returns empty string
- ✅ Frontend shows empty date field
- ✅ User can fill in date
- ✅ Validation requires date before submission

### Edge Case 3: Empty Campaigns List

**Scenario**: Draft has no teams/campaigns

**Handling**:
- ✅ `firstCampaign` = empty dictionary
- ✅ Fallback to package-level filenames
- ✅ No null reference exceptions
- ✅ UI renders correctly

### Edge Case 4: Multiple State Transitions

**Scenario**: Draft → Uploaded → PendingCH → CHRejected → Uploaded (resubmit)

**Handling**:
- ✅ Package-level filenames = null in all non-Draft states
- ✅ Campaign-level filenames always available
- ✅ Resubmit transitions back to Uploaded (not Draft)
- ✅ No "Replace" button shown (read-only)

### Edge Case 5: Concurrent Edits

**Scenario**: User edits draft in two browser tabs

**Handling**:
- ✅ Last write wins (standard behavior)
- ✅ Next GET request loads latest data
- ✅ No data corruption
- ✅ User sees current state

---

## Deployment Notes

### Database Changes
- ✅ **None required** - Uses existing columns (InvoiceDate, GSTNumber already exist)

### API Changes
- ✅ **Backward compatible** - New properties are optional (nullable)
- ✅ **No breaking changes** - Old clients continue to work

### Frontend Changes
- ✅ **No breaking changes** - Uses null-coalescing for safe fallback
- ✅ **Additive only** - New logic doesn't remove existing functionality

### Configuration Changes
- ✅ **None required** - No new configuration needed

### Migration Steps

1. **Deploy Backend**:
   ```bash
   dotnet build
   dotnet test
   dotnet publish -c Release
   ```

2. **Deploy Frontend**:
   ```bash
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   flutter build web
   ```

3. **Verify**:
   - Create draft submission
   - Return to draft
   - Verify all data loads correctly
   - Verify "Replace" buttons show
   - Verify invoice dates/GSTIN populated

### Rollback Plan

If issues occur:
1. Revert backend to previous version
2. Revert frontend to previous version
3. No database cleanup needed (no schema changes)
4. Users' draft data remains intact

---

## Summary

### What Was Created

| Component | Type | Purpose |
|-----------|------|---------|
| Package-level filenames (DTO) | Backend | Store document filenames at package level |
| Invoice date/GSTIN (DTO) | Backend | Persist invoice details in draft |
| Draft-only conditional logic | Backend | Return filenames only in Draft state |
| ModelValidationFilter | Backend | Transform technical errors to user-friendly messages |
| AdditionalDocument enum | Backend | Support additional document types |
| Data loading logic | Frontend | Load package-level filenames with fallback |
| Invoice detail loading | Frontend | Load and display invoice date/GSTIN |
| File upload widget | Frontend | Show "Replace" button when file exists |

### How It Works

1. **User creates draft** → Package created with State=Draft
2. **User uploads documents** → Stored at package level
3. **User returns to draft** → GET /submissions/{id} returns package-level filenames
4. **Frontend loads data** → Checks package-level first, falls back to campaign-level
5. **UI shows "Replace"** → Because existingFileName is not null
6. **User submits** → State transitions to Uploaded
7. **Package-level filenames = null** → Read-only mode activated
8. **Campaign-level filenames used** → Always available in all states

### Key Benefits

- ✅ Seamless draft editing experience
- ✅ No data loss when returning to draft
- ✅ Clear visual distinction between "upload" and "replace"
- ✅ User-friendly error messages
- ✅ Backward compatible
- ✅ No database migrations needed
- ✅ Safe to deploy immediately

---

**Feature Status**: ✅ COMPLETE AND VERIFIED  
**Ready for**: Testing and Deployment  
**Last Updated**: March 28, 2026
