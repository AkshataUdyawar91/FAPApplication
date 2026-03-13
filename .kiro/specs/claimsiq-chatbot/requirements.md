# ClaimsIQ — T1: Agency Conversational Submission — Requirements

## Requirement 1: Conversational Submission State Machine
Build a server-side `ConversationalSubmissionService` that drives a 10-step guided chatbot flow for agency FAP claim submission. The service must track the current step per session, persist progress to the database, and expose a single chat endpoint that accepts user messages/actions and returns bot responses with buttons/cards.

### Acceptance Criteria
- AC1: Service maintains a per-submission state machine with steps: `Greeting → POSelection → StateSelection → InvoiceUpload → ActivitySummaryUpload → CostSummaryUpload → TeamDetailsLoop → EnquiryDumpUpload → AdditionalDocsUpload → FinalReview`
- AC2: Each step transition is persisted so sessions can resume after timeout
- AC3: The chat endpoint returns structured JSON responses containing: message text, action buttons, card data, current step, and submission progress percentage
- AC4: Invalid step transitions are rejected with helpful error messages

## Requirement 2: PO Search & Selection (Step 2)
Agencies must be able to find and select a Purchase Order from their pre-synced SAP POs. Support two paths: direct PO number typeahead search, and progressive filtering (by date, amount, pagination).

### Acceptance Criteria
- AC1: `GET /api/purchase-orders/search?vendorCode={code}&q={partial}&status=Open,PartiallyConsumed` returns matching POs with typeahead (min 3 chars, max 10 results, debounce 300ms client-side)
- AC2: `GET /api/purchase-orders?vendorCode={code}&dateFrom=&dateTo=&amountMin=&amountMax=&sort=poDate:desc&page=1&size=5` supports progressive filtering with pagination
- AC3: Zero results returns explanation (PO closed, not synced, etc.) with action buttons
- AC4: On PO confirmation, `POST /api/submissions/draft { poId, agencyId }` creates a draft `DocumentPackage` with new `Draft` state
- AC5: PO entity must have `RemainingBalance`, `POStatus` (Open/PartiallyConsumed/Closed), and `VendorCode` fields for search/filter queries

## Requirement 3: State & Activity Region Selection (Step 3)
Agency enters the state where the activity was performed. This state is stored on the submission and used later for CIRCLE HEAD auto-assignment.

### Acceptance Criteria
- AC1: Bot shows agency's top 4 most frequently used states derived from: `SELECT TOP 4 State FROM DocumentPackages WHERE AgencyId = @agencyId GROUP BY State ORDER BY COUNT(*) DESC`
- AC2: `[More states...]` shows full searchable list of 36 Indian states/UTs with typeahead
- AC3: `PATCH /api/submissions/{id} { state: 'Maharashtra' }` updates the submission. State is NOT nullable — enforced at submit time
- AC4: `DocumentPackage` entity must have a `State` column (string, nullable until submit)

## Requirement 4: Proactive Document Validation at Upload Time (Steps 4-6)
Each document (Invoice, Activity Summary, Cost Summary) is validated immediately after upload — not batched at the end. The bot shows pass/fail/warning per field in real-time.

### Acceptance Criteria
- AC1: `POST /api/documents/upload { submissionId, documentType }` uploads to Blob Storage, triggers extraction via DocumentAgent, then runs proactive validation rules
- AC2: `GET /api/documents/{id}/status` returns extraction status (Pending/Processing/Completed/Failed) — client polls every 3s
- AC3: `GET /api/documents/{id}/validation-results` returns per-field validation results with rule codes, pass/fail/warning status, and extracted values
- AC4: Invoice validation rules implemented: `INV_INVOICE_NUMBER_PRESENT`, `INV_DATE_PRESENT`, `INV_AMOUNT_PRESENT`, `INV_GST_NUMBER_PRESENT`, `INV_GST_PERCENT_PRESENT`, `INV_HSN_SAC_PRESENT`, `INV_VENDOR_CODE_PRESENT`, `INV_PO_NUMBER_MATCH`, `INV_AMOUNT_VS_PO_BALANCE`
- AC5: Activity Summary rules: `AS_DEALER_LOCATION_PRESENT`, `AS_DAYS_MATCH_COST_SUMMARY`, `AS_DAYS_MATCH_TEAM_DETAILS`
- AC6: Cost Summary rules: `CS_PLACE_OF_SUPPLY_PRESENT`, `CS_TOTAL_DAYS_PRESENT`, `CS_TOTAL_VS_INVOICE`, `CS_ELEMENT_COST_VS_RATES`
- AC7: Re-upload soft-deletes old document and links new one. Warnings carry forward to CIRCLE HEAD review as `ProactiveValidationResult`

## Requirement 5: Team Details Entry Loop (Step 7)
Collect per-team data sequentially: team name, dealer selection, activity dates/working days, and photo proofs with AI vision validation.

### Acceptance Criteria
- AC1: `POST /api/team-details { submissionId, teamName, dealerCode, dealerName, city, startDate, endDate, workingDays }` creates a team record
- AC2: `PUT /api/team-details/{id}` updates team details
- AC3: `GET /api/state/dealers?state={state}&q={searchTerm}&size=5` provides dealer typeahead from StateMapping table
- AC4: If dealer not found, allow manual text entry — store as unverified, flag for CIRCLE HEAD review
- AC5: Working days auto-calculated as business days (exclude Sundays) between start and end dates. User can adjust for holidays
- AC6: Photo upload: min 3, max 10 per team. Client-side compression to ≤500KB (canvas.toBlob quality=0.7, max 1920px)
- AC7: Per-photo AI vision validation via Azure OpenAI checks: Date overlay, GPS overlay, Blue T-shirt detection, 3W Vehicle detection. Results stored per-photo in ValidationResults
- AC8: Bot shows thumbnail grid with per-photo pass/fail. Actions: Replace, Add more, Done with team
- AC9: Progress indicator shows "Team X of Y done" throughout the loop

## Requirement 6: Enquiry Dump Upload — Mandatory (Step 8)
Enquiry dump is mandatory evidence of enquiry generation. Hard-blocked if missing.

### Acceptance Criteria
- AC1: Accepted formats: Excel (.xlsx, .csv) or PDF
- AC2: Backend extracts enquiry records. Bot shows: total records, complete vs incomplete, fields checked per record (State, Date, Dealer Code, Dealer Name, District, Pincode, Customer Name, Customer Phone, Test Ride), sample record
- AC3: Hard block: submission cannot transition from Draft to Submitted without `DocumentType = 'EnquiryDump'` document
- AC4: Customer phone numbers stored with AES-256 column-level encryption
- AC5: `SyncedToWarehouse = 0` initially; J7 (Enquiry Warehouse Sync) handles nightly push

## Requirement 7: Additional Documents Upload — Optional (Step 9)
Optional supporting documents with a skip button.

### Acceptance Criteria
- AC1: Bot prompts for additional documents with `[Upload]` and `[Skip →]` buttons
- AC2: Multiple additional documents allowed, stored in `AdditionalDocuments` table

## Requirement 8: Final Review & Submit (Step 10)
Comprehensive summary card showing everything before final submission.

### Acceptance Criteria
- AC1: Summary card displays: PO details, State, Invoice (number, amount, validation status), Cost Summary, Activity Summary, all Teams (dealer, city, days, photo count/status), Enquiry Dump (record count, completeness), overall totals
- AC2: `[Edit something]` navigates back to specific section; other data preserved
- AC3: `POST /api/submissions/{id}/submit` validates: all mandatory documents present (Invoice, CostSummary, EnquiryDump, ActivitySummary, min 1 team with min 3 photos), State is set
- AC4: On submit: status transitions `Draft → Submitted`, CIRCLE HEAD auto-assigned via `StateMapping WHERE State = submission.State AND IsActive = 1` with load balancing (least pending submissions)
- AC5: Background pipeline triggered: J4 (Full Validation) → J5 (Confidence Score) → J6 (Notification)
- AC6: Bot confirms with: Submission ID (format `CIQ-YYYY-XXXXX`), assigned reviewer name, expected review timeline (24-48 hours)
- AC7: If no CIRCLE HEAD found for state, flag for manual assignment

## Requirement 9: Draft Persistence & Session Resume
Submissions are saved as drafts and resumable after session timeout.

### Acceptance Criteria
- AC1: New `Draft` value added to `PackageState` enum (value = 0, before Uploaded)
- AC2: On return, bot detects existing draft: "Welcome back! You have a draft submission for PO X. [Resume] [Start over]"
- AC3: Resume loads from last completed step. All previously uploaded documents and entered data preserved
- AC4: `GET /api/submissions/{id}` returns full submission detail including current step for resume

## Requirement 10: Duplicate Submission Detection
Warn when same PO + invoice number combination already exists.

### Acceptance Criteria
- AC1: On invoice upload, check: `SELECT FROM DocumentPackages dp JOIN Invoices i ON dp.Id = i.PackageId WHERE dp.PO.PONumber = @poNumber AND i.InvoiceNumber = @invoiceNum AND dp.IsDeleted = 0 AND dp.State NOT IN ('Rejected')`
- AC2: If duplicate found, bot warns: "Submission CIQ-X already exists for this PO with invoice INV-X. [View existing] [Submit anyway (new version)]"

## Requirement 11: Edge Cases & Error Handling
Robust handling of all failure scenarios.

### Acceptance Criteria
- AC1: Upload failure: client retries 3x with exponential backoff. Bot shows "Upload failed. [Retry upload]". Draft preserved
- AC2: AI extraction timeout (>60s): switch from polling to push via SignalR. Bot: "Taking longer than usual. I'll notify you when done."
- AC3: Wrong document type: DocumentAgent classification confidence <70% triggers warning: "This looks like a Cost Summary, not an Invoice. [Upload correct] [Proceed anyway]"
- AC4: No open POs: "No open POs found. POs sync every 4 hours. [Check status] [Contact support]"
- AC5: Photo >10MB before compression: auto-compress. If still >10MB: "Photo too large. Please use lower resolution." If original >20MB: reject outright
- AC6: Enquiry dump unexpected format: "Couldn't extract records. [Re-upload] [Upload as additional document]"

## Requirement 12: Submission ID Format
Submissions use ClaimsIQ branding format.

### Acceptance Criteria
- AC1: Submission number format: `CIQ-YYYY-XXXXX` (e.g., CIQ-2026-00042)
- AC2: Auto-generated sequential number per year
