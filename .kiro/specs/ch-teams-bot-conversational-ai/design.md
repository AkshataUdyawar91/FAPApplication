# Design: ClaimsIQ Teams Bot — Conversational AI for Approvers

## Architecture Overview

The Teams bot currently handles ONE code path: Adaptive Card invoke actions (button clicks from notification cards). The conversational AI adds a SECOND parallel code path for text messages. They share the same bot class but dispatch to completely separate handlers.

```
Incoming Teams Bot Activity
    │
    ├─ Activity.Type == "invoke" (card button: Approve, Reject, Review)
    │   └─ OnAdaptiveCardInvokeAsync() ← EXISTING — ZERO CHANGES
    │       ├─ HandleQuickApprove()     ← EXISTING
    │       ├─ HandleReject()           ← EXISTING
    │       └─ HandleReviewDetails()    ← EXISTING
    │
    └─ Activity.Type == "message" (typed text from Circle Head)
        └─ OnMessageActivityAsync() ← NEW METHOD
            │
            ├─ Feature flag check
            │   └─ if "TeamsConversationalAI" == false → static fallback
            │
            ├─ InputSanitiser.Check()
            │   └─ if injection detected → block + log
            │
            ├─ ApproverResolver.Resolve()
            │   └─ AAD Object ID → User + Role + Assigned States
            │   └─ if unresolved → "identity error"
            │
            ├─ TeamsIntentClassifier.Classify()
            │   ├─ Phase 1: ApproverKeywordClassifier
            │   └─ Phase 2: ApproverLLMClassifier (GPT-4o-mini)
            │       └─ Falls back to keyword on timeout/error
            │
            ├─ Intent Router
            │   ├─ PENDING_APPROVALS  → PendingApprovalsHandler
            │   ├─ SUBMISSION_DETAIL  → SubmissionDetailHandler
            │   ├─ APPROVED_LIST      → ApprovedListHandler
            │   ├─ REJECTED_LIST      → RejectedListHandler
            │   ├─ ACTIVITY_SUMMARY   → ActivitySummaryHandler
            │   ├─ HELP               → HelpHandler
            │   ├─ GREETING           → GreetingHandler
            │   └─ FALLBACK           → FallbackHandler
            │
            ├─ Handler calls ApproverScopedQueryService
            │   └─ ASM: WHERE AssignedASMUserId = {userId}
            │       OR WHERE State IN (ASM's assigned states)
            │   └─ RA: WHERE State IN (RA's states via RAStateMapping)
            │
            ├─ Response formatted
            │   ├─ Actionable items → Adaptive Cards (reuse existing templates)
            │   └─ Informational items → Plain text
            │
            └─ ConversationAuditLogger.Log() (fire-and-forget)
```

**CRITICAL**: The existing `OnAdaptiveCardInvokeAsync` method and all card action handlers remain UNTOUCHED. The conversational layer is purely additive.

## Shared vs New Components

```
SHARED (reuse from Agency ConvAI):
  ├─ InputSanitiser.cs           ← Same injection patterns
  ├─ ConversationAuditLogger.cs  ← Same audit table, Channel="TeamsBot"
  ├─ ConversationAuditLog entity ← Same DB table
  └─ Models (IntentResult, SanitisationResult, ConversationAuditEntry)

NEW (Teams-specific):
  ├─ TeamsConversationRouter.cs     ← Orchestrator for approver queries
  ├─ ApproverResolver.cs            ← AAD ID → User + Role + States
  ├─ ApproverKeywordClassifier.cs   ← Keyword matching for approver intents
  ├─ ApproverLLMClassifier.cs       ← GPT-4o-mini for approver intents
  ├─ ApproverScopedQueryService.cs  ← All queries scoped by approver
  └─ Models/
      ├─ ApproverResolvedUser.cs
      ├─ PendingApprovalSummary.cs
      └─ ApproverActivitySummary.cs
```

## New Files to Create

### 1. Services/ConversationalAI/Teams/TeamsConversationRouter.cs
**Purpose**: Main orchestrator for Teams text messages from Circle Heads and RAs.
**Dependencies**: ApproverResolver, ITeamsIntentClassifier, ApproverScopedQueryService, InputSanitiser, ConversationAuditLogger, IConfiguration
**Requirement refs**: Req 1, 3, 4, 13, 14

```
class TeamsConversationRouter
    method HandleAsync(userText: string, aadObjectId: string, turnContext, ct) -> void
        1. Check feature flag "TeamsConversationalAI" — send fallback text if disabled
        2. Sanitise input — block if injection detected
        3. Resolve approver identity (AAD ID → User + Role + States)
        4. Classify intent
        5. Switch on intent → call handler
        6. For PENDING_APPROVALS and SUBMISSION_DETAIL → send Adaptive Card via turnContext
        7. For informational intents → send text via turnContext
        8. Log audit entry (fire-and-forget)
```

**Key difference from Agency router**: This router sends Adaptive Cards (not just text) for actionable items like pending approvals. It uses `turnContext.SendActivityAsync()` directly instead of returning a string, because cards need to be sent as `Activity` objects with `Attachments`.

### 2. Services/ConversationalAI/Teams/ApproverResolver.cs
**Purpose**: Resolves AAD Object ID to ClaimsIQ User with role and assigned states.
**Dependencies**: AppDbContext
**Requirement refs**: Req 2

```
class ApproverResolver
    method ResolveAsync(aadObjectId: string) -> ApproverResolvedUser?
        1. Query Users WHERE AadObjectId = aadObjectId
           OR query TeamsConversation WHERE TeamsUserId = aadObjectId → load User
        2. Determine role: check if user exists in ASMs table → role = "ASM"
           OR check if user exists in RAStateMapping → role = "RA"
        3. Load assigned states:
           ASM: ASMs.Location (single state)
           RA: RAStateMapping WHERE UserId = userId (multiple states)
        4. Return ApproverResolvedUser { UserId, Role, DisplayName, AssignedStates[] }
```

### 3. Services/ConversationalAI/Teams/ApproverKeywordClassifier.cs
**Purpose**: Phase 1 intent classification for approver queries.
**Requirement refs**: Req 3

```
class ApproverKeywordClassifier : ITeamsIntentClassifier
    method ClassifyAsync(userText: string) -> IntentResult
        
        PENDING_APPROVALS: "open", "pending", "waiting", "approval", 
            "new requests", "anything for me", "any open", "need my review"
        
        APPROVED_LIST: "approved", "done", "completed", "how many approved"
        
        REJECTED_LIST: "reject", "return", "sent back"
        
        SUBMISSION_DETAIL: "details", "show me", "tell me about" + FAP ID regex
        
        ACTIVITY_SUMMARY: "summary", "today", "this week", "how many", "count"
        
        HELP: "help", "what can you do"
        
        GREETING: "hi", "hello", "good morning"
        
        Extract entities:
            fapId: regex FAP-[A-Za-z0-9]{6,8}
            timeRange: "today", "this week", "this month", "last week"
```

### 4. Services/ConversationalAI/Teams/ApproverLLMClassifier.cs
**Purpose**: Phase 2 GPT-4o-mini classification for approver natural language.
**Requirement refs**: Req 4

System prompt:
```
You are an intent classifier for ClaimsIQ, used by Circle Heads and Regional Approvers.
Classify the message into exactly one intent. Respond with ONLY JSON.

Intents:
- PENDING_APPROVALS: asking about open/pending requests awaiting their approval
- SUBMISSION_DETAIL: asking about a specific submission (FAP ID mentioned)
- APPROVED_LIST: asking about what they've approved recently
- REJECTED_LIST: asking about what they've rejected/returned
- ACTIVITY_SUMMARY: asking for counts, summary, overview of their queue
- HELP: asking what the bot can do
- GREETING: hi, hello
- OUT_OF_SCOPE: unrelated to approvals

Entities to extract:
- fapId: specific FAP ID if mentioned
- timeRange: time period ("today", "this week", "this month", "last 3 days")

Format: {"intent":"PENDING_APPROVALS","confidence":0.95,"entities":{"fapId":null,"timeRange":null}}
```

### 5. Services/ConversationalAI/Teams/ApproverScopedQueryService.cs
**Purpose**: All database queries scoped by approver's role and assigned states.
**Dependencies**: AppDbContext
**Requirement refs**: Req 5, 6, 7, 8, 9

```
class ApproverScopedQueryService

    method GetPendingApprovals(userId: Guid, role: string, states: string[]) 
        -> List<PendingApprovalSummary>
        
        If role == "ASM":
            Query DocumentPackages
                .Where(Status == "PendingASM")
                .Where(AssignedASMUserId == userId 
                    OR Teams.Any(t => states.Contains(t.State)))
                .OrderBy(CreatedAt)  // oldest first
                .Take(10)
                .Select(FapId, AgencyName, Amount, SubmittedAt, DaysPending)
        
        If role == "RA":
            Query DocumentPackages
                .Where(Status == "PendingRA")
                .Where(Teams.Any(t => states.Contains(t.State)))
                .OrderBy(CreatedAt)
                .Take(10)
                .Select(...)

    method GetSubmissionDetail(userId: Guid, role: string, states: string[], fapIdSearch: string) 
        -> SubmissionFullDetail?
        
        Query DocumentPackage by partial ID match
        Verify it's within the approver's scope (state match)
        Include: ValidationResults, Recommendation, PO details
        Return full detail needed to render the existing notification card

    method GetApprovedByMe(userId: Guid, from: DateTime, to: DateTime) 
        -> List<ApprovalRecord>
        
        Query RequestApprovalHistory
            .Where(ReviewerUserId == userId)
            .Where(Action == "Approve")
            .Where(ActionAt >= from AND ActionAt <= to)
            .Select(FapId, Amount, ActionAt)

    method GetRejectedByMe(userId: Guid, from: DateTime, to: DateTime) 
        -> List<RejectionRecord>
        
        Query RequestApprovalHistory
            .Where(ReviewerUserId == userId)
            .Where(Action == "Reject")
            .Where(ActionAt >= from AND ActionAt <= to)
            .Select(FapId, Amount, Comments, ActionAt)

    method GetActivitySummary(userId: Guid, role: string, states: string[]) 
        -> ApproverActivitySummary
        
        Aggregate:
            PendingCount: DocumentPackages in scope with pending status
            NewToday: submitted today in scope
            ApprovedThisWeek: approvals by this user this week
            RejectedThisWeek: rejections by this user this week
            AvgProcessingDays: avg days from PendingASM to action for this user
```

### 6. Models/ConversationalAI/Teams/ (multiple files)

```
ApproverResolvedUser {
    UserId: Guid
    Role: string          // "ASM" or "RA"
    DisplayName: string
    AssignedStates: string[]  // ["Maharashtra"] or ["Maharashtra", "Gujarat"]
}

PendingApprovalSummary {
    FapId: string
    SubmissionId: Guid    // needed for card action data
    AgencyName: string
    Amount: decimal
    SubmittedAt: DateTime
    DaysPending: int
    State: string
}

ApproverActivitySummary {
    PendingCount: int
    NewToday: int
    ApprovedThisWeek: int
    ApprovedAmountThisWeek: decimal
    RejectedThisWeek: int
    AvgProcessingDays: double
}
```

## Adaptive Card Responses (Reuse Existing Templates)

### Pending Approvals Card

For PENDING_APPROVALS intent, the handler builds an Adaptive Card:

```
┌─────────────────────────────────────────────┐
│  📋 Pending Approvals (3)                    │
│                                              │
│  ┌─────────────────────────────────────┐    │
│  │ FAP-28C9823C                        │    │
│  │ Pinnacle Advertising | ₹2,86,740    │    │
│  │ Submitted 21-Mar-2026 | 2 days ago  │    │
│  │ [Quick Approve] [Review Details]    │    │
│  └─────────────────────────────────────┘    │
│  ┌─────────────────────────────────────┐    │
│  │ FAP-7A3F9D12                        │    │
│  │ M/S Swift Events | ₹4,12,500       │    │
│  │ Submitted 20-Mar-2026 | 3 days ago  │    │
│  │ [Quick Approve] [Review Details]    │    │
│  └─────────────────────────────────────┘    │
│                                              │
│  [View All in Portal]                        │
└─────────────────────────────────────────────┘
```

**CRITICAL**: The "Quick Approve" and "Review Details" buttons must use the SAME Action.Submit data structure as the existing notification cards, so they trigger the EXISTING OnAdaptiveCardInvokeAsync handlers. Do NOT create new action handlers.

```json
// Quick Approve button data — must match existing handler expectations
{
    "action": "quickApprove",
    "submissionId": "28c9823c-...",
    "fapId": "FAP-28C9823C"
}
```

### Submission Detail Card

For SUBMISSION_DETAIL intent, reuse the EXISTING notification card template from NotificationDispatcher. The card already has: Header, Key Facts (9 fields), AI Recommendation, PO balance placeholder, Action Buttons. Don't rebuild it — call the same card builder method.

```
method BuildDetailCard(submissionId) -> Attachment
    // Call existing: NotificationCardBuilder.BuildNotificationCard(submission)
    // This is the SAME card the proactive notification sends
    // Zero new card code needed
```

## Modified Files (Minimal Changes)

### ClaimsIQBot.cs (Teams Bot Handler)

**Change**: Add OnMessageActivityAsync and inject TeamsConversationRouter.
**Existing methods untouched**: OnAdaptiveCardInvokeAsync, HandleQuickApprove, HandleReject, HandleReviewDetails, all proactive messaging code.

```
EXISTING constructor params + ADD: TeamsConversationRouter _teamsRouter

ADD method:
    OnMessageActivityAsync(turnContext, cancellationToken)
        - userText = Activity.Text?.Trim()
        - if empty → return
        - if feature flag off → send static fallback text
        - aadObjectId = Activity.From.AadObjectId
        - await _teamsRouter.HandleAsync(userText, aadObjectId, turnContext, ct)
```

### Program.cs / Startup.cs

**Change**: Add DI registrations for Teams conversational AI services.

```
ADD:
    services.AddScoped<TeamsConversationRouter>();
    services.AddScoped<ApproverResolver>();
    services.AddScoped<ApproverScopedQueryService>();
    services.AddScoped<ITeamsIntentClassifier, ApproverKeywordClassifier>(); // Phase 1
    // services.AddScoped<ITeamsIntentClassifier, ApproverLLMClassifier>(); // Phase 2
```

### appsettings.json

```json
ADD:
{
    "Features": {
        "AgencyConversationalAI": false,
        "TeamsConversationalAI": false,
        "UseLLMClassifier": false
    }
}
```

## Implementation Order

| Order | Task | Time | Risk to Existing |
|-------|------|------|-----------------|
| 1 | Create Teams-specific models | 20 min | Zero — new files |
| 2 | Create ApproverResolver | 30 min | Zero — new file |
| 3 | Create ApproverKeywordClassifier | 30 min | Zero — new file |
| 4 | Create ApproverScopedQueryService | 1.5 hours | Zero — new file, reads existing tables |
| 5 | Create TeamsConversationRouter | 1 hour | Zero — new file |
| 6 | Add OnMessageActivityAsync to Teams bot | 30 min | Zero — new method, existing card handlers untouched |
| 7 | DI registration + feature flags | 15 min | Zero — additive |
| 8 | Test in Bot Framework Emulator | 30 min | Zero |
| 9 | Create ApproverLLMClassifier (Phase 2) | 1 hour | Zero — swap DI line when ready |

**Total: ~6 hours**

## Interface Definitions

```csharp
public interface ITeamsIntentClassifier
{
    Task<IntentResult> ClassifyAsync(string userText, CancellationToken ct = default);
}
```

Separate interface from Agency classifier (IIntentClassifier) because the intent lists are different. Agency has STATUS_CHECK, REJECTION_REASON, NEW_SUBMISSION. Teams has PENDING_APPROVALS, SUBMISSION_DETAIL, APPROVED_LIST, REJECTED_LIST, ACTIVITY_SUMMARY.

## Safety Guarantees

| What | Guarantee |
|------|-----------|
| Existing card actions | OnAdaptiveCardInvokeAsync is NEVER modified |
| Proactive notifications | NotificationDispatcher is NEVER modified |
| Card button handlers | HandleQuickApprove, HandleReject, HandleReviewDetails are NEVER modified |
| DB schema | No changes to existing tables. Only 1 new table (ConversationAuditLog, shared with Agency bot) |
| Feature flag | TeamsConversationalAI defaults to false. Existing card flow works regardless of flag state |
| Rollback | Set flag to false → instant disable. No redeploy needed. |
