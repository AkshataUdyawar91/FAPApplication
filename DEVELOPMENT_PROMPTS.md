# Development Prompts — Bajaj Document Processing System

> Copy-paste these prompts into Kiro to implement each user story.
> Each prompt references the steering guidelines so the AI follows project standards.
> Prompts are ordered by dependency — start from the top.
> Team can split these across developers and work in parallel within each priority group.

---

## PRIORITY 1: Foundation (Do these FIRST — everything else depends on them)

---

### Story #20 — PO Auto-Dispatch from SAP to Agency

```
Implement PO Auto-Dispatch from SAP (User Story #20).

Follow .kiro/steering/dotnet-guidelines.md and .kiro/steering/structure.md strictly.

Context: SAP sends PO data to our system. On arrival: store in DB, generate PDF (QuestPDF), email PDF to Agency (ACS), push-notify Agency, and make PO available in Agency's PO list for FAP submission (Story #1).

Backend tasks:
1. Create PurchaseOrder entity in Domain/Entities/ — fields: Id, PONumber, POAmount, VendorCode, AgencyUserId, PODate, Description, LineItems (JSON), Status, CreatedAt. Add to ApplicationDbContext + EF migration.
2. Create IPurchaseOrderService in Application/Common/Interfaces/.
3. Create PurchaseOrderService in Infrastructure/Services/ with methods: IngestPOAsync, GetPOsByAgencyAsync (AsNoTracking), GetPOPdfAsync (QuestPDF). Use async/await + CancellationToken on all methods.
4. Create PurchaseOrdersController: POST /api/purchase-orders/ingest (SAP endpoint), GET /api/purchase-orders (JWT auth, filter by Agency user), GET /api/purchase-orders/{id}/pdf (download). Proper HTTP status codes.
5. On ingest: generate PDF, email via existing EmailAgent (new template), create notification via NotificationAgent.
6. Register services in DI. Keep controllers thin. Log with ILogger<T>. No exceptions for control flow.
```

---

### Story #10 — User Authentication & Authorization (SSO + New Roles)

```
Update User Authentication and Authorization (User Story #10).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: Current system has Agency, ASM, HQ roles with JWT auth. Need to add: (A) RA/Finance and Audit roles, (B) Teams SSO for ASM via Azure AD/Entra ID.

Backend tasks:
1. Add RAFinance and Audit values to Domain/Enums/UserRole.cs.
2. Update AuthService to handle new roles in JWT claims generation.
3. Add Teams SSO endpoint: POST /api/auth/sso/teams — accepts Azure AD token, validates with Microsoft identity platform, exchanges for portal JWT. Use Microsoft.Identity.Web NuGet package.
4. Update [Authorize] policies on controllers: RA/Finance gets approval access (like ASM), Audit gets read-only access to all submissions.
5. Add token refresh endpoint: POST /api/auth/refresh.
6. Seed RA/Finance and Audit test users in ApplicationDbContextSeed.

Frontend tasks (follow .kiro/steering/flutter-best-practices.md):
7. Update UserRole enum in frontend to include raFinance and audit.
8. Add session timeout detection — auto-redirect to login after 30 min inactivity. Use a SessionTimeoutWidget (StatelessWidget, BLoC pattern).
9. Update route guards in go_router to handle new roles.

Keep all widgets StatelessWidget. One widget per file. Max 300 lines per file.
```

---

### Story #12 — Data Persistence & Integrity

```
Complete Data Persistence and Integrity (User Story #12).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: EF Core + SQL Server is substantially implemented. Need to add soft delete, retry logic, and backup scheduling.

Tasks:
1. Add IsDeleted (bool) and DeletedAt (DateTime?) to BaseEntity in Domain/Common/BaseEntity.cs.
2. Add global query filter in ApplicationDbContext.OnModelCreating: .HasQueryFilter(e => !e.IsDeleted) for all entities inheriting BaseEntity.
3. Override SaveChangesAsync to intercept Delete operations and convert to soft delete (set IsDeleted=true, DeletedAt=DateTime.UtcNow).
4. Add DB retry logic: configure EF Core with options.EnableRetryOnFailure(maxRetryCount: 3, maxRetryDelay: TimeSpan.FromSeconds(5), errorNumbersToAdd: null) in Program.cs.
5. Create a SQL Agent job script or BackgroundService for daily backup (output as .sql script with instructions for DBA).
6. Add migration for IsDeleted + DeletedAt columns.

Use async/await throughout. Test referential integrity with cascade delete scenarios. Verify audit logging captures soft deletes.
```

---

### Story #13 — API Design & Integration

```
Complete API Design and Integration (User Story #13).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Tasks:
1. Add FluentValidation NuGet package. Create validators for all request DTOs (LoginRequest, SubmissionRequest, etc.) in Application/Validators/. Register with AddFluentValidation in Program.cs.
2. Add correlation ID middleware: read X-Correlation-Id header or generate new GUID, store in HttpContext.Items, include in all log scopes and response headers. Create CorrelationIdMiddleware in API/Middleware/.
3. Add health check endpoint: services.AddHealthChecks().AddSqlServer(connectionString).AddCheck("azure-openai", ...). Map to /health.
4. Verify all controllers return correct HTTP status codes per REST conventions (200, 201, 204, 400, 401, 403, 404, 500).

Keep middleware lightweight and async. Use ILogger<T> with structured logging.
```

---

## PRIORITY 2: Core Upload & Extraction (Stories #1, #2, #17)

---

### Story #1 — Document Upload (Invoice + Proof against PO)

```
Rework Document Upload flow (User Story #1).

Follow .kiro/steering/dotnet-guidelines.md (backend) and .kiro/steering/flutter-best-practices.md (frontend).

Context: Agency selects a PO from SAP list (Story #20), then uploads 5 mandatory docs against it. PO is NOT uploaded — it comes from SAP. No document classification needed — each doc goes into its mapped field.

Backend tasks:
1. Update SubmissionsController: POST /api/submissions should accept a PurchaseOrderId (GUID) linking to the SAP PO. Validate PO exists and no duplicate submission for same PO.
2. Update DocumentsController: POST /api/submissions/{id}/documents should accept documentType as a required field (Invoice, CostSummary, ActivitySummary, PhotoProof, EnquiryDump). Remove any classification logic.
3. Add EnquiryDump to Domain/Enums/DocumentType.cs (rename Additional_Document if needed). Ensure ActivitySummary exists.
4. Update submit validation: all 5 doc types must be present before allowing state change to Submitted.
5. Enable multi-file upload for PhotoProof type (accept array of files in single request).
6. On each upload, trigger Document Intelligence extraction (existing DocumentAgent) and return extracted fields in response.

Frontend tasks:
7. Build PO selection page: fetch GET /api/purchase-orders, display as selectable list with PO#, Amount, Date. On select → navigate to upload page with PO context.
8. Build upload page with 5 mandatory doc cards: Invoice, Cost Summary, Activity Summary, Photo Proofs (multi-upload), Enquiry Dump. Each card shows: doc type name, accepted formats, max size, dashed upload area.
9. On upload success: show extracted fields inline (read-only) below each card — e.g., Invoice: Number, Amount, GSTIN.
10. Submit button: green when all 5 present, gray/disabled otherwise. On submit → POST to backend.
11. Block duplicate PO submission on frontend (check before navigating to upload).

Use BLoC pattern for state. GetIt for DI. One widget per file. StatelessWidget only. Responsive: stacked on mobile, 2-3 col grid on desktop.
```

---

### Story #2 — Document Data Extraction (No Classification)

```
Rework Document Data Extraction — remove classification (User Story #2).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: Classification is NOT needed — docs are uploaded into mapped fields (Story #1). DocumentAgent should only extract fields, not classify.

Backend tasks:
1. Update DocumentAgent.cs: remove ClassifyAsync logic or make it a no-op. The document type is provided by the upload endpoint, not inferred.
2. Update extraction to handle all 5 doc types with exact field lists:
   - Invoice: Agency Name/Address, Billing Name/Address, State, Invoice#, Date, Vendor Code, PO#, GST#, GST%, HSN/SAC, Amount
   - Cost Summary: Place of Supply, Element-wise Cost, Days, Activations, Teams, Quantity, Total Cost
   - Activity Summary: Dealer/Location, Days per location
   - Photos: Date + Lat/Long via EXIF (MetadataExtractor NuGet), Blue T-shirt + 3W Vehicle via AI Vision (Azure OpenAI GPT-4 Vision)
   - Enquiry Dump: State, Date, Dealer Code/Name, District, Pincode, Customer Name/Number, Test Ride
3. Store extracted data in ExtractedDataJson field on Document entity.
4. Return extracted fields in the upload API response so frontend can display inline.
5. For Photos: use MetadataExtractor for EXIF (Date, GPS coordinates), use Azure OpenAI GPT-4 Vision for blue t-shirt and 3W vehicle detection.

Use async/await + CancellationToken. Log extraction results. Handle extraction failures gracefully — don't block upload, show warning.
```

---

### Story #17 — Enhanced Upload Page UI & Empty State

```
Build Enhanced Upload Page UI and Empty State (User Story #17).

Follow .kiro/steering/flutter-best-practices.md strictly. Bajaj colors: #003087 (dark blue), #00A3E0 (light blue), #FFFFFF (white).

Context: This is the frontend UI for Stories #1 and #2. Agency sees "All Requests" page → empty state or list → "Create New Request" → PO selection → upload 5 docs.

Tasks:
1. All Requests page — empty state: document icon + "No requests found" heading + "Create your first request to get started" subtext + centered "Create New Request" button (blue #003087, white text, rounded, plus icon).
2. All Requests page — with data: list view of existing submissions. "Create New Request" button in top-right.
3. Upload page header: "Create New Request" title + subtitle explaining process.
4. Step progress indicator: "Step X of 4" with percentage bar (blue). Circular step icons: PO Selection, Invoice & Docs, Photo Proofs, Review & Submit. Blue for current/completed, gray for incomplete.
5. PO selection step: list of POs from SAP (GET /api/purchase-orders). Selectable cards showing PO#, Amount, Date.
6. Document upload cards (5 cards): Invoice, Cost Summary, Activity Summary, Photo Proofs, Enquiry Dump. Each card: blue icon background, doc type in blue text, accepted formats, max size, dashed border upload area with blue cloud icon + "Click to upload".
7. Upload success state: green checkmark + filename in green-tinted card.
8. Submit button: green (#4CAF50) when all 5 present, muted gray when incomplete.
9. Inline error messages per card for invalid format/size.
10. Responsive: stacked vertically on mobile (<600px), 2-3 column grid on desktop.

Architecture: BLoC for upload state management. GetIt for DI. One widget per file. StatelessWidget only (except TextEditingController forms). Max 300 lines per file. Extract sub-widgets aggressively.

File structure:
- lib/features/submission/presentation/pages/all_requests_page.dart
- lib/features/submission/presentation/pages/upload_page.dart
- lib/features/submission/presentation/widgets/empty_state_widget.dart
- lib/features/submission/presentation/widgets/po_selection_card.dart
- lib/features/submission/presentation/widgets/document_upload_card.dart
- lib/features/submission/presentation/widgets/step_progress_indicator.dart
- lib/features/submission/presentation/widgets/submit_button.dart
- lib/features/submission/presentation/bloc/upload_bloc.dart
```

---

## PRIORITY 3: Validation, Scoring & Recommendation (Stories #3, #4, #5)

---

### Story #3 — Validation (Background after Submit)

```
Rework Validation — full 41-validation matrix (User Story #3).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: After Agency submits, background validation runs across all 5 doc types. 41 total validations: presence checks + cross-document checks. UI shows per-doc status.

Backend tasks:
1. Refactor ValidationAgent.cs to implement the full validation matrix:

   INVOICE (14 validations):
   - Presence (10): Agency Name, Agency Address, Billing Name, Billing Address, State, Invoice#, Date, Vendor Code, PO#, GST#, GST%, HSN/SAC, Amount
   - Cross-checks (4): GST# matches State code, HSN/SAC in valid list, Amount ≤ PO Amount (from SAP PO), GST% = 18% for interstate

   COST SUMMARY (10 validations):
   - Presence (6): Place of Supply, Element Cost, Days, Activations, Teams, Quantity
   - Cross-checks (4): Total ≤ Invoice Amount, element costs vs state rate card, fixed cost limits, variable cost limits

   ACTIVITY SUMMARY (3 validations):
   - Presence (1): Dealer/Location list
   - Cross-checks (2): Days per location sum = Cost Summary days, locations exist in master data

   PHOTOS (5 validations):
   - Presence (3): Date, Lat/Long, Blue T-shirt detected, 3W Vehicle detected
   - Cross-checks (2): Photo count ≥ Activity man-days, Activity days ≤ Cost Summary days (3-way validation)

   ENQUIRY DUMP (9 validations):
   - Presence (9): State, Date, Dealer Code, Dealer Name, District, Pincode, Customer Name, Customer Number, Test Ride flag

2. Create reference data tables + seed data:
   - GSTStateMapping: GST prefix → State name (seed from known FAPs)
   - HSNSACCodes: valid HSN/SAC code list (placeholder — get from Vivek)
   - StateCostRates: state → element cost rate card (placeholder)

3. Store validation results per document in ValidationResult entity with field-level details (FieldName, ExpectedValue, ActualValue, Status, Message).

4. Run validations as BackgroundService triggered on submission. Update DocumentPackage state: Validating → ValidationComplete or ValidationFailed.

5. Create API endpoint: GET /api/submissions/{id}/validations — returns per-document validation status and details.

Frontend tasks:
6. Show per-document validation status on submission detail page: "Invoice - Validation In Progress" → "Invoice - Validation Completed" (or Failed with details). Poll or use SignalR for real-time updates.

Use async/await + CancellationToken. Log each validation result. Handle missing reference data gracefully (warn, don't block).
```

---

### Story #4 — Confidence Score Calculation

```
Update Confidence Score Calculation — new weights, no PO (User Story #4).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: PO is excluded from scoring (comes from SAP). New weights: Invoice 30% + Cost Summary 20% + Activity 20% + Photos 30% = 100%.

Backend tasks:
1. Update ConfidenceScoreService.cs:
   - Remove PO weight entirely
   - New weights: Invoice = 0.30, CostSummary = 0.20, Activity = 0.20, Photos = 0.30
   - Score range: 0-100
   - Below 70 → flag for mandatory ASM review (set PackageState to FlaggedForReview)

2. Update ConfidenceScore entity if needed — ensure it stores per-document scores + overall weighted score.

3. Ensure scoring runs after validation completes (chain: Submit → Validate → Score → Recommend).

4. Update GET /api/submissions and GET /api/submissions/{id} to include confidence data.

Frontend tasks:
5. Display confidence score on Agency dashboard and ASM review page with color coding: green >85%, amber 70-85%, red <70%.

Test edge cases: one doc type scores 0, all score 100, boundary values at 70 and 85.
```

---

### Story #5 — Approval Recommendation (Short Summary)

```
Update Approval Recommendation — enforce ~100 char summary (User Story #5).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: After validation + scoring, RecommendationAgent generates APPROVE / REVIEW / REJECT with a very short summary (~2 lines, ~100 characters).

Backend tasks:
1. Update RecommendationAgent.cs:
   - Update the Azure OpenAI prompt to enforce concise output: "Generate a recommendation summary in under 100 characters. Format: [key finding]. Confidence [X]%. Recommend [approval/review/rejection]."
   - Example outputs: "All validations passed. Confidence 92%. Recommend approval." / "Invoice amount exceeds PO. Confidence 58%. Recommend rejection."
   - Thresholds: Score >85 + validation pass → APPROVE, 70-85 → REVIEW, <70 or validation fail → REJECT

2. Truncate summary to 120 chars max as a safety net (soft limit 100, hard limit 120).

3. Store recommendation in Recommendation entity with: Type (Approve/Review/Reject), Summary, ConfidenceScore, CreatedAt.

4. Ensure recommendation runs after scoring completes in the workflow chain.

Frontend tasks:
5. Update recommendation_card.dart for compact display — 2 lines max, no scrolling within the card.

Test all 3 recommendation types produce short summaries.
```

---

## PRIORITY 4: Review & Approval Flow (Stories #18, #19 ASM Review, #19 RA/Finance)

---

### Story #18 — Submissions Dashboard (PO from SAP)

```
Update Submissions Dashboard — PO data from SAP (User Story #18).

Follow .kiro/steering/flutter-best-practices.md strictly. Bajaj colors: #003087, #00A3E0, #FFFFFF.

Context: Agency dashboard shows submissions with PO data sourced from SAP (not uploaded). Columns: FAP#, PO No., PO Amt, Invoice No., Invoice Amt, Submitted Date, AI Score, Status, View.

Frontend tasks:
1. Update agency_dashboard_page.dart table columns to exact order: FAP NUMBER, PO NO., PO AMT, INVOICE NO., INVOICE AMT, SUBMITTED DATE, AI SCORE, STATUS, View.
2. PO No. and PO Amt come from the linked PurchaseOrder entity (SAP data), not from uploaded documents.
3. Currency formatting: ₹ symbol, 2 decimal places, right-aligned for amounts.
4. AI Score: center-aligned, color-coded (green >85%, amber 70-85%, red <70%).
5. Status: color-coded badge (Submitted=blue, Validating=amber, Approved=green, Rejected=red).
6. Pagination with page size selector.
7. JWT auth — Agency sees only own submissions.

Backend tasks:
8. Update GET /api/submissions to include poNumber and poAmount from the linked PurchaseOrder entity (not from ExtractedDataJson). Use .Include(p => p.PurchaseOrder) and .Include(p => p.ConfidenceScore).

BLoC pattern. GetIt for DI. One widget per file. Responsive table on desktop, card list on mobile.
```

---

### Story #19 — RA/Finance Approval (Post-ASM) + ASM Review Page

```
Implement RA/Finance Approval flow and update ASM Review Page (User Story #19).

Follow .kiro/steering/dotnet-guidelines.md (backend) and .kiro/steering/flutter-best-practices.md (frontend).

Context: After ASM approves → submission moves to RA/Finance queue. RA reviews same docs + ASM note + AI summary. Can Approve (→ Approved-Final) or Reject (→ Rejected back to Agency).

Backend tasks:
1. Update PackageState enum: add ASMApproved, RAPending, RAApproved, RARejected states.
2. Update state machine in WorkflowOrchestrator:
   - ASM Approve → state = ASMApproved → auto-move to RAPending
   - RA Approve → state = RAApproved (final) → trigger SES creation (Story #22) + email Agency
   - RA Reject → state = RARejected → email Agency with rejection comments
3. Create RA approval endpoints in SubmissionsController:
   - GET /api/submissions/ra-queue — list submissions in RAPending state (RA/Finance role only)
   - POST /api/submissions/{id}/ra-approve — RA approves
   - POST /api/submissions/{id}/ra-reject — RA rejects with comments
4. Add ASM approval note field: when ASM approves, store optional comment. Show on RA review page.
5. Audit log all RA actions (user, action, timestamp, IP).

Frontend tasks:
6. ASM Review Page (existing — enhance):
   - Single stacked page layout (no tabs): AI Quick Summary at top (overall score + bullet points), then PO, Invoice, Cost Summary, Activity, Photos, Enquiry Dump sections.
   - Each section: doc title + individual confidence score (e.g., "Invoice 92%") + concise bullet-point validation summary.
   - Color indicators: green >85%, amber 70-85%, red <70%.
   - Approve (green) and Reject (red) buttons with comment field on reject.

7. RA/Finance Review Page (new — similar to ASM):
   - Same stacked layout as ASM review.
   - Additional section: ASM approval note.
   - Approve/Reject buttons.
   - Route: /ra-review/{submissionId}

8. RA Queue Page: list of RAPending submissions with FAP#, Agency, Score, Date. Click → RA review page.

BLoC pattern. GetIt for DI. One widget per file. Max 300 lines. Extract sub-widgets for each document section.
```

---

## PRIORITY 5: Communication & Notifications (Stories #6, #8, #24, #27)

---

### Story #6 — Email Communication (PO PDF + Status)

```
Rework Email Communication — PO PDF + status emails (User Story #6).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: Two email scenarios: (A) PO arrives from SAP → generate PO PDF → email to Agency. (B) Status emails for validation fail, ASM approve/reject, RA approve/reject.

Backend tasks:
1. PO PDF generation: add QuestPDF NuGet package. Create PoPdfGenerator service in Infrastructure/Services/. Generate branded PDF with PO#, Amount, Line Items, Date, Vendor details. Bajaj colors (#003087 header).

2. Update EmailAgent.cs with new email templates:
   - PO Arrival: "New Purchase Order Available" + PO PDF attachment
   - Validation Failed: "Action Required: Document Corrections Needed" + list of failed fields
   - ASM Approved: "FAP Approved by Area Manager"
   - ASM Rejected: "FAP Requires Corrections" + rejection comments
   - RA Approved: "FAP Final Approval Confirmed"
   - RA Rejected: "FAP Rejected by Finance" + rejection comments

3. All emails sent via ACS with 3x retry (exponential backoff — use existing Polly policies).

4. Add PO PDF download endpoint: GET /api/purchase-orders/{id}/pdf (reuse PoPdfGenerator).

5. Log all email sends/failures. Store failed emails for retry queue.

Use async/await. CancellationToken on all methods. ILogger<T> for logging.
```

---

### Story #8 — Notifications (Push for New PO + In-App)

```
Implement Notifications — push + in-app (User Story #8).

Follow .kiro/steering/dotnet-guidelines.md (backend) and .kiro/steering/flutter-best-practices.md (frontend).

Context: Push notification to Agency when new PO arrives (FCM/APNs). In-app notifications for all status changes. Bell icon with unread badge.

Backend tasks:
1. Create IPushNotificationService interface + placeholder implementation (FCM/APNs integration — use Firebase Admin SDK NuGet for FCM).
2. Update NotificationAgent to create notifications for: new PO, submission status changes, ASM/RA approve/reject.
3. Add DeviceToken field to User entity (for push registration).
4. API endpoints:
   - POST /api/notifications/register-device — store FCM/APNs token
   - GET /api/notifications — list user's notifications (paginated, unread first)
   - PATCH /api/notifications/{id}/read — mark as read
   - GET /api/notifications/unread-count — badge count

Frontend tasks:
5. Bell icon in app bar with unread count badge. Tap → notification list page.
6. Notification list: unread highlighted, tap to mark read + navigate to relevant page.
7. Register device token on login (FCM for Android, APNs for iOS).

BLoC pattern. GetIt for DI. One widget per file.
```

---

### Story #24 — TeamsBot Real-Time Notifications

```
Implement Teams Bot Real-Time Notifications (User Story #24).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: ASM gets proactive Teams messages for: new submission, validation complete, score ready. Agency gets Teams messages for: PO arrived, approval/rejection. Messages include FAP#, score, status + deep link to portal.

Backend tasks:
1. Create ITeamsNotificationService interface in Application/Common/Interfaces/.
2. Create TeamsNotificationService in Infrastructure/Services/ using Microsoft.Bot.Builder SDK:
   - SendProactiveMessageAsync(string teamsUserId, AdaptiveCard card)
   - Map users to Teams IDs via email (store TeamsUserId on User entity)
3. Create adaptive card templates for each notification type:
   - New Submission (ASM): FAP#, Agency name, doc count, deep link
   - Validation Complete (ASM): FAP#, validation summary, deep link
   - Score Ready (ASM): FAP#, confidence score, recommendation, deep link
   - PO Arrived (Agency): PO#, Amount, deep link
   - Approved/Rejected (Agency): FAP#, status, comments, deep link
4. Hook into existing notification pipeline — when NotificationAgent creates a notification, also send Teams message if user has TeamsUserId.
5. Register Teams Bot in Azure Bot Service (provide setup instructions).

Use async/await. Handle Teams API rate limits. Log all sends.
```

---

### Story #27 — WhatsApp Notifications

```
Implement WhatsApp Notifications (User Story #27).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: Agency receives WhatsApp messages for key events: PO arrived, status change, approval/rejection. Uses WhatsApp Business API via ACS or Twilio.

Backend tasks:
1. Create IWhatsAppService interface in Application/Common/Interfaces/.
2. Create WhatsAppService in Infrastructure/Services/ — placeholder implementation using ACS WhatsApp channel (or Twilio as fallback).
3. Add PhoneNumber field to User entity + migration.
4. Create message templates (must be pre-approved by Meta):
   - PO Arrived: "New PO #{poNumber} for ₹{amount} is available. View: {deepLink}"
   - Status Change: "FAP #{fapId} status updated to {status}. View: {deepLink}"
   - Approved: "FAP #{fapId} has been approved. View: {deepLink}"
   - Rejected: "FAP #{fapId} was rejected: {reason}. View: {deepLink}"
5. Add WhatsApp opt-in/consent flag on User entity. Only send if opted in.
6. Hook into notification pipeline — send WhatsApp alongside email/push if user has phone + consent.
7. API endpoint: POST /api/users/whatsapp-optin — toggle consent.

Frontend tasks:
8. Add phone number field to user profile page.
9. WhatsApp opt-in toggle in notification preferences.

Use async/await. Log all sends. Handle delivery failures gracefully.
```

---

## PRIORITY 6: Analytics & Chat (Stories #7, #9, #11)

---

### Story #7 — Analytics (Simple Quarterly FAP Totals)

```
Simplify Analytics to quarterly FAP totals (User Story #7).

Follow .kiro/steering/dotnet-guidelines.md (backend) and .kiro/steering/flutter-best-practices.md (frontend).

Context: Simple analytics only. Primary KPI: total FAP amount per quarter. Basic chart + Excel export. No complex campaign/state breakdowns.

Backend tasks:
1. Simplify AnalyticsController: GET /api/analytics/quarterly — returns array of { quarter: "Q1 2026", totalAmount: 1500000, submissionCount: 45, approvalRate: 0.82 }.
2. Query: group DocumentPackages by quarter (CreatedAt), sum Invoice amounts for approved submissions.
3. Excel export: GET /api/analytics/quarterly/export — generate .xlsx using ClosedXML or EPPlus NuGet package.
4. Remove or defer complex analytics endpoints (state ROI, campaigns).

Frontend tasks:
5. HQ analytics page: single bar/line chart showing quarterly FAP totals using fl_chart package.
6. Export button → download Excel file.
7. Simple, clean layout — no cluttered dashboard.

BLoC pattern. GetIt for DI. One widget per file. Responsive.
```

---

### Story #9 — Conversational Bot (All Roles, Full Actions)

```
Expand Conversational Bot for all roles with full actions (User Story #9).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: Chat bot is the PRIMARY interface for ALL roles. Agency + ASM + HQ can perform app actions via chat, not just Q&A. Bot navigates users to app sections.

Backend tasks:
1. Update ChatService.cs to support all 3 roles (currently HQ-only). Check user role from JWT claims and scope available actions.
2. Add intent recognition: classify user message as ACTION (do something) vs QUESTION (answer something). Use Semantic Kernel function calling.
3. Create Semantic Kernel plugins for actions:
   - AgencyPlugin: ViewPOs, CheckSubmissionStatus, DownloadPOPdf, StartNewSubmission (returns deep link)
   - ASMPlugin: ListPendingApprovals, ApproveSubmission, RejectSubmission, ViewSubmissionDetails
   - HQPlugin: GetQuarterlyAnalytics, GetApprovalRate (existing)
4. Add navigation responses: when action requires UI, return { type: "navigate", path: "/upload/{poId}" } so frontend can deep-link.
5. Maintain conversation context across 10+ messages (existing ConversationMessage entity).
6. Add confirmation step for destructive actions (approve/reject via chat): "Are you sure you want to approve FAP #123?"

Frontend tasks:
7. Enable chat widget on home page for ALL roles (not just HQ).
8. Handle navigation responses from bot — use go_router to navigate.
9. Chat UI: message bubbles, typing indicator, action buttons for confirmations.

Use Semantic Kernel + Azure OpenAI. Async/await. Log all chat interactions.
```

---

### Story #11 — UI and Branding (Minimalist Chat-First)

```
Redesign UI to minimalist chat-first layout (User Story #11).

Follow .kiro/steering/flutter-best-practices.md strictly. Bajaj colors: #003087 (dark blue), #00A3E0 (light blue), #FFFFFF (white).

Context: Home page for ALL roles: conversational chat as primary element + 1-2 role-specific KPIs + 1-2 quick action buttons. No cluttered dashboards.

Frontend tasks:
1. Redesign home page layout:
   - Top: App bar with Bajaj logo + user name + bell icon (notifications) + role badge
   - Center (60% of viewport): Chat interface (full-width, prominent)
   - Bottom/Side: 1-2 KPI cards + 1-2 quick action buttons

2. Role-specific content:
   - Agency: KPIs = (Pending submissions count, Latest PO date). Actions = (New FAP, View POs)
   - ASM: KPIs = (Pending approvals, Today's submissions). Actions = (Review Queue)
   - HQ: KPIs = (Quarterly FAP total, Approval rate %). Actions = (Analytics)
   - RA/Finance: KPIs = (Pending RA reviews). Actions = (RA Queue)
   - Audit: KPIs = (Total submissions). Actions = (View All, Export)

3. Chat widget: takes up majority of screen. Typing a message answers questions OR navigates to sections.

4. Bajaj brand colors throughout: #003087 primary, #00A3E0 accents, #FFFFFF backgrounds. Dark blue app bar.

5. Responsive: on mobile, KPIs stack below chat. On desktop, KPIs in sidebar.

Architecture: BLoC for home state. GetIt for DI. One widget per file. Max 300 lines.

File structure:
- lib/features/home/presentation/pages/home_page.dart
- lib/features/home/presentation/widgets/chat_widget.dart
- lib/features/home/presentation/widgets/kpi_card.dart
- lib/features/home/presentation/widgets/quick_action_button.dart
- lib/features/home/presentation/widgets/role_content_widget.dart
- lib/features/home/presentation/bloc/home_bloc.dart
```

---

## PRIORITY 7: SAP Integration & Audit (Stories #22, #21)

---

### Story #22 — SAP Service Entry Sheet Creation

```
Implement SAP Service Entry Sheet creation on final approval (User Story #22).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: After RA approves (RAApproved state) → system creates a Service Entry Sheet in SAP. Maps FAP data to SES format. Posts via SAP API/RFC.

Backend tasks:
1. Create ISapService interface in Application/Common/Interfaces/ with method: CreateServiceEntrySheetAsync(Guid submissionId).
2. Create SapService in Infrastructure/Services/:
   - Map approved FAP data to SAP SES format (placeholder mapping — actual field mapping TBD from SAP team)
   - POST to SAP API endpoint (use IHttpClientFactory with Polly retry policies)
   - Log success/failure with full request/response details
3. On RAApproved state change in WorkflowOrchestrator, trigger SES creation as background job.
4. Retry queue: if SES creation fails, add to retry queue (BackgroundService that retries every 15 min, max 5 attempts).
5. Admin alert on SES failure: create AdminAlert entity + notification to admin users.
6. Email Agency on SES creation success: "Service Entry Sheet created in SAP for FAP #{fapId}".
7. Store SES reference number on DocumentPackage entity (SESNumber, SESCreatedAt fields).

Use IHttpClientFactory for SAP calls. Polly for retry/circuit breaker. Async/await + CancellationToken. Structured logging.
```

---

### Story #21 — Audit Read-Only View & Case Bundle Export

```
Implement Audit role with read-only view and case bundle export (User Story #21).

Follow .kiro/steering/dotnet-guidelines.md (backend) and .kiro/steering/flutter-best-practices.md (frontend).

Context: Audit role has read-only access to ALL submissions across all agencies. Can view everything. Can export a "case bundle" ZIP per submission.

Backend tasks:
1. Add Audit role authorization policy: read-only access to all submissions (no approve/reject endpoints).
2. API endpoints:
   - GET /api/audit/submissions — list ALL submissions (all agencies), paginated, with filters (date range, status, agency)
   - GET /api/audit/submissions/{id} — full detail: docs + validations + scores + recommendations + approval history
   - GET /api/audit/submissions/{id}/case-bundle — download ZIP
3. Case bundle ZIP generation (use System.IO.Compression.ZipArchive):
   - All uploaded documents (original files from blob/local storage)
   - Validation report as PDF (generate with QuestPDF): all 41 validation results per document
   - Approval chain as PDF: who approved/rejected, when, comments
   - AI summary as PDF: confidence scores + recommendation + evidence
4. Ensure Audit role CANNOT access approve/reject endpoints (return 403).

Frontend tasks:
5. Audit dashboard page: table of all submissions with filters. No approve/reject buttons visible.
6. Audit detail page: read-only view of all docs, validations, scores, approvals.
7. "Export Case Bundle" button → download ZIP.

BLoC pattern. GetIt for DI. One widget per file. Responsive.
```

---

## PRIORITY 8: Teams Integration (Stories #23)

---

### Story #23 — TeamsBot Approve/Reject + SSO

```
Implement Teams Bot with approve/reject adaptive cards and SSO (User Story #23).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Context: ASM receives Teams notification for new submission. Can approve/reject directly from Teams adaptive card. Teams SSO: Azure AD/Entra ID → portal JWT seamlessly.

Backend tasks:
1. Create Teams Bot project or integrate into existing API:
   - Use Microsoft.Bot.Builder and Microsoft.Bot.Builder.Integration.AspNet.Core NuGet packages
   - Register bot endpoint: POST /api/messages (Teams webhook)
2. Create adaptive card template for submission review:
   - Header: FAP #{fapId} — {agencyName}
   - Body: AI Score: {score}%, Recommendation: {recommendation}, Summary: {summary}
   - Actions: "Approve" button (green), "Reject" button (red) with comment input
3. Bot action handler:
   - On Approve → call existing approval logic (update state, trigger emails, move to RA queue)
   - On Reject → prompt for comment → call existing rejection logic
4. Teams SSO implementation:
   - Use Microsoft.Identity.Web for Azure AD token validation
   - Token exchange: Teams token → validate with Azure AD → issue portal JWT
   - Endpoint: POST /api/auth/sso/teams (same as Story #10)
   - If ASM clicks deep link from Teams → auto-authenticate with Teams identity, no login page
5. Register bot in Azure Bot Service (provide ARM template or setup instructions).
6. Store Teams conversation references for proactive messaging (feeds Story #24).

Test: approve/reject from Teams card, SSO from Teams to portal without re-login.
```

---

## PRIORITY 9: Infrastructure & Hardening (Stories #14, #15, #16)

---

### Story #14 — Performance & Scalability

```
Implement Performance and Scalability improvements (User Story #14).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Tasks:
1. Add AsNoTracking() to ALL read-only queries across all controllers and services. Grep for .ToListAsync(), .FirstOrDefaultAsync() etc. and add AsNoTracking() where entity is not modified.
2. Add database indexes via EF migration:
   - DocumentPackage: State, SubmittedByUserId, CreatedAt (composite index on State + CreatedAt for dashboard queries)
   - Document: DocumentPackageId, DocumentType
   - Notification: UserId, IsRead, CreatedAt
   - PurchaseOrder: AgencyUserId, PONumber
3. Enable response compression in Program.cs:
   - services.AddResponseCompression(options => { options.EnableForHttps = true; options.Providers.Add<BrotliCompressionProvider>(); options.Providers.Add<GzipCompressionProvider>(); });
   - app.UseResponseCompression() before app.UseStaticFiles()
4. Verify pagination is implemented on all list endpoints (submissions, notifications, audit).

Profile with EF Core logging to verify no N+1 queries.
```

---

### Story #15 — Error Handling & Resilience

```
Complete Error Handling and Resilience (User Story #15).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Tasks:
1. SAP retry queue: create SapRetryQueue entity (RequestType, Payload, RetryCount, NextRetryAt, Status). BackgroundService polls every 5 min, retries failed SAP calls (max 5 attempts, exponential backoff).
2. Failed email queue: create EmailRetryQueue entity. When ACS email fails after 3 retries, store in queue. BackgroundService retries every 10 min.
3. Admin alert mechanism: create AdminAlert entity (Severity, Message, Source, CreatedAt, AcknowledgedAt). On critical failures (SAP down, email service down, Document Intelligence failure), create alert + send email to admin users.
4. API endpoint: GET /api/admin/alerts — list unacknowledged alerts (admin role only). PATCH /api/admin/alerts/{id}/acknowledge.

Use BackgroundService for retry queues. IServiceScopeFactory for scoped services in singletons. Structured logging for all retry attempts.
```

---

### Story #16 — Security & Compliance

```
Complete Security and Compliance (User Story #16).

Follow .kiro/steering/dotnet-guidelines.md strictly.

Tasks:
1. Move all secrets to environment variables: ConnectionStrings, Azure OpenAI keys, ACS connection string, JWT secret. Update appsettings.json to use ${ENV_VAR} pattern. Update Program.cs: builder.Configuration.AddEnvironmentVariables().
2. Enforce TLS 1.3: in Program.cs, configure Kestrel: options.ConfigureHttpsDefaults(https => { https.SslProtocols = SslProtocols.Tls13; }).
3. Restrict CORS: replace AllowAnyOrigin with specific allowed origins (frontend URL). Configure in Program.cs.
4. Add IP address to audit logs: update AuditLoggingMiddleware to capture HttpContext.Connection.RemoteIpAddress and store in AuditLog entity.
5. Verify RBAC: test that each role can only access their authorized endpoints. Agency cannot access ASM/RA/Audit endpoints. Audit cannot approve/reject.

No hardcoded secrets anywhere in codebase. Verify with grep for connection strings, API keys, passwords.
```

---

## PRIORITY 10: Mobile & Final Polish (Stories #26)

---

### Story #26 — Mobile App (Flutter — Test + Camera)

```
Test and enhance Mobile App — add camera capture (User Story #26).

Follow .kiro/steering/flutter-best-practices.md strictly.

Context: Existing Flutter app should work on mobile. Primary addition: camera capture for photo proofs.

Tasks:
1. Add camera capture option for photo proofs using image_picker package:
   - On Photo Proofs upload card, show two options: "Take Photo" (camera) and "Choose from Gallery" (file picker)
   - Use ImagePicker().pickImage(source: ImageSource.camera) for camera
   - Use ImagePicker().pickImage(source: ImageSource.gallery) for gallery
   - Support multiple photos (pickMultiImage for gallery)
2. Test all existing screens on mobile form factor (320px-428px width):
   - Login page
   - Home page (chat-first layout)
   - All Requests page
   - Upload page (cards should stack vertically)
   - Submission detail page
   - ASM review page
3. Verify flutter_secure_storage works on both Android and iOS.
4. Test push notifications: FCM for Android, APNs for iOS.
5. Ensure responsive layouts: use LayoutBuilder and MediaQuery. Mobile breakpoint < 600px.
6. Test full flow on mobile: login → PO list → upload (camera capture) → submit → view status.

One widget per file. StatelessWidget only. BLoC pattern.
```

---

## QUICK REFERENCE: Developer Assignment Suggestions

| Developer | Stories | Focus Area |
|-----------|---------|------------|
| Backend Dev 1 | #20, #12, #13, #3 | SAP integration, DB, validation |
| Backend Dev 2 | #10, #22, #14, #15, #16 | Auth, SAP SES, infrastructure |
| Backend Dev 3 | #2, #4, #5, #6, #8 | AI extraction, scoring, email |
| Frontend Dev 1 | #1, #17, #18 | Upload flow, dashboard |
| Frontend Dev 2 | #11, #19 (frontend), #26 | Home redesign, review pages, mobile |
| Full-Stack Dev | #9, #7, #23, #24, #27 | Chat bot, analytics, Teams, WhatsApp |

---

## NOTES FOR ALL DEVELOPERS

- Always read `.kiro/steering/dotnet-guidelines.md` before backend work
- Always read `.kiro/steering/flutter-best-practices.md` before frontend work
- Bajaj brand colors: #003087 (dark blue), #00A3E0 (light blue), #FFFFFF (white)
- Backend runs on http://localhost:5000 (or https://localhost:7001)
- Use `dotnet build` to verify compilation after changes
- Use `flutter analyze` to check for lint issues
- All async methods need CancellationToken (.NET) or proper disposal (Flutter)
- No hardcoded secrets — use environment variables
- One widget per file, max 300 lines, StatelessWidget only (Flutter)
- Keep controllers thin, business logic in services (.NET)
- Test credentials: agency@bajaj.com / asm@bajaj.com / hq@bajaj.com — all Password123!
