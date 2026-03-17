# ClaimsIQ — T1: Agency Conversational Submission — Tasks

## Task 1: Database Schema Changes & Migrations — ⏱ 1 day
- [x] Add `Draft = 0` to `PackageState` enum in `BajajDocumentProcessing.Domain/Enums/PackageState.cs`
- [x] Add new fields to `DocumentPackage` entity: `State` (string?), `SubmissionNumber` (string?), `CurrentStep` (int, default 0), `AssignedCircleHeadUserId` (Guid?), `SelectedPOId` (Guid?)
- [x] Add new fields to `PO` entity: `VendorCode` (string?), `POStatus` (string?), `RemainingBalance` (decimal?)
- [x] Create `StateMapping` entity in `Domain/Entities/StateMapping.cs` with fields: `State`, `DealerCode`, `DealerName`, `City`, `CircleHeadUserId` (Guid?), `IsActive` (bool)
- [x] Create `SubmissionSequence` entity in `Domain/Entities/SubmissionSequence.cs` with fields: `Year` (int, PK), `LastNumber` (int)
- [x] Add `RuleResultsJson` (string?) field to `ValidationResult` entity
- [x] Register `StateMappings` and `SubmissionSequences` DbSets in `ApplicationDbContext.cs`
- [x] Add EF Core configurations for new entities in `Infrastructure/Persistence/Configurations/`
- [x] Add soft-delete query filter for `StateMapping`
- [x] Create EF Core migration: `dotnet ef migrations add ConversationalSubmission`
- [x] Verify migration SQL matches design.md schema (column types, defaults, FKs)

## Task 2: ConversationStep Enum & DTOs — ⏱ 0.5 day
- [x] Create `ConversationStep` enum in `Domain/Enums/ConversationStep.cs` (Greeting=0 through Submitted=10)
- [x] Create `ConversationRequest` DTO in `Application/DTOs/Conversation/ConversationRequest.cs` with: `SubmissionId` (Guid?), `Action` (string), `Message` (string?), `PayloadJson` (string?)
- [x] Create `ConversationResponse` DTO in `Application/DTOs/Conversation/ConversationResponse.cs` with: `SubmissionId`, `CurrentStep`, `BotMessage`, `Buttons` (List<ActionButton>), `Card` (CardData?), `RequiresFileUpload`, `FileUploadType`, `ProgressPercent`, `Error`
- [x] Create `ActionButton` DTO: `Label`, `Action`, `PayloadJson`
- [x] Create `CardData` base class and subtypes: `POListCard`, `ValidationResultCard`, `TeamSummaryCard`, `FinalReviewCard`
- [x] Create `POSearchResult` DTO: `Id`, `PONumber`, `PODate`, `VendorName`, `TotalAmount`, `RemainingBalance`, `POStatus`
- [x] Create `DealerResult` DTO: `DealerCode`, `DealerName`, `City`, `State`
- [x] Create `ProactiveValidationResponse` and `ProactiveRuleResult` DTOs as per design.md

## Task 3: PurchaseOrdersController — PO Search & Filter — ⏱ 1 day
- [x] Create `PurchaseOrdersController` in `API/Controllers/PurchaseOrdersController.cs`
- [x] Implement `GET /api/purchase-orders/search?vendorCode={code}&q={partial}&status=Open,PartiallyConsumed` — typeahead search, max 10 results, LIKE query on PONumber
- [x] Implement `GET /api/purchase-orders?vendorCode={code}&dateFrom=&dateTo=&amountMin=&amountMax=&sort=poDate:desc&page=1&size=5` — filtered list with pagination
- [x] Add agency-scoped authorization: only return POs where `AgencyId = currentUser.AgencyId`
- [x] Return `POSearchResult` DTOs with `PONumber`, `PODate`, `VendorName`, `TotalAmount`, `RemainingBalance`, `POStatus`
- [x] Handle zero results with descriptive message

## Task 4: StateController — Dealer Typeahead — ⏱️ Estimated: 3 hours
- [x] Create `StateController` in `API/Controllers/StateController.cs`
- [x] Implement `GET /api/state/dealers?state={state}&q={partial}&size=10` — dealer typeahead within a state, queries `StateMappings` table
- [x] Return `List<DealerResult>` DTOs with `DealerCode`, `DealerName`, `City`, `State`
- [x] Add agency-scoped authorization
- [x] Handle zero results with descriptive message

## Task 5: SubmissionNumberService — ⏱️ Estimated: 2 hours
- [x] Create `ISubmissionNumberService` interface in `Application/Common/Interfaces/`
- [x] Implement `SubmissionNumberService` in `Application/Services/SubmissionNumberService.cs`
- [x] Implement `GenerateAsync()` — thread-safe sequential number generation using MERGE SQL on `SubmissionSequences` table, returns `CIQ-{year}-{number:D5}` format
- [x] Register in DI container

## Task 6: ProactiveValidationService — ⏱️ Estimated: 10 hours
- [x] Create `IProactiveValidationService` interface in `Application/Common/Interfaces/`
- [x] Implement `ProactiveValidationService` in `Application/Services/ProactiveValidationService.cs`
- [x] Implement `ValidateDocumentAsync(Guid documentId, DocumentType documentType, Guid packageId)` — runs per-document validation immediately after extraction
- [x] Implement Invoice validation rules (9 rules): field presence checks on extracted JSON + cross-checks against PO (number match, amount vs balance)
- [x] Implement Activity Summary validation rules (3 rules): field presence + cross-check days against cost summary and team entries
- [x] Implement Cost Summary validation rules (4 rules): field presence + total vs invoice amount + element costs vs rate master
- [x] Persist results to `ValidationResult.RuleResultsJson` as JSON array of `{ ruleCode, type, passed, extractedValue, expectedValue }`
- [x] Return `ProactiveValidationResponse` with per-rule results, pass/fail/warning counts
- [x] Inject `IHubContext<SubmissionNotificationHub>` to push `ValidationComplete` event via SignalR
- [x] Register in DI container

## Task 7: ConversationalSubmissionService — State Machine — ⏱️ Estimated: 16 hours
- [x] Create `IConversationalSubmissionService` interface in `Application/Common/Interfaces/`
- [x] Implement `ConversationalSubmissionService` in `Application/Services/ConversationalSubmissionService.cs`
- [x] Implement step handler for Step 0 (Greeting): return greeting with agency name + action buttons
- [x] Implement step handler for Step 1 (POSelection): handle "select_po" action, create draft DocumentPackage with `State = Draft`, link PO
- [x] Implement step handler for Step 2 (StateSelection): query top 4 frequent states for agency, handle state selection, PATCH submission
- [x] Implement step handler for Step 3 (InvoiceUpload): handle upload confirmation, trigger proactive validation, return validation card
- [x] Implement step handler for Step 4 (ActivitySummaryUpload): same pattern as invoice
- [x] Implement step handler for Step 5 (CostSummaryUpload): same pattern as invoice
- [x] Implement step handler for Step 6 (TeamDetailsLoop): handle team creation, dealer selection, photo uploads, loop control (add team / done)
- [x] Implement step handler for Step 7 (EnquiryDumpUpload): hard-block skip, extract records, show summary
- [x] Implement step handler for Step 8 (AdditionalDocsUpload): optional with skip
- [x] Implement step handler for Step 9 (FinalReview): build comprehensive summary card, handle edit navigation, handle submit action
- [x] Persist `CurrentStep` to `DocumentPackage` on each step transition
- [x] Implement draft detection: check for existing `Draft` packages for the agency on greeting
- [x] Implement resume logic: load submission from DB, return response from last completed step
- [x] Implement duplicate detection: on invoice upload, check for existing PO + invoice number combination
- [x] Inject `IDocumentAgent`, `IProactiveValidationService`, `ISubmissionNumberService`, `IApplicationDbContext`

## Task 8: ConversationalSubmissionController — ⏱️ Estimated: 4 hours
- [x] Create `ConversationalSubmissionController` in `API/Controllers/ConversationalSubmissionController.cs`
- [x] Implement `POST /api/conversation/message` — accepts `ConversationRequest`, delegates to `IConversationalSubmissionService`, returns `ConversationResponse`
- [x] Implement `GET /api/conversation/{submissionId}/state` — returns current step, progress percent, last completed step
- [x] Implement `POST /api/conversation/{submissionId}/resume` — resumes draft from last completed step
- [x] Add `[Authorize]` with agency role check
- [x] Add input validation on `ConversationRequest`

## Task 9: Extend Existing Endpoints — ⏱️ Estimated: 8 hours
- [x] Extend `SubmissionsController` — add `POST /api/submissions/draft` endpoint to create draft DocumentPackage
- [x] Extend `SubmissionsController` — add `PATCH /api/submissions/{id}` endpoint to update state field
- [x] Extend `POST /api/submissions/{id}/submit` — add completeness validation (all mandatory docs, state set), CIRCLE HEAD auto-assignment via StateMapping with load balancing, submission number generation, state enforcement (Draft → Submitted only)
- [x] Extend `DocumentsController` — add `GET /api/documents/{id}/status` endpoint for extraction status polling
- [x] Extend `DocumentsController` — add `GET /api/documents/{id}/validation-results` endpoint for proactive validation results
- [x] Extend `POST /api/documents/upload` — accept `submissionId` + `documentType` params, trigger proactive validation after extraction
- [x] Extend `GET /api/submissions/{id}` response — include `currentStep`, `submissionNumber`, `assignedCircleHeadUserId`, `state`, `selectedPOId`

## Task 10: CIRCLE HEAD Auto-Assignment — ⏱️ Estimated: 5 hours
- [x] Implement `ICircleHeadAssignmentService` interface and `CircleHeadAssignmentService`
- [x] Query `StateMappings WHERE State = submission.State AND IsActive = 1`
- [x] If 0 results: set `AssignedCircleHeadUserId = NULL`, create AuditLog entry for manual assignment
- [x] If 1 result: assign directly
- [x] If multiple: load-balance by counting pending submissions (`PendingASM` or `PendingRA` state) per CIRCLE HEAD, assign to least loaded
- [x] Called from submit endpoint after status transition
- [x] Register in DI container

## Task 11: SignalR NotificationHub — ⏱️ Estimated: 6 hours
- [x] Add `Microsoft.AspNetCore.SignalR` NuGet package (if not already present)
- [x] Create `SubmissionNotificationHub` in `API/Hubs/SubmissionNotificationHub.cs`
- [x] Implement `JoinSubmission(Guid submissionId)` and `LeaveSubmission(Guid submissionId)` group methods
- [x] Register hub in `Program.cs`: `app.MapHub<SubmissionNotificationHub>("/hubs/submission")`
- [x] Inject `IHubContext<SubmissionNotificationHub>` into `ProactiveValidationService` and `WorkflowOrchestrator`
- [x] Push `ExtractionComplete` event when DocumentAgent finishes extraction
- [x] Push `ValidationComplete` event when ProactiveValidationService finishes
- [x] Push `SubmissionStatusChanged` event on status transitions
- [x] Add `[Authorize]` to hub

## Task 12: Duplicate Submission Detection — ⏱️ Estimated: 3 hours
- [x] Implement duplicate check in `ConversationalSubmissionService` at invoice upload step
- [x] Query: `DocumentPackages dp JOIN Invoices i ON dp.Id = i.PackageId WHERE dp.PO.PONumber = @poNumber AND i.InvoiceNumber = @invoiceNum AND dp.IsDeleted = 0 AND dp.State NOT IN (ASMRejected, RARejected)`
- [x] If duplicate found: return warning in `ConversationResponse` with existing submission ID and action buttons `[View existing]` `[Submit anyway (new version)]`
- [x] If "Submit anyway": increment `VersionNumber` on new submission, proceed normally

## Task 13: Flutter Frontend — Conversational Submission Feature Setup — ⏱️ Estimated: 4 hours
- [x] Add `signalr_netcore` and `flutter_image_compress` dependencies to `pubspec.yaml`
- [x] Create feature directory structure: `lib/features/conversational_submission/{data,domain,presentation}` with subdirectories matching Clean Architecture pattern
- [x] Create domain entities: `ConversationMessage`, `ConversationState`, `POSearchResult`, `DealerResult`, `ValidationRuleResult` in `domain/entities/`
- [x] Create data models with JSON serialization: `ConversationRequestModel`, `ConversationResponseModel`, `ActionButtonModel`, `CardDataModel` (base + subtypes), `POSearchResultModel`, `DealerResultModel`, `ValidationResultModel` in `data/models/`
- [x] Create `ConversationRemoteDatasource` in `data/datasources/` — API calls to `/api/conversation/message`, `/api/conversation/{id}/state`, `/api/conversation/{id}/resume`, PO search, dealer search
- [x] Create `SignalRDatasource` in `data/datasources/` — SignalR connection lifecycle, join/leave submission groups, handle push events (`ExtractionComplete`, `ValidationComplete`, `SubmissionStatusChanged`)
- [x] Create `ConversationRepository` abstract class and `ConversationRepositoryImpl` implementation
- [x] Add conversation API endpoint constants to `core/constants/api_constants.dart`
- [x] Add `/conversational-submission` route to `core/router/app_router.dart`

## Task 14: Flutter Frontend — Chat UI Widgets — ⏱️ Estimated: 12 hours
- [x] Create `chat_window.dart` — `ListView.builder` with `ScrollController` auto-scroll, input area at bottom using `Column` + `Expanded`
- [x] Create `bot_message_bubble.dart` — bot bubble with card rendering support, typing indicator (300ms `Future.delayed`)
- [x] Create `user_message_bubble.dart` — user bubble for text and action confirmations
- [x] Create `action_buttons_row.dart` — `Wrap` widget of `ElevatedButton`s rendered below bot messages, sends `ConversationRequest` on tap
- [x] Create `step_progress_bar.dart` — `LinearProgressIndicator` in AppBar showing step progress (0-100%)
- [x] Create `ConversationNotifier` (Riverpod `StateNotifier`) in `presentation/providers/` — manages chat message list, sends requests via repository, handles responses, tracks current step
- [x] Create `SignalRNotifier` (Riverpod `StateNotifier`) in `presentation/providers/` — SignalR connection state, joins/leaves submission groups, dispatches push events to conversation notifier

## Task 15: Flutter Frontend — Feature Widgets — ⏱️ Estimated: 14 hours
- [x] Create `po_card.dart` — PO selection card with number, date, amount, remaining balance, `InkWell` tap to select
- [x] Create `file_upload_zone.dart` — `InkWell` zone that opens `image_picker` (camera) or `file_picker` (documents), client-side compression via `flutter_image_compress` (quality 70, max 1920px, target ≤500KB), upload progress via `LinearProgressIndicator`, retry on failure (3x exponential backoff)
- [x] Create `validation_card.dart` — per-document validation results with color-coded rows (`Container` with green/red/yellow border for pass/fail/warning)
- [x] Create `team_summary_card.dart` — team details summary (dealer, city, dates, working days, photo count/status)
- [x] Create `photo_grid.dart` — `GridView.builder` thumbnail grid with per-photo AI validation status (✅/❌), replace/add actions
- [x] Create `final_review_card.dart` — comprehensive pre-submit summary card with all sections, edit buttons per section
- [x] Create `FileUploadNotifier` (Riverpod `StateNotifier`) in `presentation/providers/` — handles compression, upload via Dio to `POST /api/documents/upload`, polls `GET /api/documents/{id}/status` every 3s, falls back to SignalR push after 60s

## Task 16: Flutter Frontend — Pages & Routing — ⏱️ Estimated: 6 hours
- [x] Create `conversational_submission_page.dart` — main chat page using `ChatWindow`, `ConversationNotifier`, `SignalRNotifier`, wrapped in `ConsumerWidget`
- [x] Add navigation entry point from existing home/submission screens to conversational submission page
- [x] Create submissions list integration — link "My Submissions" to existing `submission` feature or add conversational submission list view
- [x] Ensure mobile responsiveness: chat bubbles `ConstrainedBox(maxWidth: screenWidth * 0.85)` mobile / `0.6` desktop, photo grid `crossAxisCount` 3 mobile / 4 tablet / 5 desktop via `LayoutBuilder`
- [x] Update `web/manifest.json` with ClaimsIQ PWA branding (name, theme_color `#003087`, icons)
- [x] Test on Chrome Android and Safari iOS viewports

---

## 📊 Total Estimated Time

| Task | Estimate |
|------|----------|
| Task 1: Database Schema Changes & Migrations | 4 hours |
| Task 2: ConversationStep Enum & DTOs | 3 hours |
| Task 3: PurchaseOrdersController — PO Search & Filter | 5 hours |
| Task 4: StateController — Dealer Typeahead | 3 hours |
| Task 5: SubmissionNumberService | 2 hours |
| Task 6: ProactiveValidationService | 10 hours |
| Task 7: ConversationalSubmissionService — State Machine | 16 hours |
| Task 8: ConversationalSubmissionController | 4 hours |
| Task 9: Extend Existing Endpoints | 8 hours |
| Task 10: CIRCLE HEAD Auto-Assignment | 5 hours |
| Task 11: SignalR NotificationHub | 6 hours |
| Task 12: Duplicate Submission Detection | 3 hours |
| Task 13: Flutter Frontend — Conversational Submission Feature Setup | 4 hours |
| Task 14: Flutter Frontend — Chat UI Widgets | 12 hours |
| Task 15: Flutter Frontend — Feature Widgets | 14 hours |
| Task 16: Flutter Frontend — Pages & Routing | 6 hours |
| **TOTAL** | **105 hours (~13 working days)** |
