# ClaimsIQ — Guided Workflow Assistant — Requirements

---

## Architecture

- Frontend: Flutter Web (reuse existing project structure)
- Backend: .NET 8 Web API
- Database: SQL Server
- Flow: Flutter Web → .NET API → SQL Server
- Reuse existing modules — no duplicate services or unnecessary scaffolding

---

## Implementation Status Summary

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | Assistant UI and Basic Menu | ✅ DONE |
| Phase 2 | PO Search & Selection | ✅ DONE |
| Phase 3 | State & Activity Region Selection | ✅ DONE |
| Phase 4 | Invoice Upload | ✅ DONE |
| Phase 5 | Invoice Validation (9 rules, inline card, save to DB) | ✅ DONE |
| Phase 6 | Activity Summary Upload & Validation (AS_DEALER_LOCATION_PRESENT, save to DB) | ✅ DONE |
| Phase 7–10 | Full Submission Flow | 🔲 Pending |

---

## PHASE 1 — Assistant UI and Basic Menu ✅

### Requirement P1.1: Copilot-Style Assistant UI
Copilot-style assistant UI that opens as the main chat experience after login.

#### What's Implemented
- Login navigates to `/agency/assistant` (ChatScreen)
- Greeting message: "Hello! I am your Field Activity Assistant. I can help you manage campaign requests."
- 3 workflow action cards: Create Request, View My Requests, Pending Approvals
- User message bubble shows action in sentence case (e.g., "Create Request")
- FAB on Agency Dashboard navigates to `/agency/assistant`

#### Backend
- `POST /api/assistant/message` with `action: 'greet'` returns greeting + cards
- `AssistantController.cs` handles all assistant actions via single endpoint

#### Frontend Files
- `chat_screen.dart` — main chat page with message list, input mode switching
- `assistant_notifier.dart` — Riverpod StateNotifier managing chat state
- `assistant_remote_datasource.dart` — Dio-based API calls
- `assistant_response_model.dart` — response DTO with type, message, cards, poItems, states fields
- `assistant_providers.dart` — Riverpod provider definitions
- Widgets: `AssistantHeader`, `AssistantBubble`, `UserBubble`, `WorkflowActionCard`, `ChatInputBar`

#### Acceptance Criteria — ALL MET ✅
- AC1: Greeting + 3 cards appear on assistant open
- AC2: Card tap sends action to backend
- AC3: Backend returns structured JSON
- AC4: AssistantNotifier manages state
- AC5: AssistantRemoteDataSource calls API via Dio

---

## PHASE 2 — PO Search & Selection ✅

### Requirement P2.1: PO Number Typeahead Search
When user taps "Create Request", assistant shows PO search with typeahead.

#### What's Implemented
- Tapping "Create Request" sends `create_request` action → backend returns `po_search` type
- Search bar appears at bottom with "Search PO number (min 3 chars)..." hint
- Typing 3+ chars triggers debounced search (400ms) via `search_po` action
- Backend queries `PurchaseOrdersController` search endpoint internally
- Results display as simple `OutlinedButton` list showing PO numbers only (no amount, no vendor)
- Consistent styling: navy blue text (#003087), rounded corners, left-aligned

#### Backend Actions
- `create_request` → returns `po_search` type with search prompt
- `search_po` → queries POs by number, returns `po_search_results` with `poItems` array

#### Frontend Files
- `po_search_list.dart` — renders PO results as OutlinedButton list (PO number only)
- Input mode `'po'` activates PO search bar at bottom

#### Acceptance Criteria — ALL MET ✅
- AC1: Create Request shows PO search prompt
- AC2: Search bar appears for PO input
- AC3: 3+ chars triggers typeahead
- AC4: Results as selectable PO number list
- AC5: Selecting PO sends `select_po` with PO ID
- AC6: Mock POs seeded (8110011482, 8110011617, 8110011618, 8110011755)

### Requirement P2.2: Direct to State Selection After PO Selection
After PO selection, assistant skips file upload and goes directly to state selection.

#### What's Implemented
- `select_po` action → backend returns `state_selection` type (not `upload_po`)
- PO upload step removed from flow
- Response includes quick-select state buttons

#### Acceptance Criteria — ALL MET ✅
- AC1: After PO selection, state selection appears immediately
- AC2: No upload step between PO selection and state selection

---

## PHASE 3 — State & Activity Region Selection ✅

### Requirement P3.1: State Selection with Quick-Select and Typeahead
After PO selection, assistant asks which state the activity was conducted in.

#### What's Implemented
- After `select_po`, backend returns `state_selection` type with:
  - Message: "PO {number} selected. Which state was this activity conducted in? Start typing or select:"
  - Quick-select cards for top 4 frequent states (default: Maharashtra, Gujarat, Karnataka, Tamil Nadu)
  - "More states..." card with search icon
- State buttons rendered as `OutlinedButton` list (same style as PO list)
- "More states..." button has search icon prefix
- State search bar appears at bottom (input mode `'state'`) alongside buttons
- Typing filters states via `search_state` action (debounced 300ms)
- `list_states` returns all 36 Indian states/UTs as `state_search_results`
- `select_state` validates against 36 states, returns `state_confirmed`
- Confirmation shows green checkmark: "State set to {state}. Proceeding to the next step..."
- Header label "Select State" above buttons (matches "Purchase Orders" label style)

#### Backend Actions (AssistantController.cs)
- `select_state` → validates state name, returns `state_confirmed`
- `search_state` → filters AllIndianStates list by query, returns `state_search_results` with `states` array
- `list_states` → returns full 36 states/UTs
- `BuildStateSelectionPrompt` → builds top 4 frequent states + "More states..." card
- `AllIndianStates` — static list of 36 Indian states and union territories

#### Frontend
- `_stateButton` helper in `chat_screen.dart` — reusable OutlinedButton with consistent styling
- Input mode `'state'` shows state search bar for both `state_selection` and `state_search_results` types
- `states` field on `AssistantResponseModel` for state search results

#### Acceptance Criteria — ALL MET ✅
- AC1: After PO selection, state selection prompt with quick-select buttons appears
- AC2: Top 4 frequent states shown as tappable buttons (OutlinedButton style)
- AC3: "More states..." opens full searchable list
- AC4: Typing in search bar filters states in real-time
- AC5: Selecting a state shows confirmation with green checkmark
- AC6: Invalid state names rejected with helpful message
- AC7: Both quick-select buttons and search bar available simultaneously

---

## PHASE 4 — Invoice Upload ✅

### Requirement P4.1: Invoice Document Upload
After state confirmation, assistant prompts for invoice upload with two action buttons.

#### What's Implemented
- After `select_state`, backend creates a Draft `DocumentPackage` (linked to selected PO via `SelectedPOId` and `ActivityState`)
- Backend returns `invoice_upload` type with:
  - Message: "State set to {state}. Please upload the invoice document."
  - Two action buttons: "Upload from device" (upload_file icon), "Take photo" (camera_alt icon)
  - `submissionId` (the draft package GUID) for frontend to attach upload to correct package
  - `allowedFormats`: PDF, JPG, PNG
- `HandleSelectPO` now returns `SelectedPO` in response so frontend stores the PO ID in state
- `selectState` frontend method passes `poId` in `payloadJson` so backend can link PO to draft
- Frontend `_pickInvoiceFile` uses `file_picker` package (PDF, JPG, PNG, max 10 MB)
- Upload posts to `POST /api/documents/upload` with `documentType=Invoice`, `submissionId`, `Content-Type: multipart/form-data`
- `LinearProgressIndicator` shown during upload
- On success, frontend sends `invoice_uploaded` action with `documentId` → backend returns `invoice_upload_success`
- Green checkmark confirmation: "Invoice uploaded successfully!"

#### Backend Changes (AssistantController.cs)
- `HandleSelectState` creates Draft `DocumentPackage` with `SelectedPOId`, `ActivityState`, `AgencyId`
- `HandleSelectPO` returns `SelectedPO` object in response (fix: was missing, caused null `poId` downstream)
- Added `SubmissionId` field to `AssistantResponse` DTO
- Added `invoice_uploaded` action to router → `HandleInvoiceUploaded` method
- Logging: `=== SELECT STATE ===` shows PayloadJson and SelectedPOId for debugging

#### Backend Changes (DocumentService.cs)
- Invoice `POId` FK fix: now uses `package.SelectedPOId` (assistant flow) before falling back to `PackageId` match (legacy flow)
- Invoice extraction now saves individual fields (InvoiceNumber, InvoiceDate, VendorName, GSTNumber, SubTotal, TaxAmount, TotalAmount) to Invoice entity columns, not just `ExtractedDataJson`
- Extraction pipeline: File → Azure Blob Storage → Azure Document Intelligence + OpenAI → DB
- Detailed logging added: `=== UPLOAD START ===`, `=== BLOB UPLOAD ===`, `=== INVOICE: Looking for PO ===`, `=== INVOICE EXTRACTION START/RESULT ===`

#### Frontend Changes
- `assistant_response_model.dart` — added `submissionId` field
- `assistant_remote_datasource.dart` — added `uploadInvoice` method (multipart form to `/documents/upload` with explicit `Content-Type: multipart/form-data` via Dio `Options`)
- `assistant_notifier.dart` — added `submissionId` to `AssistantState`, added `uploadInvoice(bytes, fileName)` method, `selectState` passes `poId` in payload
- `chat_screen.dart` — `invoice_upload` case with two `OutlinedButton.icon` buttons (consistent navy blue #003087 styling), `LinearProgressIndicator`, format hint text; `invoice_upload_success` case with green checkmark; `_pickInvoiceFile` method

#### Upload Endpoint (Existing — No Changes to Interface)
- `POST /api/documents/upload` in `DocumentsController.cs`
- Multipart form: `file`, `documentType=Invoice`, `submissionId={packageId}`
- Pipeline: blob storage → AI extraction (Document Intelligence + OpenAI) → DB record with extracted fields → proactive validation

#### Acceptance Criteria — ALL MET ✅
- AC1: After state confirmation, invoice upload prompt appears with two buttons
- AC2: Two buttons: "Upload from device" and "Take photo" (OutlinedButton.icon style)
- AC3: File picker accepts PDF, JPG, PNG (max 10 MB enforced client-side)
- AC4: Upload progress shown via LinearProgressIndicator
- AC5: Upload uses existing `POST /api/documents/upload` endpoint with multipart/form-data
- AC6: Draft submission created with PO (via SelectedPOId) and state linked
- AC7: Invoice row saved to Invoices table with correct POId FK
- AC8: AI extraction runs and saves extracted fields to individual DB columns

---

## PHASES 5–10 — Full Submission Flow

- **Phase 5**: ✅ DONE — Proactive Invoice Validation at Upload Time (see below)
- **Phase 6**: ✅ DONE — Activity Summary Upload & Validation (see below)
- **Phase 7**: Team Details Entry Loop (team name, dealer, dates, working days, photo proofs with AI vision)
- **Phase 8**: Enquiry Dump Upload (mandatory, Excel/CSV/PDF)
- **Phase 9**: Additional Documents Upload (optional with skip)
- **Phase 10**: Final Review & Submit (summary card, Draft → Submitted, CIRCLE HEAD auto-assigned)

---

## PHASE 6 — Activity Summary Upload & Validation ✅

### Requirement P6.1: Activity Summary Upload After Invoice Accepted

After the user clicks "Continue" on the invoice validation card, the assistant prompts for Activity Summary upload.

#### What's Implemented
- `continue_invoice` action → backend returns `activity_summary_upload` type
- Upload card shows: "Upload Activity Summary" label, "Upload from device" button, accepted formats hint (PDF, JPG, PNG, XLS, XLSX, max 10 MB)
- `reupload_activity_summary` action → returns same `activity_summary_upload` prompt
- Frontend `_pickActivitySummaryFile` uses `file_picker` (PDF, JPG, JPEG, PNG, XLS, XLSX, max 10 MB enforced client-side)
- Upload posts to `POST /api/documents/upload` with `documentType=ActivitySummary`, `submissionId`
- Frontend polls `GET /api/documents/{id}/extraction-status` every 3s (max 60s) until `"extracted"`
- On extraction complete, frontend sends `activity_summary_uploaded` action with `documentId`

### Requirement P6.2: Activity Summary Extraction — Dedicated DB Columns

Extracted data from the Activity Summary is stored in both `ExtractedDataJson` and dedicated columns.

#### What's Implemented
- `ActivitySummary` entity has 3 new columns: `DealerName` (nvarchar 500), `TotalDays` (int), `TotalWorkingDays` (int)
- `ActivitySummaryConfiguration.cs` maps these columns with correct types/lengths
- `DocumentService.cs` — after extraction, parses `ActivityData.Rows`:
  - `DealerName` ← `Rows[0].DealerName`
  - `TotalDays` ← `Sum(r.Day)` across all rows
  - `TotalWorkingDays` ← `Sum(r.WorkingDay)` across all rows
- Migration `20260317000001_AddActivitySummaryExtractedColumns` adds the 3 columns to `ActivitySummaries` table
- `ApplicationDbContextModelSnapshot` updated to reflect new columns

#### Database Tables Affected
- `ActivitySummaries` — `DealerName`, `TotalDays`, `TotalWorkingDays` columns added alongside `ExtractedDataJson`

### Requirement P6.3: Activity Summary Validation — AS_DEALER_LOCATION_PRESENT

After extraction completes, backend runs 1 validation rule and shows a structured validation card (same pattern as invoice validation).

#### End-to-End Flow

1. User uploads Activity Summary → `POST /api/documents/upload` → new row in `ActivitySummaries` table
2. Background job runs AI extraction → writes `DealerName`, `TotalDays`, `TotalWorkingDays`, `ExtractedDataJson` to `ActivitySummaries` row
3. Frontend polls `GET /api/documents/{id}/extraction-status` every 3s (max 60s) until `"extracted"`
4. Frontend sends `activity_summary_uploaded` action with `documentId`
5. Backend loads `ActivitySummaries` row, runs 1 validation rule, saves to `ValidationResults`, returns `activity_summary_validation` response
6. Bot shows validation card with rule row + Re-upload and Continue buttons

#### Validation Rule

| Rule Code | Type | Logic |
|-----------|------|-------|
| AS_DEALER_LOCATION_PRESENT | Required | Both `DealerName` and `Location` (from `Rows[0]`) must be non-empty |

- If dealer present but location missing → "Location not detected"
- If location present but dealer missing → "Dealer name not detected"
- If both missing → "Dealer name and location not detected"
- Extracted value shown in card: "DealerName, Location" (comma-separated, whichever are present)

#### Database — What Gets Saved

- `ValidationResults` table — upsert by `DocumentId` (ActivitySummary Id): `AllValidationsPassed`, `RuleResultsJson` (rule as JSON array), `FailureReason`, `DocumentType = ActivitySummary`
- Response is built by reading back from `ValidationResults.RuleResultsJson` (same DB-first pattern as invoice)

#### Backend (AssistantController.cs)

- `HandleActivitySummaryUploaded` — loads `ActivitySummaries` row, calls `RunActivitySummaryValidationRules`, persists to `ValidationResults`, reads back from DB, returns `activity_summary_validation` type
- `RunActivitySummaryValidationRules` — runs `AS_DEALER_LOCATION_PRESENT`: reads `DealerName` from entity column (falls back to `ExtractedDataJson` → `Rows[0].DealerName`), reads `Location` from `ExtractedDataJson` → `Rows[0].Location`
- `HandleContinueAfterActivity` — placeholder returning `text` type (Phase 7 pending)
- `HandleReuploadActivitySummary` — returns `activity_summary_upload` type

#### Frontend

- `assistant_notifier.dart`
  - `uploadActivitySummary(bytes, fileName)` — uploads file, stores `lastDocumentId`, polls extraction status, sends `activity_summary_uploaded`
  - `continueAfterActivity()` — sends `continue_after_activity`
  - `reUploadActivitySummary()` — sends `reupload_activity_summary`
- `chat_screen.dart`
  - `activity_summary_upload` case — upload card with "Upload from device" button, `LinearProgressIndicator` (only on last bot message), format hint
  - `activity_summary_validation` case → calls `_activitySummaryValidationCard(r)`
  - `_activitySummaryValidationCard` — same structure as `_invoiceValidationCard`: pass/fail/warn chips, rule rows, two action buttons
  - Buttons: "Re-upload" (red outlined, calls `reUploadActivitySummary()`) + "Continue with warnings" / "Continue →" (navy filled, calls `continueAfterActivity()`)
  - Loading bar fix: `LinearProgressIndicator` only shows on the last bot message (`isLastBot` check) — prevents old upload cards from showing loading bar when a new upload is in progress

#### Loading Bar Fix

- `_msgList` passes `isLastBot` flag to `_botMsg` — true only if no later bot message exists after this index
- `_botMsg(msg, {bool isLast = false})` — `LinearProgressIndicator` renders only when `isLoading && isLast`
- Prevents invoice upload card from showing loading bar while activity summary is uploading

#### Acceptance Criteria — ALL MET ✅
- AC1: After invoice "Continue", activity summary upload prompt appears
- AC2: Upload card accepts PDF, JPG, PNG, XLS, XLSX (max 10 MB)
- AC3: Frontend polls extraction status before firing validation
- AC4: `AS_DEALER_LOCATION_PRESENT` rule runs against real extracted data
- AC5: Result saved to `ValidationResults` table with `DocumentType = ActivitySummary`
- AC6: Response built from DB read-back (not in-memory) — UI always reflects DB state
- AC7: Validation card shows rule row with color-coded icon, extracted value, error message
- AC8: "Re-upload" button shows upload prompt again
- AC9: "Continue" / "Continue with warnings" button moves to next phase
- AC10: `DealerName`, `TotalDays`, `TotalWorkingDays` saved as dedicated columns in `ActivitySummaries`
- AC11: Loading bar only shows on the currently active upload card, not on previously completed cards

---

## PHASE 5 — Invoice Validation ✅

### Requirement P5.1: Proactive Validation After Invoice Upload

After invoice upload, the assistant waits for AI extraction to complete, then runs 9 validation rules and shows a structured validation card.

#### End-to-End Flow

1. User uploads invoice → `POST /api/documents/upload` → new row in `Invoices` table (new `Guid` per upload)
2. Background job runs AI extraction (Azure Document Intelligence + OpenAI) → writes `InvoiceNumber`, `InvoiceDate`, `TotalAmount`, `GSTNumber`, `ExtractedDataJson` back to the same `Invoices` row
3. Frontend polls `GET /api/documents/{id}/extraction-status` every 3s (max 60s) until status = `"extracted"`
4. Frontend sends `invoice_uploaded` action with `documentId`
5. Backend loads `Invoices` row + linked `POs` row, runs 9 rules, saves to `ValidationResults`, returns `invoice_validation` response
6. Bot shows validation card with rule rows + action buttons

#### 9 Validation Rules

| Rule Code | Type | Logic |
|-----------|------|-------|
| INV_INVOICE_NUMBER_PRESENT | Required | `InvoiceNumber` not null/empty |
| INV_DATE_PRESENT | Required | `InvoiceDate` has value |
| INV_AMOUNT_PRESENT | Required | `TotalAmount` > 0 |
| INV_GST_NUMBER_PRESENT | Required | `GSTNumber` present and 15 chars |
| INV_GST_PERCENT_PRESENT | Required | `GSTPercentage` in `ExtractedDataJson` > 0 |
| INV_HSN_SAC_PRESENT | Required | `HSNSACCode` in `ExtractedDataJson` not empty |
| INV_VENDOR_CODE_PRESENT | Required | `VendorCode` in `ExtractedDataJson` not empty |
| INV_PO_NUMBER_MATCH | Check | Extracted `PONumber` matches `POs.PONumber` |
| INV_AMOUNT_VS_PO_BALANCE | Warning | `TotalAmount` ≤ `POs.RemainingBalance` (warning only, not hard block) |

#### Database — What Gets Saved

- `Invoices` table — new row per upload (never replaced/updated on re-upload)
- `ValidationResults` table — upsert by `DocumentId` (Invoice Id): `AllValidationsPassed`, `RuleResultsJson` (all 9 rules as JSON array), `FailureReason`, `DocumentType = Invoice`
- `DocumentPackages` table — already created in Phase 4, `CurrentStep` stays at 4 until user continues

#### Backend (AssistantController.cs)

- `HandleInvoiceUploaded` — loads Invoice + PO, calls `RunInvoiceValidationRules`, persists to `ValidationResults`, then reads back the saved `ValidationResults` row and deserializes `RuleResultsJson` to build the response (UI always reflects DB data, not in-memory rules)
- `RunInvoiceValidationRules` — all 9 rules, reads direct DB columns for rules 1–4, reads `ExtractedDataJson` for rules 5–8, compares against PO for rules 8–9
- `HandleContinueInvoice` — returns `activity_upload_prompt` (Phase 6 placeholder)
- `HandleReuploadInvoice` — returns `invoice_upload` type so user can upload again
- `GET /api/documents/{id}/extraction-status` — polls `Invoices` row, returns `"extracted"` or `"processing"`
- Bot message is a short summary: "Invoice analysed. X of 9 checks passed." — detail is in the card
- Fallback: if DB read-back fails, in-memory rules are used so the response is never empty

#### Frontend

- `assistant_notifier.dart`
  - `uploadInvoice` — uploads file, stores `lastDocumentId` in state, polls extraction status (max 60s/3s interval), then sends `invoice_uploaded`
  - `continueAfterValidation()` — sends `continue_invoice` with `documentId`
  - `reUploadInvoice()` — sends `reupload_invoice`, bot shows upload prompt again
  - `AssistantState` has `lastDocumentId` field to track current invoice
- `chat_screen.dart`
  - `invoice_validation` case → calls `_invoiceValidationCard(r)`
  - `_invoiceValidationCard` — renders pass/fail/warn count chips, rule rows, two action buttons
  - `_validationRuleRow` — ✅ green / ❌ red / ⚠️ orange icon + label + extracted value + message
  - `_validationChip` — colored pill badge for counts
  - Buttons: "Re-upload invoice" (red outlined) + "Continue with warnings" or "Continue" (navy filled)
- `assistant_response_model.dart` — `validationRules`, `passedCount`, `failedCount`, `warningCount` fields + `ValidationRuleResultModel` class
- `assistant_remote_datasource.dart` — `getDocumentExtractionStatus(documentId)` method

#### Acceptance Criteria — ALL MET ✅
- AC1: After upload, frontend polls extraction status before firing validation
- AC2: All 9 rules run against real extracted data + PO master
- AC3: Results always saved to `ValidationResults` table regardless of pass/fail
- AC3a: Response is built by reading back from `ValidationResults.RuleResultsJson` (not in-memory) — UI always reflects DB state
- AC4: Bot shows short summary message + styled validation card below
- AC5: Card shows color-coded rule rows with extracted values
- AC6: Pass/fail/warn count chips shown
- AC7: "Re-upload invoice" button works — shows upload prompt again
- AC8: "Continue with warnings" / "Continue" button works — moves to next phase
- AC9: `INV_AMOUNT_VS_PO_BALANCE` is warning only, not a hard block
- AC10: Each invoice upload creates a new `Invoices` row (no replace)

---

## Routing (Current)

| Route | Page | Auth |
|-------|------|------|
| `/` | NewLoginPage | No |
| `/agency/dashboard` | AgencyDashboardPage | Yes (AuthWrapper) |
| `/agency/assistant` | ChatScreen | Yes (AuthWrapper) |
| `/agency/conversational-submission` | ConversationalSubmissionPage (old) | Yes |

- Login navigates to `/agency/assistant`
- Dashboard FAB navigates to `/agency/assistant`
- "New Request" button on dashboard navigates to upload page
- `main.dart` uses `MaterialApp` with named routes (active routing system)

---

## Key Backend Files

| File | Purpose |
|------|---------|
| `AssistantController.cs` | All assistant chat actions (greet, create_request, search_po, select_po, select_state, search_state, list_states, invoice_uploaded, continue_invoice, reupload_invoice, activity_summary_uploaded, reupload_activity_summary, continue_after_activity) |
| `DocumentsController.cs` | Document upload (with logging), extraction status, validation, download |
| `DocumentService.cs` | Upload pipeline: file validation → blob storage → Invoice/PO entity creation → AI extraction → save extracted fields to DB columns |
| `PurchaseOrdersController.cs` | PO search/typeahead and paginated list |
| `DocumentsController.cs` | Document upload, extraction status, validation, download |
| `SubmissionsController.cs` | Submission CRUD, approval flow, draft creation |
| `ConversationalSubmissionController.cs` | Old 10-step chatbot (still functional) |
| `ApplicationDbContextSeed.cs` | Seeds agency, user, 3 sample POs |

## Key Frontend Files

| File | Purpose |
|------|---------|
| `chat_screen.dart` | Main chat page, message list, input mode switching (none/po/state) |
| `assistant_notifier.dart` | StateNotifier: greet, sendAction, searchPO, selectPO, searchState, selectState, listAllStates, uploadInvoice, continueAfterValidation, reUploadInvoice, uploadActivitySummary, continueAfterActivity, reUploadActivitySummary. State includes `lastDocumentId` |
| `assistant_remote_datasource.dart` | Dio API calls to /assistant/message, /upload/po, /documents/upload (invoice + activity summary), /documents/{id}/extraction-status |
| `assistant_response_model.dart` | Response DTO: type, message, cards, poItems, states, selectedPO, allowedFormats, submissionId, validationRules, passedCount, failedCount, warningCount. Includes `ValidationRuleResultModel` |
| `assistant_providers.dart` | Riverpod provider definitions |
| `po_search_list.dart` | PO results as OutlinedButton list (number only) |
| `workflow_action_card.dart` | Tappable workflow card with icon |
| `file_upload_card.dart` | File upload widget with drag-drop |
