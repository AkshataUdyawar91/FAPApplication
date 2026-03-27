# Web Create Request Flow Documentation

This document describes the complete "Create New Request" flow from the Agency Upload Page, covering every step, API call, form field, and how data is stored in the database so it appears on the Submission Details page.

---

## Flow Overview

The web upload flow is a 3-step wizard on `AgencyUploadPage`:

```
Step 1: Invoice                    Step 2: Team & Activity Details       Step 3: Enquiry & Supporting Docs
┌─────────────────────────┐       ┌──────────────────────────────┐      ┌──────────────────────────────┐
│ Select PO (dropdown)    │       │ Upload Activity Summary      │      │ Upload Enquiry Document      │
│ Select Activation State │       │ For each Team:               │      │ Upload Additional Docs       │
│ Upload Invoice(s)       │       │   - Dealer Name (dropdown)   │      │                              │
│   → AI extraction       │       │   - City (dropdown)          │      │ [Submit for Validation]      │
│   → Autofill fields     │       │   - Start/End Date           │      └──────────────────────────────┘
│ Upload Cost Summary     │       │   - Working Days             │
│                         │       │   - Team Photos (min 3)      │
│ [Next Step →]           │       │ [Next Step →]                │
└─────────────────────────┘       └──────────────────────────────┘
```

---

## Step-by-Step API Calls and DB Storage

### Step 0: Page Load

| Action | API Call | Purpose |
|---|---|---|
| Load POs | `GET /api/pos` | Fetches open POs for the agency. Filtered by `AgencyId`, status `Open`/`PartiallyConsumed` |
| Load Indian States | `GET /api/state/list` | Fetches all 36 Indian states/UTs for the activation state dropdown |

### Step 1: Invoice (Tab 1)

#### 1a. Select PO from Dropdown

User selects a PO from the dropdown list. No API call — the PO data is already loaded. The selected PO's `id` is stored in `_selectedPO`.

#### 1b. Select Activation State

User searches and selects a state from the dropdown. Stored in `_selectedActivationState`.

#### 1c. Upload Invoice File

| Action | API Call | Method | Request | Response |
|---|---|---|---|---|
| Extract invoice fields | `POST /api/documents/extract` | Multipart | `file` (bytes), `documentType: "Invoice"` | `{ extractedData: { InvoiceNumber, InvoiceDate, TotalAmount, GSTNumber, ... } }` |

This is an extract-only call — no package or document record is created yet. The extracted fields auto-fill the form:

| Form Field | Extracted JSON Key (fallbacks) | Stored In |
|---|---|---|
| Invoice Number | `InvoiceNumber` / `invoiceNumber` | `InvoiceItemData.invoiceNumber` |
| Invoice Date | `InvoiceDate` / `invoiceDate` / `Date` | `InvoiceItemData.invoiceDate` |
| Total Amount | `TotalAmount` / `totalAmount` | `InvoiceItemData.totalAmount` |
| GSTIN | `GSTNumber` / `gstNumber` / `GSTIN` | `InvoiceItemData.gstNumber` |

If extraction fails, the user fills these fields manually.

#### 1d. Upload Cost Summary File

File is stored locally in `_costSummaryFile`. No API call at this step — uploaded during final submit.

#### 1e. Click "Next Step"

Advances to Tab 2. No API call.

---

### Step 2: Team and Activity Details (Tab 2)

#### 2a. Upload Activity Summary File

File stored locally in `_activitySummaryFile`. No API call yet.

#### 2b. Load Dealers for State

| Action | API Call | Method | Request | Response |
|---|---|---|---|---|
| Load dealers | `GET /api/state/dealers?state={state}&q=&size=50` | GET | Query params: `state`, `q` (search), `size` | Array of `{ dealerName, dealerCode, city, state }` |

Dealers are filtered by the selected activation state. Unique dealer names are extracted for the dropdown.

#### 2c. Fill Team Details

For each team (campaign), the user fills:

| Form Field | Data Model Field | DB Column (Teams table) |
|---|---|---|
| Dealer Name | `CampaignItemData.dealershipName` | `Teams.DealershipName` |
| City | `CampaignItemData.dealershipAddress` | `Teams.DealershipAddress` |
| Dealer Code | `CampaignItemData.campaignName` | `Teams.CampaignName` / `Teams.TeamCode` |
| Start Date | `CampaignItemData.startDate` | `Teams.StartDate` |
| End Date | `CampaignItemData.endDate` | `Teams.EndDate` |
| Working Days | `CampaignItemData.workingDays` | `Teams.WorkingDays` |
| Photos (min 3, max 50) | `CampaignItemData.photos` | `TeamPhotos` (one row per photo) |

#### 2d. Click "Next Step"

Advances to Tab 3. No API call.

---

### Step 3: Enquiry and Supporting Docs (Tab 3)

#### 3a. Upload Enquiry Document

File stored locally in `_enquiryDocFile`. No API call yet.

#### 3b. Upload Additional Documents (optional)

Files stored locally in `_additionalDocs`. No API call yet.

---

### Final Submit: "Submit for Validation"

This is where all API calls happen in sequence. The `_handleSubmit()` method orchestrates the entire upload.

#### Validation Before Submit

The frontend validates all required fields before making any API calls:
- PO must be selected or uploaded
- Activation State must be selected
- At least 1 invoice with all fields filled (Invoice Number, Date, Amount, GSTIN)
- Cost Summary file uploaded
- Activity Summary file uploaded
- Enquiry Document uploaded
- Each team must have at least 3 photos

#### API Call Sequence

```
1. POST /api/submissions                              → Creates DocumentPackage
2. POST /api/documents/upload (Invoice)               → Creates Invoice record(s)
3. POST /api/hierarchical/{id}/campaigns              → Creates Teams record(s)
4. POST /api/hierarchical/{id}/campaigns/{cid}/photos → Creates TeamPhotos records
5. POST /api/hierarchical/{id}/campaigns/{cid}/cost-summary    → Creates CostSummary
6. POST /api/hierarchical/{id}/campaigns/{cid}/activity-summary → Creates ActivitySummary
7. POST /api/hierarchical/{id}/enquiry-doc            → Creates EnquiryDocument
8. POST /api/documents/upload (AdditionalDocument)    → Creates AdditionalDocument(s)
9. POST /api/submissions/{id}/process-async           → Queues background workflow
```

---

## Detailed API Call → DB Mapping

### Call 1: Create Submission Package

`POST /api/submissions`

Request body:
```json
{
  "selectedPoId": "guid",
  "activityState": "Maharashtra"
}
```

DB writes to `DocumentPackages`:

| DB Column | Value | Source |
|---|---|---|
| `Id` | New GUID | Auto-generated |
| `SubmittedByUserId` | JWT user ID | Token claim `NameIdentifier` |
| `AgencyId` | User's agency | Looked up from `Users` table |
| `SelectedPOId` | PO GUID | `request.selectedPoId` |
| `ActivityState` | State name | `request.activityState` |
| `State` | `Uploaded` | Default initial state |
| `SubmissionNumber` | `CIQ-YYYY-XXXXX` | Generated by `ISubmissionNumberService` |
| `AssignedCircleHeadUserId` | GUID or null | Auto-assigned via `ICircleHeadAssignmentService` based on `ActivityState` |
| `VersionNumber` | 1 | Default |
| `CurrentStep` | 0 | Default |

Also links the master PO: sets `POs.PackageId = package.Id` for the selected PO.

Response: `{ id: "package-guid", state: "Uploaded" }`

---

### Call 2: Upload Invoice(s)

`POST /api/documents/upload`

Multipart form:
- `file`: Invoice PDF/image bytes
- `documentType`: `"Invoice"`
- `packageId`: Package GUID from Call 1

DB writes to `Invoices`:

| DB Column | Value | Source |
|---|---|---|
| `Id` | New GUID | Auto-generated |
| `PackageId` | Package GUID | From request |
| `POId` | PO GUID | From `DocumentPackage.PO.Id` (via `SelectedPOId`) |
| `FileName` | Original filename | From uploaded file |
| `BlobUrl` | Azure Blob URL | From `IFileStorageService.UploadFileAsync()` |
| `FileSizeBytes` | File size | From uploaded file |
| `ContentType` | MIME type | From uploaded file |
| `ExtractedDataJson` | AI-extracted JSON | Populated by `DocumentService` background extraction |
| `ExtractionConfidence` | 0.0–1.0 | Populated by extraction |
| `InvoiceNumber` | Extracted value | From AI extraction or manual entry |
| `InvoiceDate` | Extracted value | From AI extraction or manual entry |
| `TotalAmount` | Extracted value | From AI extraction or manual entry |
| `GSTNumber` | Extracted value | From AI extraction or manual entry |
| `VendorName` | Extracted value | From AI extraction |
| `VersionNumber` | Package version | Matches `DocumentPackage.VersionNumber` |

---

### Call 3: Create Team (Campaign)

`POST /api/hierarchical/{packageId}/campaigns`

Request body:
```json
{
  "campaignName": "T1",
  "teamCode": "T1",
  "startDate": "2026-01-01T00:00:00Z",
  "endDate": "2026-01-31T00:00:00Z",
  "workingDays": 23,
  "dealershipName": "Bajaj Motors",
  "dealershipAddress": "Mumbai",
  "state": "Maharashtra"
}
```

DB writes to `Teams`:

| DB Column | Value | Source |
|---|---|---|
| `Id` | New GUID | Auto-generated |
| `PackageId` | Package GUID | From URL |
| `CampaignName` | Team name / dealer code | `request.campaignName` |
| `TeamCode` | Team code | `request.teamCode` |
| `TeamNumber` | Sequential (1, 2, 3...) | Auto-assigned based on existing team count |
| `StartDate` | Campaign start | `request.startDate` |
| `EndDate` | Campaign end | `request.endDate` |
| `WorkingDays` | Working days count | `request.workingDays` |
| `DealershipName` | Dealer name | `request.dealershipName` |
| `DealershipAddress` | City / address | `request.dealershipAddress` |
| `State` | Activity state | `request.state` |

Response: `{ campaignId: "team-guid" }`

---

### Call 4: Upload Team Photos

`POST /api/hierarchical/{packageId}/campaigns/{campaignId}/photos`

Multipart form with multiple `files` entries.

For each photo, `DocumentService.UploadDocumentAsync()` is called which:
1. Uploads file to Azure Blob Storage
2. Creates a `TeamPhotos` record
3. Triggers background EXIF + AI extraction (date, GPS, blue t-shirt, 3-wheeler detection)

DB writes to `TeamPhotos` (per photo):

| DB Column | Value | Source |
|---|---|---|
| `Id` | New GUID | Auto-generated |
| `TeamId` | Campaign GUID | Set after upload |
| `PackageId` | Package GUID | From URL |
| `FileName` | Original filename | From uploaded file |
| `BlobUrl` | Azure Blob URL | From blob storage |
| `DisplayOrder` | Sequential | Based on existing photo count |
| `PhotoTimestamp` | EXIF timestamp | Background extraction |
| `Latitude` / `Longitude` | GPS coords | Background EXIF extraction |
| `DateVisible` | bool | Background AI vision |
| `BlueTshirtPresent` | bool | Background AI vision |
| `ThreeWheelerPresent` | bool | Background AI vision |
| `ExtractedMetadataJson` | Full metadata JSON | Background extraction |

---

### Call 5: Upload Cost Summary

`POST /api/hierarchical/{packageId}/campaigns/{campaignId}/cost-summary`

Multipart form with `file`. Cost summary is package-level (one per package), `campaignId` is for API route consistency only.

DB writes to `CostSummaries`:

| DB Column | Value | Source |
|---|---|---|
| `Id` | New GUID | Auto-generated |
| `PackageId` | Package GUID | From URL |
| `FileName` | Original filename | From uploaded file |
| `BlobUrl` | Azure Blob URL | From blob storage |
| `ContentType` | MIME type | From uploaded file |
| `FileSizeBytes` | File size | From uploaded file |
| `ExtractedDataJson` | AI-extracted JSON | Background extraction |
| `ExtractionConfidence` | 0.0–1.0 | Background extraction |
| `PlaceOfSupply` | State name | Parsed from extracted data |
| `NumberOfDays` | int | Parsed from extracted data |
| `NumberOfActivations` | int | Parsed from extracted data |
| `NumberOfTeams` | int | Parsed from extracted data |
| `TotalCost` | decimal | Parsed from extracted data |
| `ElementWiseCostsJson` | JSON array | Built from `costBreakdowns[]` |
| `ElementWiseQuantityJson` | JSON array | Built from `costBreakdowns[]` |
| `CostBreakdownJson` | Full breakdown JSON | Built from `costBreakdowns[]` with `isFixedCost`/`isVariableCost` flags |

Background extraction runs in a fire-and-forget `Task.Run()` that:
1. Calls `IDocumentAgent.ExtractCostSummaryAsync(blobUrl)`
2. Parses the result into dedicated columns
3. Creates a preliminary `ValidationResult` record

---

### Call 6: Upload Activity Summary

`POST /api/hierarchical/{packageId}/campaigns/{campaignId}/activity-summary`

Same pattern as cost summary. Package-level, one per package.

DB writes to `ActivitySummaries`:

| DB Column | Value | Source |
|---|---|---|
| `Id` | New GUID | Auto-generated |
| `PackageId` | Package GUID | From URL |
| `FileName` | Original filename | From uploaded file |
| `BlobUrl` | Azure Blob URL | From blob storage |
| `ExtractedDataJson` | AI-extracted JSON | Background extraction |
| `ActivityDescription` | Extracted text | Background extraction |
| `DealerName` | Extracted dealer | Background extraction |
| `TotalDays` | int | Background extraction |
| `TotalWorkingDays` | int | Background extraction |

---

### Call 7: Upload Enquiry Document

`POST /api/hierarchical/{packageId}/enquiry-doc`

Multipart form with `file`.

DB writes to `EnquiryDocuments`:

| DB Column | Value | Source |
|---|---|---|
| `Id` | New GUID | Auto-generated |
| `PackageId` | Package GUID | From URL |
| `FileName` | Original filename | From uploaded file |
| `BlobUrl` | Azure Blob URL | From blob storage |
| `ExtractedDataJson` | AI-extracted JSON | Background extraction (contains `Records[]` array) |

---

### Call 8: Upload Additional Documents (optional)

`POST /api/documents/upload` with `documentType: "AdditionalDocument"` and `packageId`.

---

### Call 9: Trigger Background Processing

`POST /api/submissions/{packageId}/process-async`

Request body:
```json
{
  "activityState": "Maharashtra"
}
```

This is the final call that kicks off the full AI workflow. It:

1. Sets `ActivityState` if not already set
2. Generates `SubmissionNumber` if missing (`CIQ-YYYY-XXXXX`)
3. Auto-assigns `AssignedCircleHeadUserId` if missing (via `ICircleHeadAssignmentService`)
4. Resets `State` to `Uploaded` (ensures clean reprocessing)
5. Queues the package for background processing via `IBackgroundWorkflowQueue`

The background workflow (`WorkflowOrchestrator.ProcessSubmissionAsync`) then runs:

```
Uploaded → Extracting → Validating → Validated → Scoring → Recommending → PendingApproval
```

Each stage populates:
- `ValidationResults` table (per document type)
- `ConfidenceScores` table (weighted: PO 30%, Invoice 30%, CostSummary 20%, Activity 10%, Photos 10%)
- `Recommendations` table (AI-generated approve/reject with evidence)

Response: `202 Accepted` with `{ id, success: true, message: "Submission received. Processing in background." }`

After processing completes, the submission appears on the dashboard and the detail page shows all validation results, confidence scores, and AI recommendation.

---

## How Uploaded Data Maps to Submission Details Page

| Upload Step | DB Table | Detail Page Section | Detail Page Field |
|---|---|---|---|
| Select PO | `POs` (linked via `SelectedPOId`) | PO Section | PO Number, Date, Vendor, Amount, extracted fields |
| Select State | `DocumentPackages.ActivityState` | Header | Activity state label |
| Invoice file + fields | `Invoices` | Documents array, Invoice Summary | Invoice Number, Date, Amount, GSTIN, filename, blob URL |
| Cost Summary file | `CostSummaries` | Campaigns array | `costSummaryFileName`, `costSummaryBlobUrl`, `totalCost` |
| Activity Summary file | `ActivitySummaries` | Campaigns array | `activitySummaryFileName`, `activitySummaryBlobUrl` |
| Team details | `Teams` | Campaigns array | `campaignName`, `startDate`, `endDate`, `workingDays`, `dealershipName`, `dealershipAddress` |
| Team photos | `TeamPhotos` | Campaigns → photos array, Photo Gallery | `fileName`, `blobUrl`, validation status (border color) |
| Enquiry document | `EnquiryDocuments` | Validation Summary (enquiry section) | Enquiry validation rules |
| Background workflow | `ValidationResults` | Validation Summary | Per-document validation tables |
| Background workflow | `ConfidenceScores` | AI Recommendation (ASM) | Overall + per-document confidence |
| Background workflow | `Recommendations` | AI Recommendation (ASM) | Approve/Reject recommendation + evidence |
| Submit action | `RequestApprovalHistory` | Approval History | Submitted action with timestamp |

---

## Edit / Resubmit Mode

When `submissionId` is provided, the page enters edit mode:
- Loads existing submission data via `GET /api/submissions/{id}`
- Pre-fills all form fields from existing data
- Shows existing filenames for already-uploaded documents
- On submit, calls `PATCH /api/submissions/{id}/resubmit` instead of `process-async`
- Increments `VersionNumber` on the package

---

## Integration Test Coverage

The integration test (`create_request_test.dart`) validates the complete flow:

| Phase | Steps Tested |
|---|---|
| 1. Login | Page renders, credentials prefilled, sign in, dashboard loads |
| 2. Navigate | "New Request" button visible, navigate to upload page |
| 3. Step 1 | Select PO from dropdown, select Maharashtra state, upload invoice (real PDF from assets), wait for AI extraction, upload cost summary, click Next |
| 4. Step 2 | Upload activity summary, load dealers from API, select dealer name, select city, set dates, add 3 team photos, click Next |
| 5. Step 3 | Upload enquiry document, click "Submit for Validation", verify redirect to dashboard, verify success toast |

Test assets used: `E-Invoice-145.pdf`, `Cost_Summary.pdf`, `Activity_Summary.jpg`, `Team_Photo.jpeg` × 3, `Enquiry_Report.xlsx`

Prerequisites: Backend on `http://localhost:5000`, seeded agency user `agency@bajaj.com`, test docs in `assets/test_docs/`
