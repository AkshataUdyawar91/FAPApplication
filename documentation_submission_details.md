# Submission Details Documentation

This document describes the submission detail pages — what sections are shown, how they work, which API serves the data, and how every field maps to the database.

---

## UI Sections Overview

There are three detail pages that consume the same API:

1. Agency Submission Detail Page (`agency_submission_detail_page.dart`) — for Agency users viewing their own submissions
2. ASM Review Detail Page (`asm_review_detail_page.dart`) — for Circle Head / ASM users reviewing submissions for approval
3. HQ/RA Review Detail Page (`hq_review_detail_page.dart`) — for RA (Regional Authority) users performing final approval

All three pages call `GET /api/submissions/{id}` and render the same core sections with role-specific differences.

### Page Layout Structure

On desktop/tablet, all three pages use a split layout:
- Full-width header area (top): Header, Rejection Card, PO Section
- Below that, a side-by-side Row:
  - Left (3/4 width): Invoice Summary, AI Recommendation, Validation Summary, Photo Gallery
  - Right (1/4 width): Approval Flow timeline (sticky sidebar)

On mobile, everything stacks vertically in a single column with the Approval Flow at the very bottom.

### Section Layout (top to bottom)

| # | Section | Agency Page | ASM Page | RA Page | Position | Description |
|---|---|---|---|---|---|---|
| 1 | Header / Title Bar | ✅ | ✅ | ✅ | Full width | Submission ID, invoice number, agency name, date, status badge |
| 2 | Rejection Card | ✅ (conditional) | — | — | Full width | Red card shown when state is `CHRejected` or `RARejected` with rejection reason and "Edit Submission" button |
| 3 | Processing Failed Card | ✅ (conditional) | — | — | Full width | Yellow warning card shown when submission processing has failed, with "Edit & Resubmit" button. **NOTE: There is no `ProcessingFailed` value in the `PackageState` enum — this state is checked client-side and may rely on a custom/legacy mapping.** |
| 4 | PO Section | ✅ | — | — | Full width | Expandable card showing PO document with extracted fields and download button |
| 5 | Invoice Summary | ✅ | ✅ | ✅ | Left (3/4) | Card with 3 key metrics: Invoice Amount, Agency Name, Submitted Date |
| 6 | ASM Review Card | — | — | ✅ | Left (3/4) | Shows ASM review date and notes (only if ASM has already reviewed) |
| 7 | AI Recommendation | — | ✅ | ✅ | Left (3/4) | Collapsible card showing AI pass percentage, approve/reject recommendation |
| 8 | Approve/Reject Actions | — | ✅ | ✅ | Left (3/4) | Approve and Reject buttons with optional comments field |
| 9 | PO Balance | — | ✅ | ✅ | Left (3/4) | Shows remaining PO balance fetched from separate API |
| 10 | Invoice Documents Table | — | — | ✅ | Left (3/4) | Table of PO documents with validation status and remarks |
| 11 | Validation Summary | ✅ | ✅ | ✅ | Left (3/4) | Card containing per-document validation tables |
| 12 | Photo Gallery | ✅ | ✅ | ✅ | Left (3/4) | Thumbnail grid of team photos with color-coded borders |
| 13 | Approval Flow | ✅ | ✅ | ✅ | Right (1/4) | Timeline showing Submitted → CH Review → RA Review with dates, comments, and full history |

---

## Section Details

### 1. Header Section

Displays the submission identity and status at the top of the page.

Agency page fields:
- FAP number: `FAP-{submissionId first 8 chars}` (derived client-side)
- Status badge: mapped from `state` field with color coding
- Back navigation button

ASM page fields:
- Title: `{invoiceNumber} - {agencyName}` (parsed from `documents[].extractedData` for invoice number, `agencyName` from response)
- Request number: `submissionNumber` field (format `CIQ-YYYY-XXXXX`), fallback to `REQ-{id first 8 chars}`
- Submitted date: `createdAt` formatted as `DD MMM YYYY`
- Approve/Reject buttons (only when submission is in an actionable state like `PendingCH` or `PendingRA`)
- Comments text field for reviewer notes

Data sources: `submission.state`, `submission.submissionNumber`, `submission.createdAt`, `submission.documents[type=Invoice].extractedData.InvoiceNumber`, `submission.agencyName`

### 2. Rejection Card (Agency only, conditional)

Shown when `state` is `CHRejected` or `RARejected` (also matches legacy aliases `RejectedByASM`, `RejectedByHQ`, `RejectedByRA`). Displays:
- Who rejected: "Rejected by CH" or "Rejected by RA"
- Rejection reason: `asmReviewNotes` (for CH rejection) or `hqReviewNotes` (for RA rejection)
- "Edit Submission" button that navigates to the upload/edit page

Data sources: `submission.state`, `submission.asmReviewNotes`, `submission.hqReviewNotes`

### 3. Processing Failed Card (Agency only, conditional)

Shown when `state` is `ProcessingFailed`. Yellow warning card with "Edit & Resubmit" button.

**NOTE: `ProcessingFailed` is not a value in the current `PackageState` enum (`Draft`, `Uploaded`, `Extracting`, `Validating`, `PendingCH`, `CHRejected`, `PendingRA`, `RARejected`, `Approved`). This state check may rely on a client-side mapping or a legacy/planned enum value.**

Data source: `submission.state`

### 4. PO Section (Agency only)

Expandable card listing PO documents from the `documents[]` array where `type == "PO"`.

For each PO document:
- Filename with download button
- All extracted fields from `extractedData` JSON displayed as label-value pairs (auto-formatted from camelCase/PascalCase keys)
- Excludes internal fields: `LineItems`, `FieldConfidences`, `IsFlaggedForReview`

Data sources: `submission.documents[]` filtered by `type == "PO"` → `filename`, `extractedData` (parsed JSON), `id` (for download)

### 5. Invoice Summary Section

Shared widget (`InvoiceSummarySection`) showing 3 key metrics in a horizontal card:

| Metric | Source | How It's Derived |
|---|---|---|
| Invoice Amount | `campaigns[0].invoices[0].totalAmount` | First non-zero invoice amount from campaigns. Fallback: parse from `documents[type=Invoice].extractedData.TotalAmount`. Formatted as `₹{amount}` |
| Agency | `submission.agencyName` | Agency name from the API response |
| Submitted on | `submission.createdAt` | Formatted as `DD MMM YYYY` |

Responsive: horizontal layout on desktop, vertical stack on mobile.

### 6. ASM Review Card (RA page only)

Shown only on the HQ/RA review page when the ASM has already reviewed the submission (`asmReviewedAt != null`). Displays:
- Green check icon with "ASM Review" title
- Review date: `asmReviewedAt` formatted as `DD MMM YYYY HH:mm`
- ASM notes: `asmReviewNotes` (if provided)

This gives the RA reviewer context on what the ASM decided before they make their own decision.

Data sources: `submission.asmReviewedAt`, `submission.asmReviewNotes`

### 7. AI Recommendation Section (ASM and RA)

Collapsible card (`AiAnalysisSection`) showing AI analysis results. Only renders if `confidenceScore` or `recommendation` exists in the response. Present on both ASM and RA pages.

How it works:
1. Computes an overall pass percentage by iterating all `validationDetailsJson` across invoice, cost summary, activity, enquiry, and photo validations
2. Counts total rules and passed rules from `proactiveRules[]` or `rules[]` arrays in each `validationDetailsJson`
3. If pass rate ≥ 95% → "Recommended for Approval" (green)
4. If pass rate < 95% → "Recommended for Rejection" (red)

Data sources: `submission.confidenceScore`, `submission.recommendation`, all `*Validation.validationDetailsJson` fields

### 7. Approve/Reject Actions (ASM and RA)

Shown only when the submission is in an actionable state. Contains:
- "Reject" outlined button → opens reject dialog for reason input
- "Approve Request" elevated button → calls approve API
- Comments text field (optional)

**Actionable state logic per role:**
- ASM page (`_isSubmissionActionable`): state is `PendingCH`, `PendingApproval`, `PendingCHApproval`, or `RARejected`
- RA page (`_isSubmissionActionable`): state is `PendingRA` or `PendingHQApproval`

When CH has rejected a submission (state = `CHRejected`), the RA page does NOT show action buttons. The RA can only act once the agency resubmits and the submission flows back through processing to `PendingRA`.

ASM actions call `PATCH /api/submissions/{id}/asm-approve` or `PATCH /api/submissions/{id}/asm-reject`.
RA actions call `PATCH /api/submissions/{id}/hq-approve` or `PATCH /api/submissions/{id}/hq-reject`.

### 8. PO Balance Section (ASM only)

Fetches and displays the remaining PO balance from a separate API call. Shows:
- Available balance amount with currency
- Loading spinner while fetching
- Error message if fetch fails

### 10. Invoice Documents Table (RA page only)

Table widget (`InvoiceDocumentsTable`) showing PO documents with validation status. Only shown on the HQ/RA review page. Each row shows:
- Serial number
- Document category (PO)
- Filename (clickable to download)
- Validation status (OK / Failed)
- Remarks (parsed from `validationResult.failureReason` by keyword matching)

Data sources: `submission.documents[]` filtered by `type == "PO"`, `submission.validationResult.failureReason`

### 11. Validation Summary Section

The largest section.

Sub-sections rendered in order:
1. Invoice Validations (one card per invoice)
2. Cost Summary Validation
3. Activity Validation
4. Enquiry Validation (view/download only, no validation table)
5. Photo Validations

Each validation card shows:
- Document title and filename
- View/Download buttons (calls `GET /api/documents/{id}/view`)
- Pass/Fail badge with count
- Validation table with 3 columns: "What Was Checked" | "Result" (✅/❌/⚠️) | "What Was Found"

How validation data is parsed:
1. Read `validationDetailsJson` string from the API response
2. Parse as JSON
3. Extract `proactiveRules[]` array (or `rules[]` fallback)
4. Each rule has: `label` (What Was Checked), `passed`/`isWarning` (Result icon), `extractedValue` + `message` (What Was Found)

For photos: only the aggregate validation (where `documentId == packageId`) is shown, not per-photo entries.

If no validation data exists for any document type, shows "No validation data available for this submission".

Data sources: `submission.invoiceValidations[]`, `submission.costSummaryValidation`, `submission.activityValidation`, `submission.enquiryValidation`, `submission.photoValidations[]` — each containing `validationDetailsJson`

### 12. Photo Thumbnail Gallery

Grid of photo thumbnails collected from all campaigns. Each photo has a color-coded border:
- Green border: all validation rules passed
- Red border: validation failed (`allPassed == false` or `failureReason` is non-empty)
- Yellow border: has warning rules (parsed from `validationDetailsJson.proactiveRules` where `isWarning == true`)
- Grey border: pending (no validation data, or submission still processing)

Photos are sorted: failed first → warning → pending → passed.

Clicking a photo opens a preview via `GET /api/documents/{id}/view`.

How photos are collected:
1. Iterate `submission.campaigns[].photos[]`
2. For each photo, look up its validation from `photoValidations[]` by matching `documentId`
3. If no per-photo validation exists, check for aggregate validation (where `documentId == packageId`)
4. If submission state is `Draft`/`Uploaded`/`Extracting`/`Validating`, all photos show as pending (grey)

Data sources: `submission.campaigns[].photos[]` (id, fileName), `submission.photoValidations[]` (documentId, allPassed, failureReason, validationDetailsJson)

### 13. Approval Flow (Right Sidebar — 1/4 width)

A card pinned to the right side of the page on desktop/tablet (stacks at the bottom on mobile). Shows the full approval lifecycle as a vertical timeline.

The timeline has 3 fixed steps:

| Step | Icon | Title (varies by state) | Date Source | Comment Source |
|---|---|---|---|---|
| 1. Submitted | Upload icon (blue) | "Submitted" | `submission.createdAt` | — |
| 2. CH Review | Check/Cancel/Clock | "Approved by CH" / "Rejected by CH" / "Pending CH Review" | `submission.asmReviewedAt` | `submission.asmReviewNotes` |
| 3. RA Review | Check/Cancel/Clock | "Approved by RA" / "Rejected by RA" / "Pending RA Review" | `submission.hqReviewedAt` | `submission.hqReviewNotes` |

Step status is derived from `submission.state`:
- CH approved: state is `PendingRA`, `RARejected`, or `Approved`
- CH rejected: state is `CHRejected`
- RA approved: state is `Approved`
- RA rejected: state is `RARejected`

**State string matching**: The backend returns `PackageState` enum names (`CHRejected`, `RARejected`, `PendingRA`, etc.). The frontend normalizes to lowercase and matches against both the enum names and legacy aliases:
- CH rejected: `chrejected` or `rejectedbyasm`
- CH approved: `approved`, `pendingra`, `rarejected`, `pendinghq`, `rejectedbyhq`
- RA rejected: `rarejected` or `rejectedbyhq`
- RA approved: `approved`

Each step shows:
- Colored circle icon (green=approved, red=rejected, grey=pending)
- Title text
- Date (formatted as `DD MMM YYYY HH:mm`)
- Comment bubble (if reviewer left comments/rejection reason)

Below the timeline, if `approvalHistory[]` is populated in the API response, a "History" section renders the full chronological list of all approval actions with:
- Action icon (green check for approved, red X for rejected, grey info for others)
- "{Action} by {ApproverName}" text
- Date
- Comment bubble (if comments exist)

Data sources: `submission.state`, `submission.createdAt`, `submission.asmReviewedAt`, `submission.asmReviewNotes`, `submission.hqReviewedAt`, `submission.hqReviewNotes`, `submission.approvalHistory[]`

---

## Data Flow Summary

```
User opens detail page
    │
    ├─ GET /api/submissions/{id}  ──→  SubmissionDetailResponse
    │       │
    │       ├─ SubmissionDataTransformer.extractInvoiceSummary()  ──→  InvoiceSummaryData
    │       │       reads: campaigns[].invoices[].totalAmount, agencyName, createdAt
    │       │
    │       ├─ SubmissionDataTransformer.transformToCampaignDetails()  ──→  CampaignDetailRow[]
    │       │       reads: campaigns[] (invoices, costSummary, activitySummary, photos)
    │       │
    │       ├─ Extract validation data from response fields
    │       │       invoiceValidations[], costSummaryValidation, activityValidation,
    │       │       enquiryValidation, photoValidations[]
    │       │
    │       ├─ Extract blob URLs from campaigns[0]
    │       │       costSummaryBlobUrl, activitySummaryBlobUrl, enquiryBlobUrl
    │       │
    │       └─ Extract approval history from response
    │               approvalHistory[], asmReviewedAt, asmReviewNotes,
    │               hqReviewedAt, hqReviewNotes
    │
    ├─ (ASM only) Fetch PO balance from separate endpoint
    │
    └─ Render layout
            │
            ├─ Full-width header area (top)
            │       Header, Rejection Card, PO Section
            │
            └─ Side-by-side Row (desktop/tablet)
                    ├─ Left 3/4: Invoice Summary, AI, Validations, Photos
                    └─ Right 1/4: Approval Flow timeline
```

---

## API Endpoint

`GET /api/submissions/{id}`

Controller: `SubmissionsController.GetSubmission()`

Authorization: JWT required. Role-based filtering:
- Agency: can only see submissions belonging to their agency (`package.AgencyId == user.AgencyId`)
- ASM/Circle Head: can only see submissions where `ActivityState` matches their assigned states
- RA: can only see submissions where `ActivityState` matches their RA-assigned states AND `State` is one of `PendingRA`, `RARejected`, `Approved` (CHRejected submissions are not visible to RA — they must be resubmitted by Agency first)
- HQ/Admin: can see all submissions

Response DTO: `SubmissionDetailResponse`

### EF Core Query (Eager Loading)

```csharp
_context.DocumentPackages
    .Include(p => p.PO)
    .Include(p => p.Invoices)
    .Include(p => p.ConfidenceScore)
    .Include(p => p.Recommendation)
    .Include(p => p.SubmittedBy)
    .Include(p => p.Teams).ThenInclude(c => c.Photos)
    .Include(p => p.CostSummary)
    .Include(p => p.ActivitySummary)
    .Include(p => p.EnquiryDocument)
    .Include(p => p.RequestApprovalHistory).ThenInclude(h => h.Approver)
    .AsSplitQuery()
```

Validation results are loaded separately per document type via individual queries against `ValidationResults` table.

---

## Database Entity Relationships

```
DocumentPackage (root)
├── PO                          (one-to-one via SelectedPOId)
├── Invoices[]                  (one-to-many via PackageId)
├── CostSummary                 (one-to-one via PackageId)
├── ActivitySummary             (one-to-one via PackageId)
├── EnquiryDocument             (one-to-one via PackageId)
├── Teams[]                     (one-to-many via PackageId)
│   └── TeamPhotos[]            (one-to-many via TeamId)
├── ConfidenceScore             (one-to-one via PackageId)
├── Recommendation              (one-to-one via PackageId)
├── RequestApprovalHistory[]    (one-to-many via PackageId)
├── RequestComments[]           (one-to-many via PackageId)
└── ValidationResults[]         (one per document, via DocumentId)
```

All entities inherit from `BaseEntity`:

| Column | Type | Description |
|---|---|---|
| `Id` | `Guid` | Primary key |
| `CreatedAt` | `DateTime` | Record creation timestamp |
| `UpdatedAt` | `DateTime?` | Last update timestamp |
| `CreatedBy` | `string?` | User who created the record |
| `UpdatedBy` | `string?` | User who last updated |
| `IsDeleted` | `bool` | Soft delete flag (global query filter) |

---

## 1. Core Submission Fields

API response root → DB table `DocumentPackages`

| API Field (JSON) | Type | DB Entity | DB Column | Notes |
|---|---|---|---|---|
| `id` | `Guid` | `DocumentPackage` | `Id` | Primary key |
| `state` | `string` | `DocumentPackage` | `State` | Enum `PackageState` → `.ToString()`. Values: `Draft`, `Uploaded`, `Extracting`, `Validating`, `PendingCH`, `CHRejected`, `PendingRA`, `RARejected`, `Approved` |
| `createdAt` | `DateTime` | `DocumentPackage` | `CreatedAt` | UTC |
| `updatedAt` | `DateTime?` | `DocumentPackage` | `UpdatedAt` | UTC |
| `submissionNumber` | `string?` | `DocumentPackage` | `SubmissionNumber` | Format: `CIQ-YYYY-XXXXX`. Generated at submit time |
| `activityState` | `string?` | `DocumentPackage` | `ActivityState` | State/region where activity was conducted (e.g., "Maharashtra") |
| `selectedPOId` | `Guid?` | `DocumentPackage` | `SelectedPOId` | FK to `POs` table, set during chatbot PO selection |
| `currentStep` | `int` | `DocumentPackage` | `CurrentStep` | Conversational flow step (0-10) |
| `versionNumber` | `int` | `DocumentPackage` | `VersionNumber` | Starts at 1, increments on resubmission |
| `agencyId` | `Guid?` | `DocumentPackage` | `AgencyId` | FK to `Agencies` table. **NOTE: Not currently set in the response mapping — always `null` in API output. The `Agency` navigation property is not `.Include()`d in the query.** |
| `agencyName` | `string?` | — | — | **NOTE: Not currently set in the response mapping — always `null` in API output. The `Agency` navigation property is not `.Include()`d in the query, so `Agency.Name` cannot be resolved.** |
| `assignedCircleHeadUserId` | `Guid?` | `DocumentPackage` | `AssignedCircleHeadUserId` | Auto-assigned at submit time via StateMapping |

---

## 2. Review & Approval Fields

API response root → DB table `RequestApprovalHistory`

These fields are derived from the `RequestApprovalHistory` collection, not stored directly on `DocumentPackage`:

| API Field (JSON) | Type | Source | How It's Derived |
|---|---|---|---|
| `asmReviewedAt` | `DateTime?` | `RequestApprovalHistory` | Latest entry where `ApproverRole == ASM`, ordered by `ActionDate` desc → `ActionDate` |
| `asmReviewNotes` | `string?` | `RequestApprovalHistory` | Same entry → `Comments` |
| `hqReviewedAt` | `DateTime?` | `RequestApprovalHistory` | Latest entry where `ApproverRole == RA`, ordered by `ActionDate` desc → `ActionDate` |
| `hqReviewNotes` | `string?` | `RequestApprovalHistory` | Same entry → `Comments` |
| `reviewedAt` | `DateTime?` | `RequestApprovalHistory` | Legacy alias for `asmReviewedAt` |
| `reviewNotes` | `string?` | `RequestApprovalHistory` | Legacy alias for `asmReviewNotes` |

### `RequestApprovalHistory` Entity → DB Table `RequestApprovalHistory`

| DB Column | Type | Description |
|---|---|---|
| `PackageId` | `Guid` | FK to `DocumentPackages` |
| `ApproverId` | `Guid` | FK to `Users` |
| `ApproverRole` | `enum UserRole` | `Agency`, `ASM`, `RA`, `Admin` |
| `Action` | `enum ApprovalAction` | `Submitted`, `Approved`, `Rejected`, `Resubmitted` |
| `Comments` | `string?` | Reviewer comments |
| `ActionDate` | `DateTime` | When the action was taken |
| `VersionNumber` | `int` | Package version at time of action |
| `Channel` | `string?` | `"Portal"`, `"TeamsBot"`, or null |

### `approvalHistory[]` Array in Response

| API Field | DB Column |
|---|---|
| `id` | `Id` |
| `approverName` | `Approver.FullName` (via navigation) |
| `approverRole` | `ApproverRole.ToString()` |
| `action` | `Action.ToString()` |
| `comments` | `Comments` |
| `actionDate` | `ActionDate` |
| `versionNumber` | `VersionNumber` |

---

## 3. Documents Array

API field: `documents[]` → Built by `BuildDocumentDtos()`

This flat array contains PO and Invoice documents only. Cost Summary, Activity Summary, Enquiry, and Photos are in the `campaigns[]` array.

### PO Document

| API Field | DB Entity | DB Column |
|---|---|---|
| `id` | `PO` | `Id` |
| `type` | — | Hardcoded `"PO"` |
| `filename` | `PO` | `FileName` |
| `blobUrl` | `PO` | `BlobUrl` |
| `extractionConfidence` | `PO` | `ExtractionConfidence` |
| `extractedData` | `PO` | `ExtractedDataJson` |

### PO Entity → DB Table `POs`

| DB Column | Type | Description |
|---|---|---|
| `PackageId` | `Guid?` | FK to `DocumentPackages`. Null for unassigned master POs |
| `AgencyId` | `Guid` | FK to `Agencies` |
| `PONumber` | `string?` | Extracted PO number |
| `PODate` | `DateTime?` | Extracted PO date |
| `VendorName` | `string?` | Extracted vendor name |
| `TotalAmount` | `decimal?` | Extracted total amount |
| `RemainingBalance` | `decimal?` | Available balance (from SAP or computed) |
| `POStatus` | `string?` | `Open`, `PartiallyConsumed`, `Closed` |
| `VendorCode` | `string?` | Agency vendor code from SAP |
| `RefreshedAt` | `DateTime?` | When balance was last refreshed from SAP |
| `FileName` | `string` | Original uploaded filename |
| `BlobUrl` | `string` | Azure Blob Storage URL |
| `FileSizeBytes` | `long` | File size in bytes |
| `ContentType` | `string` | MIME content type |
| `ExtractedDataJson` | `string?` | Full AI-extracted data as JSON |
| `ExtractionConfidence` | `double?` | AI confidence score (0.0–1.0) |
| `IsFlaggedForReview` | `bool` | Flagged for manual review |
| `VersionNumber` | `int` | Matches parent package version |

### Invoice Document

| API Field | DB Entity | DB Column |
|---|---|---|
| `id` | `Invoice` | `Id` |
| `type` | — | Hardcoded `"Invoice"` |
| `filename` | `Invoice` | `FileName` |
| `blobUrl` | `Invoice` | `BlobUrl` |
| `extractionConfidence` | `Invoice` | `ExtractionConfidence` |
| `extractedData` | `Invoice` | `ExtractedDataJson` |

### Invoice Entity → DB Table `Invoices`

| DB Column | Type | Description |
|---|---|---|
| `PackageId` | `Guid` | FK to `DocumentPackages` |
| `POId` | `Guid` | FK to `POs` |
| `InvoiceNumber` | `string?` | Extracted invoice number |
| `InvoiceDate` | `DateTime?` | Extracted invoice date |
| `VendorName` | `string?` | Vendor/supplier name |
| `GSTNumber` | `string?` | GST identification number |
| `SubTotal` | `decimal?` | Amount before tax |
| `TaxAmount` | `decimal?` | Tax amount |
| `TotalAmount` | `decimal?` | Total invoice amount |
| `FileName` | `string` | Original uploaded filename |
| `BlobUrl` | `string` | Azure Blob Storage URL |
| `FileSizeBytes` | `long` | File size in bytes |
| `ContentType` | `string` | MIME content type |
| `ExtractedDataJson` | `string?` | Full AI-extracted data as JSON |
| `ExtractionConfidence` | `double?` | AI confidence score (0.0–1.0) |
| `IsFlaggedForReview` | `bool` | Flagged for manual review |
| `VersionNumber` | `int` | Matches parent package version |

---

## 4. Campaigns Array (Teams + Nested Documents)

API field: `campaigns[]` → Mapped from `DocumentPackage.Teams` collection

Each campaign represents a Team. Cost Summary, Activity Summary, and Invoices are attached at the package level but surfaced through the campaigns array for UI convenience.

| API Field | DB Entity | DB Column | Notes |
|---|---|---|---|
| `id` | `Teams` | `Id` | |
| `campaignName` | `Teams` | `CampaignName` | Team/campaign name |
| `teamCode` | `Teams` | `TeamCode` | Team identifier |
| `startDate` | `Teams` | `StartDate` | Campaign start date |
| `endDate` | `Teams` | `EndDate` | Campaign end date |
| `workingDays` | `Teams` | `WorkingDays` | Number of working days |
| `dealershipName` | `Teams` | `DealershipName` | Dealer where activity took place |
| `dealershipAddress` | `Teams` | `DealershipAddress` | Full dealer address |
| `totalCost` | `CostSummary` | `TotalCost` | Package-level cost summary total (same for all campaigns) |
| `costSummaryFileName` | `CostSummary` | `FileName` | |
| `costSummaryBlobUrl` | `CostSummary` | `BlobUrl` | |
| `activitySummaryFileName` | `ActivitySummary` | `FileName` | |
| `activitySummaryBlobUrl` | `ActivitySummary` | `BlobUrl` | |
| `invoices[]` | `Invoice` | — | Only included in the first campaign (index 0). Contains all package-level invoices |
| `photos[]` | `TeamPhotos` | — | Filtered by `!IsDeleted`, ordered by `DisplayOrder` |

### Teams Entity → DB Table `Teams`

| DB Column | Type | Description |
|---|---|---|
| `PackageId` | `Guid` | FK to `DocumentPackages` |
| `CampaignName` | `string?` | Team/campaign name |
| `TeamCode` | `string?` | Team identifier code |
| `TeamNumber` | `int?` | Sequential number within package (1, 2, 3...) |
| `StartDate` | `DateTime?` | Campaign start date |
| `EndDate` | `DateTime?` | Campaign end date |
| `WorkingDays` | `int?` | Number of working days |
| `DealershipName` | `string?` | Dealer name |
| `DealershipAddress` | `string?` | Dealer address |
| `GPSLocation` | `string?` | GPS coordinates |
| `State` | `string?` | State/region |
| `VersionNumber` | `int` | Matches parent package version |

### Campaign Invoice DTO

| API Field | DB Entity | DB Column |
|---|---|---|
| `id` | `Invoice` | `Id` |
| `invoiceNumber` | `Invoice` | `InvoiceNumber` |
| `vendorName` | `Invoice` | `VendorName` |
| `totalAmount` | `Invoice` | `TotalAmount` |
| `fileName` | `Invoice` | `FileName` |
| `blobUrl` | `Invoice` | `BlobUrl` |

### Campaign Photo DTO

| API Field | DB Entity | DB Column |
|---|---|---|
| `id` | `TeamPhotos` | `Id` |
| `fileName` | `TeamPhotos` | `FileName` |
| `blobUrl` | `TeamPhotos` | `BlobUrl` |
| `caption` | `TeamPhotos` | `Caption` |

### TeamPhotos Entity → DB Table `TeamPhotos`

| DB Column | Type | Description |
|---|---|---|
| `TeamId` | `Guid` | FK to `Teams` |
| `PackageId` | `Guid` | FK to `DocumentPackages` |
| `FileName` | `string` | Original filename |
| `BlobUrl` | `string` | Azure Blob Storage URL |
| `FileSizeBytes` | `long` | File size in bytes |
| `ContentType` | `string` | MIME content type |
| `Caption` | `string?` | Photo caption |
| `PhotoTimestamp` | `DateTime?` | EXIF timestamp |
| `Latitude` | `double?` | EXIF GPS latitude |
| `Longitude` | `double?` | EXIF GPS longitude |
| `DeviceModel` | `string?` | EXIF device model |
| `DateVisible` | `bool?` | AI: date visible in photo |
| `BlueTshirtPresent` | `bool?` | AI: blue t-shirt detected |
| `ThreeWheelerPresent` | `bool?` | AI: 3-wheeler detected |
| `PhotoDateOverlay` | `string?` | Date text from photo overlay |
| `ExtractedMetadataJson` | `string?` | Full extracted metadata JSON |
| `ExtractionConfidence` | `double?` | AI confidence (0–100) |
| `IsFlaggedForReview` | `bool` | Flagged for manual review |
| `DisplayOrder` | `int` | Sort order within team |
| `VersionNumber` | `int` | Matches parent package version |

---

## 5. Cost Summary

Not in `documents[]` array. Accessed via `campaigns[].costSummaryFileName`, `campaigns[].costSummaryBlobUrl`, and `campaigns[].totalCost`.

### CostSummary Entity → DB Table `CostSummaries`

| DB Column | Type | Description |
|---|---|---|
| `PackageId` | `Guid` | FK to `DocumentPackages` (one-to-one) |
| `TotalCost` | `decimal?` | Extracted total cost |
| `PlaceOfSupply` | `string?` | State for GST purposes |
| `NumberOfDays` | `int?` | Total days extracted |
| `NumberOfActivations` | `int?` | Number of activations |
| `NumberOfTeams` | `int?` | Number of teams |
| `ElementWiseCostsJson` | `string?` | JSON array: `[{category, elementName, amount}]` |
| `ElementWiseQuantityJson` | `string?` | JSON array: `[{category, quantity, unit}]` |
| `CostBreakdownJson` | `string?` | Detailed breakdown with `isFixedCost`/`isVariableCost` flags |
| `FileName` | `string` | Original filename |
| `BlobUrl` | `string` | Azure Blob Storage URL |
| `FileSizeBytes` | `long` | File size in bytes |
| `ContentType` | `string` | MIME content type |
| `ExtractedDataJson` | `string?` | Full AI-extracted data JSON |
| `ExtractionConfidence` | `double?` | AI confidence (0.0–1.0) |
| `IsFlaggedForReview` | `bool` | Flagged for manual review |
| `VersionNumber` | `int` | Matches parent package version |

---

## 6. Activity Summary

Not in `documents[]` array. Accessed via `campaigns[].activitySummaryFileName` and `campaigns[].activitySummaryBlobUrl`.

### ActivitySummary Entity → DB Table `ActivitySummaries`

| DB Column | Type | Description |
|---|---|---|
| `PackageId` | `Guid` | FK to `DocumentPackages` (one-to-one) |
| `ActivityDescription` | `string?` | Extracted activity description |
| `DealerName` | `string?` | Extracted dealer name |
| `TotalDays` | `int?` | Total days from Day column |
| `TotalWorkingDays` | `int?` | Total working days from WorkingDay column |
| `FileName` | `string` | Original filename |
| `BlobUrl` | `string` | Azure Blob Storage URL |
| `FileSizeBytes` | `long` | File size in bytes |
| `ContentType` | `string` | MIME content type |
| `ExtractedDataJson` | `string?` | Full AI-extracted data JSON |
| `ExtractionConfidence` | `double?` | AI confidence (0.0–1.0) |
| `IsFlaggedForReview` | `bool` | Flagged for manual review |
| `VersionNumber` | `int` | Matches parent package version |

---

## 7. Enquiry Document

### EnquiryDocument Entity → DB Table `EnquiryDocuments`

| DB Column | Type | Description |
|---|---|---|
| `PackageId` | `Guid` | FK to `DocumentPackages` (one-to-one) |
| `FileName` | `string` | Original filename |
| `BlobUrl` | `string` | Azure Blob Storage URL |
| `FileSizeBytes` | `long` | File size |
| `ContentType` | `string` | MIME type |
| `ExtractedDataJson` | `string?` | Full AI-extracted data JSON (contains `Records[]` with enquiry rows) |
| `ExtractionConfidence` | `double?` | AI confidence (0.0–1.0) |
| `IsFlaggedForReview` | `bool` | Flagged for manual review |
| `VersionNumber` | `int` | Matches parent package version |

---

## 8. Validation Results

Each document type has its own validation result loaded separately from the `ValidationResults` table.

### How Validations Are Loaded

```
poValidation         → WHERE DocumentType = 'PO'              AND DocumentId = PO.Id
invoiceValidations[] → WHERE DocumentType = 'Invoice'          AND DocumentId = Invoice.Id  (per invoice)
costSummaryValidation→ WHERE DocumentType = 'CostSummary'      AND DocumentId = CostSummary.Id
activityValidation   → WHERE DocumentType = 'ActivitySummary'  AND DocumentId = ActivitySummary.Id
enquiryValidation    → WHERE DocumentType = 'EnquiryDocument'  AND DocumentId = EnquiryDocument.Id
photoValidations[]   → WHERE DocumentType = 'TeamPhoto'        AND DocumentId IN (PackageId, ...all photo IDs)
```

### Two Validation Flows

Validation rules are written by two different flows depending on how the submission was created. Both flows write to the same `ValidationResults` table columns (`RuleResultsJson` and `ValidationDetailsJson`), but they run at different times and with different logic.

**1. Chatbot Flow (Proactive) — `AssistantController` + `ProactiveValidationService`**

- Triggered during the conversational submission flow (chatbot) as documents are uploaded step-by-step.
- Validates each document immediately after upload using `ProactiveValidationService`.
- Writes rules to `RuleResultsJson` as a JSON array of `ValidationRuleResult` objects.
- Writes a structured `ValidationDetailsJson` containing a `proactiveRules[]` array.
- Each rule has: `ruleCode`, `type`, `passed`, `isWarning`, `label`, `extractedValue`, `expectedValue`, `message`.

**2. Web Flow (Reactive) — `ValidationAgent`**

- Triggered by the workflow pipeline after the full submission is created via the web upload page.
- Runs all validations in batch after extraction completes.
- Writes rules to `RuleResultsJson` as a JSON array with the same structure.
- Writes `ValidationDetailsJson` with section-based structure (e.g., `InvoiceFieldPresence`, cross-document checks) plus a `proactiveRules[]` array merged in.
- If proactive rules already exist (from a prior chatbot step), the reactive flow merges them via `MergeProactiveRulesIntoDetails()` — reactive rules take precedence for duplicates since they use live API data.

**Key difference**: The chatbot flow validates incrementally per document; the web flow validates everything at once after submission. Both produce the same rule codes (e.g., `INV_VENDOR_CODE_PRESENT` for Agency Code) so the frontend can parse them identically from `validationDetailsJson.proactiveRules[]`.

**Agency Code example**: Both flows check `INV_VENDOR_CODE_PRESENT` (label: "Agency Code") by reading `VendorCode` from `Invoice.ExtractedDataJson`. This ensures the Agency Code validation appears on the submission details page regardless of which flow created the submission.

### PO / Cost Summary / Activity / Enquiry Validation DTO (`ValidationResultDto`)

| API Field | DB Entity | DB Column | Notes |
|---|---|---|---|
| `documentId` | `ValidationResult` | `DocumentId` | **NOTE: For `poValidation`, `documentId` is NOT set in the response mapping (always `null`). It IS set for `costSummaryValidation`, `activityValidation`, and `enquiryValidation`.** |
| `allValidationsPassed` | `ValidationResult` | `AllValidationsPassed` | |
| `failureReason` | `ValidationResult` | `FailureReason` | |
| `sapVerificationPassed` | `ValidationResult` | `SapVerificationPassed` | |
| `amountConsistencyPassed` | `ValidationResult` | `AmountConsistencyPassed` | |
| `lineItemMatchingPassed` | `ValidationResult` | `LineItemMatchingPassed` | |
| `completenessCheckPassed` | `ValidationResult` | `CompletenessCheckPassed` | |
| `dateValidationPassed` | `ValidationResult` | `DateValidationPassed` | |
| `vendorMatchingPassed` | `ValidationResult` | `VendorMatchingPassed` | |
| `ruleResultsJson` | `ValidationResult` | `RuleResultsJson` | JSON array of validation rule results. Written by both chatbot (proactive) and web (reactive) flows. Contains objects with `ruleCode`, `type`, `passed`, `isWarning`, `label`, `extractedValue`, `expectedValue`, `message`. |
| `validationDetailsJson` | `ValidationResult` | `ValidationDetailsJson` | Structured validation details. Chatbot flow writes `proactiveRules[]` array directly. Web flow writes section-based structure (e.g., `InvoiceFieldPresence`) plus merges `proactiveRules[]` via `MergeProactiveRulesIntoDetails()`. Frontend reads `proactiveRules[]` (or `rules[]` fallback) for the validation table display. |

### Invoice / Photo Validation DTO (`DocumentValidationDto`)

| API Field | DB Entity | DB Column | Notes |
|---|---|---|---|
| `documentType` | — | — | Hardcoded `"Invoice"` or `"TeamPhoto"` |
| `documentId` | `ValidationResult` | `DocumentId` | |
| `fileName` | `Invoice` / parsed from JSON | `FileName` | For photos: parsed from `ValidationDetailsJson.fileName`, fallback `"Team Photos (All)"` |
| `allPassed` | `ValidationResult` | `AllValidationsPassed` | |
| `failureReason` | `ValidationResult` | `FailureReason` | |
| `validatedAt` | `ValidationResult` | `CreatedAt` | |
| `validationDetailsJson` | `ValidationResult` | `ValidationDetailsJson` | |

---

## 9. Confidence Score

API field: `confidenceScore` → DB table `ConfidenceScores`

| API Field | DB Entity | DB Column | Notes |
|---|---|---|---|
| `overallConfidence` | `ConfidenceScore` | `OverallConfidence` | Weighted: PO 30% + Invoice 30% + CostSummary 20% + Activity 10% + Photos 10% |
| `poConfidence` | `ConfidenceScore` | `PoConfidence` | 0–100, weighted 30% |
| `invoiceConfidence` | `ConfidenceScore` | `InvoiceConfidence` | 0–100, weighted 30% |
| `costSummaryConfidence` | `ConfidenceScore` | `CostSummaryConfidence` | 0–100, weighted 20% |
| `activityConfidence` | `ConfidenceScore` | `ActivityConfidence` | 0–100, weighted 10% |
| `photosConfidence` | `ConfidenceScore` | `PhotosConfidence` | 0–100, weighted 10% |

---

## 10. AI Recommendation

API field: `recommendation` → DB table `Recommendations`

| API Field | DB Entity | DB Column | Notes |
|---|---|---|---|
| `type` | `Recommendation` | `Type` | Enum `RecommendationType` → `.ToString()`. Values: `Approve`, `Reject`, `RequestMoreInfo`, `FlagForReview` |
| `evidence` | `Recommendation` | `Evidence` | AI-generated text explaining the recommendation |

Additional DB columns not in the API response:
- `ValidationIssuesJson`: JSON of validation issues found
- `ConfidenceScore`: Recommendation confidence (0–100)

---

## 11. Comments

API field: `comments[]` → DB table `RequestComments`

**NOTE: The `comments[]` field is defined in the `SubmissionDetailResponse` DTO but is NOT currently populated in the `GetSubmission` controller mapping. The `RequestComments` collection is not `.Include()`d in the EF Core query and is never mapped to the response. This field will always be `null` in the API output.**

Expected DTO mapping (when implemented):

| API Field | DB Column |
|---|---|
| `id` | `Id` |
| `userName` | `User.FullName` (via navigation) |
| `userRole` | `UserRole.ToString()` |
| `commentText` | `CommentText` |
| `commentDate` | `CommentDate` |
| `versionNumber` | `VersionNumber` |

---

## Frontend Pages That Consume This API

### Agency Submission Detail Page

File: `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart`

Fetches `GET /api/submissions/{id}` with JWT token. Stores response in `_submission` map. Transforms data via `SubmissionDataTransformer` into:
- `InvoiceSummaryData` — invoice header fields for display
- `List<CampaignDetailRow>` — campaign/team details table

Extracts validation data from nested JSON:
- `_invoiceValidations` from `invoiceValidations[].validationDetailsJson`
- `_photoValidations` from `photoValidations[].validationDetailsJson`
- `_costSummaryValidation` from `costSummaryValidation.validationDetailsJson`
- `_activityValidation` from `activityValidation.validationDetailsJson`
- `_enquiryValidation` from `enquiryValidation.validationDetailsJson`

Blob URLs for Cost Summary, Activity Summary, and Enquiry are extracted from the `campaigns[]` array.

### ASM Review Detail Page

File: `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`

Same API call and data extraction pattern. Additionally:
- Loads PO balance via separate endpoint
- Shows AI analysis section with confidence scores and recommendation
- Provides approve/reject actions with comments

### HQ/RA Review Detail Page

File: `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`

Same API call and data extraction pattern. Additionally:
- Shows ASM Review Card with prior ASM decision and notes
- Shows Invoice Documents Table (PO documents with validation status)
- Loads PO balance via separate endpoint
- Shows AI analysis section
- Provides RA-level approve/reject actions with comments
- Also fetches hierarchical structure via `GET /api/hierarchical/{id}/structure` for campaign photos and document URLs

---

## Additional API Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `GET /api/submissions/{id}` | GET | Full submission detail (documented above) |
| `GET /api/submissions/{id}/validation-report` | GET | Enhanced validation report (ASM/RA only). Uses `IEnhancedValidationReportService` |
| `PATCH /api/submissions/{id}` | PATCH | Update draft submission (state, selectedPOId). Agency only, Draft state only |
| `PATCH /api/submissions/{id}/asm-approve` | PATCH | ASM approves submission. Body: `{ notes }` |
| `PATCH /api/submissions/{id}/asm-reject` | PATCH | ASM rejects submission. Body: `{ Reason }` |
| `PATCH /api/submissions/{id}/ra-approve` | PATCH | RA approves submission. Body: `{ notes }` |
| `PATCH /api/submissions/{id}/ra-reject` | PATCH | RA rejects submission. Body: `{ Reason }` |
| `GET /api/hierarchical/{id}/structure` | GET | Hierarchical campaign structure with photos, cost/activity summary URLs |
| `GET /api/documents/{id}/extraction-status` | GET | Poll AI extraction status |
| `GET /api/documents/{id}/view` | GET | Download/view document file content |
