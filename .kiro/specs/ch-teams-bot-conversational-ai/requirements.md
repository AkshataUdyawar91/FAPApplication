# Requirements: ClaimsIQ Teams Bot — Conversational AI for Approvers

## Feature: Natural Language Queries for Circle Heads, ASMs, and RAs via Microsoft Teams

### Requirement 1: Text Message Handler (Teams)
**User Story**: As a Circle Head, I want to type a question in Microsoft Teams and get an answer about my pending approvals, so that I don't have to open the portal.

**Acceptance Criteria**:
- 1.1 Given the Teams bot receives a text message (not a card button click), When OnMessageActivityAsync is invoked, Then it routes to the TeamsConversationRouter without affecting existing Adaptive Card invoke handlers (Quick Approve, Reject, Review Details).
- 1.2 Given the TeamsConversationalAI feature flag is set to false, When a text message arrives, Then the bot responds with "I can send you approval notifications. For other queries, please use the ClaimsIQ portal." and does not invoke any AI processing.
- 1.3 Given the TeamsConversationalAI feature flag is set to true, When a text message arrives, Then it is processed through the intent classification → scoped data query → response pipeline.
- 1.4 Given a text message is empty or null, When OnMessageActivityAsync is invoked, Then it returns silently without sending any response.
- 1.5 The existing OnAdaptiveCardInvokeAsync method is NOT modified in any way. All card button handlers (approve, reject, review details) continue working exactly as before.

### Requirement 2: Approver Identity Resolution
**User Story**: As the system, I need to resolve the Teams user to a Circle Head / ASM / RA identity, so that every query shows only submissions assigned to them.

**Acceptance Criteria**:
- 2.1 Given a message from a Teams user, When the TeamsConversationRouter receives it, Then it resolves the AAD Object ID (from Activity.From.AadObjectId) to a ClaimsIQ User record.
- 2.2 Given the user is resolved as an ASM/Circle Head, When querying data, Then all queries include WHERE AssignedASMUserId = {userId} OR scope by the ASM's assigned state(s).
- 2.3 Given the user is resolved as an RA, When querying data, Then all queries scope by the RA's assigned states via RAStateMapping.
- 2.4 Given the Teams user cannot be resolved, When processing, Then the bot responds "I couldn't verify your identity. Please contact your administrator." and does not execute any data query.
- 2.5 Given a resolved user, When logging, Then UserId, Role, Channel="TeamsBot", and the resolved scope (state/states) are recorded in ConversationAuditLog.

### Requirement 3: Intent Classification (Keyword Phase)
**User Story**: As the system, I need to classify the Circle Head's message into an intent, so that the correct data handler is invoked.

**Acceptance Criteria**:
- 3.1 Given the user types a message containing "open", "pending", "waiting", "approval", "new requests", "anything for me", or "any open", When classified, Then intent is PENDING_APPROVALS.
- 3.2 Given the user types a message containing "approved", "done", "completed", "how many approved", When classified, Then intent is APPROVED_LIST.
- 3.3 Given the user types a message containing "reject", "return", "sent back", When classified, Then intent is REJECTED_LIST.
- 3.4 Given the user types a message containing "details", "show me", "tell me about", followed by a FAP ID, When classified, Then intent is SUBMISSION_DETAIL with the FAP ID extracted as an entity.
- 3.5 Given the user types a message containing "summary", "today", "this week", "how many", "count", When classified, Then intent is ACTIVITY_SUMMARY.
- 3.6 Given the user types a message containing "help", "what can you do", When classified, Then intent is HELP.
- 3.7 Given the user types "hi", "hello", When classified, Then intent is GREETING.
- 3.8 Given no pattern matches, Then intent is FALLBACK.

### Requirement 4: Intent Classification (LLM Phase)
**User Story**: As the system, I need GPT-4o-mini to understand natural language approval queries, so that Circle Heads can ask in their own words.

**Acceptance Criteria**:
- 4.1 Given a natural language message, When sent to GPT-4o-mini, Then it returns a JSON object with intent, confidence, and extracted entities (fapId, timeRange, statusFilter).
- 4.2 Given confidence below 0.7, Then the bot asks for clarification.
- 4.3 Given timeout (>5s) or failure, Then the system falls back to keyword matching.
- 4.4 Temperature is set to 0.1.
- 4.5 The LLM system prompt includes all approver-specific intents: PENDING_APPROVALS, APPROVED_LIST, REJECTED_LIST, SUBMISSION_DETAIL, ACTIVITY_SUMMARY.

### Requirement 5: Pending Approvals Handler
**User Story**: As a Circle Head, I want to ask "are there any open requests for my approval?" and see a list of pending submissions, so that I know what needs my attention.

**Acceptance Criteria**:
- 5.1 Given a Circle Head asks about pending approvals, When the handler executes, Then it queries DocumentPackages WHERE Status = "PendingASM" AND (AssignedASMUserId = {userId} OR Teams.State IN ASM's assigned states).
- 5.2 Given pending submissions exist, When formatting the response, Then the bot sends an Adaptive Card with a summary header ("You have 3 requests pending your approval") and a list showing: FAP ID, Agency Name, Invoice Amount (₹ Indian notation), Submitted Date, Days Pending.
- 5.3 Each item in the card includes two action buttons: "Quick Approve" and "Review Details" — these trigger the EXISTING card action handlers (same OnAdaptiveCardInvokeAsync flow).
- 5.4 Given no pending submissions exist, When responding, Then the bot says "You're all caught up — no pending approvals right now."
- 5.5 The list is ordered by SubmittedAt ascending (oldest first — longest waiting gets attention first).
- 5.6 If more than 5 pending, show first 5 with "View all N pending in portal" link.

### Requirement 6: Submission Detail Handler
**User Story**: As a Circle Head, I want to ask "tell me about FAP-28C9823C" and see the full details including AI recommendation and validation results.

**Acceptance Criteria**:
- 6.1 Given the user asks about a specific submission, When the handler executes, Then it returns an Adaptive Card matching the EXISTING notification card format: Header, Key Facts (9 fields), AI Recommendation, and Action Buttons.
- 6.2 The card is the SAME card format currently sent by NotificationDispatcher — reuse the existing Adaptive Card template.
- 6.3 Given the FAP ID is not found within the approver's scope, When responding, Then the bot says "I couldn't find that submission in your approval queue."
- 6.4 The "Review Details" button on the card triggers the EXISTING review details flow.

### Requirement 7: Approved List Handler
**User Story**: As a Circle Head, I want to ask "what did I approve this week?" and see a summary of my recent approvals.

**Acceptance Criteria**:
- 7.1 Given the user asks about approved submissions, When the handler executes, Then it queries RequestApprovalHistory WHERE ReviewerUserId = {userId} AND Action = "Approve" with optional date filter.
- 7.2 If no time range specified, default to last 7 days.
- 7.3 Response shows: count, total amount, and a list with FAP ID + Amount for each.
- 7.4 Response is plain text (not a card) since these are informational, not actionable.

### Requirement 8: Rejected List Handler
**User Story**: As a Circle Head, I want to ask "which claims did I reject?" and see my recent rejections with reasons.

**Acceptance Criteria**:
- 8.1 Given the user asks about rejections, When the handler executes, Then it queries RequestApprovalHistory WHERE ReviewerUserId = {userId} AND Action = "Reject" with optional date filter.
- 8.2 If no time range specified, default to last 7 days.
- 8.3 Response shows: FAP ID, Amount, Rejection Reason (truncated to 100 chars), Date.

### Requirement 9: Activity Summary Handler
**User Story**: As a Circle Head, I want to ask "give me a summary of today" or "how many requests this week?" and get aggregate numbers.

**Acceptance Criteria**:
- 9.1 Given the user asks for a summary, When the handler executes, Then it returns: total pending count, new submissions today/this week, approved count + amount, rejected count, average processing time.
- 9.2 All numbers are scoped to the approver's assigned state(s).
- 9.3 Amounts use ₹ Indian comma notation.
- 9.4 Response is a concise text summary, not a card.

### Requirement 10: Help Handler
**User Story**: As a Circle Head, I want to type "help" and see what the bot can do.

**Acceptance Criteria**:
- 10.1 The help response lists: pending approvals, submission details, approved/rejected lists, activity summary.
- 10.2 Includes example questions: "Any open requests?", "Tell me about FAP-28C9823C", "What did I approve this week?", "Summary of today".

### Requirement 11: Conversation Audit Logging
**User Story**: As an administrator, I need every Teams bot conversation logged.

**Acceptance Criteria**:
- 11.1 Every message and response is logged to ConversationAuditLog with Channel="TeamsBot".
- 11.2 Write-only table. Logging failures never block the response.

### Requirement 12: Input Sanitisation
**User Story**: As the system, I need to detect and block prompt injection attempts in Teams messages.

**Acceptance Criteria**:
- 12.1 Same injection patterns as Agency bot — "ignore instructions", "show all agencies", etc.
- 12.2 Runs BEFORE intent classification.

### Requirement 13: Feature Flag
**User Story**: As DevOps, I need to enable/disable Teams conversational AI independently from the agency bot.

**Acceptance Criteria**:
- 13.1 Configuration key "Features:TeamsConversationalAI" (boolean, default false) controls Teams text message processing.
- 13.2 Separate from "Features:AgencyConversationalAI" — each can be toggled independently.
- 13.3 When disabled, existing Adaptive Card actions (approve/reject from notification cards) continue working.

### Requirement 14: Coexistence with Proactive Notifications
**User Story**: As the system, conversational AI must not interfere with proactive notification cards being sent to Circle Heads.

**Acceptance Criteria**:
- 14.1 The NotificationDispatcher continues sending proactive Adaptive Cards exactly as before — no changes.
- 14.2 When a Circle Head receives a notification card AND types a text message, both flows work independently.
- 14.3 Card button clicks (Quick Approve, Reject, Review Details) always go through OnAdaptiveCardInvokeAsync, never through the conversational router.
