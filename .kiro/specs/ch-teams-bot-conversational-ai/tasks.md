# Implementation Plan: ClaimsIQ Teams Bot — Conversational AI for Approvers

## Overview

Add a second parallel code path in the Teams bot for text messages from Circle Heads, ASMs, and RAs. The existing Adaptive Card invoke handlers remain untouched. Implementation follows the design's bottom-up order: Models → ApproverResolver → ApproverKeywordClassifier → ApproverScopedQueryService → TeamsConversationRouter → Bot integration → DI + feature flags → Testing → LLM classifier (Phase 2).

## Tasks

- [x] 1. Create Teams ConvAI models and ITeamsIntentClassifier interface
  - [x] 1.1 Create `ApproverResolvedUser` model in `Infrastructure/Services/ConversationalAI/Teams/Models/ApproverResolvedUser.cs`
    - Properties: UserId (Guid), Role (string: "ASM" or "RA"), DisplayName (string), AssignedStates (string[])
    - _Requirements: 2.1, 2.2, 2.3_
  - [x] 1.2 Create `PendingApprovalSummary` model in `Infrastructure/Services/ConversationalAI/Teams/Models/PendingApprovalSummary.cs`
    - Properties: FapId (string), SubmissionId (Guid), AgencyName (string), Amount (decimal), SubmittedAt (DateTime), DaysPending (int), State (string)
    - _Requirements: 5.1, 5.2_
  - [x] 1.3 Create `ApproverActivitySummary` model in `Infrastructure/Services/ConversationalAI/Teams/Models/ApproverActivitySummary.cs`
    - Properties: PendingCount, NewToday, ApprovedThisWeek, ApprovedAmountThisWeek, RejectedThisWeek, AvgProcessingDays
    - _Requirements: 9.1_
  - [x] 1.4 Create `ITeamsIntentClassifier` interface in `Application/Common/Interfaces/ITeamsIntentClassifier.cs`
    - Method: `Task<IntentResult> ClassifyAsync(string userText, CancellationToken ct = default)`
    - Reuse existing `IntentResult` model if it exists, or create a Teams-specific one with Intent (string), Confidence (double), Entities (fapId, timeRange)
    - _Requirements: 3.1–3.8, 4.1_

- [x] 2. Implement ApproverResolver
  - [x] 2.1 Create `ApproverResolver.cs` in `Infrastructure/Services/ConversationalAI/Teams/ApproverResolver.cs`
    - Inject `ApplicationDbContext`
    - `ResolveAsync(string aadObjectId)` → query Users by AadObjectId, fallback to TeamsConversation by TeamsUserId → load User
    - Determine role: check UserRole enum on User entity (ASM=2, RA=3)
    - Load assigned states: ASM → query StateMapping WHERE CircleHeadUserId = userId; RA → query StateMapping WHERE RAUserId = userId
    - Return `ApproverResolvedUser` or null if not found
    - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - [ ]* 2.2 Write unit tests for ApproverResolver in `Tests/Infrastructure/Teams/ApproverResolverTests.cs`
    - Test: resolved ASM returns correct role and states
    - Test: resolved RA returns correct role and states from StateMapping
    - Test: unresolved AAD ID returns null
    - Test: fallback to TeamsConversation lookup when AadObjectId not on User
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 3. Checkpoint — Ensure models and resolver compile and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement ApproverKeywordClassifier
  - [x] 4.1 Create `ApproverKeywordClassifier.cs` in `Infrastructure/Services/ConversationalAI/Teams/ApproverKeywordClassifier.cs`
    - Implement `ITeamsIntentClassifier`
    - Keyword sets per intent: PENDING_APPROVALS ("open", "pending", "waiting", "approval", "new requests", "anything for me", "any open"), APPROVED_LIST ("approved", "done", "completed", "how many approved"), REJECTED_LIST ("reject", "return", "sent back"), SUBMISSION_DETAIL ("details", "show me", "tell me about" + FAP ID regex `FAP-[A-Za-z0-9]{6,8}`), ACTIVITY_SUMMARY ("summary", "today", "this week", "how many", "count"), HELP ("help", "what can you do"), GREETING ("hi", "hello", "good morning")
    - Extract entities: fapId via regex, timeRange from keywords ("today", "this week", "this month", "last week")
    - Return FALLBACK when no pattern matches
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_
  - [ ]* 4.2 Write unit tests for ApproverKeywordClassifier in `Tests/Infrastructure/Teams/ApproverKeywordClassifierTests.cs`
    - Test each intent keyword set maps to correct intent
    - Test FAP ID extraction from "tell me about FAP-28C9823C"
    - Test timeRange extraction
    - Test FALLBACK for unrecognized input
    - Test case-insensitivity
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_
  - [ ]* 4.3 Write property test for keyword classifier in `Tests/Infrastructure/Properties/ApproverKeywordClassifierProperties.cs`
    - **Property 1: Every non-empty input produces a valid intent** — For any non-empty string input, ClassifyAsync always returns an IntentResult with a non-null Intent string from the known set {PENDING_APPROVALS, APPROVED_LIST, REJECTED_LIST, SUBMISSION_DETAIL, ACTIVITY_SUMMARY, HELP, GREETING, FALLBACK}
    - **Validates: Requirements 3.1–3.8**

- [x] 5. Implement ApproverScopedQueryService
  - [x] 5.1 Create `ApproverScopedQueryService.cs` in `Infrastructure/Services/ConversationalAI/Teams/ApproverScopedQueryService.cs`
    - Inject `ApplicationDbContext`
    - `GetPendingApprovalsAsync(Guid userId, string role, string[] states)` — query DocumentPackages WHERE Status = PendingASM (for ASM) or PendingRA (for RA), scoped by AssignedASMUserId or state, ordered by CreatedAt ascending, take 10, project to PendingApprovalSummary
    - `GetSubmissionDetailAsync(Guid userId, string role, string[] states, string fapIdSearch)` — query DocumentPackage by partial FAP ID match within approver's scope, include ValidationResults and Recommendation
    - `GetApprovedByMeAsync(Guid userId, DateTime from, DateTime to)` — query RequestApprovalHistory WHERE ApproverId = userId AND Action = Approved, within date range
    - `GetRejectedByMeAsync(Guid userId, DateTime from, DateTime to)` — query RequestApprovalHistory WHERE ApproverId = userId AND Action = Rejected, within date range
    - `GetActivitySummaryAsync(Guid userId, string role, string[] states)` — aggregate: PendingCount, NewToday, ApprovedThisWeek, RejectedThisWeek, AvgProcessingDays
    - Use `AsNoTracking()` on all queries
    - _Requirements: 5.1, 5.5, 6.1, 6.3, 7.1, 7.2, 7.3, 8.1, 8.2, 8.3, 9.1, 9.2, 9.3_
  - [ ]* 5.2 Write unit tests for ApproverScopedQueryService in `Tests/Infrastructure/Teams/ApproverScopedQueryServiceTests.cs`
    - Test: ASM pending query scopes by AssignedASMUserId and state
    - Test: RA pending query scopes by RA's states
    - Test: submission detail returns null for FAP ID outside approver's scope
    - Test: approved/rejected default to last 7 days when no date range
    - Test: activity summary aggregates correctly
    - _Requirements: 5.1, 6.3, 7.2, 8.2, 9.1_

- [x] 6. Checkpoint — Ensure classifier and query service compile and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement TeamsConversationRouter and ConversationAuditLog entity
  - [x] 7.1 Create `ConversationAuditLog` entity in `Domain/Entities/ConversationAuditLog.cs` if it does not already exist
    - Properties: Id, UserId, UserRole, Channel (string), UserMessage, BotResponse, Intent, Timestamp
    - Write-only table — no update/delete operations
    - Add DbSet to ApplicationDbContext and create EF migration
    - _Requirements: 11.1, 11.2, 2.5_
  - [x] 7.2 Create `TeamsConversationRouter.cs` in `Infrastructure/Services/ConversationalAI/Teams/TeamsConversationRouter.cs`
    - Inject: ApproverResolver, ITeamsIntentClassifier, ApproverScopedQueryService, IInputGuardrailService, IConfiguration, ILogger
    - `HandleAsync(string userText, string aadObjectId, ITurnContext turnContext, CancellationToken ct)`
    - Step 1: Check feature flag "Features:TeamsConversationalAI" — if false, send static fallback text per Req 1.2
    - Step 2: Call InputGuardrailService.ValidateInputAsync — if injection detected, send block message and log
    - Step 3: Call ApproverResolver.ResolveAsync — if null, send identity error per Req 2.4
    - Step 4: Call ITeamsIntentClassifier.ClassifyAsync
    - Step 5: Switch on intent → call appropriate handler method
    - Step 6: For PENDING_APPROVALS → build Adaptive Card with pending list, action buttons matching existing card data structure (action: "approve", fapId), send via turnContext.SendActivityAsync
    - Step 7: For SUBMISSION_DETAIL → reuse ApprovalCardBuilder.BuildApprovalCard or existing card template, send as attachment
    - Step 8: For APPROVED_LIST, REJECTED_LIST, ACTIVITY_SUMMARY → format plain text with ₹ Indian notation, send via turnContext
    - Step 9: For HELP → send help text per Req 10.1, 10.2
    - Step 10: For GREETING → send welcome + pending count
    - Step 11: For FALLBACK → send "I didn't understand" with help suggestions
    - Step 12: Log to ConversationAuditLog (fire-and-forget, failures never block response) per Req 11.1, 11.2
    - Pending list: show first 5, if more than 5 add "View all N pending in portal" link per Req 5.6
    - Pending list ordered by SubmittedAt ascending per Req 5.5
    - "You're all caught up" message when no pending per Req 5.4
    - _Requirements: 1.1, 1.2, 1.3, 2.4, 2.5, 3.1–3.8, 5.1–5.6, 6.1–6.4, 7.1–7.4, 8.1–8.3, 9.1–9.4, 10.1, 10.2, 11.1, 11.2, 12.1, 12.2, 13.1, 14.2_
  - [ ]* 7.3 Write unit tests for TeamsConversationRouter in `Tests/Infrastructure/Teams/TeamsConversationRouterTests.cs`
    - Test: feature flag off → static fallback text, no AI processing
    - Test: injection detected → block message sent
    - Test: unresolved user → identity error message
    - Test: PENDING_APPROVALS intent → Adaptive Card sent with correct structure
    - Test: empty/null text → returns silently (no response sent)
    - Test: audit log written on every message (mock verify)
    - Test: audit log failure does not block response
    - _Requirements: 1.1, 1.2, 1.4, 2.4, 5.2, 11.1, 11.2, 12.1_

- [x] 8. Wire OnMessageActivityAsync in TeamsBotService and register DI
  - [x] 8.1 Modify `OnMessageActivityAsync` in `Infrastructure/Services/Teams/TeamsBotService.cs`
    - Add `TeamsConversationRouter` as a constructor dependency (injected via DI)
    - After existing `Activity.Value != null` card-submit check, add: if text is empty/null → return silently (Req 1.4)
    - Delegate to `_teamsRouter.HandleAsync(text, aadObjectId, turnContext, ct)` for all text messages
    - Remove existing inline `IsPendingSubmissionsQuery`, `IsGreeting`, and fallback help logic (replaced by router)
    - CRITICAL: Do NOT modify `OnAdaptiveCardInvokeAsync` or any card action handlers
    - _Requirements: 1.1, 1.4, 1.5, 14.1, 14.3_
  - [x] 8.2 Add DI registrations in `Infrastructure/DependencyInjection.cs`
    - Register `ApproverResolver` as Scoped
    - Register `ApproverScopedQueryService` as Scoped
    - Register `ITeamsIntentClassifier` → `ApproverKeywordClassifier` as Scoped (Phase 1)
    - Register `TeamsConversationRouter` as Scoped
    - Note: TeamsBotService is Singleton, but TeamsConversationRouter is Scoped — use `IServiceScopeFactory` in TeamsBotService to create a scope per message and resolve the router within it
    - _Requirements: 13.1, 13.2_
  - [x] 8.3 Add feature flag configuration in `appsettings.json`
    - Add `"Features": { "TeamsConversationalAI": false }` (default false)
    - Ensure it is separate from any existing `AgencyConversationalAI` flag
    - _Requirements: 13.1, 13.2, 13.3_

- [ ] 9. Checkpoint — Ensure full pipeline compiles, feature flag works, and all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [-] 10. Implement ApproverLLMClassifier (Phase 2)
  - [x] 10.1 Create `ApproverLLMClassifier.cs` in `Infrastructure/Services/ConversationalAI/Teams/ApproverLLMClassifier.cs`
    - Implement `ITeamsIntentClassifier`
    - Use Semantic Kernel / Azure OpenAI GPT-4o-mini with temperature 0.1
    - System prompt from design: classify into PENDING_APPROVALS, SUBMISSION_DETAIL, APPROVED_LIST, REJECTED_LIST, ACTIVITY_SUMMARY, HELP, GREETING, OUT_OF_SCOPE
    - Parse JSON response: { intent, confidence, entities: { fapId, timeRange } }
    - If confidence < 0.7 → return FALLBACK with clarification message
    - If timeout (>5s) or failure → fall back to ApproverKeywordClassifier
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  - [ ]* 10.2 Write unit tests for ApproverLLMClassifier in `Tests/Infrastructure/Teams/ApproverLLMClassifierTests.cs`
    - Test: valid JSON response parsed correctly
    - Test: confidence below 0.7 returns FALLBACK
    - Test: timeout falls back to keyword classifier
    - Test: malformed JSON falls back to keyword classifier
    - _Requirements: 4.1, 4.2, 4.3_

- [ ] 11. Final checkpoint — Ensure all tests pass and feature flag toggles correctly
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- The existing `OnAdaptiveCardInvokeAsync` and all card action handlers are NEVER modified
- `TeamsBotService` is registered as Singleton; `TeamsConversationRouter` and its dependencies are Scoped — use `IServiceScopeFactory` to bridge the lifetime mismatch
- Phase 2 LLM classifier (task 10) can be enabled by swapping the DI registration from `ApproverKeywordClassifier` to `ApproverLLMClassifier`
- Feature flag `Features:TeamsConversationalAI` defaults to false — existing card flows work regardless
