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
| Phase 6–10 | Full Submission Flow | ✅ Previously implemented |

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
- **Phase 6**: Team Details Entry Loop (team name, dealer, dates, working days, photo proofs with AI vision)
- **Phase 7**: Enquiry Dump Upload (mandatory, Excel/CSV/PDF)
- **Phase 8**: Additional Documents Upload (optional with skip)
- **Phase 9**: Final Review & Submit (summary card, Draft → Submitted, CIRCLE HEAD auto-assigned)
- **Phase 10**: Draft Persistence & Session Resume

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
| `AssistantController.cs` | All assistant chat actions (greet, create_request, search_po, select_po, select_state, search_state, list_states, invoice_uploaded) |
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
| `assistant_notifier.dart` | StateNotifier: greet, sendAction, searchPO, selectPO, searchState, selectState, listAllStates, uploadInvoice, continueAfterValidation, reUploadInvoice, uploadPOFile. State includes `lastDocumentId` |
| `assistant_remote_datasource.dart` | Dio API calls to /assistant/message, /upload/po, /documents/upload (invoice), /documents/{id}/extraction-status |
| `assistant_response_model.dart` | Response DTO: type, message, cards, poItems, states, selectedPO, allowedFormats, submissionId, validationRules, passedCount, failedCount, warningCount. Includes `ValidationRuleResultModel` |
| `assistant_providers.dart` | Riverpod provider definitions |
| `po_search_list.dart` | PO results as OutlinedButton list (number only) |
| `workflow_action_card.dart` | Tappable workflow card with icon |
| `file_upload_card.dart` | File upload widget with drag-drop |
