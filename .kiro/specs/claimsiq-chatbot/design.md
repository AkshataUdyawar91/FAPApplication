# ClaimsIQ — T1: Agency Conversational Submission — Design

## Architecture Overview

The conversational chatbot is built on top of the existing .NET 8 backend (`BajajDocumentProcessing`). The frontend is integrated into the existing Flutter app as a new `conversational_submission` feature module. The chatbot is NOT a separate service — it's a new controller + service layer that orchestrates the existing domain entities, services, and infrastructure.

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App (Conversational Submission Feature)        │
│  - ChatWindow widget with message bubbles               │
│  - ActionButton cards (tappable)                        │
│  - File upload with client-side compression             │
│  - SignalR client for push notifications                │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTPS / WebSocket
┌──────────────────────▼──────────────────────────────────┐
│  .NET 8 Web API (Existing Backend)                      │
│                                                         │
│  NEW:                                                   │
│  ├─ ConversationalSubmissionController                  │
│  │   POST /api/conversation/message                     │
│  │   GET  /api/conversation/{submissionId}/state        │
│  │   POST /api/conversation/{submissionId}/resume       │
│  │                                                      │
│  ├─ PurchaseOrdersController                            │
│  │   GET  /api/purchase-orders/search                   │
│  │   GET  /api/purchase-orders                          │
│  │                                                      │
│  ├─ StateController                                    │
│  │   GET  /api/state/dealers                             │
│  │                                                      │
│  ├─ ConversationalSubmissionService (State Machine)     │
│  ├─ ProactiveValidationService                          │
│  └─ SignalR Hub (NotificationHub)                       │
│                                                         │
│  EXISTING (reused as-is):                               │
│  ├─ DocumentsController (upload, get, download)         │
│  ├─ SubmissionsController (submit, approve, reject)     │
│  ├─ HierarchicalSubmissionController (teams, photos)    │
│  ├─ DocumentAgent (extraction via Doc Intelligence)     │
│  ├─ ValidationAgent (15+ validation checks)             │
│  ├─ WorkflowOrchestrator (J4→J5→J6 pipeline)           │
│  ├─ ConfidenceScoreService                              │
│  ├─ NotificationAgent                                   │
│  └─ ChatService (analytics chat — separate from this)   │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│  Azure Infrastructure (Existing)                        │
│  ├─ Azure SQL (all 21 tables)                           │
│  ├─ Azure Blob Storage (documents, photos)              │
│  ├─ Azure Document Intelligence (PDF/image extraction)  │
│  ├─ Azure OpenAI GPT-4 (classification, vision, chat)   │
│  └─ Entra ID (authentication)                           │
└─────────────────────────────────────────────────────────┘
```

## Database Changes

### 1. Add `Draft` to PackageState Enum
```csharp
public enum PackageState
{
    Draft = 0,        // NEW — created when agency starts conversational flow
    Uploaded = 1,     // existing — after final submit, before workflow processing
    Extracting = 2,
    Validating = 3,
    PendingASM = 4,
    ASMRejected = 5,
    PendingRA = 6,
    RARejected = 7,
    Approved = 8
}
```

### 2. Add Fields to DocumentPackage
```csharp
// New fields on DocumentPackage entity
public string? State { get; set; }                    // Activity region (Maharashtra, Gujarat, etc.)
public string? SubmissionNumber { get; set; }          // CIQ-2026-00042 format
public int CurrentStep { get; set; } = 0;             // Conversational flow step (0-9)
public Guid? AssignedCircleHeadUserId { get; set; }   // CIRCLE HEAD assigned at submit
public Guid? SelectedPOId { get; set; }               // PO selected in step 2 (FK to POs table)
public int VersionNumber { get; set; } = 1;           // Incremented on duplicate "submit anyway" re-submissions
```

### 3. Add Fields to PO Entity
```csharp
// New fields on PO entity for search/filter
public string? VendorCode { get; set; }       // Agency vendor code from SAP
public string? POStatus { get; set; }         // Open, PartiallyConsumed, Closed
public decimal? RemainingBalance { get; set; } // Remaining PO balance
```

### 4. New Table: StateMapping
```sql
CREATE TABLE StateMappings (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    State NVARCHAR(100) NOT NULL,
    DealerCode NVARCHAR(50) NOT NULL,
    DealerName NVARCHAR(200) NOT NULL,
    City NVARCHAR(100),
    CircleHeadUserId UNIQUEIDENTIFIER,  -- FK to Users
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0
);
```

### 5. New Table: SubmissionSequence
```sql
CREATE TABLE SubmissionSequences (
    Year INT PRIMARY KEY,
    LastNumber INT NOT NULL DEFAULT 0
);
```

### 6. New Table: AdditionalDocuments
```sql
CREATE TABLE AdditionalDocuments (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    PackageId UNIQUEIDENTIFIER NOT NULL,          -- FK to DocumentPackages
    FileName NVARCHAR(500) NOT NULL,
    BlobUrl NVARCHAR(2000) NOT NULL,
    ContentType NVARCHAR(100),
    FileSizeBytes BIGINT,
    UploadedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0,
    CONSTRAINT FK_AdditionalDocuments_DocumentPackages FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id)
);
```

### 7. Add ProactiveValidationResult Fields
The existing `ValidationResult` entity (polymorphic by DocumentType + DocumentId) is reused. Add:
```csharp
// New field on ValidationResult
public string? RuleResultsJson { get; set; }  // JSON array of { ruleCode, type, passed, extractedValue, expectedValue }
```

## Conversational State Machine Design

The `ConversationalSubmissionService` is the brain of the chatbot. It receives a user action (message, button tap, file upload) and returns a structured bot response.

### Step Enum
```csharp
public enum ConversationStep
{
    Greeting = 0,
    POSelection = 1,
    StateSelection = 2,
    InvoiceUpload = 3,
    ActivitySummaryUpload = 4,
    CostSummaryUpload = 5,
    TeamDetailsLoop = 6,
    EnquiryDumpUpload = 7,
    AdditionalDocsUpload = 8,
    FinalReview = 9,
    Submitted = 10
}
```

### Chat Message Contract
```csharp
// Request from frontend
public class ConversationRequest
{
    public Guid? SubmissionId { get; set; }     // null for new submission
    public string Action { get; set; }           // "start", "select_po", "confirm", "upload", "skip", "submit", "edit", "resume"
    public string? Message { get; set; }         // free text input
    public string? PayloadJson { get; set; }     // structured data (PO id, state name, team details, etc.)
}

// Response to frontend
public class ConversationResponse
{
    public Guid SubmissionId { get; set; }
    public int CurrentStep { get; set; }
    public string BotMessage { get; set; }
    public List<ActionButton> Buttons { get; set; }
    public CardData? Card { get; set; }           // validation results, summary, PO list, etc.
    public bool RequiresFileUpload { get; set; }
    public string? FileUploadType { get; set; }   // "Invoice", "CostSummary", etc.
    public int ProgressPercent { get; set; }
    public string? Error { get; set; }
}

public class ActionButton
{
    public string Label { get; set; }
    public string Action { get; set; }
    public string? PayloadJson { get; set; }
}
```

### Step Flow Logic
```
Step 0 (Greeting):
  → GET /api/auth/me → populate agencyName
  → Return greeting + [Submit New Claim] [Check Status] [My Submissions]
  → On "Submit New Claim" → Step 1

Step 1 (POSelection):
  → Return "Do you have the PO number?" + [Yes, I have it] [Help me find it]
  → Path A: typeahead search via GET /api/purchase-orders/search
  → Path B: show recent 5 POs, filter buttons
  → On PO confirmed → POST /api/submissions/draft → Step 2

Step 2 (StateSelection):
  → Query frequent states for agency
  → Return state buttons + [More states...]
  → On state selected → PATCH /api/submissions/{id} → Step 3

Step 3 (InvoiceUpload):
  → Return upload prompt
  → On upload → POST /api/documents/upload → poll status → run proactive validation
  → Return validation card with pass/fail/warning
  → On continue/re-upload → Step 4

Step 4 (ActivitySummaryUpload): same pattern as Step 3
Step 5 (CostSummaryUpload): same pattern as Step 3

Step 6 (TeamDetailsLoop):
  → Use team count from cost summary or ask
  → For each team: collect name → dealer → dates → photos
  → Photos: POST /api/documents/upload per photo → AI vision validation
  → After all teams → Step 7

Step 7 (EnquiryDumpUpload):
  → Hard block if skip attempted — submission cannot proceed without EnquiryDump
  → Accepted formats: Excel (.xlsx, .csv) or PDF
  → On upload → extract enquiry records → validate per-record fields:
    State, Date, Dealer Code, Dealer Name, District, Pincode, Customer Name, Customer Phone, Test Ride
  → Customer phone numbers encrypted with AES-256 column-level encryption before persistence
  → Set `SyncedToWarehouse = 0` (J7 Enquiry Warehouse Sync handles nightly push)
  → Bot shows summary card: total records, complete vs incomplete count, sample record preview
  → On continue → Step 8

Step 8 (AdditionalDocsUpload):
  → Optional with [Skip →] button → Step 9

Step 9 (FinalReview):
  → Build comprehensive summary from all submission data
  → [Submit ✅] or [Edit something]
  → On submit → POST /api/submissions/{id}/submit → CIRCLE HEAD assignment → pipeline trigger
```

## API Endpoint Design

All new endpoints follow existing patterns: `[ApiController]`, `[Route("api/[controller]")]`, JWT auth via `[Authorize]`, `IApplicationDbContext` injected, `CancellationToken` propagated.

### New Endpoints

| Method | Route | Controller | Purpose | Request | Response |
|--------|-------|------------|---------|---------|----------|
| POST | `/api/conversation/message` | ConversationalSubmissionController | Process a chat action and return next bot response | `ConversationRequest` | `ConversationResponse` |
| GET | `/api/conversation/{submissionId}/state` | ConversationalSubmissionController | Get current conversation state for resume | — | `{ submissionId, currentStep, progressPercent, lastCompletedStep }` |
| POST | `/api/conversation/{submissionId}/resume` | ConversationalSubmissionController | Resume a draft submission | — | `ConversationResponse` (from last completed step) |
| GET | `/api/purchase-orders/search` | PurchaseOrdersController | Typeahead PO search | `?vendorCode=&q=&status=` | `List<POSearchResult>` (max 10) |
| GET | `/api/purchase-orders` | PurchaseOrdersController | Filtered PO list with pagination | `?vendorCode=&dateFrom=&dateTo=&amountMin=&amountMax=&sort=&page=&size=` | `PagedResult<POListItem>` |
| GET | `/api/state/dealers` | StateController | Dealer typeahead within state | `?state=&q=&size=` | `List<DealerResult>` |
| POST | `/api/submissions/draft` | SubmissionsController (extend) | Create draft DocumentPackage | `{ poId, agencyId }` | `{ submissionId, submissionNumber }` |
| PATCH | `/api/submissions/{id}` | SubmissionsController (extend) | Update submission fields (state, etc.) | `{ state }` | `204 No Content` |
| GET | `/api/documents/{id}/status` | DocumentsController (extend) | Poll extraction status | — | `{ status, extractedAt, error }` |
| GET | `/api/documents/{id}/validation-results` | DocumentsController (extend) | Per-document proactive validation results | — | `{ rules: [{ ruleCode, passed, type, extractedValue, expectedValue }] }` |
| POST | `/api/team-details` | HierarchicalSubmissionController (extend) | Create team record in conversational flow | `{ submissionId, teamName, dealerCode, dealerName, city, startDate, endDate, workingDays }` | `{ teamId }` |
| PUT | `/api/team-details/{id}` | HierarchicalSubmissionController (extend) | Update team record | same as POST | `204 No Content` |

### Modified Existing Endpoints

| Endpoint | Change |
|----------|--------|
| `POST /api/submissions/{id}/submit` | Add completeness validation (all mandatory docs present, state set), CIRCLE HEAD auto-assignment, submission number generation, state enforcement (`Draft → Submitted` only) |
| `POST /api/documents/upload` | Accept `submissionId` + `documentType` for conversational flow. Trigger proactive validation after extraction completes |
| `GET /api/submissions/{id}` | Include `currentStep`, `submissionNumber`, `assignedCircleHeadUserId`, `state`, `selectedPOId` in response |

## ProactiveValidationService Design

A new service that runs per-document validation immediately after extraction, returning granular rule-level results. This is distinct from the existing `IValidationAgent.ValidatePackageAsync()` which validates the entire package post-submit.

```csharp
public interface IProactiveValidationService
{
    /// <summary>
    /// Validates a single document immediately after extraction.
    /// Returns per-rule results for real-time display in the chat UI.
    /// </summary>
    Task<ProactiveValidationResponse> ValidateDocumentAsync(
        Guid documentId,
        DocumentType documentType,
        Guid packageId,
        CancellationToken ct = default);
}

public class ProactiveValidationResponse
{
    public Guid DocumentId { get; set; }
    public DocumentType DocumentType { get; set; }
    public bool AllPassed { get; set; }
    public int PassCount { get; set; }
    public int FailCount { get; set; }
    public int WarningCount { get; set; }
    public List<ProactiveRuleResult> Rules { get; set; } = new();
}

public class ProactiveRuleResult
{
    public string RuleCode { get; set; }        // e.g. "INV_INVOICE_NUMBER_PRESENT"
    public string Type { get; set; }            // "Required" or "Check"
    public bool Passed { get; set; }
    public string? ExtractedValue { get; set; }
    public string? ExpectedValue { get; set; }
    public string? Message { get; set; }        // Human-readable explanation
    public string Severity { get; set; }        // "Pass", "Fail", "Warning"
}
```

### Validation Rule Implementation

The service loads the relevant document + PO data from DB, then runs rule functions:

- Invoice rules (9 rules): Field presence checks on extracted JSON + cross-checks against PO (number match, amount vs balance)
- Activity Summary rules (3 rules): Field presence + cross-check days against cost summary and team entries
- Cost Summary rules (4 rules): Field presence + total vs invoice amount + element costs vs rate master
- Photo rules (4 rules): Delegated to existing `DocumentAgent.ExtractPhotoMetadataAsync()` via Azure OpenAI Vision:
  - `PHOTO_DATE_OVERLAY` — Date text overlay detected in image
  - `PHOTO_GPS_OVERLAY` — GPS/location overlay detected in image
  - `PHOTO_BLUE_TSHIRT` — Blue T-shirt (agency uniform) detected on person(s)
  - `PHOTO_3W_VEHICLE` — 3-wheeler vehicle detected in frame
  Results stored per-photo in `ValidationResult.RuleResultsJson`.

Results are persisted to `ValidationResult.RuleResultsJson` for the document, so they carry forward to CIRCLE HEAD review.

## SignalR Hub Design

A new `SubmissionNotificationHub` for real-time push notifications. The primary use case is the polling-to-push fallback: the client polls `GET /api/documents/{id}/status` every 3 seconds for extraction status. If extraction exceeds 60 seconds, the client stops polling and relies on SignalR push events instead.

```csharp
[Authorize]
public class SubmissionNotificationHub : Hub
{
    /// <summary>
    /// Client joins a submission-specific group to receive updates.
    /// </summary>
    public async Task JoinSubmission(Guid submissionId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"submission-{submissionId}");
    }

    public async Task LeaveSubmission(Guid submissionId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"submission-{submissionId}");
    }
}

// Server-side push (called from WorkflowOrchestrator or ProactiveValidationService):
// await _hubContext.Clients.Group($"submission-{submissionId}")
//     .SendAsync("ExtractionComplete", new { documentId, documentType, status });
// await _hubContext.Clients.Group($"submission-{submissionId}")
//     .SendAsync("ValidationComplete", new { documentId, validationResults });
```

### SignalR Events

| Event | Payload | Trigger |
|-------|---------|---------|
| `ExtractionComplete` | `{ documentId, documentType, status, extractedFields }` | DocumentAgent finishes extraction |
| `ValidationComplete` | `{ documentId, rules[] }` | ProactiveValidationService finishes |
| `SubmissionStatusChanged` | `{ submissionId, newStatus, assignedTo }` | Status transition (submit, approve, reject) |

## Frontend Design (Flutter — Integrated into Existing App)

### Technology Stack
- Flutter 3.2+ (existing app in `frontend/`)
- Dart with Riverpod for state management
- Dio for HTTP client (existing `dio_client.dart`)
- Go Router for navigation (existing `app_router.dart`)
- `signalr_netcore` package for SignalR real-time updates
- `image_picker` (existing) + `file_picker` (existing) for file/camera capture
- `flutter_image_compress` for client-side photo compression

### Feature Architecture (Clean Architecture)

The chatbot is added as a new feature module `conversational_submission` under `lib/features/`, following the same Clean Architecture pattern as existing features (auth, chat, submission, etc.).

```
lib/features/conversational_submission/
├── data/
│   ├── datasources/
│   │   ├── conversation_remote_datasource.dart    # API calls to /api/conversation/*
│   │   └── signalr_datasource.dart                # SignalR connection lifecycle
│   ├── models/
│   │   ├── conversation_request_model.dart        # ConversationRequest DTO
│   │   ├── conversation_response_model.dart       # ConversationResponse DTO
│   │   ├── action_button_model.dart               # ActionButton DTO
│   │   ├── card_data_model.dart                   # CardData base + subtypes
│   │   ├── po_search_result_model.dart            # POSearchResult DTO
│   │   ├── dealer_result_model.dart               # DealerResult DTO
│   │   └── validation_result_model.dart           # ProactiveRuleResult DTO
│   └── repositories/
│       └── conversation_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── conversation_message.dart              # Chat message entity
│   │   ├── conversation_state.dart                # Step + progress state
│   │   ├── po_search_result.dart
│   │   ├── dealer_result.dart
│   │   └── validation_rule_result.dart
│   ├── repositories/
│   │   └── conversation_repository.dart           # Abstract repository
│   └── usecases/
│       ├── send_message_usecase.dart
│       ├── resume_submission_usecase.dart
│       ├── search_purchase_orders_usecase.dart
│       └── search_dealers_usecase.dart
└── presentation/
    ├── pages/
    │   └── conversational_submission_page.dart     # Main chat page
    ├── providers/
    │   ├── conversation_notifier.dart             # Riverpod StateNotifier for chat state
    │   ├── conversation_providers.dart            # Provider definitions
    │   ├── signalr_notifier.dart                  # SignalR connection state
    │   └── file_upload_notifier.dart              # Upload + compression + retry state
    └── widgets/
        ├── chat_window.dart                       # Scrollable message list + input area
        ├── bot_message_bubble.dart                # Bot bubble with card rendering
        ├── user_message_bubble.dart               # User bubble for text/action confirmations
        ├── action_buttons_row.dart                # Tappable button row below bot messages
        ├── po_card.dart                           # PO selection card
        ├── validation_card.dart                   # Per-document validation results card
        ├── team_summary_card.dart                 # Team details summary card
        ├── photo_grid.dart                        # Thumbnail grid with per-photo status
        ├── final_review_card.dart                 # Comprehensive pre-submit summary
        ├── file_upload_zone.dart                  # File picker + camera capture zone
        └── step_progress_bar.dart                 # Step progress indicator (0-100%)
```

### Chat Flow UX

1. Messages render top-to-bottom in a `ListView.builder` with `reverse: false` and auto-scroll via `ScrollController.animateTo`.
2. Bot messages appear with a typing indicator (300ms delay via `Future.delayed` for natural feel).
3. Action buttons render below the last bot message as a `Wrap` widget of `ElevatedButton`s. Tapping sends a `ConversationRequest` with the button's `action` + `payloadJson`.
4. File upload: tapping upload button opens `image_picker` (camera) or `file_picker` (documents). Photos are compressed client-side via `flutter_image_compress` (quality 70, max 1920px, target ≤500KB), then uploaded via `POST /api/documents/upload`. Polling starts for extraction status.
5. Validation cards render inline as bot messages with color-coded pass/fail/warning rows using `Container` with colored borders.
6. Progress bar is a `LinearProgressIndicator` in the `AppBar` showing current step (0-100%).

### PWA Configuration (Web Build)

The existing `web/manifest.json` is updated with ClaimsIQ branding:

```json
{
  "name": "ClaimsIQ",
  "short_name": "ClaimsIQ",
  "start_url": "/",
  "display": "standalone",
  "theme_color": "#003087",
  "background_color": "#FFFFFF",
  "icons": [{ "src": "icons/Icon-192.png", "sizes": "192x192" }, { "src": "icons/Icon-512.png", "sizes": "512x512" }]
}
```

### Mobile Responsiveness
- Uses existing `core/responsive/responsive.dart` for breakpoint-aware layouts
- Chat bubbles constrained via `ConstrainedBox(maxWidth: MediaQuery.of(context).size.width * 0.85)` on mobile, `0.6` on desktop
- Photo grid: `GridView.builder` with `crossAxisCount` based on screen width (3 mobile, 4 tablet, 5 desktop)
- File upload zone: full-width with `InkWell` tap target (min 48px height per Material guidelines)
- No horizontal overflow — all widgets use `Flexible`/`Expanded` within `Row`/`Column`

## Security Considerations

### Authentication & Authorization
- All API endpoints require JWT bearer token from Entra ID External Identities
- Agency users can only access their own submissions: `WHERE AgencyId = currentUser.AgencyId`
- CIRCLE HEAD users can only see submissions assigned to them or their state
- Rate limiting: 100 requests/minute per user on search endpoints, 20 uploads/minute

### Data Protection
- Customer phone numbers in enquiry dump: AES-256 column-level encryption at rest
- All file uploads scanned for malware via Azure Blob Storage threat detection
- Blob URLs are SAS-token protected with 1-hour expiry
- No PII in application logs — use correlation IDs only

### Input Validation
- All text inputs sanitized (XSS prevention)
- File type validation: server-side MIME type check (not just extension)
- Max file sizes enforced server-side: 10MB documents, 20MB photos (pre-compression)
- SQL injection prevention via EF Core parameterized queries (already in place)

## Submission Number Generation

Thread-safe sequential number generation using database sequence:

```csharp
public class SubmissionNumberService
{
    public async Task<string> GenerateAsync(IApplicationDbContext db, CancellationToken ct)
    {
        var year = DateTime.UtcNow.Year;
        // Atomic increment using raw SQL for thread safety
        var number = await db.Database.ExecuteSqlRawAsync(
            @"MERGE SubmissionSequences AS target
              USING (SELECT @p0 AS Year) AS source ON target.Year = source.Year
              WHEN MATCHED THEN UPDATE SET LastNumber = LastNumber + 1
              WHEN NOT MATCHED THEN INSERT (Year, LastNumber) VALUES (@p0, 1);
              SELECT LastNumber FROM SubmissionSequences WHERE Year = @p0;",
            year, ct);
        return $"CIQ-{year}-{number:D5}";
    }
}
```

## CIRCLE HEAD Auto-Assignment Logic

```
1. Query: SELECT CircleHeadUserId FROM StateMappings
          WHERE State = @submissionState AND IsActive = 1
2. If 0 results → flag for manual assignment (set AssignedCircleHeadUserId = NULL, add AuditLog entry)
3. If 1 result → assign directly
4. If multiple → load-balance:
   SELECT TOP 1 tm.CircleHeadUserId
   FROM StateMappings tm
   LEFT JOIN DocumentPackages dp ON dp.AssignedCircleHeadUserId = tm.CircleHeadUserId
       AND dp.State IN ('PendingASM', 'PendingRA') AND dp.IsDeleted = 0
   WHERE tm.State = @submissionState AND tm.IsActive = 1
   GROUP BY tm.CircleHeadUserId
   ORDER BY COUNT(dp.Id) ASC
```

## Duplicate Submission Detection

Triggered at the invoice upload step (Step 3) inside `ConversationalSubmissionService`. After extraction identifies the invoice number, the service checks for an existing non-rejected submission with the same PO + invoice combination.

### Detection Query
```sql
SELECT dp.Id, dp.SubmissionNumber, dp.State, i.InvoiceNumber
FROM DocumentPackages dp
JOIN Invoices i ON dp.Id = i.PackageId
WHERE dp.PO.PONumber = @poNumber
  AND i.InvoiceNumber = @invoiceNumber
  AND dp.IsDeleted = 0
  AND dp.State NOT IN ('ASMRejected', 'RARejected')
```

### Behavior
- If duplicate found: bot returns a warning response:
  `"Submission CIQ-X already exists for this PO with invoice INV-X. [View existing] [Submit anyway (new version)]"`
- If user chooses "Submit anyway": the new submission's `VersionNumber` is set to `MAX(VersionNumber) + 1` for that PO + invoice combination, and the flow proceeds normally.
- If user chooses "View existing": bot shows the existing submission's summary card with status.

## Enquiry Dump Processing Detail

### Extraction Fields (per record)
The backend extracts and validates the following fields from each enquiry record:
- State
- Date
- Dealer Code
- Dealer Name
- District
- Pincode
- Customer Name
- Customer Phone (encrypted with AES-256 column-level encryption at rest)
- Test Ride (boolean)

### Persistence
- Each extracted record is stored with `SyncedToWarehouse = 0`. The J7 (Enquiry Warehouse Sync) background job handles nightly push to the data warehouse.
- Records with missing mandatory fields are flagged as "incomplete" but still stored.

### Bot Response
After extraction, the bot shows a summary card:
- Total records extracted
- Complete records count vs incomplete records count
- Fields checked per record (list above)
- Sample record preview (first record, with phone number masked)

## Error Handling & Edge Cases

### Upload Failures
- Client retries failed uploads 3x with exponential backoff (1s → 2s → 4s).
- After 3 failures, bot shows: `"Upload failed. [Retry upload]"`. Draft is preserved — no data loss.
- Server-side: transient Azure Blob failures are retried via Polly retry policy (already configured in infrastructure).

### AI Extraction Timeout
- Client polls `GET /api/documents/{id}/status` every 3 seconds.
- If extraction exceeds 60 seconds, client stops polling and switches to SignalR push via `SubmissionNotificationHub`.
- Bot shows: `"Taking longer than usual. I'll notify you when done."` with a loading indicator.
- On `ExtractionComplete` SignalR event, the chat UI auto-resumes the flow.

### Wrong Document Type Detection
- After DocumentAgent extraction, if classification confidence is < 70%, the bot warns:
  `"This looks like a {detectedType}, not a {expectedType}. [Upload correct document] [Proceed anyway]"`
- If user proceeds anyway, the document is accepted but flagged with `ClassificationOverride = true` for CIRCLE HEAD review.

### No Open POs
- If PO search returns zero results, bot explains possible reasons:
  `"No open POs found for your account. POs sync from SAP every 4 hours. [Check sync status] [Contact support]"`

### Photo Size Handling
- Photos > 10MB (pre-compression): auto-compressed client-side via `flutter_image_compress` (quality 70, max 1920px).
- If still > 10MB after compression: bot shows `"Photo too large even after compression. Please use a lower resolution image."`
- Photos > 20MB (original): rejected outright before any processing. Bot shows `"Photo exceeds 20MB limit. Please reduce the file size."`

### Enquiry Dump Format Error
- If backend cannot parse the uploaded file (unexpected columns, corrupt file, unsupported format):
  `"Couldn't extract enquiry records from this file. [Re-upload] [Upload as additional document instead]"`
- If uploaded as additional document, the enquiry dump requirement remains unfulfilled — submission is still hard-blocked until a valid enquiry dump is provided.

## Rate Limiting

Implemented via ASP.NET Core rate limiting middleware (`Microsoft.AspNetCore.RateLimiting`).

| Endpoint Category | Limit | Window |
|-------------------|-------|--------|
| Search endpoints (`/api/purchase-orders/search`, `/api/state/dealers`) | 100 requests | Per minute per user |
| Upload endpoints (`/api/documents/upload`) | 20 requests | Per minute per user |
| Conversation endpoint (`/api/conversation/message`) | 60 requests | Per minute per user |

Rate limit exceeded returns `429 Too Many Requests` with `Retry-After` header.