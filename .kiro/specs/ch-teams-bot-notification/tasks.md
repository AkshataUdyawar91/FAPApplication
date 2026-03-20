# Implementation Plan: CH Teams Bot — New Claim Notification

## Overview

Implement the full CH Teams Bot notification feature: rich Adaptive Card notifications to ASM users when submissions reach `PendingASM`, Quick Approve conversational flow, Review Details inline flow, email fallback, notification logging, and pending submissions query. Builds on existing `TeamsBotService`, `TeamsNotificationService`, `TeamsCardService`, and `TeamsConversation` infrastructure.

Tasks 1–2 from the previous iteration (header template, SubmissionCardData DTO, ITeamsCardService, TeamsCardService) are already implemented. This plan extends those components and adds all remaining functionality.

## Tasks

- [x] 1. Create Adaptive Card header template and card service (COMPLETED)
  - Header template, SubmissionCardData DTO, ITeamsCardService, TeamsCardService already exist
  - _Requirements: 2.1_

- [x] 2. Checkpoint — Header section verified (COMPLETED)

- [x] 3. Domain layer — New enums and entity extensions
  - [x] 3.1 Create `NotificationChannel` enum
    - Create `backend/src/BajajDocumentProcessing.Domain/Enums/NotificationChannel.cs`
    - Values: `InApp = 1`, `Teams = 2`, `Email = 3`
    - _Requirements: 7.5, 15.1_

  - [x] 3.2 Create `NotificationDeliveryStatus` enum
    - Create `backend/src/BajajDocumentProcessing.Domain/Enums/NotificationDeliveryStatus.cs`
    - Values: `Pending = 1`, `Sent = 2`, `Failed = 3`, `FallbackSent = 4`
    - _Requirements: 7.5, 15.1_

  - [x] 3.3 Extend `NotificationType` enum with `ReadyForReview = 6`
    - Modify `backend/src/BajajDocumentProcessing.Domain/Enums/NotificationType.cs`
    - _Requirements: 15.1_

  - [x] 3.4 Extend `Notification` entity with multi-channel delivery fields
    - Add `Channel` (NotificationChannel, default InApp), `DeliveryStatus` (NotificationDeliveryStatus, default Sent), `RetryCount` (int, default 0), `SentAt` (DateTime?), `ExternalMessageId` (string?), `FailureReason` (string?)
    - Modify `backend/src/BajajDocumentProcessing.Domain/Entities/Notification.cs`
    - _Requirements: 7.5, 15.1, 15.2_

  - [x] 3.5 Extend `RequestApprovalHistory` entity with `Channel` field
    - Add `Channel` (string?, nullable) to track "Portal", "TeamsBot", or null (legacy)
    - Modify `backend/src/BajajDocumentProcessing.Domain/Entities/RequestApprovalHistory.cs`
    - _Requirements: 15.3_

- [x] 4. Database migration for new fields
  - [x] 4.1 Create EF Core migration for Notification and RequestApprovalHistory extensions
    - Add columns: `Notifications.Channel`, `Notifications.DeliveryStatus`, `Notifications.RetryCount`, `Notifications.SentAt`, `Notifications.ExternalMessageId`, `Notifications.FailureReason`
    - Add column: `RequestApprovalHistory.Channel`
    - Add composite index `IX_Notifications_UserId_Channel_DeliveryStatus`
    - Add composite index `IX_Notifications_RelatedEntityId_Channel`
    - Update EF Core entity configurations in `ApplicationDbContext` or configuration files
    - Ensure existing rows default to `Channel = InApp`, `DeliveryStatus = Sent`
    - _Requirements: 7.5, 15.1, 15.3_

- [x] 5. Checkpoint — Ensure migration applies cleanly and all tests pass
  - Ensure all tests pass, ask the user if questions arise.


- [x] 6. Application layer — New interfaces and DTO extensions
  - [x] 6.1 Extend `SubmissionCardData` DTO with all token fields
    - Add Key Facts fields: `AgencyName`, `PoNumber`, `InvoiceNumber`, `InvoiceAmount`, `InvoiceAmountRaw`, `State`, `SubmittedAt`, `SubmittedAtFormatted`, `TeamCount`, `PhotoCount`, `TeamPhotoSummary`, `InquirySummary`
    - Add AI Recommendation fields: `Recommendation`, `RecommendationEmoji`, `CardStyle`, `ConfidenceScore`, `ConfidenceScoreFormatted`, `PassedChecks`, `TotalChecks`, `ChecksSummary`, `AllChecksPassed`, `TopIssues` (List<ValidationIssueItem>), `RemainingIssueCount`, `RemainingIssueText`
    - Add PO Balance placeholder: `PoBalanceMessage`
    - Add Action fields: `ShowQuickApprove`, `PortalUrl`
    - Create `ValidationIssueItem` class (Severity, Description)
    - Modify `backend/src/BajajDocumentProcessing.Application/DTOs/Notifications/SubmissionCardData.cs`
    - _Requirements: 2.2, 3.1–3.6, 4.1, 5.1–5.3, 10.3_

  - [x] 6.2 Create `ValidationBreakdownData` DTO
    - Create `backend/src/BajajDocumentProcessing.Application/DTOs/Notifications/ValidationBreakdownData.cs`
    - Include `SubmissionId`, `SubmissionNumber`, `CurrentStatus`, `ProcessedAt`, `ProcessedBy`, `IsAlreadyProcessed`, `CheckGroups` (List<ValidationCheckGroup>), `PortalUrl`
    - Create `ValidationCheckGroup` class (GroupName, Status, Details)
    - _Requirements: 11.1, 11.3_

  - [x] 6.3 Create `ProactiveMessageResult` DTO
    - Create in `backend/src/BajajDocumentProcessing.Application/DTOs/Notifications/ProactiveMessageResult.cs`
    - Include `Success`, `HttpStatusCode`, `ErrorMessage`, `ActivityId`
    - _Requirements: 9.1, 9.4_

  - [x] 6.4 Create `INotificationDispatcher` interface
    - Create `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/INotificationDispatcher.cs`
    - Define `Task DispatchNewSubmissionNotificationAsync(Guid packageId, CancellationToken cancellationToken = default)`
    - _Requirements: 1.1, 1.3, 7.1, 9.1_

  - [x] 6.5 Create `INotificationDataService` interface
    - Create `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/INotificationDataService.cs`
    - Define `Task<SubmissionCardData> GetSubmissionCardDataAsync(Guid packageId, CancellationToken ct)`
    - Define `Task<ValidationBreakdownData> GetValidationBreakdownAsync(Guid packageId, CancellationToken ct)`
    - _Requirements: 9.5, 11.1_

  - [x] 6.6 Extend `ITeamsCardService` with `BuildReviewDetailsCard`
    - Add `string BuildReviewDetailsCard(ValidationBreakdownData data)` to existing interface
    - Modify `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/ITeamsCardService.cs`
    - _Requirements: 11.1_

  - [x] 6.7 Extend `ITeamsNotificationService` with per-user proactive send
    - Add `Task<ProactiveMessageResult> SendProactiveCardToUserAsync(TeamsConversation conversation, string cardJson, CancellationToken ct)` to existing interface
    - Modify `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/ITeamsNotificationService.cs`
    - _Requirements: 9.1, 9.2_

- [x] 7. Implement `NotificationDataService` — data assembly for cards and emails
  - [x] 7.1 Implement `GetSubmissionCardDataAsync`
    - Create `backend/src/BajajDocumentProcessing.Infrastructure/Services/NotificationDataService.cs`
    - Load `DocumentPackage` with all required includes (PO, Agency, Teams.Invoices, Teams.Photos, EnquiryDocument, ConfidenceScore, Recommendation, ValidationResult) using `AsSplitQuery()` and `AsNoTracking()`
    - Derive FAP ID: `"FAP-" + package.Id.ToString()[..8].ToUpper()`
    - Map Key Facts: AgencyName from `Agency.SupplierName`, PO from `PO.PONumber` with fallback, Invoice from first `CampaignInvoice`, Amount as sum of `TotalAmount`, State from Teams, team/photo counts, inquiry from `EnquiryDocument`
    - Map AI Recommendation: type → emoji/cardStyle mapping (Approve→"good"/"✅", Review→"attention"/"⚠️", Reject→"warning"/"❌"), confidence score formatting, validation check counting (6 boolean fields on ValidationResult), top 3 issues sorted Fail before Warning, remaining issue count
    - Set `ShowQuickApprove = true` only when `Recommendation.Type == Approve`
    - Set `PortalUrl` from `TeamsBot:PortalBaseUrl` configuration + `/fap/{submissionId}/review`
    - Handle null navigations gracefully with "N/A" fallbacks
    - _Requirements: 2.2, 3.1–3.6, 4.1, 5.1–5.3, 9.5, 10.3_

  - [ ]* 7.2 Write property test — Property 3: Recommendation type maps to correct card style and emoji
    - **Property 3: For any `RecommendationType`, the mapping produces the correct (CardStyle, Emoji) pair: Approve→("good","✅"), Review→("attention","⚠️"), Reject→("warning","❌")**
    - **Validates: Requirements 3.1, 3.2, 3.3**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDataServiceProperties.cs`

  - [ ]* 7.3 Write property test — Property 7: Validation issues sorted by severity, capped at 3
    - **Property 7: For any list of validation issues, TopIssues is sorted Fail-before-Warning, contains ≤3 items, and RemainingIssueCount = max(0, total - 3). When AllValidationsPassed=true, TopIssues is empty**
    - **Validates: Requirements 3.4, 3.5, 3.6**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDataServiceProperties.cs`

  - [ ]* 7.4 Write property test — Property 19: Portal URL format
    - **Property 19: For any submission ID, PortalUrl equals `{configuredBaseUrl}/fap/{submissionId}/review`**
    - **Validates: Requirements 5.6**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDataServiceProperties.cs`

  - [x] 7.5 Implement `GetValidationBreakdownAsync`
    - Load package with ValidationResult and latest RequestApprovalHistory
    - Group validation checks by type: SAP Verification, Amount Consistency, Line Item Matching, Completeness, Date Validation, Vendor Matching
    - Set pass/fail status per group from ValidationResult boolean fields
    - Parse `ValidationDetailsJson` for detailed issue descriptions
    - Set `IsAlreadyProcessed` when state ≠ PendingASM, populate `ProcessedBy`/`ProcessedAt` from latest history
    - _Requirements: 11.1, 11.3_

  - [ ]* 7.6 Write property test — Property 15: Validation breakdown grouped by check type
    - **Property 15: For any ValidationResult, the breakdown contains checks grouped by type (6 groups), each with non-empty GroupName and Status of "Pass" or "Fail"**
    - **Validates: Requirements 11.1, 11.3**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDataServiceProperties.cs`

  - [ ]* 7.7 Write unit tests for NotificationDataService
    - Test known submission data produces expected SubmissionCardData with all fields populated
    - Test null PO number falls back to "N/A"
    - Test zero teams produces "0 teams | 0 photos"
    - Test boundary confidence scores (0, 59, 60, 79, 80, 100)
    - Test null EnquiryDocument produces "N/A" inquiry summary
    - Test missing Agency navigation handled gracefully
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/NotificationDataServiceTests.cs`
    - _Requirements: 2.2, 3.1–3.6, 9.5_


- [x] 8. Extend Adaptive Card templates — full 5-section card and review details card
  - [x] 8.1 Extend `new-submission-card.json` with all 5 sections
    - Extend existing template at `backend/templates/teams-cards/new-submission-card.json`
    - Section 2 (Key Facts): FactSet with tokens `${submissionNumber}`, `${agencyName}`, `${poNumber}`, `${invoiceNumber}`, `${invoiceAmount}`, `${state}`, `${submittedAtFormatted}`, `${teamPhotoSummary}`, `${inquirySummary}`
    - Section 3 (AI Recommendation): Container with `${cardStyle}` style, `${recommendationEmoji}` + `${recommendation}` + `${confidenceScoreFormatted}`, `${checksSummary}`, conditional `${topIssues}` array iteration, `${remainingIssueText}`, conditional "All checks passed" when `${allChecksPassed}`
    - Section 4 (PO Balance placeholder): TextBlock with `${poBalanceMessage}` and "Open in Portal" Action.OpenUrl
    - Section 5 (Action Buttons): "Quick Approve" (Action.Submit, conditional on `${showQuickApprove}`), "Review Details" (Action.Submit), "Open in Portal" (Action.OpenUrl with `${portalUrl}`)
    - Use Adaptive Card schema v1.4 with `${property}` token syntax
    - Keep payload under 4KB, use emojis not images
    - _Requirements: 2.1, 2.2, 3.1–3.6, 4.1, 5.1–5.6, 10.1, 10.2, 13.5_

  - [x] 8.2 Create `review-details-card.json` template
    - Create `backend/templates/teams-cards/review-details-card.json`
    - Header with FAP ID and current status
    - Validation check groups as FactSet rows (GroupName → Status with pass/fail indicators)
    - Conditional "already processed" banner when `${isAlreadyProcessed}` is true, showing `${processedBy}` and `${processedAt}`
    - Action buttons: "Approve" (Action.Submit), "Reject" (Action.Submit), "Open in Portal" (Action.OpenUrl) — conditionally hidden when already processed
    - _Requirements: 11.1, 11.2, 11.3, 12.3_

  - [x] 8.3 Extend `TeamsCardService` to expand all tokens for full card
    - Update `BuildNewSubmissionCard` implementation to pass all `SubmissionCardData` fields to template expansion
    - Implement `BuildReviewDetailsCard(ValidationBreakdownData data)` — load `review-details-card.json`, expand with data
    - Ensure both methods handle null/missing fields with fallback values
    - Modify `backend/src/BajajDocumentProcessing.Infrastructure/Services/TeamsCardService.cs`
    - _Requirements: 10.2, 10.3, 11.1_

  - [ ]* 8.4 Write property test — Property 4: Quick Approve visibility follows recommendation type
    - **Property 4: For any SubmissionCardData, ShowQuickApprove is true iff Recommendation == "Approve". For Review/Reject, ShowQuickApprove is false**
    - **Validates: Requirements 5.1, 5.2, 5.3**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/TeamsCardServiceProperties.cs`

  - [ ]* 8.5 Write property test — Property 5: Card template resolves all tokens (full card)
    - **Property 5: For any SubmissionCardData (including null optional fields), the card JSON never contains `${` or `{{` substrings**
    - **Validates: Requirements 10.3, 10.4**
    - Extend existing test in `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/TeamsCardServiceProperties.cs`

  - [ ]* 8.6 Write property test — Property 6: Card contains all required key facts (full card)
    - **Property 6: For any SubmissionCardData, the card JSON contains: FAP ID, agency name, PO number (or "N/A"), invoice amount with ₹, state, submitted timestamp, team/photo summary, inquiry summary**
    - **Validates: Requirements 2.1, 2.2**
    - Extend existing test in `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/TeamsCardServiceProperties.cs`

  - [ ]* 8.7 Write property test — Property 14: Card payload size constraint
    - **Property 14: For any generated adaptive card JSON, payload size < 4KB and contains no `data:image` substrings**
    - **Validates: Requirements 13.5**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/TeamsCardServiceProperties.cs`

- [x] 9. Checkpoint — Card templates and data service verified
  - Ensure all tests pass, ask the user if questions arise.


- [x] 10. Extend `TeamsNotificationService` with per-user proactive messaging
  - [x] 10.1 Implement `SendProactiveCardToUserAsync`
    - Add method to existing `TeamsNotificationService` in `backend/src/BajajDocumentProcessing.Infrastructure/Services/Teams/TeamsNotificationService.cs`
    - Load `ConversationReference` from `TeamsConversation.ConversationReferenceJson`
    - Use `BotAdapter.ContinueConversationAsync` with Bot App ID, conversation reference, and callback that sends the card as an Adaptive Card attachment
    - Return `ProactiveMessageResult` with success/failure, HTTP status code, and Teams activity ID
    - Handle 403/404 errors (return result with status code for dispatcher to handle)
    - Handle 503/timeout errors (return result for dispatcher retry logic)
    - Implement 2-second delay between sequential sends to same user (rate limiting per Req 9.3)
    - _Requirements: 9.1, 9.2, 9.3_

  - [ ]* 10.2 Write unit tests for proactive messaging
    - Test successful send returns ProactiveMessageResult with Success=true and ActivityId
    - Test 403 error returns result with HttpStatusCode=403
    - Test 503 error returns result with HttpStatusCode=503
    - Test conversation reference deserialization from JSON
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/ProactiveMessagingServiceTests.cs`
    - _Requirements: 9.1, 9.2_

- [x] 11. Implement `NotificationDispatcher` — channel selection, retry, fallback, logging
  - [x] 11.1 Implement `NotificationDispatcher`
    - Create `backend/src/BajajDocumentProcessing.Infrastructure/Services/NotificationDispatcher.cs`
    - Inject `INotificationDataService`, `ITeamsCardService`, `ITeamsNotificationService`, `IEmailAgent`, `ApplicationDbContext`, `ILogger`
    - `DispatchNewSubmissionNotificationAsync`: Load all ASM-role users with their `TeamsConversation` records
    - For each ASM user (broadcast model until ASM assignment exists):
      - Call `GetSubmissionCardDataAsync` to assemble card data
      - If user has active `TeamsConversation`: build card → send proactively → handle result
      - If no active `TeamsConversation`: send email fallback directly
    - Retry logic for transient Teams errors (503/timeout): 3 retries with 5s, 15s, 45s exponential backoff
    - On 403/404: set `TeamsConversation.IsActive = false`, fall back to email, no retry
    - On all retries exhausted: log Teams attempt as Failed (RetryCount=3), send email fallback
    - Create `Notification` record for every attempt (Teams and/or Email) with correct Channel, DeliveryStatus, RetryCount, SentAt, ExternalMessageId, FailureReason
    - Set `Notification.Type = ReadyForReview`, `RelatedEntityId = packageId`
    - _Requirements: 1.1, 1.3, 7.1, 9.1, 9.4, 14.1, 14.2, 14.3, 15.1, 15.2_

  - [ ]* 11.2 Write property test — Property 1: Only PendingASM state triggers CH notification
    - **Property 1: For any submission state, NotificationDispatcher creates notification records iff state == PendingASM. Other states produce zero records**
    - **Validates: Requirements 1.1, 1.2, 1.4, 1.5, 14.5**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDispatcherProperties.cs`

  - [ ]* 11.3 Write property test — Property 2: Channel selection — Teams when available, Email when not
    - **Property 2: For any CH user with active TeamsConversation, notification Channel=Teams. Without active TeamsConversation, Channel=Email and no Teams delivery attempted**
    - **Validates: Requirements 1.1, 1.3, 7.1**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDispatcherProperties.cs`

  - [ ]* 11.4 Write property test — Property 9: Retry exhaustion triggers email fallback with correct logging
    - **Property 9: For any transient Teams failure (503/timeout), system retries 3× with 5s/15s/45s backoff. After exhaustion, Notifications table has one Teams/Failed/RetryCount=3 record and one Email record**
    - **Validates: Requirements 9.4, 14.2, 14.3, 15.2**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDispatcherProperties.cs`

  - [ ]* 11.5 Write property test — Property 10: Stale conversation reference invalidation and fallback
    - **Property 10: For any 403/404 proactive message error, TeamsConversation.IsActive is set to false, Email fallback is created, and no retry is attempted**
    - **Validates: Requirements 8.4, 14.1**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDispatcherProperties.cs`

  - [ ]* 11.6 Write property test — Property 13: Notification logging completeness
    - **Property 13: For any notification dispatch, a Notification record is created with Type=ReadyForReview, non-null Channel, non-null DeliveryStatus, SentAt populated when Sent, and RelatedEntityId = packageId**
    - **Validates: Requirements 15.1**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDispatcherProperties.cs`

  - [ ]* 11.7 Write property test — Property 20: Existing agency notification preserved
    - **Property 20: For any PendingASM submission, the existing NotifySubmissionReceivedAsync call to the agency user still executes alongside the new ASM notification**
    - **Validates: Requirements 1.6**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDispatcherProperties.cs`

  - [ ]* 11.8 Write unit tests for NotificationDispatcher
    - Test happy path: ASM with active Teams conversation receives Teams notification
    - Test fallback: ASM without Teams conversation receives email
    - Test retry: 503 error triggers 3 retries then email fallback
    - Test stale ref: 403 error deactivates conversation and sends email
    - Test logging: verify Notification records created with correct fields
    - Test broadcast: multiple ASM users each receive their own notification
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/NotificationDispatcherTests.cs`
    - _Requirements: 1.1, 1.3, 7.1, 9.4, 14.1–14.3, 15.1, 15.2_

- [x] 12. Checkpoint — Notification dispatch pipeline verified
  - Ensure all tests pass, ask the user if questions arise.


- [x] 13. Implement email fallback notification
  - [x] 13.1 Create email fallback HTML template
    - Create `backend/src/BajajDocumentProcessing.API/templates/email/new-submission.html`
    - ClaimsIQ logo header
    - Key facts in HTML table format (same data as adaptive card: FAP ID, Agency, PO, Invoice, Amount, State, Submitted, Teams/Photos, Inquiries)
    - AI recommendation section with color-coded inline styling (green/amber/red based on recommendation type)
    - CTA button "Review in ClaimsIQ Portal" linking to portal URL
    - Footer: "You're receiving this because you're an assigned reviewer. Install the ClaimsIQ Teams bot for richer notifications."
    - No inline approval buttons (portal link only per Req 7.4)
    - _Requirements: 7.2, 7.3, 7.4, 7.6, 7.7_

  - [x] 13.2 Implement email send method in NotificationDispatcher
    - Add `SendNewSubmissionEmailAsync(Guid packageId, string asmEmail, SubmissionCardData cardData, CancellationToken ct)` private method
    - Use existing `IEmailAgent` infrastructure for delivery with retry
    - Subject line: `ClaimsIQ: New claim from {agencyName} — ₹{invoiceAmount}`
    - Load HTML template, replace tokens with card data values
    - _Requirements: 7.1, 7.2, 7.3_

  - [ ]* 13.3 Write property test — Property 18: Email subject line format
    - **Property 18: For any email fallback notification, subject matches `ClaimsIQ: New claim from {agencyName} — ₹{invoiceAmount}` with populated values from submission data**
    - **Validates: Requirements 7.2**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDispatcherProperties.cs`

  - [ ]* 13.4 Write unit tests for email fallback
    - Test email subject line contains agency name and formatted amount
    - Test email body contains all key facts from SubmissionCardData
    - Test email footer contains bot installation prompt text
    - Test email does NOT contain action buttons (only portal link)
    - Test email sent when ASM has no TeamsConversation
    - Test email sent after Teams retry exhaustion
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/EmailFallbackTests.cs`
    - _Requirements: 7.1–7.7_

- [x] 14. Extend `TeamsBotService` — Quick Approve conversational flow
  - [x] 14.1 Implement Quick Approve 4-step dialog in `OnAdaptiveCardInvokeAsync`
    - Extend existing `TeamsBotService` at `backend/src/BajajDocumentProcessing.Infrastructure/Services/Teams/TeamsBotService.cs`
    - Route `action = "quick_approve"`: Check `DocumentPackage.State == PendingASM` first (idempotency). If valid, post confirmation card: "You're about to approve FAP-{shortId} ({agencyName}, ₹{amount}). Do you want to continue? [Approve Invoice] [Cancel]"
    - Route `action = "confirm_approve"`: Ask for optional comments: "Any comments? (optional — type or tap Skip) [Skip]"
    - Route `action = "submit_approval"`: Call existing ASM approve logic (direct service call, not HTTP) with optional comments. Set `Channel = "TeamsBot"` on `RequestApprovalHistory`. On success: "✅ Approved! FAP-{shortId} forwarded to RA. {agencyName} will be notified. Payable amount: ₹{amount}"
    - Route `action = "cancel_approve"`: Post "Approval cancelled. No changes made."
    - Handle state ≠ PendingASM: "FAP-{shortId} has already been processed. No further action needed."
    - Handle 400 from approval logic (concurrent approval): graceful "already actioned" message
    - Handle service errors: "Something went wrong. Please try again or use the portal." with ERROR logging
    - Resolve Teams user identity to system User via `TeamsConversation.TeamsUserId` → User lookup
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 12.1, 12.2_

  - [ ]* 14.2 Write property test — Property 8: Idempotent approval — duplicate clicks don't create duplicate records
    - **Property 8: For any submission not in PendingASM (or RARejected), Quick Approve returns "already processed" and creates zero new RequestApprovalHistory records**
    - **Validates: Requirements 12.1, 12.2**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalFlowProperties.cs`

  - [ ]* 14.3 Write property test — Property 12: Approval via Teams records correct channel in audit trail
    - **Property 12: For any approval processed through Teams bot, the RequestApprovalHistory record has Channel = "TeamsBot"**
    - **Validates: Requirements 6.6, 15.3**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalFlowProperties.cs`

  - [ ]* 14.4 Write property test — Property 16: Quick Approve confirmation contains correct submission details
    - **Property 16: For any PendingASM submission, the confirmation message contains the FAP ID, agency name, and invoice amount matching the submission data**
    - **Validates: Requirements 6.1, 6.3**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalFlowProperties.cs`

  - [ ]* 14.5 Write property test — Property 17: Cancel preserves submission state
    - **Property 17: For any PendingASM submission where CH initiates Quick Approve then cancels, state remains PendingASM and no RequestApprovalHistory record is created**
    - **Validates: Requirements 6.4**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalFlowProperties.cs`

  - [ ]* 14.6 Write unit tests for Quick Approve flow
    - Test full 4-step flow: card → confirm → comments → approved
    - Test cancel flow: card → confirm → cancel → no state change
    - Test skip comments: card → confirm → skip → approved with null comments
    - Test idempotency: Quick Approve on already-approved submission returns "already processed"
    - Test concurrent approval: second click handled gracefully
    - Test user identity resolution from TeamsConversation
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Teams/QuickApproveFlowTests.cs`
    - _Requirements: 6.1–6.6, 12.1, 12.2_

- [x] 15. Extend `TeamsBotService` — Review Details flow
  - [x] 15.1 Implement Review Details action handler
    - Route `action = "review_details"` in `OnAdaptiveCardInvokeAsync`
    - Call `INotificationDataService.GetValidationBreakdownAsync(submissionId)`
    - Build review details card via `ITeamsCardService.BuildReviewDetailsCard(breakdownData)`
    - Post card as follow-up message in conversation
    - If submission already processed, show read-only breakdown with current status banner
    - Route `action = "approve_from_review"`: Start approval flow (same as Quick Approve confirm step)
    - Route `action = "reject_from_review"`: Start rejection flow (ask for reason, call existing reject endpoint)
    - _Requirements: 11.1, 11.2, 11.3, 12.3_

  - [ ]* 15.2 Write unit tests for Review Details flow
    - Test review details card posted with correct validation breakdown
    - Test already-processed submission shows status banner with approver and date
    - Test approve from review triggers approval flow
    - Test reject from review asks for reason then calls reject endpoint
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Teams/TeamsBotServiceTests.cs`
    - _Requirements: 11.1–11.3, 12.3_

- [x] 16. Extend `TeamsBotService` — Pending submissions query
  - [x] 16.1 Implement pending submissions message handler
    - Extend `OnMessageActivityAsync` in `TeamsBotService`
    - Detect messages like "show my pending", "what's pending?", "pending submissions" (simple keyword matching)
    - Query `DocumentPackages` where `State == PendingASM`, project to summary (FAP ID, agency name, PO number, invoice amount, confidence score)
    - Return summary card listing pending submissions with key facts
    - Each submission in the list has a "View" button that posts the full notification card for that submission
    - If no pending submissions: "No pending submissions at this time."
    - _Requirements: 16.1, 16.2, 16.3_

  - [ ]* 16.2 Write unit tests for pending submissions query
    - Test message "show my pending" returns list of PendingASM submissions
    - Test empty list returns "No pending submissions" message
    - Test "View" button on list item posts full notification card
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Teams/TeamsBotServiceTests.cs`
    - _Requirements: 16.1–16.3_

- [x] 17. Checkpoint — Bot conversational flows verified
  - Ensure all tests pass, ask the user if questions arise.


- [x] 18. Wire `WorkflowOrchestrator` integration and DI registration
  - [x] 18.1 Register new services in DI container
    - Modify `backend/src/BajajDocumentProcessing.Infrastructure/DependencyInjection.cs`
    - Register `INotificationDispatcher` → `NotificationDispatcher` as Scoped
    - Register `INotificationDataService` → `NotificationDataService` as Scoped
    - Verify existing `ITeamsCardService` → `TeamsCardService` registration (already exists, no change needed)
    - Verify existing `ITeamsNotificationService` → `TeamsNotificationService` registration (already exists, no change needed)
    - _Requirements: 1.1_

  - [x] 18.2 Integrate `NotificationDispatcher` into `WorkflowOrchestrator`
    - Modify `backend/src/BajajDocumentProcessing.Infrastructure/Services/WorkflowOrchestrator.cs`
    - Inject `INotificationDispatcher` via constructor
    - After the existing `PendingASM` state transition and existing `NotifySubmissionReceivedAsync` call (which remains unchanged for agency users):
      - Add call to `_notificationDispatcher.DispatchNewSubmissionNotificationAsync(package.Id, cancellationToken)`
    - Ensure the existing agency notification (`NotifySubmissionReceivedAsync`) is NOT replaced or modified
    - Wrap dispatcher call in try/catch so notification failure does not roll back the state transition
    - Log at WARNING level if notification dispatch fails (submission processing should succeed regardless)
    - _Requirements: 1.1, 1.6, 14.5_

  - [ ]* 18.3 Write property test — Property 11: Conversation reference capture on first interaction
    - **Property 11: For any message or install event from a Teams user, the bot creates/updates a TeamsConversation record with non-empty ConversationReferenceJson, ConversationId, ServiceUrl, ChannelId, and TeamsUserId**
    - **Validates: Requirements 8.1**
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/NotificationDispatcherProperties.cs`

  - [ ]* 18.4 Write integration-level unit tests for orchestrator integration
    - Test WorkflowOrchestrator calls both NotifySubmissionReceivedAsync (agency) AND DispatchNewSubmissionNotificationAsync (ASM) after PendingASM transition
    - Test notification dispatch failure does not prevent state transition from completing
    - Test agency notification still fires even if ASM notification fails
    - Add to `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/WorkflowOrchestratorNotificationTests.cs`
    - _Requirements: 1.1, 1.6_

- [x] 19. Final checkpoint — Full end-to-end verification
  - Ensure all tests pass, ask the user if questions arise.
  - Verify all 20 correctness properties are covered by property tests
  - Verify all 16 requirements are covered by implementation tasks
  - Verify no orphaned code — all new components are wired into the existing codebase

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Tasks 1–2 were completed in a previous iteration (header template, DTO, interface, service)
- Each task references specific requirements for traceability
- Checkpoints at tasks 5, 9, 12, 17, and 19 ensure incremental validation
- Property tests validate the 20 correctness properties from the design document
- Unit tests validate specific examples, edge cases, and error conditions
- The broadcast model (all ASM users) is used until the ASM assignment prerequisite is implemented
- Manual testing is still required for cross-platform card rendering (Req 13), bot installation flow (Req 8.2–8.3), and proactive messaging timing (Req 1.1)
