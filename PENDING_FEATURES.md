# ClaimsIQ — Pending Features & Gaps Analysis
**Generated**: March 14, 2026
**Source**: ClaimsIQRequirements.md v3.0 vs Implemented Codebase
**Purpose**: Tracks all unimplemented or partially implemented requirements against the spec.

---

## Terminology Mapping (Spec → Codebase)

| Spec Term | Codebase Term | Notes |
|-----------|--------------|-------|
| FAP | DocumentPackage | Core entity name differs |
| Circle Head (CH) | ASM | Role name differs throughout |
| HQ | Admin | Role enum value differs |
| PendingCircleHead | PendingASM | State enum value differs |
| CHrejected | ASMRejected | State enum value differs |
| ClaimsIQ | Bajaj Document Processing | Branding not yet renamed |
| Entra ID | Simple JWT (email/password) | Auth model fundamentally different |
| Draft | (not implemented) | State missing from PackageState enum |
| PendingValidation | (not implemented) | State missing — goes Uploaded → Extracting |
| PaymentInitiated | (not implemented) | State missing from PackageState enum |

## State Machine Gap

**Spec states**: Draft → PendingValidation → PendingCircleHead → PendingRA → Approved → PaymentInitiated, CHrejected, RArejected
**Codebase states**: Uploaded(1) → Extracting(2) → Validating(3) → PendingASM(4) → ASMRejected(5) → PendingRA(6) → RARejected(7) → Approved(8)

**Missing states**: Draft, PendingValidation, PaymentInitiated
**Missing transitions**: Approved → PaymentInitiated, PaymentInitiated → Approved (SAP failure revert)

---

## FEATURE 1 — DOCUMENT UPLOAD (US1) — PARTIALLY IMPLEMENTED

**What exists**: `POST /api/documents/upload` endpoint, `FileStorageService`, `MalwareScanService`, `DocumentsController` with upload/get/download actions, `BackgroundWorkflowQueue` for async processing.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-1.3 | Nginx `client_max_body_size 50m` + Kestrel `MaxRequestBodySize = 52428800` enforcement | Not configured | P0 |
| REQ-1.4 | Photo count cap at 50 per FAP across all teams — return HTTP 400 on exceed | Not implemented | P0 |
| REQ-1.5 | Upload idempotency via SHA-256 content hash — return existing documentId for duplicate | Not implemented | P1 |
| REQ-1.8 | Background job via `IHostedService` + `Channel<T>` for validation processing | Partial — uses `BackgroundWorkflowQueue` (different pattern) | P0 |
| REQ-1.9 | Submit button disabled until all mandatory docs uploaded + validated (PO, Invoice, CostSummary, InquiryDoc, 1+ team photo set) | Not verified in Flutter | P0 |
| REQ-1.12 | AgencyId extracted from Entra JWT token — never trust from request body | Not possible — auth is email/password JWT, not Entra | P0 (blocked by Feature 9) |

---

## FEATURE 2 — DOCUMENT CLASSIFICATION & EXTRACTION (US2) — PARTIALLY IMPLEMENTED

**What exists**: `DocumentAgent` with GPT-4o integration, extraction pipeline in `WorkflowOrchestrator.ExecuteExtractionStepAsync`, extraction data stored as JSON on document entities.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-2.3 | DocumentAgent system prompt with explicit prompt injection protection text | Not verified — need to audit DocumentAgent prompts | P0 |
| REQ-2.5 | Log/flag documents with imperative keywords ("approve", "ignore", "override", "bypass", "skip") in `SecurityFlags` column | Not implemented — no SecurityFlags column exists | P1 |
| REQ-2.6 | Indian number format handling (lakh/crore: 5,00,000 = 500000) in extraction prompt | Not verified | P0 |
| REQ-2.7 | Zero-amount guard — flag as EXTRACTION_ERROR if invoice amount = 0 | Not implemented | P0 |
| REQ-2.8 | Duplicate invoice detection — check extracted invoice number against all existing submissions | Not implemented | P0 |
| REQ-2.9 | Low-quality scan detection — flag LOW_QUALITY if >50% fields have confidence <0.5 | Not implemented | P1 |
| REQ-2.2 | `ExtractionResults` table with per-field confidence scores linked to documentId | Not implemented — extraction stored as JSON on document entities | P1 |

---

## FEATURE 3 — VALIDATION RULES ENGINE (US3) — PARTIALLY IMPLEMENTED (major gap)

**What exists**: `ValidationAgent` with Polly retry + circuit breaker, SAP HTTP client, `ValidationResult` entity with boolean fields (`SapVerificationPassed`, `AmountConsistencyPassed`, `LineItemMatchingPassed`, `CompletenessCheckPassed`, `DateValidationPassed`, `VendorMatchingPassed`).

**Architectural gap**: Spec requires 43 individual rules with per-rule `RuleCode`, `Status` (PASS/FAIL/WARN/PENDING), `EvidenceText`, `OverrideReason`, `OverrideBy`. Codebase uses boolean pass/fail fields — no per-rule granularity.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-3.1 | 43 validation rules in 3 tiers (Tier 1: fast/local, Tier 2: cross-document, Tier 3: SAP ground truth) | Partial — some validation logic exists but not as 43 discrete rules | P0 |
| REQ-3.1 | Tier 1 rules: R-001 to R-007 (file format, GSTIN regex, date sequence, file size, required fields, future date, PO format) | Partial — some checks exist in ValidationAgent | P0 |
| REQ-3.1 | Tier 2 rules: R-010 to R-015 (amount tolerance, GSTIN match, service entry, vendor code, invoice uniqueness) | Partial — amount consistency exists as boolean | P0 |
| REQ-3.1 | Tier 3 rules: R-020 to R-022 (SAP PO balance check, available balance calc, invoice vs balance) | SAP client configured but on-demand check not wired | P0 |
| REQ-3.1 | Photo rules: R-030 to R-035 (GPS, face detection, blue t-shirt, branded asset, perceptual hash) | Not implemented | P0 |
| REQ-3.2 | Photo validation via GPT-4o-mini, batched in groups of 5 with `Task.WhenAll` | Not implemented | P0 |
| REQ-3.3 | SAP unavailable → mark SAP_PENDING and queue for retry | Not implemented | P1 |
| REQ-3.4 | Per-rule `ValidationResults` table with RuleCode, Status, EvidenceText, OverrideReason, OverrideBy, CreatedAt | Not implemented — current model uses boolean fields | P0 |
| REQ-3.5 | Circle Head override WARN rules with reason — stored in ValidationResults | Not implemented | P0 |

---

## FEATURE 4 — CONFIDENCE SCORE (US4) — MOSTLY IMPLEMENTED

**What exists**: `ConfidenceScoreService` with correct 30/30/20/10/10 weights, `ConfidenceScore` entity with all component fields + `OverallConfidence` + `IsFlaggedForReview`.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-4.4 | Score below 70 sets `MandatoryReviewFlag = true` on FAP record | Uses `IsFlaggedForReview` on ConfidenceScore entity instead of FAP | P1 |
| REQ-4.6 | API returns `confidenceScore: null` (not 0) while AI processing in-flight | Not verified | P1 |
| REQ-4.7 | Score recalculated from scratch on resubmission (not cumulative) | Not verified | P1 |

---

## FEATURE 5 — APPROVAL RECOMMENDATIONS (US5) — PARTIALLY IMPLEMENTED

**What exists**: `RecommendationAgent`, `Recommendation` entity with Type/Evidence/ValidationIssuesJson/ConfidenceScore.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-5.2 | Hard-coded thresholds in app logic (>85 APPROVE, 60-85 REVIEW, <60 REJECT) — NOT in AI | Not verified — may be delegated to AI prompt | P0 |
| REQ-5.3 | UI displays all 43 validation items as table (Rule Code, Rule Name, Status, Evidence) | Not implemented — depends on Feature 3 per-rule model | P0 |
| REQ-5.5 | `RecommendationHistory` table for versioned recommendations on resubmission | Not implemented — no history table exists | P1 |

---

## FEATURE 6 — EMAIL COMMUNICATION (US6) — NOT IMPLEMENTED

**What exists**: `EmailAgent` service registered but is a mock/stub with TODO comments saying "Replace mock implementation with actual EmailClient SDK calls".

**All requirements pending**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-6.1 | 6 email templates (submission_received, validation_failed, circleHead_approved, circleHead_rejected, ra_approved, ra_rejected) | Not implemented | P1 |
| REQ-6.2 | Azure Communication Services `EmailClient` SDK integration | Not implemented — mock only | P1 |
| REQ-6.3 | Polly retry: 3 retries with 5-minute exponential backoff | Not implemented | P1 |
| REQ-6.4 | `EmailDeliveryLog` table (Id, TemplateId, RecipientEmail, FAPId, Status, Timestamp, ErrorMessage, AttemptNumber) | Not implemented — no entity exists | P1 |
| REQ-6.5 | All email branding says "ClaimsIQ" — zero "FAP Portal" references | Not implemented | P1 |
| REQ-6.6 | Rejection emails include approver's rejection reason text | Not implemented | P1 |
| REQ-6.7 | ACS connection string in Azure Key Vault — not in appsettings.json | Not implemented | P1 |

---

## FEATURE 7 — ANALYTICS DASHBOARD (US7) — PARTIALLY IMPLEMENTED

**What exists**: `AnalyticsController` with KPIs, state ROI, campaign breakdown, export, narrative, dashboard, quarterly FAP endpoints. `AnalyticsAgent` with AI narrative. Flutter `analytics` feature with full clean architecture.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-7.1 | 5 specific KPIs: total FAP count, approval rate %, avg processing time (days), total spend by region (bar chart), rejection reasons breakdown (top 5) | Partial — KPIs endpoint exists but spec-exact metrics not verified | P1 |
| REQ-7.2 | Quarter filter (Q1 Apr-Jun, Q2 Jul-Sep, Q3 Oct-Dec, Q4 Jan-Mar) applied to all metrics | Not verified — `quarter_year_filter.dart` widget exists | P1 |
| REQ-7.3 | Region filter dropdown applied to all metrics | Not verified | P1 |
| REQ-7.4 | Page load <3s, SQL indexes on Submissions(Status, CreatedAt) + region composites | Indexes not verified | P1 |
| REQ-7.5 | "Export to CSV" matching currently active filters | Export endpoint exists — filter pass-through not verified | P1 |
| REQ-7.6 | Default to current Indian financial year (April-March) | Not implemented | P1 |
| REQ-7.7 | Only HQ role access — others get HTTP 403 | Role guard not verified on analytics endpoints | P1 |

---

## FEATURE 8 — IN-APP NOTIFICATION MANAGEMENT (US8) — PARTIALLY IMPLEMENTED

**What exists**: `NotificationsController` (GET list, GET unread-count, PATCH mark-as-read), `Notification` entity (UserId, Type, Title, Message, IsRead, ReadAt, RelatedEntityId), `NotificationAgent` service.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-8.1 | Notification entity needs `EventType` (string), `EntityType` fields | Missing — has `Type` (enum) but no `EntityType` | P1 |
| REQ-8.2 | Bell icon in app header with unread count badge (red circle) | Not implemented in Flutter | P1 |
| REQ-8.3 | Notification panel: unread first, then read, sorted by CreatedAt desc | Not implemented in Flutter | P1 |
| REQ-8.4 | `PUT /api/notifications/read-all` (mark all as read) | Not implemented — only single mark-as-read exists | P1 |
| REQ-8.5 | HTTP polling every 30 seconds via `GET /api/notifications/unread-count` | Backend endpoint exists — Flutter polling not implemented | P1 |
| REQ-8.6 | 5 event types: new_submission, validation_complete, circleHead_action, ra_action, payment_initiated | Not verified against NotificationType enum | P1 |
| REQ-8.7 | Role-based scoping: Agency sees own FAPs, CH sees state, RA sees assigned states | Not implemented — requires territory mapping | P1 |

---

## FEATURE 9 — USER AUTH & RBAC (US10) — PARTIALLY IMPLEMENTED (major architectural gap)

**What exists**: `AuthController` (login/logout/me/refresh), `AuthService` with JWT, `User` entity (Email, PasswordHash, Role, AgencyId). Roles: Agency=1, ASM=2, RA=3, Admin=4.

**Architectural gap**: Auth is simple email/password JWT. Spec requires Entra ID Workforce (SSO for CH/RA/HQ) + Entra External ID (phone/email for Agency). This is a fundamental difference that affects REQ-1.12, REQ-9.7, and all AgencyId-from-token requirements.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-9.1 | Entra ID Workforce integration for CH, RA, HQ via SSO on Bajaj M365 tenant | Not implemented — uses email/password | P0 |
| REQ-9.2 | Entra External ID for Agency users (phone or email login) | Not implemented | P0 |
| REQ-9.3 | JIT user provisioning on first auth — auto-create User with EntraObjectId, Role, AgencyCode | Not implemented — manual user creation | P0 |
| REQ-9.4 | Roles: Agency, CircleHead, RA, HQ, Audit | Partial — has Agency, ASM, RA, Admin. Missing: CircleHead (name), HQ (name), Audit | P0 |
| REQ-9.5 | 30-minute sliding session timeout with activity reset | Not implemented | P1 |
| REQ-9.7 | AgencyId from Entra JWT claims — never trust from request body | Not possible with current auth model | P0 |
| REQ-9.8 | `SecurityAuditLog` table for HTTP 403 responses (UserId, Endpoint, Method, Timestamp, IPAddress, Reason) | Not implemented — `AuditLog` exists but different schema | P1 |

---

## FEATURE 10 — UI / BRANDING (US11) — PARTIALLY IMPLEMENTED

**What exists**: `AppTheme`/`AppColors` in Flutter, responsive layouts in review pages, `document_upload_card.dart` widget.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-10.2 | Shared component library: Button, Badge, StatusChip, DocumentCard, SummaryPanel, SkeletonLoader | Not implemented as reusable shared widgets | P1 |
| REQ-10.4 | Skeleton loading states on ALL data-fetching components (not spinners) | Not implemented | P1 |
| REQ-10.5 | ErrorBoundary widget on each major page with "Retry" button | Not implemented | P1 |
| REQ-10.6 | All UI labels say "ClaimsIQ" — zero "FAP Portal" references | Not done — app title is "Bajaj Document Processing" | P0 |
| REQ-10.7 | StatusChip for spec states (Draft, PendingValidation, PendingCircleHead, PendingRA, Approved, Rejected, PaymentInitiated) | Uses codebase states instead | P1 |

---

## FEATURE 11 — DATA PERSISTENCE & INTEGRITY (US12) — PARTIALLY IMPLEMENTED

**What exists**: Soft delete with `IsDeleted` + global query filters on most entities, `SaveChangesAsync` used throughout.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-11.2 | Polly retry on transient Azure SQL errors (3 retries, exponential backoff) | `ResiliencePolicies.GetDatabaseRetryPolicy` exists but not verified if wired to DbContext | P0 |
| REQ-11.4 | ACID transactions (`TransactionScope`) for multi-table writes (submission + docs, approval + status + notification) | Not verified — likely using single `SaveChangesAsync` | P0 |
| REQ-11.5 | No orphan records: every document linked to FAP, every blob has DB record | Not enforced programmatically | P1 |
| REQ-11.6 | Weekly blob cleanup job (J11) — remove orphan blobs >24 hours old | Not implemented (see Feature 35) | P2 |

---

## FEATURE 12 — API DESIGN (US13) — MOSTLY IMPLEMENTED

**What exists**: `CorrelationIdMiddleware`, `GlobalExceptionMiddleware`, JWT auth, paginated responses.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-12.5 | Async operations return HTTP 202 with poll URL `{ statusUrl: "/api/documents/{id}/status" }` | Not verified — `process-async` endpoint exists but response format unclear | P1 |
| REQ-12.7 | All error responses use RFC 7807 ProblemDetails with traceId | GlobalExceptionMiddleware exists but ProblemDetails format not verified | P1 |
| REQ-12.8 | Payment trigger endpoint internal-only — reject external requests | Not implemented — no payment endpoint exists | P1 |

---

## FEATURE 13 — PERFORMANCE & SCALABILITY (US14) — NOT IMPLEMENTED

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-13.1 | N+1 query audit across ALL controllers — resolve with `.Include()` or projection | Not audited | P1 |
| REQ-13.2 | SQL indexes: `IX_Submissions_Status_CreatedAt`, `IX_ValidationResults_SubmissionId` | Not verified | P1 |
| REQ-13.3 | All AI/validation on background queue — API returns 202 immediately | Partial — `BackgroundWorkflowProcessor` exists | P1 |
| REQ-13.4 | k6 load test script for 100 concurrent users | Not implemented | P1 |
| REQ-13.5 | Performance targets (upload <500ms, fast validation <1s, AI <20s, page load <3s, etc.) | Not tested | P1 |

---

## FEATURE 14 — ERROR HANDLING & RESILIENCE (US15) — PARTIALLY IMPLEMENTED

**What exists**: `GlobalExceptionMiddleware`, `ResiliencePolicies` with DB retry + circuit breaker, Polly in `ValidationAgent`.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-14.1 | Global exception middleware returns RFC 7807 ProblemDetails with traceId | Middleware exists — ProblemDetails format not verified | P0 |
| REQ-14.3 | Polly for MuleSoft SAP: 3 retries + exponential backoff, final failure → SAP_PENDING | SAP retry exists in ValidationAgent but SAP_PENDING queuing not implemented | P0 |
| REQ-14.4 | Polly for ACS Email: 3 retries with 5-minute backoff | Not implemented — email is mock | P1 |
| REQ-14.6 | App Insights alert: >5% error rate on any endpoint over 5-minute window | Not implemented | P1 |
| REQ-14.7 | SAP payment failure: revert to RAApproved, alert RA + admin, retry via admin dashboard | Not implemented — no payment service exists | P1 |
| REQ-14.8 | Dead Letter Queue for failed batch job records (J7 Inquiry Sync) | Not implemented | P1 |

---

## FEATURE 15 — SECURITY & COMPLIANCE (US16) — PARTIALLY IMPLEMENTED

**What exists**: `AuditLog` entity (UserId, Action, EntityType, EntityId, OldValuesJson, NewValuesJson, IpAddress, UserAgent), `AuditLogService`, `AuditLoggingMiddleware`.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-15.1 | Azure SQL TDE enabled | Azure portal config — not in code | P0 |
| REQ-15.2 | TLS 1.3 in Nginx `ssl_protocols` | No Nginx config in repo | P0 |
| REQ-15.3 | ALL secrets in Azure Key Vault — zero in appsettings.json | Not implemented — secrets in appsettings | P0 |
| REQ-15.4 | Managed Identity for Azure service-to-service (SQL, Blob, OpenAI, ACS) | Not implemented — uses connection strings/API keys | P0 |
| REQ-15.5 | `AuditEventLog` write-only table (no UPDATE/DELETE) | `AuditLog` exists but different schema, write-only not enforced | P1 |
| REQ-15.6 | CORS whitelist only — no wildcard `*` origins | Not verified — likely `AllowAnyOrigin` in dev | P1 |
| REQ-15.7 | Payment fires ONLY after both CircleHeadApprovedAt AND RAApprovedAt exist | Not implemented — no payment service, no timestamp fields on DocumentPackage | P1 |
| REQ-15.8 | `PaymentIdempotencyKey` (FAPId + version hash) before SAP payment | Not implemented | P1 |

---

## FEATURE 16 — UPLOAD PAGE UI (US17) — PARTIALLY IMPLEMENTED

**What exists**: `agency_upload_page.dart`, `document_upload_page.dart`, `document_upload_card.dart`, `po_fields_section.dart`, `invoice_fields_section.dart`, `campaign_details_section.dart`.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-16.1 | Empty state: centred "Create New Submission" button when no FAPs in progress | Not verified | P0 |
| REQ-16.2 | Step progress indicator during submission flow | Not implemented — no `StepProgressIndicator` widget | P0 |
| REQ-16.3 | DocumentCard: filename, upload progress %, preview thumbnail, validation status indicator | Partial — `document_upload_card.dart` exists but features not verified | P0 |
| REQ-16.5 | Inline validation errors below each DocumentCard (not toast/modal) | Not verified | P1 |
| REQ-16.6 | Submit button disabled until mandatory docs validated, loading state, double-submit prevention | Not verified | P0 |

---

## FEATURE 17 — SUBMISSIONS DASHBOARD (US18) — MOSTLY IMPLEMENTED

**What exists**: `SubmissionsController` with GET list (paginated), `agency_dashboard_page.dart`, `asm_review_page.dart`, `hq_review_page.dart`.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-17.3 | Confidence score displays as blank/dash while AI in-flight (not "0") | Not verified in Flutter | P1 |
| REQ-17.6 | Role-based filtering: Agency own only, CH sees state, RA sees assigned states | Partial — Agency filtering exists, territory-based CH/RA filtering requires Feature 32 | P0 |

---

## FEATURE 18 — RA APPROVAL FLOW (US19) — PARTIALLY IMPLEMENTED

**What exists**: `PATCH /api/submissions/{id}/hq-approve` and `hq-reject` endpoints (note: spec says RA, code uses HQ naming), `hq_review_page.dart`, `hq_review_detail_page.dart`.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-18.2 | Approve → triggers payment flow to SAP via MuleSoft | Not implemented — no `PaymentService` exists | P0 |
| REQ-18.4 | Rejection → Agency resubmit → full AI re-runs → CH re-reviews → RA re-reviews (full chain reset) | Resubmit endpoint exists but full chain reset not verified | P1 |
| REQ-18.5 | `RAApprovedAt` timestamp on FAP record, payment fires only after both CH + RA timestamps | Not implemented — no approval timestamp fields on DocumentPackage | P0 |
| REQ-18.6 | SAP payment failure: revert to RAApproved, alert RA + admin | Not implemented | P1 |

---

## FEATURE 19 — PO AUTO-DISPATCH TO AGENCY (US20) — NOT IMPLEMENTED

**What exists**: Nothing. No `POPdfGeneratorService`, no `PODispatchService`, no QuestPDF dependency.

**All requirements pending**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-19.1 | Auto-generate PO PDF using QuestPDF when PO syncs from SAP (Job J1) | Not implemented | P1 |
| REQ-19.2 | PDF stored in Blob Storage, linked via `PODocumentBlobUrl` | Not implemented | P1 |
| REQ-19.3 | Email to Agency with PDF download link | Not implemented | P1 |
| REQ-19.4 | Download endpoint: `GET /api/documents/po/{poNumber}/download` with 1-hour SAS URL | Not implemented | P1 |
| REQ-19.6 | Idempotency: don't regenerate if PO PDF already exists | Not implemented | P1 |
| REQ-19.7 | Agency dashboard shows POs filtered by Vendor Code (numbers only, no amounts) | Not implemented | P1 |

---

## FEATURE 20 — AUDIT READ-ONLY ACCESS (US21) — NOT IMPLEMENTED (deferred P2)

**All requirements pending** — spec marks as "For Later":

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-20.1 | Audit role sees all FAPs read-only | Not implemented | P2 |
| REQ-20.2 | Quarter + region filter dropdowns | Not implemented | P2 |
| REQ-20.3 | One-click case bundle export (ZIP + PDF manifest with SHA-256 checksums) | Not implemented | P2 |
| REQ-20.4 | No action buttons visible to Audit role | Not implemented | P2 |
| REQ-20.5 | AuditEventLog viewable as searchable read-only table | Not implemented | P2 |

---

## FEATURE 21 — SAP SERVICE ENTRY AUTO-CREATE (US22) — NOT IMPLEMENTED (BLOCKED)

**Blocked**: Awaiting SAP API feasibility confirmation from Abhinandan.

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-21.1–21.5 | Auto-create service entry in SAP after RA approval, idempotency, retry | BLOCKED — all pending | P2 |

---

## FEATURE 22 — TEAMS BOT: CIRCLE HEAD APPROVE/REJECT (US23) — NOT IMPLEMENTED

**What exists**: Nothing. No `TeamsNotificationService`, no Adaptive Card templates, no Bot Framework NuGet packages, no webhook infrastructure. Separate spec exists at `.kiro/specs/ch-teams-bot-notification/` but no code implemented.

**All requirements pending**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-22.1 | Send Adaptive Card to CH Teams channel when FAP = PendingCircleHead | Not implemented | P1 |
| REQ-22.2 | Card: FAP ref, agency name, confidence score, AI recommendation, top 3 issues | Not implemented | P1 |
| REQ-22.3 | Action buttons: Open in Portal, Approve, Reject | Not implemented | P1 |
| REQ-22.4 | Card replaced with confirmation state after action — no duplicate approvals | Not implemented | P1 |
| REQ-22.6 | MVP: Incoming Webhook + Adaptive Card JSON (no Azure Bot Service) | Not implemented | P1 |
| REQ-22.7 | `TeamsNotificationService.cs` with webhook POST + Polly retry | Not implemented | P1 |
| REQ-22.8 | Wired to orchestrator on PendingCircleHead state change | Not implemented | P1 |

---

## FEATURE 23 — TEAMS BOT: NEW FAP ALERT (US24) — NOT IMPLEMENTED

**Depends on Feature 22 infrastructure.**

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-23.1–23.5 | Proactive Teams notification on new FAP submission, summary card, informational only | Not implemented | P1 |

---

## FEATURE 24 — MOBILE APP FLUTTER (US26) — PARTIALLY IMPLEMENTED

**What exists**: Flutter app with auth, submission, approval, analytics, chat features. Basic clean architecture. No native mobile-specific features.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-24.2 | Camera integration via `image_picker` plugin | Not implemented | P1 |
| REQ-24.3 | Photo compression before upload (quality 75, maxWidth 800px) | Not implemented | P1 |
| REQ-24.4 | Push notifications via Firebase Cloud Messaging (FCM) | Not implemented | P1 |
| REQ-24.5 | Offline photo capture: local SQLite queue (`sqflite`) when no connectivity | Not implemented (sqflite is transitive dep only) | P1 |
| REQ-24.6 | Background sync: auto-upload queued photos on connectivity restore (`connectivity_plus`) | Not implemented | P1 |
| REQ-24.7 | Android: camera + location permissions in AndroidManifest.xml | Not verified | P1 |
| REQ-24.8 | iOS: camera + location permission descriptions in Info.plist | Not verified | P1 |
| REQ-24.9 | GPS coordinates captured from photo EXIF on upload | Not implemented | P1 |
| REQ-24.10 | Entra External ID login flow | Not implemented — uses email/password | P0 |
| REQ-24.11 | Guided submission stepper UI (see Feature 27) | Not implemented | P0 |

---

## FEATURE 25 — WHATSAPP NOTIFICATIONS (US27) — NOT IMPLEMENTED (P2)

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-25.1–25.6 | WhatsApp notifications via Meta Business API, deep links, retry, delivery tracking | Not implemented — external dependency (Meta approval) | P2 |

---

## FEATURE 26 — PORTAL RENAME TO CLAIMSIQ (US-N1) — NOT IMPLEMENTED

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-26.1 | All UI labels say "ClaimsIQ" — zero "FAP Portal" | Not done — title is "Bajaj Document Processing" | P0 |
| REQ-26.2 | All 6 email templates updated to "ClaimsIQ" | Not done — emails not implemented | P0 |
| REQ-26.3 | Teams bot display name = "ClaimsIQ" | Not done — Teams bot not implemented | P1 |
| REQ-26.4 | Flutter `MaterialApp` title = "ClaimsIQ" | Not done — currently "Bajaj Document Processing" | P0 |
| REQ-26.5 | Browser tab title = "ClaimsIQ" | Not done | P0 |
| REQ-26.7 | `grep -ri "FAP Portal"` returns 0 results | Not verified | P0 |

---

## FEATURE 27 — CONVERSATIONAL GUIDED SUBMISSION (US-N2) — NOT IMPLEMENTED

**This is a completely new Flutter feature — no code exists.**

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-27.1 | `GuidedSubmissionScreen` with step state machine (currentStepIndex, completedSteps, fapId, teams) | Not implemented | P0 |
| REQ-27.2 | 13-step guided flow (PO entry → PO upload → Invoice → CostSummary → Team Details → Photos → Add Team? → Inquiry → Activity Summary → Review → Submit) | Not implemented | P0 |
| REQ-27.3 | `ChatBubble` widget (BotBubble, UserBubble, ResultBubble) | Not implemented | P0 |
| REQ-27.4 | `StepInput` widget (textInput, singleFileUpload, multiPhotoUpload, teamDetailForm, confirmationSummary) | Not implemented | P0 |
| REQ-27.5 | File upload steps wire to existing FAP API upload endpoints | Not implemented | P0 |
| REQ-27.6 | Per-document validation fires on upload, Flutter polls `GET /api/documents/{id}/status` every 3s | Not implemented | P0 |
| REQ-27.7 | Next step unlocks only when mandatory rules PASS for current step | Not implemented | P0 |
| REQ-27.8 | "Add Another Team?" loops back to step 5 | Not implemented | P0 |
| REQ-27.9 | Review Summary (step 10) — all docs, teams, validation results in scrollable view | Not implemented | P0 |
| REQ-27.10 | Submit disabled until ALL mandatory checks pass across ALL steps | Not implemented | P0 |

---

## FEATURE 28 — TEAM-WISE ACTIVITY CAPTURE (US-N3) — PARTIALLY IMPLEMENTED

**What exists**: `Teams` entity with PackageId, CampaignName, TeamCode, StartDate, EndDate, WorkingDays, DealershipName, DealershipAddress, GPSLocation, State, TeamsJson, VersionNumber. `TeamPhotos` entity. Navigation properties on DocumentPackage.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-28.2 | Per-team fields: TeamNumber (auto-increment), DealerName, DealerCode, City — some field names differ from entity | Partial — entity has CampaignName/TeamCode instead of TeamNumber/DealerCode | P0 |
| REQ-28.3 | Team State must match FAP-level State — validation error on mismatch | Not implemented | P0 |
| REQ-28.4 | 5-6 photos per team, total cap 50 per FAP | Not enforced | P0 |
| REQ-28.6 | Team form integrated into guided submission stepper (Steps 5-7 of US-N2) | Not implemented — depends on Feature 27 | P0 |

---

## FEATURE 29 — YEAR-WISE DASHBOARD NAVIGATION (US-N7) — NOT IMPLEMENTED

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-29.1 | Dashboard defaults to current Indian financial year (April-March) | Not implemented | P1 |
| REQ-29.2 | Year selector dropdown (current + previous years, format: 2025-26) | Not implemented — no `FinancialYearSelector` widget | P1 |
| REQ-29.3 | All counts/statuses/filters apply within selected FY | Not implemented | P1 |
| REQ-29.4 | Past-year submissions read-only — no action buttons | Not implemented | P1 |
| REQ-29.5 | API accepts `financialYear` query parameter (format: 2025-26) | Not implemented — no `FinancialYearService` | P1 |

---

## FEATURE 30 — PROACTIVE PER-DOCUMENT VALIDATION (US-N8) — NOT IMPLEMENTED

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-30.1 | Validation fires on EACH file upload — not on Submit | Not implemented — validation runs as full pipeline after submission | P0 |
| REQ-30.2 | Flutter shows processing indicator (spinner in DocumentCard) after upload | Not implemented | P0 |
| REQ-30.3 | Fast rules return <1 second | Not implemented as separate tier | P0 |
| REQ-30.4 | AI rules return within 20 seconds | Not implemented as separate tier | P0 |
| REQ-30.5 | Flutter polls `GET /api/documents/{id}/status` every 3s until terminal | Not implemented — no status polling endpoint | P0 |
| REQ-30.6 | Failed checks show: rule, reason, correction instruction for agency | Not implemented | P0 |
| REQ-30.7 | Agency can replace/re-upload any doc before submission — triggers full re-validation | Partial — re-upload exists but per-doc validation doesn't | P0 |
| REQ-30.8 | Submit disabled until ALL mandatory rules pass across ALL docs | Not implemented | P0 |
| REQ-30.9 | GPS warning: soft WARN, agency can acknowledge (recorded in ValidationResults) | Not implemented | P1 |

---

## FEATURE 31 — INTEGRATION: PO SYNC FROM SAP (INT-I1) — NOT IMPLEMENTED

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-31.1 | Job J1 runs daily 11:00 PM as `IHostedService` | Not implemented — no `POSyncJob` | P0 |
| REQ-31.2 | POST to MuleSoft SAP endpoint for PO data | Not implemented | P0 |
| REQ-31.3 | API key stored in Key Vault | Not implemented | P0 |
| REQ-31.5 | Decode Base64 CSV → parse → filter by agency code | Not implemented | P0 |
| REQ-31.6 | Duplicate check before insert | Not implemented | P0 |
| REQ-31.7 | Upsert into `POAgencyMap` table | Not implemented — no entity exists | P0 |
| REQ-31.8 | Retry on failure, log sync results | Not implemented | P0 |

---

## FEATURE 32 — INTEGRATION: TERRITORY MASTER SYNC (INT-I2) — NOT IMPLEMENTED

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-32.1 | Job J2 runs daily 12:00 AM as `IHostedService` | Not implemented — no `TerritorySyncJob` | P0 |
| REQ-32.2 | POST to MuleSoft SAP endpoint for territory data | Not implemented | P0 |
| REQ-32.4 | Full refresh of `TerritoryMapping` table (StateCode, CircleHeadUserId, RAUserId, Region) | Not implemented — no entity exists | P0 |
| REQ-32.5 | Territory drives FAP routing: StateCode → CH → RA | Not implemented — this is the prerequisite for role-based scoping | P0 |

---

## FEATURE 33 — INTEGRATION: REAL-TIME PO BALANCE CHECK (INT-I3) — PARTIALLY IMPLEMENTED

**What exists**: SAP HTTP client configured in DI with base URL + API key. `ValidationAgent` has SAP call logic with Polly retry + circuit breaker.

**Pending Requirements**:

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-33.1 | GET endpoint to MuleSoft for PO data | SAP client configured but specific endpoint not wired | P0 |
| REQ-33.2 | Triggered on-demand by CH clicking "Check PO Amount" — NOT automatic | Not implemented as on-demand endpoint | P0 |
| REQ-33.3 | Request body format with company_code, po_num, request_type | Not verified | P0 |
| REQ-33.4 | Response parsing: po_header, po_line_item[], gr_data[] | Not verified | P0 |
| REQ-33.5 | Balance calc: Sum(price_without_tax) - Sum(invoice_value) across non-deleted line items | Not implemented | P0 |
| REQ-33.7 | Invoice > PO balance → EXCEEDS_BALANCE flag, CH can override (soft block) | Not implemented | P0 |
| REQ-33.8 | SAP unavailable → SAP_PENDING with retryAfter: 300 | Not implemented | P1 |
| REQ-33.9 | Polly retry: 3 attempts, exponential backoff, queue on final failure | Partial — retry exists in ValidationAgent | P1 |

---

## FEATURE 34 — INTEGRATION: INQUIRY DATA SYNC TO WAREHOUSE (INT-I4) — NOT IMPLEMENTED (BLOCKED)

**Blocked**: Warehouse API contract pending from Kaushik / Warehouse team.

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-34.1 | Job J7 runs daily 1:00 AM | Not implemented | P1 |
| REQ-34.2–34.5 | POST to warehouse, batch processing, DLQ for failures | Not implemented | P1 |
| REQ-34.6 | BLOCKED: API contract pending | OPEN question | P1 |

---

## FEATURE 35 — BLOB CLEANUP JOB (INT-J11) — NOT IMPLEMENTED

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-35.1 | Job J11 runs weekly Sunday 1:00 AM | Not implemented | P2 |
| REQ-35.2 | Scan Blob Storage for orphan blobs (no DB record) | Not implemented | P2 |
| REQ-35.3 | Delete confirmed orphans only | Not implemented | P2 |
| REQ-35.4 | Safety: never delete blobs <24 hours old | Not implemented | P2 |
| REQ-35.5 | Log all deletions (blob name, size, creation date) | Not implemented | P2 |

---

## FEATURE 36 — AUDIT LOG ARCHIVAL JOB (INT-J12) — NOT IMPLEMENTED

| REQ | Description | Status | Priority |
|-----|-------------|--------|----------|
| REQ-36.1 | Job J12 runs monthly 1st at 2:00 AM | Not implemented | P2 |
| REQ-36.2 | Move AuditEventLog records >12 months to `AuditEventLogArchive` | Not implemented | P2 |
| REQ-36.3 | Archive table is write-only (no UPDATE/DELETE) | Not implemented | P2 |
| REQ-36.4 | Delete from active table only after confirmed archive write (transaction) | Not implemented | P2 |
| REQ-36.5 | Log archival run stats | Not implemented | P2 |

---

## SUMMARY — IMPLEMENTATION STATUS BY FEATURE

| # | Feature | Spec Status | Impl Status | Priority |
|---|---------|-------------|-------------|----------|
| 1 | Document Upload | Done | Partial | P0 |
| 2 | Document Classification & Extraction | Done | Partial | P0 |
| 3 | Validation Rules Engine | In Progress | Partial (major gap) | P0 |
| 4 | Confidence Score | In Progress | Mostly done | P0 |
| 5 | Approval Recommendations | In Progress | Partial | P0 |
| 6 | Email Communication | Not Started | Not implemented | P1 |
| 7 | Analytics Dashboard | Not Started | Partial | P1 |
| 8 | In-App Notification Management | Not Started | Partial | P1 |
| 9 | User Auth & RBAC | In Progress | Partial (major gap) | P0 |
| 10 | UI / Branding | In Progress | Partial | P1 |
| 11 | Data Persistence & Integrity | In Progress | Partial | P0 |
| 12 | API Design | Done | Mostly done | P0 |
| 13 | Performance & Scalability | Not Started | Not implemented | P1 |
| 14 | Error Handling & Resilience | In Progress | Partial | P0 |
| 15 | Security & Compliance | In Progress | Partial | P0 |
| 16 | Upload Page UI | Done | Partial | P0 |
| 17 | Submissions Dashboard | Done | Mostly done | P0 |
| 18 | RA Approval Flow | Done | Partial | P0 |
| 19 | PO Auto-Dispatch | In Progress | Not implemented | P1 |
| 20 | Audit Read-Only Access | For Later | Not implemented | P2 |
| 21 | SAP Service Entry Auto-Create | BLOCKED | Not implemented | P2 |
| 22 | Teams Bot: CH Approve/Reject | In Progress | Not implemented | P1 |
| 23 | Teams Bot: New FAP Alert | In Progress | Not implemented | P1 |
| 24 | Mobile App Flutter | Not Started | Partial (web only) | P1 |
| 25 | WhatsApp Notifications | Not Started | Not implemented | P2 |
| 26 | Portal Rename to ClaimsIQ | New | Not implemented | P0 |
| 27 | Conversational Guided Submission | New | Not implemented | P0 |
| 28 | Team-Wise Activity Capture | New | Partial (entity exists) | P0 |
| 29 | Year-Wise Dashboard Navigation | New | Not implemented | P1 |
| 30 | Proactive Per-Document Validation | New | Not implemented | P0 |
| 31 | PO Sync from SAP (INT-I1) | In Progress | Not implemented | P0 |
| 32 | Territory Master Sync (INT-I2) | In Progress | Not implemented | P0 |
| 33 | Real-Time PO Balance Check (INT-I3) | In Progress | Partial | P0 |
| 34 | Inquiry Data Sync (INT-I4) | Not Started | Not implemented (BLOCKED) | P1 |
| 35 | Blob Cleanup Job (INT-J11) | Not Started | Not implemented | P2 |
| 36 | Audit Log Archival (INT-J12) | Not Started | Not implemented | P2 |

---

## CRITICAL BLOCKERS & DEPENDENCIES

1. **Feature 9 (Entra ID Auth)** blocks Features 1, 17, 24 — AgencyId-from-token pattern requires Entra integration
2. **Feature 32 (Territory Sync)** blocks Features 8, 17, 22, 23 — role-based scoping and CH/RA assignment requires territory mapping
3. **Feature 3 (Validation Rules Engine redesign)** blocks Features 5, 30 — per-rule model needed for validation table display and per-document validation
4. **Feature 31 (PO Sync)** blocks Feature 19 — PO auto-dispatch requires PO data from SAP
5. **Feature 21 (SAP Service Entry)** BLOCKED by external dependency (Abhinandan)
6. **Feature 34 (Inquiry Sync)** BLOCKED by external dependency (Kaushik / Warehouse team)
7. **Feature 25 (WhatsApp)** BLOCKED by external dependency (Meta Business Account approval)

## RECOMMENDED IMPLEMENTATION ORDER (P0 first)

### Phase 1 — Foundation
1. Feature 26 — Portal Rename to ClaimsIQ (quick win, P0)
2. Feature 9 — Entra ID Auth (unblocks many features)
3. Feature 32 — Territory Master Sync (unblocks role-based routing)
4. Feature 3 — Validation Rules Engine redesign (per-rule model)

### Phase 2 — Core Workflow
5. Feature 30 — Proactive Per-Document Validation
6. Feature 27 — Conversational Guided Submission
7. Feature 28 — Team-Wise Activity Capture (complete gaps)
8. Feature 31 — PO Sync from SAP
9. Feature 33 — Real-Time PO Balance Check

### Phase 3 — Approval & Notifications
10. Feature 18 — RA Approval Flow (payment integration)
11. Feature 22 — Teams Bot: CH Approve/Reject
12. Feature 23 — Teams Bot: New FAP Alert
13. Feature 6 — Email Communication
14. Feature 8 — In-App Notifications (complete)

### Phase 4 — Polish & Scale
15. Feature 10 — UI/Branding (shared components)
16. Feature 29 — Year-Wise Dashboard Navigation
17. Feature 7 — Analytics Dashboard (complete)
18. Feature 13 — Performance & Scalability
19. Feature 24 — Mobile App (native features)
20. Feature 19 — PO Auto-Dispatch

### Phase 5 — Deferred
21. Feature 20 — Audit Read-Only Access (P2)
22. Feature 35 — Blob Cleanup Job (P2)
23. Feature 36 — Audit Log Archival (P2)
24. Feature 25 — WhatsApp Notifications (P2, blocked)
25. Feature 21 — SAP Service Entry (P2, blocked)
26. Feature 34 — Inquiry Data Sync (P1, blocked)
