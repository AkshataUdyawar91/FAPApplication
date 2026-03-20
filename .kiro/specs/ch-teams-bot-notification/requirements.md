# Requirements: CH Teams Bot — New Claim Notification

## Overview
The CH (Circle Head / ASM) needs to receive a rich Microsoft Teams notification the moment a new claim submission completes AI validation. The notification must provide enough context for quick decision-making directly within Teams, with fallback to email when Teams is unavailable.

## Personas
- **CH (Circle Head)**: First-level approver, manages 5–15 dealers across a territory. Receives 3–8 submissions/week (up to 15–20 at quarter-end). Primary workspace is Microsoft Teams on mobile.
- **Agency**: Submits document packages (PO, invoices, photos, cost summaries). Receives status updates after CH action.
- **RA (Regional Approver / HQ)**: Second-level approver. Receives submissions forwarded by CH after approval.

> **Codebase Mapping**:
> - CH = ASM role (`UserRole.ASM`), RA = HQ role (`UserRole.RA`)
> - ReadyForReview = `PackageState.PendingASM` (enum value 4)
> - AIProcessing = The package remains in `Extracting` (2) or `Validating` (3) state while the `WorkflowOrchestrator` runs all 4 pipeline steps (Extract → Validate → Score → Recommend). There are no separate `Scoring` or `Recommending` states — the package jumps directly from `Validating` to `PendingASM` upon successful pipeline completion.
> - FAP ID = Human-readable submission identifier derived as `FAP-{first 8 chars of DocumentPackage.Id GUID, uppercased}` (e.g., `FAP-28C9823C`). This is a display convention used in ChatService and AnalyticsPlugin — not a stored field. The full GUID is used for API calls.
> - **ASM Assignment (DEFERRED)**: Currently, there is NO per-submission ASM assignment. The `ASM` entity has a `Location` field and `Teams` entity has a `State` field, but no matching logic exists. All ASM-role users see all `PendingASM` submissions (broadcast model). Territory-based ASM-to-Agency/Submission routing is a prerequisite for targeted notifications and must be implemented before this feature. See "Deferred: ASM Assignment" section below.

## Deferred: ASM Assignment (Prerequisite)

> **Status**: DEFERRED — Must be implemented before notification targeting can work correctly.
>
> The current codebase has no mechanism to determine which ASM is responsible for a given submission. The building blocks exist (`ASM.Location`, `Teams.State`, `Agency.SupplierCode`) but the wiring is absent:
> - `DocumentPackage` has no `AssignedASMUserId` field
> - `Agency` has no territory/location/ASM reference
> - `ListSubmissions` returns all packages for non-Agency roles with zero filtering
> - The seed data has a single `asm@bajaj.com` user
>
> **Required before this feature**: Implement ASM-to-submission assignment logic (e.g., match `Teams.State` or Agency location against `ASM.Location`, or add an explicit `AssignedASMUserId` FK on `DocumentPackage`). Once assignment exists, Req 1 and Req 14.4 can target the assigned ASM instead of broadcasting.
>
> **Impact on this spec**: All requirements below that reference "the assigned ASM" assume this prerequisite is in place. Until then, notification targeting cannot be implemented correctly.

---

### Requirement 1: Notification Trigger on Submission Ready for Review

**User Story**: As a CH, I want to automatically receive a Teams notification when a submission completes AI validation, so that I am immediately aware of new claims requiring my attention.

**Acceptance Criteria**:

- 1.1 Given a submission's status transitions to `PendingASM` (set by `WorkflowOrchestrator.ProcessSubmissionAsync` after all 4 pipeline steps complete) AND the assigned ASM user has a valid `TeamsConversationRef` stored in the Users table, When the state transition completes, Then a Teams Adaptive Card notification is sent to that ASM user's 1:1 chat with the ClaimsIQ bot within 2 minutes. _(Depends on ASM assignment prerequisite — see Deferred section.)_
- 1.2 Given a submission is still being processed by the `WorkflowOrchestrator` (state remains `Extracting` or `Validating` throughout the Extract → Validate → Score → Recommend pipeline), When the pipeline is running, Then NO notification is sent until the pipeline completes and the orchestrator sets state to `PendingASM`.
- 1.3 Given the assigned ASM user record has `TeamsConversationRef` = NULL (bot not installed), When a submission reaches `PendingASM`, Then the system falls back to email notification for that ASM (see Requirement 7) and does NOT attempt Teams delivery for that user.
- 1.4 Given a submission is in `Uploaded` state (agency has not triggered processing), When the package exists, Then NO notification is sent to any ASM.
- 1.5 Given the AI validation pipeline fails (any step in `WorkflowOrchestrator` returns false) and the `CompensateAsync` method is called, When the pipeline errors out, Then NO notification is sent to any ASM (no partial notifications). The existing compensation logic (which notifies the submitting agency user via `NotifySubmissionReceivedAsync`) handles the failure path. A separate ops alert should be logged at ERROR level.
- 1.6 Given the `WorkflowOrchestrator` currently calls `NotifySubmissionReceivedAsync(package.SubmittedByUserId, ...)` after setting `PendingASM`, When the new Teams notification feature is implemented, Then a new call to the ASM notification service is added alongside (not replacing) the existing agency notification. The agency user continues to receive their "submission received" notification as before.

---

### Requirement 2: Adaptive Card — Header and Key Facts Sections

**User Story**: As a CH, I want the notification card to show a clear header and key claim facts at a glance, so that I can quickly identify which submission this is about without opening the portal.

**Acceptance Criteria**:

- 2.1 Given a new claim notification is sent, When the Adaptive Card renders, Then Section 1 (Header) displays the title "New Claim Submitted" (size=medium, weight=bolder, color=accent) and the notification timestamp (size=small, isSubtle=true, right-aligned).
- 2.2 Given a new claim notification is sent, When the Adaptive Card renders, Then Section 2 (Key Facts) displays a FactSet with: FAP ID (e.g., "FAP-28C9823C", derived from first 8 chars of `DocumentPackage.Id`), Agency name (from `Agency.SupplierName` via `DocumentPackage.Agency`), PO Number (from `PO.PONumber` or fallback to `PO.ExtractedDataJson`), Invoice Number (from first `CampaignInvoice.InvoiceNumber` across Teams), Invoice Amount (sum of `CampaignInvoice.TotalAmount` across all Teams, formatted with ₹ currency), State (from `DocumentPackage` Teams' geographic `State` field), Submitted timestamp (from `DocumentPackage.CreatedAt`), Team count with photo count (e.g., "3 teams | 19 photos" from `DocumentPackage.Teams.Count` and `DocumentPackage.TeamPhotos.Count`), and Inquiry count with completion (from `EnquiryDocument` extracted data if available, otherwise "N/A").
- 2.3 Given the card is viewed on Teams mobile (Android or iOS), When the FactSet renders, Then all facts are readable without horizontal scrolling and labels/values wrap cleanly.

---

### Requirement 3: Adaptive Card — AI Recommendation Section

**User Story**: As a CH, I want to see the AI recommendation and confidence score on the notification card, so that I can gauge the claim quality before reviewing details.

**Acceptance Criteria**:

- 3.1 Given a submission with `Recommendation.Type = RecommendationType.Approve`, When the card renders, Then the AI section displays a banner with emoji indicator: "✅ Recommended: Approve". No background color change is applied to the container.
- 3.2 Given a submission with `Recommendation.Type = RecommendationType.Review`, When the card renders, Then the AI section displays a banner with emoji indicator: "⚠️ Recommended: Review". No background color change is applied to the container.
- 3.3 Given a submission with `Recommendation.Type = RecommendationType.Reject`, When the card renders, Then the AI section displays a banner with emoji indicator: "❌ Recommended: Reject". No background color change is applied to the container.

---

### Requirement 4: Adaptive Card — PO Balance Quick Glance Section

> **Note**: PO balance data (PO Total Amount, Previously Consumed, Remaining Balance) is not currently stored in the application database. This data comes from SAP via MuleSoft integration and is fetched on-demand when the CH clicks "Check PO Amount" in the portal. This requirement is deferred to a future iteration pending SAP integration availability. The adaptive card should include a placeholder section with a "Check PO Balance in Portal" link instead.

**User Story**: As a CH, I want to see a link to check PO balance from the notification card, so that I can verify the claim amount in the portal.

**Acceptance Criteria**:

- 4.1 Given a submission notification is sent, When the card renders, Then the PO Balance section displays a message: "PO balance check available in portal" with an "Open in Portal" link.
- 4.2 _(Deferred)_ Full PO balance display with real-time SAP data will be added when the MuleSoft integration endpoint is available for server-side consumption.

---

### Requirement 5: Adaptive Card — Action Buttons with Conditional Visibility

**User Story**: As a CH, I want contextually appropriate action buttons on the notification card, so that I can take the right action based on the AI recommendation without unnecessary steps.

**Acceptance Criteria**:

- 5.1 Given a submission with `Recommendation.Type = RecommendationType.Approve` (score ≥ 80), When the card renders, Then three buttons are shown: "Quick Approve" (primary/accent style), "Review Details", and "Open in Portal".
- 5.2 Given a submission with `Recommendation.Type = RecommendationType.Review` (score 60–79), When the card renders, Then two buttons are shown: "Review Details" (primary style) and "Open in Portal". The "Quick Approve" button is hidden.
- 5.3 Given a submission with `Recommendation.Type = RecommendationType.Reject` (score < 60), When the card renders, Then two buttons are shown: "Review Details" (primary style) and "Open in Portal". The "Quick Approve" button is hidden.
- 5.4 Given the "Quick Approve" button, When implemented, Then it uses Action.Submit with data `{ action: 'quick_approve', submissionId: '<GUID>' }` so the bot handles it inline.
- 5.5 Given the "Review Details" button, When implemented, Then it uses Action.Submit with data `{ action: 'review_details', submissionId: '<GUID>' }` so the bot posts a follow-up validation breakdown.
- 5.6 Given the "Open in Portal" button, When implemented, Then it uses Action.OpenUrl with the deep link URL to the portal review page for the submission (configurable base URL).

---

### Requirement 6: Quick Approve Conversational Flow

**User Story**: As a CH, I want to approve a high-confidence claim directly from Teams in a few taps, so that I can process straightforward claims without switching to the portal.

**Acceptance Criteria**:

- 6.1 Given the CH clicks "Quick Approve" on the notification card, When the bot receives the Action.Submit, Then the bot posts a confirmation message: "You're about to approve FAP-{shortId} ({agencyName}, ₹{amount}). Do you want to continue? [Approve Invoice] [Cancel]".
- 6.2 Given the CH clicks "Approve Invoice" on the confirmation, When confirmed, Then the bot asks for optional comments: "Any comments? (optional — type or tap Skip) [Skip]".
- 6.3 Given the CH provides comments or clicks "Skip", When the response is received, Then the bot calls `PATCH /api/submissions/{id}/asm-approve` with `ApproveSubmissionRequest { Notes: '<comments or null>' }` (matching the existing endpoint which accepts `[FromBody] ApproveSubmissionRequest?` with an optional `Notes` field, max 500 chars). The submission `{id}` is the GUID from the card's action data. The bot authenticates as the ASM user via JWT. On success, the bot posts: "✅ Approved! FAP-{shortId} forwarded to RA. {agencyName} will be notified. Payable amount: ₹{amount}".
- 6.4 Given the CH clicks "Cancel" on the confirmation, When cancelled, Then the bot posts "Approval cancelled. No changes made." and the submission remains in `PendingASM` state.
- 6.5 Given the entire Quick Approve flow, When counted, Then the flow completes in ≤ 4 interaction steps: card → confirmation → comments → confirmed.
- 6.6 Given the approval succeeds, When the backend processes it, Then the existing `ASMApproveSubmission` endpoint logic executes: state transitions to `PendingRA`, a `RequestApprovalHistory` record is created with `ApproverRole = UserRole.ASM` and `Action = ApprovalAction.Approved`. Downstream notifications (RA notification, Agency status update) should be triggered as per the existing flow.

---

### Requirement 7: Email Fallback Notification

**User Story**: As a CH who hasn't installed the Teams bot, I want to receive an email notification when a new claim is ready for review, so that I'm not left unaware of pending submissions.

**Acceptance Criteria**:

- 7.1 Given the assigned ASM user has `TeamsConversationRef` = NULL in the Users table, When a submission reaches `PendingASM`, Then an email notification is sent within 2 minutes using the existing `IEmailAgent` infrastructure (a new method or extension of `SendDataPassEmailAsync`).
- 7.2 Given the email notification, When sent, Then the subject line is "ClaimsIQ: New claim from {agencyName} — ₹{invoiceAmount}".
- 7.3 Given the email notification, When rendered, Then the body contains: ClaimsIQ logo header, the same key facts as the adaptive card including FAP ID (HTML table format), AI recommendation section (color-coded inline), and a CTA button "Review in ClaimsIQ Portal" linking to the portal URL.
- 7.4 Given the email notification, When the CH reads it, Then the email does NOT support inline approval — the CH must click through to the portal to take action.
- 7.5 Given the email is sent, When recorded, Then a record is created in the Notifications table. The existing `Notification` entity will be extended with new fields: `Channel` (string: 'Teams', 'Email', or 'InApp'), `DeliveryStatus` (string: 'Sent', 'Failed', 'Pending'), `RetryCount` (int), and `SentAt` (DateTime?). Existing in-app notifications default to `Channel = 'InApp'`, `DeliveryStatus = 'Sent'`.
- 7.6 Given the email template, When stored, Then it is located at `backend/src/BajajDocumentProcessing.API/templates/email/new-submission.html` and uses the same data context as the adaptive card.
- 7.7 Given the email footer, When rendered, Then it includes: "You're receiving this because you're an assigned reviewer. Install the ClaimsIQ Teams bot for richer notifications."

---

### Requirement 8: Bot Installation and Conversation Reference Capture

**User Story**: As a CH, I want the ClaimsIQ bot to automatically capture my Teams conversation reference when I first interact with it, so that the system can send me proactive notifications going forward.

**Acceptance Criteria**:

- 8.1 Given a CH sends any message to the ClaimsIQ bot for the first time, When the bot receives the message, Then the bot captures the ConversationReference via `turnContext.Activity.GetConversationReference()` and stores it as JSON in a new `Users.TeamsConversationRef` column (nvarchar(max), nullable) and extracts the channel ID into a new `Users.TeamsChannelId` column (nvarchar(200), nullable). This requires an EF Core migration to add both columns to the Users table.
- 8.2 Given the bot is registered in Azure Bot Service, When the Teams App Manifest is created, Then the bot is configured in "personal" scope (1:1 chat with user).
- 8.3 Given the Teams app is published, When deployed, Then it is side-loaded via Bajaj's Teams admin center for all CH and RA users.
- 8.4 Given a CH reinstalls Teams or the conversation reference becomes stale, When the bot attempts proactive messaging and receives a 403/404 error, Then the system sets `TeamsConversationRef = NULL` and `TeamsChannelId = NULL` and falls back to email. On the CH's next interaction with the bot, the reference is re-captured.

---

### Requirement 9: Proactive Messaging via Bot Framework

**User Story**: As the system, I want to send Teams notifications proactively (without the CH initiating a conversation), so that CHs receive timely claim notifications as soon as submissions are ready for review.

**Acceptance Criteria**:

- 9.1 Given a submission reaches `PendingASM` (set by `WorkflowOrchestrator`), When the Notification Dispatcher processes the event, Then for the assigned ASM user with a non-null `TeamsConversationRef`, it loads the ConversationReference, populates the adaptive card template with submission data, and sends the card via `BotAdapter.ContinueConversationAsync`. _(Depends on ASM assignment prerequisite.)_
- 9.2 Given the proactive message send, When executed, Then it uses the Bot App ID from Azure Bot registration, the stored ConversationReference, and a callback that constructs and sends the Adaptive Card attachment.
- 9.3 Given multiple submissions arrive for the same CH within a short window, When sending notifications, Then cards are sent sequentially with a 2-second delay between them to avoid Teams API rate limiting.
- 9.4 Given the Teams API returns an error (503, timeout), When the send fails, Then the system retries 3 times with exponential backoff (5s, 15s, 45s). After 3 failures, it falls back to email and logs all attempts in the Notifications table with `RetryCount` and `DeliveryStatus = 'Failed'`.
- 9.5 Given the Notification Dispatcher, When assembling card data, Then it calls a `NotificationDataService.GetSubmissionCardDataAsync(submissionId)` method which loads the `DocumentPackage` with all required includes (`PO`, `Teams.Invoices`, `Teams.Photos`, `EnquiryDocument`, `ConfidenceScore`, `Recommendation`, `ValidationResult`, `Agency`) and returns a strongly-typed DTO with all token values.

---

### Requirement 10: Adaptive Card Template and Token Population

**User Story**: As a developer, I want the adaptive card to be built from a JSON template with token placeholders populated at send time, so that the card design can be updated independently of the code.

**Acceptance Criteria**:

- 10.1 Given the card template, When stored, Then it is located at `backend/src/BajajDocumentProcessing.API/templates/teams-cards/new-submission-card.json` and follows Adaptive Card schema version 1.4.
- 10.2 Given the template, When populated, Then the AdaptiveCards.Templating NuGet package is used: `var template = new AdaptiveCardTemplate(jsonTemplate); var cardJson = template.Expand(dataContext);` where dataContext is a C# object with all token values.
- 10.3 Given the token set, When the card is populated, Then ALL of the following tokens are resolved: `submissionId` (GUID from `DocumentPackage.Id`), `fapId` (derived as `FAP-{first 8 chars of Id, uppercased}`, e.g., `FAP-28C9823C`), `agencyName` (from `Agency.SupplierName`), `poNumber` (from `PO.PONumber`), `invoiceNumber` (first `CampaignInvoice.InvoiceNumber`), `invoiceAmount` (sum of `CampaignInvoice.TotalAmount`), `state` (from Teams geographic `State` field), `submittedAt` (from `DocumentPackage.CreatedAt`), `teamCount` (from `Teams.Count`), `photoCount` (from `TeamPhotos.Count`), `inquiryTotal` / `inquiryComplete` (from `EnquiryDocument` if available), `recommendation` (from `Recommendation.Type.ToString()`), `cardStyle` (mapped from `RecommendationType`: Approve→"good", Review→"attention", Reject→"warning"), `passedChecks` / `totalChecks` (derived from `ValidationResult` boolean fields), `warningsList` (derived from failed validation checks and `ValidationDetailsJson`), `showQuickApprove` (true only when `Recommendation.Type = Approve`), `portalUrl` (configurable base URL + submissionId).
- 10.4 Given 5 different claim submissions, When cards are generated, Then no raw `{{placeholder}}` tokens are visible in any rendered card.

---

### Requirement 11: Review Details Inline Flow

**User Story**: As a CH, I want to click "Review Details" on the notification card and see a per-document validation breakdown directly in Teams, so that I can review issues without switching to the portal.

**Acceptance Criteria**:

- 11.1 Given the CH clicks "Review Details" on the notification card, When the bot receives the Action.Submit with `{ action: 'review_details', submissionId: '<GUID>' }`, Then the bot posts a follow-up message containing the full per-document validation summary.
- 11.2 Given the validation summary is posted, When the CH reviews it, Then the CH can approve or reject the submission inline within the Teams conversation (triggering the appropriate approval/rejection flow via the existing `PATCH /api/submissions/{id}/asm-approve` or `PATCH /api/submissions/{id}/asm-reject` endpoints).
- 11.3 Given the validation summary, When rendered, Then it includes validation results derived from the `ValidationResult` entity's boolean fields grouped by check type (SAP Verification, Amount Consistency, Line Item Matching, Completeness, Date Validation, Vendor Matching) with pass/fail status for each, plus any detailed issues from `ValidationDetailsJson`.

---

### Requirement 12: Idempotency and Duplicate Action Prevention

**User Story**: As a CH, I want the system to gracefully handle duplicate button clicks on the notification card, so that accidental double-taps don't create duplicate approvals or errors.

**Acceptance Criteria**:

- 12.1 Given the CH clicks "Quick Approve" on a card, When the bot processes the action, Then it first checks the current submission status by loading `DocumentPackage.State`. If the state is no longer `PendingASM` (e.g., already `PendingRA` or `Approved`), the bot responds: "FAP-{shortId} has already been processed. No further action needed." and does NOT call the approve endpoint.
- 12.2 Given the CH clicks "Quick Approve" twice rapidly, When both requests arrive, Then only one `RequestApprovalHistory` record is created. The second click receives the idempotent response. The existing `ASMApproveSubmission` endpoint already guards against invalid state transitions (returns 400 if state is not `PendingASM` or `RARejected`), so the bot should handle the 400 response gracefully.
- 12.3 Given the CH clicks "Review Details" on an already-processed submission, When the bot receives the action, Then the bot still shows the validation summary (read-only) but indicates the current status (e.g., "FAP-{shortId} was approved on {date}" derived from the latest `RequestApprovalHistory` record).

---

### Requirement 13: Cross-Platform Card Rendering

**User Story**: As a CH, I want the notification card to render correctly on all Teams platforms, so that I can act on claims regardless of which device I'm using.

**Acceptance Criteria**:

- 13.1 Given the Adaptive Card, When rendered on Teams Desktop (Windows/Mac), Then all sections display correctly with no truncation, and all buttons are functional.
- 13.2 Given the Adaptive Card, When rendered on Teams Web, Then all sections display correctly with no truncation, and all buttons are functional.
- 13.3 Given the Adaptive Card, When rendered on Teams Mobile (iOS), Then all sections are readable without horizontal scrolling, FactSet wraps cleanly, and buttons are tappable with minimum 48×48 touch targets.
- 13.4 Given the Adaptive Card, When rendered on Teams Mobile (Android), Then all sections are readable without horizontal scrolling, FactSet wraps cleanly, and buttons are tappable with minimum 48×48 touch targets.
- 13.5 Given the card payload, When generated, Then it is lightweight (~2KB JSON) with no embedded images (use emojis for status indicators) to ensure fast rendering on slow mobile connections.

---

### Requirement 14: Error Handling and Resilience

**User Story**: As the system, I want robust error handling for all notification delivery paths, so that CHs always receive their notifications through at least one channel.

**Acceptance Criteria**:

- 14.1 Given the Teams API returns a 403 or 404 error during proactive messaging, When the error is caught, Then the system sets `Users.TeamsConversationRef = NULL` and `Users.TeamsChannelId = NULL`, falls back to email notification, and logs the error at WARNING level.
- 14.2 Given the Teams API returns a 503 or timeout, When the error is caught, Then the system retries 3 times with exponential backoff (5s, 15s, 45s) using the existing resilience pattern from `ResiliencePolicies.cs`. After 3 failures, it falls back to email.
- 14.3 Given all retry attempts fail, When the final failure occurs, Then the Notifications table records `RetryCount = 3`, `DeliveryStatus = 'Failed'`, and a new row is created with `Channel = 'Email'` for the fallback.
- 14.4 _(Deferred — depends on ASM assignment prerequisite)_ Given a submission reaches `PendingASM`, When the notification fires, Then it is sent to the assigned ASM user only. Until ASM assignment is implemented, this requirement cannot be fulfilled. See "Deferred: ASM Assignment" section above.
- 14.5 Given the validation pipeline takes longer than 5 minutes, When the pipeline eventually completes, Then the notification is sent with complete data (delayed but not partial). No notification fires while the pipeline is still running — the trigger point is exclusively the `PendingASM` state transition in `WorkflowOrchestrator`.

---

### Requirement 15: Notification Logging and Audit Trail

**User Story**: As an administrator, I want all notification attempts and outcomes logged, so that I can troubleshoot delivery issues and audit the notification history.

**Acceptance Criteria**:

- 15.1 Given any notification is sent (Teams or email), When delivered, Then a record is created in the Notifications table (extended `Notification` entity) with: `Channel` ('Teams' or 'Email'), `DeliveryStatus` ('Sent', 'Failed', 'Pending'), `RetryCount`, `SentAt` timestamp, `Type` (using existing `NotificationType` enum — a new value `ReadyForReview` should be added for this notification type), and the related `RelatedEntityId` set to the `DocumentPackage.Id`.
- 15.2 Given a Teams notification fails and falls back to email, When both attempts are recorded, Then the Notifications table contains two rows: one for the failed Teams attempt (`Channel = 'Teams'`, `DeliveryStatus = 'Failed'`) and one for the email fallback (`Channel = 'Email'`, `DeliveryStatus = 'Sent'` or `'Failed'`).
- 15.3 Given a Quick Approve action is taken via Teams, When the approval is processed, Then the `RequestApprovalHistory` record is created by the existing `ASMApproveSubmission` endpoint. To distinguish Teams-originated approvals, a new optional `Channel` field (nvarchar(50), nullable, default NULL) should be added to `RequestApprovalHistory`. Portal approvals default to NULL or 'Portal', bot approvals set `Channel = 'TeamsBot'`. This requires an EF Core migration.

---

### Requirement 16: Conversational Bot — Query Pending Submissions

**User Story**: As a CH, I want to ask the ClaimsIQ bot to show me my pending submissions, so that I can initiate the review/approval flow even without receiving a proactive notification (e.g., if the notification was missed or delayed).

**Acceptance Criteria**:

- 16.1 Given the CH sends a message like "show my pending submissions" or "what's pending?" to the bot, When the bot processes the message, Then the bot calls `GET /api/submissions?state=PendingASM` (authenticated as the ASM user) and returns a summary card listing pending submissions with key facts (FAP ID, agency name, PO number, invoice amount, confidence score).
- 16.2 Given the pending submissions list is displayed, When the CH selects a submission, Then the bot displays the same notification card (Requirement 2–5) for that submission, enabling the same Quick Approve and Review Details flows.
- 16.3 Given the CH has no pending submissions, When the bot queries, Then the bot responds: "No pending submissions at this time."
