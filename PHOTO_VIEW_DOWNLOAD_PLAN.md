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
| T9 | `_buildPhotoValidationCard()` — added `final photoDocId = photo['documentId']?.toString() ?? photo['id']?.toString() ?? '';` and passed `resolvedDocId: photoDocId` to `_buildValidationCardWidget()` | Remove the `photoDocId` variable line and remove `resolvedDocId: photoDocId,` from the return call |

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
| T11 | `_buildPhotoValidationCard()` — added `final photoDocId = photo['documentId']?.toString() ?? photo['id']?.toString() ?? '';` and passed `documentId: photoDocId` to `_buildValidationCard()` | Remove the `photoDocId` variable line and remove `documentId: photoDocId,` from the return call |

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
| T16 | `_buildPhotoValidationCard()` — added `final photoDocId = photo['documentId']?.toString() ?? photo['id']?.toString() ?? '';` and passed `documentId: photoDocId` | Remove the `photoDocId` variable line and remove `documentId: photoDocId,` from the return call |

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
2. In `_buildPhotoValidationCard()`: remove `photoDocId` variable and `resolvedDocId: photoDocId`
3. In enquiry call: remove `documentId: _getDocumentIdByType('EnquiryDocument')`

### To remove ALL View/Download from ASM Detail:
1. In `_buildPhotoValidationCard()`: remove `photoDocId` variable and `documentId: photoDocId`
2. In enquiry call: remove `documentId: _getDocumentIdByType('EnquiryDocument')`

### To remove ALL View/Download from RA (HQ) Detail:
1. Revert `_buildValidationCard()` to old signature (remove `documentId`/`blobUrl` params and button UI)
2. Revert `_buildSingleValidationCard()` to not resolve/forward IDs
3. In `_buildInvoiceValidationCard()`: remove `documentId: docId`
4. In `_buildPhotoValidationCard()`: remove `photoDocId` variable and `documentId: photoDocId`
5. In enquiry call: remove `documentId: _getDocumentIdByType('EnquiryDocument')`

### To remove Backend DocumentId support:
1. In `SubmissionDetailResponse.cs`: remove `DocumentId` property from `ValidationResultDto`
2. In `SubmissionsController.cs` (`GetSubmission`): remove `DocumentId = ...` from `CostSummaryValidation`, `ActivityValidation`, and `EnquiryValidation` DTO blocks
