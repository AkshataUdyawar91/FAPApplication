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
| Phase 6 | Activity Summary Upload & Validation | ✅ DONE |
| Phase 7 | Cost Summary Upload & Validation (7 rules) | ✅ DONE |
| Phase 8 | Team Details Entry Loop | ✅ DONE |
| Phase 9 | Photo Proofs Upload per Team (AI validation) | ✅ DONE |
| Phase 10 | Enquiry Dump Upload & Validation | ✅ DONE |
| Phase 11 | Final Review & Submit / Save as Draft | ✅ DONE |

---

## WORKFLOW ORDER (Complete)

PO Selection → State Selection → Invoice Upload & Validation → Cost Summary Upload & Validation → Activity Summary Upload & Validation → Team Details Loop (per team: name → dealer → dates → confirm → photos) → Enquiry Dump Upload & Validation → Final Review → Submit / Save as Draft

---

## PHASE 1 — Assistant UI and Basic Menu ✅

### Requirement P1.1: Copilot-Style Assistant UI
Copilot-style assistant UI that opens as the main chat experience after login.

#### What's Implemented
- Login navigates to `/agency/assistant` (ChatScreen)
- Greeting message: "Hello! I am your Field Activity Assistant. I can help you manage campaign requests."
- 3 workflow action cards: Create Request, View My Requests, Pending Approvals
- User message bubble shows action in sentence case
- FAB on Agency Dashboard navigates to `/agency/assistant`

#### Backend
- `POST /api/assistant/message` with `action: 'greet'` returns greeting + cards
- `AssistantController.cs` handles all assistant actions via single endpoint

#### Frontend Files
- `chat_screen.dart` — main chat page
- `assistant_chat_panel.dart` — side panel variant of the same chat
- `assistant_notifier.dart` — Riverpod StateNotifier managing chat state
- `assistant_remote_datasource.dart` — Dio-based API calls
- `assistant_response_model.dart` — response DTO
- `assistant_providers.dart` — Riverpod provider definitions

---

## PHASE 2 — PO Search & Selection ✅

### Requirement P2.1: PO Number Typeahead Search
- Tapping "Create Request" → `create_request` action → `po_search` type
- Search bar at bottom, min 3 chars, debounced 400ms
- Results as `OutlinedButton` list (PO number only, navy #003087)
- `select_po` → backend returns `state_selection` type (no PO upload step)

#### Backend Actions
- `create_request` → `po_search`
- `search_po` → `po_search_results` with `poItems`
- `select_po` → `state_selection` (returns `selectedPO` in response)

---

## PHASE 3 — State & Activity Region Selection ✅

### Requirement P3.1: State Selection
- After `select_po`, shows top 4 quick-select state buttons + "More states..." + search bar
- `search_state` → filters 36 Indian states/UTs
- `select_state` → validates, creates Draft `DocumentPackage` with `SelectedPOId` + `ActivityState`, returns `invoice_upload`
- Confirmation: "State set to {state}. Proceeding to the next step..."

#### Backend Actions
- `select_state`, `search_state`, `list_states`
- `HandleSelectState` creates Draft `DocumentPackage` (linked to PO via `SelectedPOId`)

---

## PHASE 4 — Invoice Upload ✅

### Requirement P4.1: Invoice Document Upload
- After state confirmation → `invoice_upload` type
- Two side-by-side buttons: "Upload from device" and "Use Camera"
- Accepted: PDF, JPG, PNG (max 10 MB)
- Upload to `POST /api/documents/upload` with `documentType=Invoice`, `submissionId`
- `LinearProgressIndicator` during upload (only on last bot message)
- On success → `invoice_uploaded` action → `invoice_validation` type

#### Camera Upload (Web)
- On desktop Chrome/Edge: opens full-screen overlay using `getUserMedia` with `facingMode: user` (front camera). User sees live preview, clicks "Capture" or "Cancel".
- Captured image encoded as JPEG (92% quality) — satisfies backend extension + magic bytes validation.
- On mobile: uses `ImagePicker` with `ImageSource.camera`.

#### Key Rules
- Each invoice upload creates a new `Invoices` row (never replaced)
- `submissionId` always passed in payload

---

## PHASE 5 — Invoice Validation ✅

### 9 Validation Rules

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
| INV_AMOUNT_VS_PO_BALANCE | Warning | `TotalAmount` ≤ `POs.RemainingBalance` (warning only) |

- Results saved to `ValidationResults` table regardless of pass/fail
- Response built by reading back from `ValidationResults.RuleResultsJson` (DB-first)
- Validation card: pass/fail/warn chips + rule rows + "Re-upload" + "Continue" buttons

---

## PHASE 7 — Cost Summary Upload & Validation ✅

### Flow
- After invoice "Continue" → `cost_summary_upload`
- Accepted: PDF, JPG, PNG, XLS, XLSX (max 10 MB)
- Frontend polls extraction status before firing validation
- Backend waits up to 60s for extraction (polls every 2s)

### 7 Validation Rules

| Rule Code | Type | Logic |
|-----------|------|-------|
| CS_PLACE_OF_SUPPLY_PRESENT | Required | `PlaceOfSupply` not empty |
| CS_TOTAL_DAYS_PRESENT | Required | `NumberOfDays` > 0 |
| CS_ACTIVATIONS_PRESENT | Required | `NumberOfActivations` > 0 |
| CS_TEAMS_PRESENT | Required | `NumberOfTeams` > 0 |
| CS_ELEMENT_WISE_COSTS_PRESENT | Required | `ElementWiseCostsJson` not empty |
| CS_ELEMENT_WISE_QUANTITY_PRESENT | Required | `ElementWiseQuantityJson` not empty |
| CS_TOTAL_VS_INVOICE | Required | `TotalCost` ≤ latest `Invoice.TotalAmount` for same `PackageId` |

- Team count sourced from `CostSummaries.NumberOfTeams` (primary), fallback to `ExtractedDataJson`
- Dedicated DB columns: `PlaceOfSupply`, `NumberOfDays`, `NumberOfActivations`, `NumberOfTeams`, `TotalCost`, `ElementWiseCostsJson`, `ElementWiseQuantityJson`

---

## PHASE 6 — Activity Summary Upload & Validation ✅

### Flow
- After cost summary "Continue" → `activity_summary_upload`
- Accepted: PDF, JPG, PNG, XLS, XLSX (max 10 MB)
- Frontend polls extraction status before firing validation

### 4 Validation Rules

| Rule Code | Type | Logic |
|-----------|------|-------|
| AS_DEALER_LOCATION_PRESENT | Required | `DealerName` and `Location` from `Rows[0]` must be non-empty |
| AS_TOTAL_DAYS | Info | Always passes — shows `TotalDays` |
| AS_TOTAL_WORKING_DAYS | Info | Always passes — shows `TotalWorkingDays` |
| AS_DAYS_MATCH_COST_SUMMARY | Required | `ActivitySummary.TotalDays` == `CostSummaries.NumberOfDays` |

- Dedicated DB columns: `DealerName`, `TotalDays`, `TotalWorkingDays`
- `continue_after_activity` passes `submissionId` in payload

---

## PHASE 8 — Team Details Entry Loop ✅

### Flow
After activity summary "Continue" → team entry loop begins. Repeats for each team (count from `CostSummaries.NumberOfTeams`).

Per team:
1. **Team Name** — free text input (input mode `team_name`)
2. **Dealer Search** — typeahead search (input mode `dealer`), min 2 chars, debounced 300ms
3. **Date Picker** — start date + end date pickers (Flutter `showDatePicker`), working days auto-calculated excluding Sundays and Indian public holidays (2025–2026)
4. **Confirm** — shows summary card: team name, dealer, city, state, start–end dates, working days. User confirms → saved to `Teams` table
5. **Loop** — repeats for next team until all teams done

### Date Confirmation Message
- Format: "Team {N}: {TeamName} at {DealerName}, {City} from {StartDate} to {EndDate} ({WorkingDays} working days)."
- No "Correct?" word appended

### Re-pick Dates Bug Fix
- "Re-pick dates" button opens date pickers locally then calls `submitTeamDates` directly (no extra action round-trip)

### Backend Actions
- `continue_after_activity` → `start_team_entry` (reads team count from DB)
- `start_team_entry` → `team_count_input` (asks how many teams if not from CS)
- `submit_team_count` → `team_name_input`
- `submit_team_name` → `dealer_search`
- `search_dealer` → `dealer_search_results`
- `select_dealer` → `team_date_input`
- `submit_team_dates` → `team_confirm` (shows confirmation card)
- `confirm_team` → saves to `Teams` table, moves to next team or photo upload

### Teams Table Columns Used
- `CampaignName` (team name), `DealershipName`, `DealershipAddress`, `State`, `StartDate`, `EndDate`, `WorkingDays`, `TeamNumber`, `PackageId`

---

## PHASE 9 — Photo Proofs Upload per Team ✅

### Flow
After all teams confirmed → photo upload per team. Min 3, max 10 photos per team.

#### Upload Options
- Two side-by-side buttons: "Choose from gallery" and "Use Camera"
- Camera (web): opens full-screen overlay using `getUserMedia` with `facingMode: user`. User sees live preview, clicks "Capture" or "Cancel". Image encoded as JPEG (92% quality).
- Camera (mobile): uses `ImagePicker` with `ImageSource.camera`.

### AI Validation (4 rules per photo)

| Rule Code | Logic |
|-----------|-------|
| PHOTO_DATE_VISIBLE | Date visible in EXIF or overlay |
| PHOTO_GPS_VISIBLE | GPS coordinates detected (Latitude + Longitude columns) |
| PHOTO_BLUE_TSHIRT | Person with blue T-shirt detected |
| PHOTO_3W_VEHICLE | 3-wheel vehicle detected |

- Results shown in a `Table` widget: columns = Photo | Date | GPS | Blue T-shirt | 3W Vehicle
- ✅ / ❌ per cell
- `flutter_image_compress` not used — raw bytes sent directly (Windows/web compatibility)
- GPS: `Latitude` and `Longitude` columns already exist on `TeamPhotos` entity

### Replace Photo
- "Replace photo" button shows `AlertDialog` asking for photo number
- Calls `_pickSinglePhotoForReplace` directly
- Backend `HandleReplacePhoto` uses upsert pattern on `ValidationResults`
- Allows +1 overage for single-photo replace (so replacing photo 10 of 10 works)
- `teamNumber` passed from real `payloadJson` (not hardcoded)

### Final Team Summary Card
- After all teams' photos done → `final_team_summary` type
- Shows each team: number, name, dealer, city, state, start–end dates, working days, photo count, photos passed
- "Continue →" button → triggers enquiry dump upload

---

## PHASE 10 — Enquiry Dump Upload & Validation ✅

### Flow
After team summary "Continue" → `enquiry_dump_upload`

- Message: "Please upload Enquiry Dump Document."
- Accepted: XLSX, CSV, PDF (max 10 MB)
- Upload to `POST /api/documents/upload` with `documentType=EnquiryDocument`
- Extraction runs as **background task** (fire-and-forget) — not synchronous
- `HandleEnquiryDumpUploaded` waits up to 60s (polls every 2s) for `ExtractedDataJson` to be populated before running validation

### Excel Column Mapping
Actual columns: `Sr No | Date | Dealership Name | District | Segment | Company Name | Brand | Address | Principal Name | Contact | Secondary Name | Secondary Contact | ...`

Mapped to:
- `dealerName` ← Dealership Name
- `district` ← District
- `customerName` ← Principal Name (fallback: Company Name)
- `customerNumber` ← Contact (column J, first contact column)
- `date` ← Date (YYYY-MM-DD)
- `state` ← inferred from district names (e.g. Muzaffarpur → Bihar)
- `testRideTaken` ← Test Drive column if present
- Phone numbers in scientific notation (e.g. `9.63E+09`) converted to full string

### 9 Validation Rules (≥80% threshold per field)

| Rule Code | Field | Logic |
|-----------|-------|-------|
| EQ_CUSTOMER_PHONE | Customer Phone | ≥80% records have `CustomerNumber` |
| EQ_STATE | State | ≥80% records have `State` |
| EQ_DATE | Date | ≥80% records have `Date` |
| EQ_DEALER_CODE | Dealer Code | ≥80% records have `DealerCode` |
| EQ_DEALER_NAME | Dealer Name | ≥80% records have `DealerName` |
| EQ_DISTRICT | District | ≥80% records have `District` |
| EQ_PINCODE | Pincode | ≥80% records have `Pincode` |
| EQ_CUSTOMER_NAME | Customer Name | ≥80% records have `CustomerName` |
| EQ_TEST_RIDE | Test Ride | ≥80% records have `TestRideTaken` |

- `EnquiryRecord.CustomerPhone` field is named `CustomerNumber` in the DTO
- Results saved to `ValidationResults` table
- Shows total records count + missing phone count
- "Re-upload" + "Continue →" buttons

---

## PHASE 11 — Final Review & Submit ✅

### Flow
After enquiry dump "Continue" → `final_review` type

### Final Review Card
Shows 6 sections, each with a ✅ (all validations passed) or ⚠️ (some failed) header:

| Section | Fields Shown |
|---------|-------------|
| Purchase Order | PO Number, PO Date, Vendor, Amount |
| Invoice | Invoice No, Invoice Date, Amount, GST No |
| Cost Summary | State, No. of Teams, No. of Days, Total Cost |
| Activity Summary | Dealer, Total Days, Working Days |
| Teams | One row per team: Team N → CampaignName \| DealershipName \| StartDate – EndDate |
| Enquiry Dump | Total Records, Missing Phone count |

- PO loaded via `SelectedPOId` (chatbot flow — no uploaded PO document)
- Validation pass/fail per section read from `ValidationResults` table

### Buttons
- **Submit** → `submit_from_chat` action → validates all required docs, generates FAP number via `ISubmissionNumberService`, transitions `Draft → Uploaded`, returns `submit_success` with FAP number
- **Save as Draft** → `save_draft_from_chat` action → package already in Draft state, returns `draft_saved` confirmation

### Submit Validation
- `SelectedPOId` must be set (PO selected via typeahead)
- At least one invoice
- Cost Summary present
- Activity Summary present
- Enquiry Dump present
- At least one team with ≥3 photos

### FAP Number Format
`CIQ-{year}-{sequence:D5}` e.g. `CIQ-2026-00001`

---

## UI Bugs Fixed

| Bug | Fix |
|-----|-----|
| Re-pick dates opens pickers again | Opens date pickers locally then calls `submitTeamDates` directly |
| Replace photo shows wrong dialog | `AlertDialog` asks for photo number, calls `_pickSinglePhotoForReplace` directly |
| Loading spinner on old messages | `_botMsg` accepts `isLast` param, `LinearProgressIndicator` only renders when `isLoading && isLast` |
| "Correct?" word in date confirmation | Removed |
| Camera button on invoice upload | Removed — only "Upload from device" |

---

## Network / Timeout Settings

- Dio `receiveTimeout`: 10 minutes (raised from 3 min to handle slow AI extraction calls)
- Enquiry dump extraction: background task, `HandleEnquiryDumpUploaded` polls DB up to 60s
- Cost summary extraction: background task, `HandleCostSummaryUploaded` polls DB up to 60s

---

## Key Backend Files

| File | Purpose |
|------|---------|
| `AssistantController.cs` | All assistant chat actions — full flow phases 1–11 |
| `DocumentService.cs` | Upload pipeline: validation → blob → entity creation → AI extraction → DB columns |
| `DocumentAgent.cs` | AI extraction: PO, Invoice, CostSummary, ActivitySummary, TeamPhoto, EnquiryDump |
| `DocumentsController.cs` | Upload endpoint, extraction status polling |
| `SubmissionsController.cs` | Submission CRUD, approval flow |
| `SubmissionNumberService.cs` | Generates `CIQ-{year}-{seq}` FAP numbers |

## Key Frontend Files

| File | Purpose |
|------|---------|
| `chat_screen.dart` | Main chat page — all card renderers for all phases |
| `assistant_chat_panel.dart` | Side panel variant — mirrors chat_screen.dart |
| `assistant_notifier.dart` | StateNotifier — all actions for all phases |
| `assistant_remote_datasource.dart` | Dio API calls — upload, sendMessage, extraction status |
| `assistant_response_model.dart` | Response DTO — all fields including `reviewSections`, `teamSummaries`, `photoResults` |
| `dio_client.dart` | Dio config — receiveTimeout: 10 min |

---

## Database Tables Used

| Table | Purpose |
|-------|---------|
| `DocumentPackages` | One per submission — holds `SelectedPOId`, `ActivityState`, `State` (Draft/Uploaded), `SubmissionNumber` |
| `POs` | Purchase orders — searched via typeahead |
| `Invoices` | One row per upload — `InvoiceNumber`, `InvoiceDate`, `TotalAmount`, `GSTNumber`, `ExtractedDataJson` |
| `CostSummaries` | `PlaceOfSupply`, `NumberOfTeams`, `NumberOfDays`, `TotalCost`, `ElementWiseCostsJson` |
| `ActivitySummaries` | `DealerName`, `TotalDays`, `TotalWorkingDays`, `ExtractedDataJson` |
| `Teams` | `CampaignName`, `DealershipName`, `StartDate`, `EndDate`, `WorkingDays`, `TeamNumber` |
| `TeamPhotos` | `Latitude`, `Longitude`, `BlueTshirtPresent`, `ThreeWheelerPresent`, `DateVisible`, `ExtractedMetadataJson` |
| `EnquiryDocuments` | `ExtractedDataJson` (list of `EnquiryRecord`) |
| `ValidationResults` | `DocumentId`, `DocumentType`, `AllValidationsPassed`, `RuleResultsJson`, `FailureReason` |


