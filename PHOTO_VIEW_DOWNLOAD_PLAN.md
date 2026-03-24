# Plan: Add View & Download to All Validation Screens

## Scope
Add View & Download functionality across ALL validation screens in:
1. Chatbot (AssistantChatPanel) — 5 validation types
2. Agency Submission Detail Page — 5 validation types
3. ASM Review Detail Page — 5 validation types
4. RA (HQ) Review Detail Page — 5 validation types

**Total: 20 validation sections with View & Download buttons**

## Backend Changes
Existing endpoint: `GET /api/documents/{id}/download` returns `{ base64Content, filename, contentType }`

### Backend Fix: Enquiry Validation DocumentId (T18–T19)
The frontend `_buildSingleValidationCard` methods fall back to `validation['documentId']` from the API response. Previously, `ValidationResultDto` had no `DocumentId` field, so enquiry (and cost summary / activity) validation cards couldn't resolve a document ID for View/Download.

| ID | File | Change | How to Remove |
|----|------|--------|---------------|
| T18 | `SubmissionDetailResponse.cs` | Added `DocumentId` (Guid?) property to `ValidationResultDto` with `[JsonPropertyName("documentId")]` | Remove the `DocumentId` property from `ValidationResultDto` |
| T19 | `SubmissionsController.cs` (`GetSubmission`) | Populated `DocumentId` for `CostSummaryValidation` (`package.CostSummary?.Id`), `ActivityValidation` (`package.ActivitySummary?.Id`), and `EnquiryValidation` (`package.EnquiryDocument?.Id`) | Remove `DocumentId = ...` lines from the three `new ValidationResultDto` blocks |

**Files Changed (Backend)**:
- `backend/src/BajajDocumentProcessing.Application/DTOs/Submissions/SubmissionDetailResponse.cs`
- `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs`

## Files Changed (Frontend)
- `frontend/lib/features/assistant/presentation/widgets/assistant_chat_panel.dart`
- `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart`
- `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`
- `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`

---

## Detailed Changes & Removal Instructions Per Section

### 1. CHATBOT — `assistant_chat_panel.dart`

#### 1.1 Helper Methods (shared by all chatbot validation cards)
| ID | Change | How to Remove |
|----|--------|---------------|
| T1 | Added `_viewDocument(String docId)` method — calls `GET /api/documents/{id}/download`, decodes base64, shows image in fullscreen `InteractiveViewer` dialog or non-image placeholder | Search for `Future<void> _viewDocument(String docId)` and delete the entire method (approx 55 lines) |
| T2 | Added `_downloadDocument(String docId, String fallbackName)` method — calls same endpoint, triggers browser download via `HTMLAnchorElement` with data URL | Search for `Future<void> _downloadDocument(String docId, String fallbackName)` and delete the entire method (approx 35 lines) |

#### 1.2 Photo Validation Table
| ID | Change | How to Remove |
|----|--------|---------------|
| T3 | `_photoTable()` — added 2 new columns (index 5: "View", index 6: "Save") with `FixedColumnWidth(40)`. Each row has `InkWell` with `Icons.visibility` and `Icons.download` using `photo.photoId` | In `_photoTable()`: remove keys `5` and `6` from `columnWidths`, remove `_tableCell('View', headerStyle)` and `_tableCell('Save', headerStyle)` from header `TableRow`, remove the last 2 `_tableBadgeCell(InkWell(...))` entries from each data `TableRow` |

#### 1.3 Invoice Validation Card
| ID | Change | How to Remove |
|----|--------|---------------|
| T4 | `_invoiceValidationCard()` — added a `Row` with View and Download `OutlinedButton.icon` above the Re-upload/Continue row. Uses `ref.read(assistantNotifierProvider).lastDocumentId` | In `_invoiceValidationCard()`: find the comment `// View & Download buttons for invoice`, delete that `Row(children: [...])` and the `const SizedBox(height: 8)` after it. Change the preceding `const SizedBox(height: 12)` back if needed |

#### 1.4 Cost Summary Validation Card
| ID | Change | How to Remove |
|----|--------|---------------|
| T5 | `_costSummaryValidationCard()` — added View/Download `Row` above Re-upload/Continue row. Uses `state.lastDocumentId` | In `_costSummaryValidationCard()`: find comment `// View & Download buttons for cost summary`, delete that `Row(children: [...])` and the `const SizedBox(height: 8)` after it |

#### 1.5 Activity Summary Validation Card
| ID | Change | How to Remove |
|----|--------|---------------|
| T6 | `_activitySummaryValidationCard()` — added View/Download `Row` above Re-upload/Continue row. Uses `state.lastDocumentId` | In `_activitySummaryValidationCard()`: find comment `// View & Download buttons for activity summary`, delete that `Row(children: [...])` and the `const SizedBox(height: 8)` after it |

#### 1.6 Enquiry Dump Validation Card
| ID | Change | How to Remove |
|----|--------|---------------|
| T7 | `_enquiryValidationCard()` — added View/Download `Row` above Re-upload/Continue row. Uses `state.lastDocumentId` | In `_enquiryValidationCard()`: find comment `// View & Download buttons for enquiry dump`, delete that `Row(children: [...])` and the `const SizedBox(height: 8)` after it |

---

### 2. AGENCY DETAIL PAGE — `agency_submission_detail_page.dart`

The agency page uses a shared `_buildValidationCardWidget()` that already had View/Download button UI — the fix was wiring up the document IDs that were not being passed through.

#### 2.1 Cost Summary / Activity Summary Validation (via `_buildSingleValidationCard`)
| ID | Change | How to Remove |
|----|--------|---------------|
| T8 | `_buildSingleValidationCard()` — added `resolvedDocId: resolvedDocId` and `resolvedBlobUrl: resolvedBlobUrl` to the `_buildValidationCardWidget()` return call (these params existed but were not forwarded) | In `_buildSingleValidationCard()`: remove `resolvedDocId: resolvedDocId,` and `resolvedBlobUrl: resolvedBlobUrl,` from the `_buildValidationCardWidget()` call |

#### 2.2 Photo Validation
| ID | Change | How to Remove |
|----|--------|---------------|
| T9 | `_buildPhotoValidationCard()` — Photo validation `documentId` from API is the package ID (not a real TeamPhoto ID), causing 404 on download. Blob URLs are private Azure storage (not accessible from browser). Fix: extract first photo's real ID from `campaigns[0].photos[0].id` and pass as `resolvedDocId` to `_buildValidationCardWidget()`. The existing `/api/documents/{id}/download` endpoint handles `DocumentType.TeamPhoto` by looking up the TeamPhoto record, fetching blob bytes through backend Azure credentials, and returning base64. | In `_buildPhotoValidationCard()`: remove the `if (resolvedPhotoDocId.isEmpty)` block that extracts photo ID from campaigns. Revert `resolvedPhotoDocId` back to `final` with the original packageId check only. Remove `resolvedDocId: resolvedPhotoDocId` from the `_buildValidationCardWidget()` call. |

#### 2.3 Enquiry Validation
| ID | Change | How to Remove |
|----|--------|---------------|
| T10 | Enquiry `_buildSingleValidationCard()` call — added `documentId: _getDocumentIdByType('EnquiryDocument')` | In `_buildValidationReportSection()`: find the enquiry `_buildSingleValidationCard(` call and remove the `documentId: _getDocumentIdByType('EnquiryDocument'),` line |

#### 2.4 Invoice Validation — already had `resolvedDocId: docId` ✅ (no change needed)

---

### 3. ASM DETAIL PAGE — `asm_review_detail_page.dart`

The ASM page uses `_buildValidationCard()` which already had View/Download button UI. The fix was wiring up missing document IDs.

#### 3.1 Photo Validation
| ID | Change | How to Remove |
|----|--------|---------------|
| T11 | `_buildPhotoValidationCard()` — Same fix as T9. Photo validation `documentId` from API is the package ID. Blob URLs are private Azure storage. Fix: extract first photo's real ID from `campaigns[0].photos[0].id` and pass as `documentId:` to `_buildValidationCard()`. Backend `/api/documents/{id}/download` handles TeamPhoto lookup and blob fetch. | In `_buildPhotoValidationCard()`: remove the `if (resolvedPhotoDocId.isEmpty)` block that extracts photo ID from campaigns. Revert `resolvedPhotoDocId` back to `final`. Remove `documentId: resolvedPhotoDocId` from the `_buildValidationCard()` call. |

#### 3.2 Enquiry Validation
| ID | Change | How to Remove |
|----|--------|---------------|
| T12 | Enquiry `_buildSingleValidationCard()` call — added `documentId: _getDocumentIdByType('EnquiryDocument')` | Find the enquiry `_buildSingleValidationCard(` call and remove the `documentId: _getDocumentIdByType('EnquiryDocument'),` line |

#### 3.3 Invoice / Cost Summary / Activity Summary — already had document IDs wired ✅ (no change needed)

---

### 4. RA (HQ) DETAIL PAGE — `hq_review_detail_page.dart`

The HQ page's `_buildValidationCard()` had NO View/Download buttons at all. Full button UI was added.

#### 4.1 Validation Card Widget (affects ALL validation types on this page)
| ID | Change | How to Remove |
|----|--------|---------------|
| T13 | `_buildValidationCard()` — added optional `String? documentId` and `String? blobUrl` params. Added `resolvedDocId`/`resolvedBlobUrl` resolution. Added View (`OutlinedButton.icon` with `Icons.visibility`) and Download (`ElevatedButton.icon` with `Icons.download`) buttons in the card header Row, conditionally shown when docId or blobUrl is available | Revert `_buildValidationCard()` signature to remove `documentId` and `blobUrl` params. Remove the `resolvedDocId`/`resolvedBlobUrl` variables. Replace the header `Row` children back to just the `RichText` passed/total widget (remove the `if (resolvedDocId.isNotEmpty || resolvedBlobUrl.isNotEmpty)` block with the two button `SizedBox` widgets). Unwrap the `Row(mainAxisSize: MainAxisSize.min, children: [...])` back to just the `RichText` |

#### 4.2 Single Validation Card (Cost Summary, Activity Summary, Enquiry)
| ID | Change | How to Remove |
|----|--------|---------------|
| T14 | `_buildSingleValidationCard()` — added `resolvedDocId`/`resolvedBlobUrl` resolution from `documentId`/`blobUrl` params and validation map fallback. Now passes `documentId:` and `blobUrl:` to `_buildValidationCard()` | Remove `resolvedDocId`/`resolvedBlobUrl` variables. Remove `documentId:` and `blobUrl:` from the `_buildValidationCard()` call |

#### 4.3 Invoice Validation
| ID | Change | How to Remove |
|----|--------|---------------|
| T15 | `_buildInvoiceValidationCard()` — added `documentId: docId` to `_buildValidationCard()` call (docId was already extracted but not passed) | Remove `documentId: docId,` from the `_buildValidationCard()` call |

#### 4.4 Photo Validation
| ID | Change | How to Remove |
|----|--------|---------------|
| T16 | `_buildPhotoValidationCard()` — Same fix as T9/T11. Photo validation `documentId` from API is the package ID. Blob URLs are private Azure storage. Fix: extract first photo's real ID from `campaigns[0].photos[0].id` and pass as `documentId:` to `_buildValidationCard()`. Backend `/api/documents/{id}/download` handles TeamPhoto lookup and blob fetch. | In `_buildPhotoValidationCard()`: remove the `if (resolvedPhotoDocId.isEmpty)` block that extracts photo ID from campaigns. Revert `resolvedPhotoDocId` back to `final`. Remove `documentId: resolvedPhotoDocId` from the `_buildValidationCard()` call. |

#### 4.5 Enquiry Validation
| ID | Change | How to Remove |
|----|--------|---------------|
| T17 | Enquiry `_buildSingleValidationCard()` call — added `documentId: _getDocumentIdByType('EnquiryDocument')` | Find the enquiry `_buildSingleValidationCard(` call and remove the `documentId: _getDocumentIdByType('EnquiryDocument'),` line |

---

### 5. BACKEND — `SubmissionDetailResponse.cs` + `SubmissionsController.cs`

The root cause for Enquiry Validation View/Download buttons not appearing: `ValidationResultDto` had no `documentId` field, so the frontend fallback `validation['documentId']` always returned null. Enquiry documents are NOT in the `documents` array (they're a separate navigation property `package.EnquiryDocument`), so `_getDocumentIdByType('EnquiryDocument')` also returned empty.

#### 5.1 DTO Change
| ID | Change | How to Remove |
|----|--------|---------------|
| T18 | `ValidationResultDto` — added `public Guid? DocumentId { get; init; }` with `[JsonPropertyName("documentId")]` | Remove the `DocumentId` property and its JSON attribute from `ValidationResultDto` in `SubmissionDetailResponse.cs` |

#### 5.2 Controller Change (populating DocumentId)
| ID | Change | How to Remove |
|----|--------|---------------|
| T19 | `GetSubmission` in `SubmissionsController.cs` — added `DocumentId = package.CostSummary?.Id` to `CostSummaryValidation`, `DocumentId = package.ActivitySummary?.Id` to `ActivityValidation`, `DocumentId = package.EnquiryDocument?.Id` to `EnquiryValidation` | Remove the `DocumentId = ...` line from each of the three `new ValidationResultDto` blocks |

---

## Quick Removal Guide (by page)

### To remove ALL View/Download from Chatbot:
1. Delete `_viewDocument()` and `_downloadDocument()` methods
2. In `_photoTable()`: revert to 5 columns (remove cols 5,6 from widths, header, and rows)
3. In each of `_invoiceValidationCard`, `_costSummaryValidationCard`, `_activitySummaryValidationCard`, `_enquiryValidationCard`: delete the View/Download `Row` block (find by comment `// View & Download buttons for ...`) and the `SizedBox(height: 8)` after it

### To remove ALL View/Download from Agency Detail:
1. In `_buildSingleValidationCard()`: remove `resolvedDocId:` and `resolvedBlobUrl:` from the return
2. In enquiry call: remove `documentId: _getDocumentIdByType('EnquiryDocument')`

### To remove ALL View/Download from ASM Detail:
1. In enquiry call: remove `documentId: _getDocumentIdByType('EnquiryDocument')`

### To remove ALL View/Download from RA (HQ) Detail:
1. Revert `_buildValidationCard()` to old signature (remove `documentId`/`blobUrl` params and button UI)
2. Revert `_buildSingleValidationCard()` to not resolve/forward IDs
3. In `_buildInvoiceValidationCard()`: remove `documentId: docId`
4. In enquiry call: remove `documentId: _getDocumentIdByType('EnquiryDocument')`

### To remove Backend DocumentId support:
1. In `SubmissionDetailResponse.cs`: remove `DocumentId` property from `ValidationResultDto`
2. In `SubmissionsController.cs` (`GetSubmission`): remove `DocumentId = ...` from `CostSummaryValidation`, `ActivityValidation`, and `EnquiryValidation` DTO blocks


---

## Changelog

### 2026-03-23 — Photo Validation: Private Blob URL Fix (T9, T11, T16)

**Problem**: Photo validation's `documentId` in the API response is the package ID (not a real TeamPhoto ID), causing 404 on the `/api/documents/{id}/download` endpoint. The previous workaround passed the first photo's blob URL (`campaigns[0].photos[0].blobUrl`) directly to the frontend, but Azure Blob Storage URLs are private and not accessible from the browser.

**Root Cause**: Azure Blob Storage container access level is set to private. Only the backend (with storage account credentials) can read blobs. The frontend cannot open or download from `https://bajajstorageprod.blob.core.windows.net/...` URLs directly.

**Solution**: Extract the first photo's real TeamPhoto ID from `campaigns[0].photos[0].id` and pass it as `documentId` to the validation card. The existing `/api/documents/{id}/download` endpoint already handles `DocumentType.TeamPhoto` — it looks up the TeamPhoto record in the database, reads the blob through the backend's Azure credentials via `_fileStorageService.GetFileBytesAsync(blobUrl)`, and returns base64 content to the frontend.

**Files Changed**:
- `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart` (T9)
- `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart` (T11)
- `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart` (T16)

**Pattern applied in all 3 files** (`_buildPhotoValidationCard`):
```dart
// Before (broken): passed private blob URL
String firstPhotoBlobUrl = '';
// ... extract from campaigns[0].photos[0].blobUrl
return _buildValidationCard(..., blobUrl: firstPhotoBlobUrl);

// After (fixed): pass real TeamPhoto ID, let backend proxy the download
if (resolvedPhotoDocId.isEmpty) {
  final campaigns = _submission?['campaigns'] as List? ?? [];
  for (final campaign in campaigns) {
    final photos = (campaign as Map<String, dynamic>)['photos'] as List? ?? [];
    if (photos.isNotEmpty) {
      resolvedPhotoDocId = (photos[0] as Map<String, dynamic>)['id']?.toString() ?? '';
      break;
    }
  }
}
return _buildValidationCard(..., documentId: resolvedPhotoDocId);
```

### 2026-03-24 — Double Entry Fix: Orphan Package from PO Extraction (T20–T21)

**Problem**: When creating a new request, the "Recent Requests" list showed two entries — the real submission (e.g. FAP-2026-00063 in "Extracting" state with data) and an orphan entry (e.g. FAP-FCB916E4 in "Pending" state with no PO, no invoice, no data).

**Root Cause**: `_uploadAndExtractPO()` in `agency_upload_page.dart` called `POST /documents/upload` without a `packageId` to extract PO fields during the create flow. `DocumentService.UploadDocumentAsync` creates a new `DocumentPackage` in `Uploaded` state when no `packageId` is provided. Then at submit time, the code correctly created a **second** fresh package via `POST /submissions`. The first orphan package was never submitted but still appeared in the list because `ListSubmissions` had no filter for incomplete packages.

**Solution (two-part fix)**:

| ID | File | Change | How to Remove |
|----|------|--------|---------------|
| T20 | `agency_upload_page.dart` | Changed `_uploadAndExtractPO()` to use `/documents/extract` (extract-only, temp blob, no DB entity) instead of `/documents/upload`. Removed `_pollForPOExtraction()` method (no longer needed — extract endpoint returns immediately). | Revert `_uploadAndExtractPO()` to call `/documents/upload` and restore `_pollForPOExtraction()` method. |
| T21 | `SubmissionsController.cs` (`ListSubmissions`) | Added two filters: exclude `Draft` state packages, and exclude orphan `Uploaded` packages that have no `SubmissionNumber` and haven't progressed past `Uploaded` state. Filter: `p.State != PackageState.Draft` and `p.SubmissionNumber != null \|\| p.State >= PackageState.Extracting`. | Remove the two `query = query.Where(...)` lines above the `OrderByDescending` call (find by comments about Draft and orphan packages). |

**Files Changed**:
- `frontend/lib/features/submission/presentation/pages/agency_upload_page.dart` (T20)
- `backend/src/BajajDocumentProcessing.API/Controllers/SubmissionsController.cs` (T21)

**Additional fix in same session** (related navigation bug):
- `agency_submission_detail_page.dart`: `_navigateToUpload()` (the "New Claim" drawer nav item) was passing `widget.submissionId` to the upload page, putting it in edit mode and pre-loading existing invoice data. Fixed by removing `submissionId` from the navigation extras so new requests start with a clean form. `_enterEditMode()` still correctly passes `submissionId` for the edit/resubmit flow.

### 2026-03-24 — Photo Validation UI: Percentage Format, Remove Per-Photo Tables, Move to Bottom (T22–T24)

**Problem**: 
1. Validation header showed "6/15 Passed" (x/y format) — should be percentage (e.g. "40% Passed")
2. Per-photo validation tables (e.g. T2_image11.jpeg, T2_image9.jpeg) were shown individually — only the aggregate "Team Photos (All)" table should be displayed
3. Photo validations appeared in the middle of the validation section — should be at the bottom

**Solution (three changes across all 3 detail pages)**:

| ID | File | Change | How to Remove |
|----|------|--------|---------------|
| T22 | `agency_submission_detail_page.dart`, `asm_review_detail_page.dart`, `hq_review_detail_page.dart` | Changed `$passedCount/$totalCount` to `${totalCount > 0 ? (passedCount * 100 ~/ totalCount) : 0}%` in the validation card header `RichText` | Revert the `TextSpan` text back to `'$passedCount/$totalCount '` |
| T23 | Same 3 files | `_buildPhotoValidationsSection()` now filters to only show aggregate entries (where `documentId == packageId` or empty), skipping per-photo entries | Revert `_buildPhotoValidationsSection()` to iterate over all `photoValidations` without filtering |
| T24 | Same 3 files | Moved the `// Photo Validations` block to after Enquiry Validation in the validation section ordering | Move the `// Photo Validations` block back to its original position (after Invoice in agency, after Activity in ASM/HQ) |

**Files Changed**:
- `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart` (T22, T23, T24)
- `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart` (T22, T23, T24)
- `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart` (T22, T23, T24)

### 2026-03-24 — Photo Validation: x/y → Percentage in "WHAT WAS FOUND" Column (T25)

**Problem**: Photo validation rows like "Date in Photos", "Location in Photos", "Blue T-shirt Detection" etc. showed "Present in 1/45 photos" or "Detected in 1/45 photos" — should show percentage instead (e.g. "Present in 2.2% photos").

**Solution**:

| ID | File | Change | How to Remove |
|----|------|--------|---------------|
| T25 | `agency_submission_detail_page.dart`, `asm_review_detail_page.dart`, `hq_review_detail_page.dart` | Changed photo fieldPresence messages from `'Present in $count/$total photos'` to `'Present in ${(count * 100 / total).toStringAsFixed(1)}% photos'` and same for `'Detected in ...'` messages. Applies to: Date in Photos, Location in Photos, Blue T-shirt Detection, Bajaj Vehicle Detection, Face Detection. | Revert the 5 `addRow()` calls in the `if (totalPhotos != null)` block back to `'Present in $photosWithDate/$totalPhotos photos'` format. |

**Files Changed**:
- `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart`
- `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart`
- `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart`


### 2026-03-24 — Photo Validation: Simplified Labels and Messages (T26)

**Problem**: Photo validation rows used verbose labels like "Date in Photos", "Location in Photos", "Blue T-shirt Detection" and percentage-based messages like "Present in 2.2% photos". User wanted short labels matching the screenshot (Date, GPS, Blue T-shirt, 3W Vehicle) and natural language messages (x/y format or "Field is missing").

**Solution**: Created a dedicated `_extractPhotoValidationRows()` method in all 3 detail pages that bypasses the generic `_extractAllValidationRows()` for photo cards. The card still uses the shared `_buildValidationCardWidget()`/`_buildValidationCard()` (same 3-column layout, percentage header, View/Download buttons, Pass/Fail badges). Only the row text content changed:

- Column 1 (WHAT WAS CHECKED): "Photo Count", "Date on Photos", "GPS Coordinates", "No. of Days", "Promoter wearing Blue T-shirt", "Branded 3 Wheeler"
- Column 3 (WHAT WAS FOUND): "10 photos uploaded", "7/10 photos have date mentioned", "8/10 photos have coordinates present", "Photo count (45) does not match days in Cost Summary (210)", "9/10 photos have promoters wear blue T-shirt", "5/10 photos have Branded 3W"
- "No. of Days" row uses `crossDocument.photoCount` and `crossDocument.costSummaryDays` for descriptive message with actual numbers
- Removed Face Detection row (not in spec)

| ID | File | Change | How to Remove |
|----|------|--------|---------------|
| T26 | `agency_submission_detail_page.dart`, `asm_review_detail_page.dart`, `hq_review_detail_page.dart` | `_buildPhotoValidationCard()` now calls `_extractPhotoValidationRows()` instead of `_extractAllValidationRows()`. Added `_extractPhotoValidationRows()` method with simplified labels and messages. | Revert `_buildPhotoValidationCard()` to call `_extractAllValidationRows()`. Remove `_extractPhotoValidationRows()` method. |

**Files Changed**:
- `frontend/lib/features/submission/presentation/pages/agency_submission_detail_page.dart` (T26)
- `frontend/lib/features/approval/presentation/pages/asm_review_detail_page.dart` (T26)
- `frontend/lib/features/approval/presentation/pages/hq_review_detail_page.dart` (T26)


### 2026-03-24 — Photo Validation Agent: Fix Aggregate Photo Validation Counts (T27)

**Problem**: The "Photo Validations" table on detail pages showed incorrect aggregate counts (e.g. "1/45 photos have date mentioned") even though the database had many more photos with those attributes populated.

**Root Cause**: `ValidatePhotoFieldPresence` in `ValidationAgent.cs` only read from `photo.ExtractedMetadataJson`. It completely ignored:
1. Dedicated DB columns (`DateVisible`, `BlueTshirtPresent`, `ThreeWheelerPresent`, `PhotoTimestamp`, `Latitude`, `Longitude`) which ARE populated for most photos
2. The `Caption` column (which contains initial AI extraction JSON)
3. Photos with `ExtractedMetadataJson = NULL` were counted as zero for all checks

**Solution**: Aligned `ValidatePhotoFieldPresence` with the same pattern already used by `RunPhotoValidationRules` (chatbot in `AssistantController.cs`) and per-photo validation in `BuildPerDocumentResults`: read dedicated columns first, fall back to `ExtractedMetadataJson`, then fall back to `Caption`. Face detection and perceptual hash are still read from JSON metadata since they have no dedicated columns.

| ID | File | Change | How to Remove |
|----|------|--------|---------------|
| T27 | `ValidationAgent.cs` | Rewrote the `foreach` loop in `ValidatePhotoFieldPresence` to read dedicated columns first (`DateVisible`, `PhotoTimestamp`, `Latitude`, `Longitude`, `BlueTshirtPresent`, `ThreeWheelerPresent`), then fall back to `ExtractedMetadataJson ?? Caption` for remaining fields (face detection, perceptual hash) and for photos where dedicated columns are null. | Revert the `foreach` loop in `ValidatePhotoFieldPresence` back to only reading `photo.ExtractedMetadataJson` (remove dedicated column reads and `Caption` fallback). |

**File Changed**:
- `backend/src/BajajDocumentProcessing.Infrastructure/Services/ValidationAgent.cs`

**Note**: Validation counts are persisted in `ValidationResults.ValidationDetailsJson` at validation time. To see corrected counts in the UI, validation must be re-run for the package.


### 2026-03-24 — Photo Upload: Non-Blocking Validation + Better Error Reporting (T30–T31)

**Problem**: When uploading photos during submission, if any photo failed file validation (size, extension, magic bytes, or malware scan), the entire submission failed with a 500 error. The `ValidateFileAsync` rejection in `DocumentService.UploadDocumentAsync` threw a `ValidationException` that propagated up through `AddPhotos` and killed the whole submission flow.

**Root Cause (Backend)**: `HierarchicalSubmissionController.AddPhotos` had a single `catch (Exception ex)` that returned `500 Internal Server Error` with a generic `"Failed to add photos"` message, hiding the actual validation error details.

**Root Cause (Frontend)**: `agency_upload_page.dart` called `_dio.post('/hierarchical/$packageId/campaigns/$campaignId/photos')` without a try/catch. Any HTTP error (400 or 500) from the photo upload threw a `DioException` that propagated up and failed the entire submission.

**Solution**:

| ID | File | Change | How to Remove |
|----|------|--------|---------------|
| T30 | `HierarchicalSubmissionController.cs` | Added a separate `catch (ValidationException vex)` block before the generic `catch (Exception)` that returns `400 Bad Request` with the actual error message and field-level errors (`vex.Errors`). Added `using BajajDocumentProcessing.Domain.Exceptions;` import. | Remove the `catch (ValidationException vex)` block from `AddPhotos`. Remove the `Domain.Exceptions` using if no longer needed. |
| T31 | `agency_upload_page.dart` | Wrapped the photo upload `_dio.post(...)` call in a try/catch. On failure, logs a debug warning but continues submission — photo validation failures do not block the request. | Remove the try/catch around the `_dio.post('/hierarchical/$packageId/campaigns/$campaignId/photos')` call and let it throw directly. |

**Files Changed**:
- `backend/src/BajajDocumentProcessing.API/Controllers/HierarchicalSubmissionController.cs` (T30)
- `frontend/lib/features/submission/presentation/pages/agency_upload_page.dart` (T31)
