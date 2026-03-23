Design: CH Teams Bot — New Claim Notification (v2 — Corrected)
Changelog from v1
v2 — Corrected based on codebase audit and requirements alignment
CRITICAL FIX: All Teams/Bot components marked as NEW (not “EXISTS”). No bot infrastructure exists in the
codebase today. The entire Infrastructure/Services/Teams/ folder, all bot services, card builders, conversation
entities, and templates are new.
FIX: Bot Framework NuGet packages listed explicitly as new dependencies (present as stale DLLs but not
referenced in any .csproj).
FIX: Aligned TeamsConversation approach — using a NEW separate TeamsConversation entity (design choice)
instead of columns on Users table (requirements.md Req 8.1). Rationale documented below.
FIX: Notification entity fields use enums (int) in code but document the string mapping for clarity. Aligns with Req
7.5 intent while using proper C# patterns.
FIX: ASM assignment model explicitly documented as broadcast (temporary) with migration path. Matches
requirements deferred section.
FIX: CompensateAsync actual behavior documented (sets ASMRejected + notifies agency, not a silent failure).
FIX: Added full appsettings.json configuration section.
FIX: Added NuGet dependency section with all required packages.
FIX: Added BotController.cs as NEW component.
Overview
This feature adds a Microsoft Teams Bot integration to deliver rich Adaptive Card notifications to CH (Circle Head / ASM)
users when submissions reach PendingASM state. The notification provides enough context for quick decision-making
directly within Teams, with a conversational Quick Approve flow and email fallback when the bot is not installed.
Important: No Teams bot infrastructure exists in the codebase today. All bot components, services, entities, templates,
and configurations described in this design are NEW. The existing codebase provides: WorkflowOrchestrator (trigger
point), NotificationAgent (in-app notifications), EmailAgent (email delivery with retry), ResiliencePolicies (retry
patterns), and the SubmissionsController (approval endpoints). Everything else is built from scratch.
Key Design Decisions
1. Single API project, not a separate bot project: The bot runs inside the existing BajajDocumentProcessing.API
project as a Singleton IBot to avoid duplicating DI, auth, and DB configuration. A new BotController handles the
/api/messages endpoint for Bot Framework webhook.
2. NotificationDispatcher pattern: A new NotificationDispatcher orchestrates channel selection (Teams → Email
fallback), retry logic, and notification logging. It is called by WorkflowOrchestrator after the PendingASM state
transition, alongside the existing NotifySubmissionReceivedAsync call (which continues unchanged for agency users).
3. New TeamsCardService with template-based cards: A new service loads JSON templates from embedded resources
and uses AdaptiveCards.Templating for token population. The card template includes all 5 sections (Header, Key
Facts, AI Recommendation, PO Balance placeholder, Action Buttons).
4. Separate TeamsConversation entity (deviation from Req 8.1):
Requirements say: Add TeamsConversationRef and TeamsChannelId columns to the Users table. Design chooses:
A separate TeamsConversation entity with a FK to User. Rationale: A separate entity cleanly handles: (a)
conversation reference JSON is large (~2KB) and would bloat every User query, (b) the IsActive flag enables soft
invalidation without touching User records, (c) future multi-tenant support (user could have refs in multiple Teams
tenants), (d) the upsert-on-install pattern is cleaner on a dedicated table. The FK to User satisfies the identity
resolution need. Requirement update needed: Req 8.1 should be updated to reflect this approach.
5. Extend Notification entity for multi-channel tracking: Add Channel , DeliveryStatus , RetryCount , SentAt ,
ExternalMessageId , and FailureReason fields. These use C# enums ( NotificationChannel ,
NotificationDeliveryStatus ) mapped to int columns. The requirements (Req 7.5) specify string values — the enum
approach is equivalent but type-safe. Mapping: NotificationChannel.InApp = “InApp”, .Teams = “Teams”, .Email =
“Email”.
6. Reuse existing approval endpoints: The Quick Approve flow calls the existing PATCH /api/submissions/{id}/asm
approve endpoint logic internally (via direct service call, not HTTP) to ensure all existing state transition guards,
RequestApprovalHistory creation, and downstream notifications execute identically to portal approvals.
7. PO Balance section deferred: Per Requirement 4, PO balance data is not available from SAP. The card includes a
placeholder with “Check PO Balance in Portal” link.
8. ASM targeting — broadcast model (temporary):
Requirements say: ASM assignment is DEFERRED. All requirements referencing “the assigned ASM” assume the
prerequisite is in place. Design implements: Broadcast to all ASM-role users as a temporary measure. This is
explicitly a stopgap — the NotificationDispatcher loads all users with Role == UserRole.ASM and sends to each.
Migration path: When ASM-to-submission assignment is implemented (e.g., DocumentPackage.AssignedASMUserId
FK), the dispatcher’s user-loading query changes from “all ASM users” to “the assigned ASM user.” The rest of the
pipeline (card building, sending, retry, fallback) remains identical. Risk: With current seed data (1 ASM user),
broadcast behaves identically to targeted. In production with multiple ASMs, all ASMs receive all notifications until
assignment is built.
9. FAP ID format: FAP-{first 8 chars of DocumentPackage.Id GUID, uppercased} (e.g., FAP-28C9823C ). This matches
the convention in ChatService and AnalyticsPlugin . It is a display convention — not a stored field.
10. CompensateAsync behavior (corrected from v1):
The WorkflowOrchestrator.CompensateAsync method does NOT silently fail. It sets the package state to
PackageState.ASMRejected and calls NotifyRejectedAsync to the agency user. This means the compensation path
produces a rejection (not a processing error). The notification dispatcher is NOT called on this path because the
state is ASMRejected , not PendingASM . The trigger for CH notification is exclusively the PendingASM state transition
in the success path.
New Dependencies
NuGet Packages (add to BajajDocumentProcessing.API.csproj )
<!-- Bot Framework -->
<PackageReference Include="Microsoft.Bot.Builder.Integration.AspNet.Core" Version="4.22.9" />
<PackageReference Include="Microsoft.Bot.Builder" Version="4.22.9" />
<!-- Adaptive Cards -->
<PackageReference Include="AdaptiveCards.Templating" Version="1.6.0" />
<PackageReference Include="AdaptiveCards" Version="3.1.0" />
Note: Bot Framework DLLs exist as stale artifacts in bin/Debug but are NOT referenced in any .csproj . These must be
added as proper package references.
appsettings.json Configuration
{
}
  "TeamsBot": {
    "MicrosoftAppId": "<Azure Bot Registration App ID>",
    "MicrosoftAppPassword": "<Azure Bot Registration App Password>",
    "MicrosoftAppTenantId": "<Bajaj M365 Tenant ID>",
    "PortalBaseUrl": "https://claimsiq.bajaj.com",
    "NotificationDelayBetweenUsersMs": 2000,
    "MaxRetryAttempts": 3,
    "RetryDelaysSeconds": [5, 15, 45]
  }
Prerequisite: Bajaj IT must register an Azure Bot resource in their Azure subscription and provide the App ID,
Password, and Tenant ID. The bot must be configured for “personal” scope (1:1 chat) in the Teams App Manifest.
Architecture
High-Level Notification Flow
sequenceDiagram
    participant WO as WorkflowOrchestrator (existing)
    participant NA as NotificationAgent (existing)
    participant ND as NotificationDispatcher (NEW)
    participant NDS as NotificationDataService (NEW)
    participant TCS as TeamsCardService (NEW)
    participant TNS as TeamsNotificationService (NEW)
    participant EA as EmailAgent (existing)
    participant DB as Database
    WO->>NA: NotifySubmissionReceivedAsync(agencyUserId, packageId)
    Note right of NA: Existing agency notification — unchanged
    WO->>ND: DispatchNewSubmissionNotificationAsync(packageId)
    ND->>DB: Load all ASM-role users (broadcast — temporary until ASM assignment exists)
    ND->>DB: Load TeamsConversation for each ASM user
    loop For each ASM user
        ND->>NDS: GetSubmissionCardDataAsync(packageId)
        NDS->>DB: Load Package + PO + Teams.Invoices + Teams.Photos + Scores + Validation + Recommendation + Agency
        NDS-->>ND: SubmissionCardData DTO
        alt User has active TeamsConversation (IsActive = true)
            ND->>TCS: BuildNewSubmissionCard(cardData)
            TCS-->>ND: Adaptive Card JSON
            ND->>TNS: SendProactiveCardToUserAsync(teamsConversation, cardJson)
            TNS-->>ND: ProactiveMessageResult
            alt Send Failed (503/timeout)
                ND->>TNS: Retry up to 3x (5s, 15s, 45s backoff)
                alt All retries exhausted
                    ND->>DB: Log Notification(Channel=Teams, Status=Failed, RetryCount=3)
                    ND->>EA: Send email fallback
                    ND->>DB: Log Notification(Channel=Email, Status=Sent/Failed)
                end
            end
            alt Send Failed (403/404 — stale ref)
                ND->>DB: Set TeamsConversation.IsActive = false
                ND->>EA: Send email fallback
                ND->>DB: Log Notification(Channel=Email, Status=Sent/Failed)
            end
            ND->>DB: Log Notification(Channel=Teams, Status=Sent)
        else No active TeamsConversation
            ND->>EA: Send email fallback
            ND->>DB: Log Notification(Channel=Email, Status=Sent/Failed)
        end
    end
Quick Approve Bot Flow
sequenceDiagram
    participant CH as CH (Teams)
    participant Bot as TeamsBotService (NEW)
    participant DB as Database
    participant SVC as Approval Service Logic (existing)
    CH->>Bot: Click "Quick Approve" (Action.Submit)
    Bot->>DB: Load DocumentPackage.State
    alt State = PendingASM
        Bot->>CH: Confirmation card "Approve FAP-{shortId} ({agencyName}, ₹{amount})? [Approve Invoice] [Cancel]"
        CH->>Bot: Click "Approve Invoice" (Action.Submit)
        Bot->>CH: "Any comments? (optional) [Skip]"
        CH->>Bot: Type comments or click "Skip" (Action.Submit)
        Bot->>SVC: Execute approval logic (same as asm-approve endpoint)
        Note right of Bot: State → PendingRA, RequestApprovalHistory created with Channel="TeamsBot"
        Bot->>CH: " Approved! FAP-{shortId} forwarded to RA."
    else State ≠ PendingASM
        Bot->>CH: "FAP-{shortId} has already been processed."
    end
Review Details Bot Flow
sequenceDiagram
    participant CH as CH (Teams)
    participant Bot as TeamsBotService (NEW)
    participant NDS as NotificationDataService (NEW)
    participant TCS as TeamsCardService (NEW)
    CH->>Bot: Click "Review Details" (Action.Submit)
    Bot->>NDS: GetValidationBreakdownAsync(submissionId)
    NDS-->>Bot: ValidationBreakdownData
    Bot->>TCS: BuildReviewDetailsCard(breakdownData)
    TCS-->>Bot: Review Details Card JSON
    Bot->>CH: Post review details card with [Approve] [Reject] [Open in Portal]
Project Structure — ALL Changes
Legend: NEW = file does not exist, create from scratch. MODIFY = file exists, add code. EXISTING = file exists, no
changes needed (listed for reference only).
backend/
├── src/
│   
├── BajajDocumentProcessing.API/
│   
│   
│   
│   
├── BajajDocumentProcessing.API.csproj          # MODIFY: add 4 NuGet packages
├── appsettings.json                             # MODIFY: add TeamsBot config section
Layer Responsibilities
Layer Component Status Responsibility
API BotController.cs NEW POST /api/messages webhook for Bot Framework
API Program.cs MODIFY Register bot services, map /api/messages endpoint
Application INotificationDispatcher NEW Interface for notification orchestration
Application INotificationDataService NEW Interface for assembling card/email data
Application ITeamsCardService NEW Interface for building adaptive cards
│   │   ├── Program.cs                                   # MODIFY: add bot DI + endpoint mapping
│   │   ├── Controllers/
│   │   │   └── BotController.cs                         # NEW: POST /api/messages webhook
│   │   └── templates/
│   │       └── email/
│   │           └── new-submission.html                  # NEW: Email fallback HTML template
│   │
│   ├── BajajDocumentProcessing.Application/
│   │   ├── Common/Interfaces/
│   │   │   ├── ITeamsCardService.cs                     # NEW: card building interface
│   │   │   ├── ITeamsNotificationService.cs             # NEW: proactive messaging interface
│   │   │   ├── INotificationDispatcher.cs               # NEW: orchestration interface
│   │   │   └── INotificationDataService.cs              # NEW: data assembly interface
│   │   └── DTOs/
│   │       └── Notifications/
│   │           ├── SubmissionCardData.cs                 # NEW: full card data DTO
│   │           ├── ValidationBreakdownData.cs            # NEW: review details DTO
│   │           └── ProactiveMessageResult.cs             # NEW: send result DTO
│   │
│   ├── BajajDocumentProcessing.Domain/
│   │   ├── Entities/
│   │   │   ├── Notification.cs                          # MODIFY: add Channel, DeliveryStatus, RetryCount, SentAt, ExternalMessageId, FailureReason
│   │   │   ├── RequestApprovalHistory.cs                # MODIFY: add Channel field
│   │   │   └── TeamsConversation.cs                     # NEW: conversation reference entity
│   │   └── Enums/
│   │       ├── NotificationChannel.cs                   # NEW: InApp=1, Teams=2, Email=3
│   │       ├── NotificationDeliveryStatus.cs            # NEW: Pending=1, Sent=2, Failed=3, FallbackSent=4
│   │       └── NotificationType.cs                      # MODIFY: add ReadyForReview = 6
│   │
│   └── BajajDocumentProcessing.Infrastructure/
│       ├── Data/
│       │   └── ApplicationDbContext.cs                  # MODIFY: add DbSet<TeamsConversation>, configure entity
│       ├── Migrations/
│       │   └── YYYYMMDDHHMMSS_AddTeamsBotSupport.cs    # NEW: EF Core migration
│       ├── Services/
│       │   ├── NotificationDispatcher.cs                # NEW: channel selection, retry, fallback, logging
│       │   ├── NotificationDataService.cs               # NEW: loads submission data into DTOs
│       │   └── Teams/                                   # NEW FOLDER
│       │       ├── TeamsBotService.cs                   # NEW: IBot implementation — handles messages, card actions, Quick Approve, Review Details
│       │       ├── TeamsNotificationService.cs          # NEW: proactive messaging via BotAdapter
│       │       ├── TeamsCardService.cs                  # NEW: template loading + token expansion
│       │       ├── BotAdapterWithErrorHandler.cs        # NEW: CloudAdapter with error logging
│       │       └── TeamsBotOptions.cs                   # NEW: strongly-typed config POCO
│       ├── Templates/TeamsCards/                         # NEW FOLDER
│       │   ├── new-submission-card.json                 # NEW: 5-section adaptive card template
│       │   └── review-details-card.json                 # NEW: validation breakdown card template
│       └── DependencyInjection.cs                       # MODIFY: register all new services
Application ITeamsNotificationService NEW Interface for proactive messaging
Application SubmissionCardData NEW Full card data DTO with all token fields
Application ValidationBreakdownData NEW Review details DTO
Application ProactiveMessageResult NEW Send result DTO
Domain TeamsConversation NEW Conversation reference entity with FK to User
Domain Notification MODIFY Add multi-channel delivery tracking fields
Domain RequestApprovalHistory MODIFY Add Channel field
Domain NotificationType MODIFY Add ReadyForReview = 6
Domain NotificationChannel NEW Enum: InApp=1, Teams=2, Email=3
Domain NotificationDeliveryStatus NEW Enum: Pending=1, Sent=2, Failed=3, FallbackSent=4
Infrastructure NotificationDispatcher NEW Channel selection, retry, fallback, logging
Infrastructure NotificationDataService NEW Loads package data into DTOs
Infrastructure TeamsCardService NEW Template loading + token expansion
Infrastructure TeamsBotService NEW IBot: messages, card actions, Quick Approve, Review
Details, pending query
Infrastructure TeamsNotificationService NEW Per-user proactive send via BotAdapter
Infrastructure BotAdapterWithErrorHandler NEW CloudAdapter with error logging
Infrastructure TeamsBotOptions NEW Strongly-typed config POCO for appsettings
Infrastructure ApplicationDbContext MODIFY Add DbSet, entity configuration
Infrastructure DependencyInjection.cs MODIFY Register all new services
Components and Interfaces
BotController (NEW)
namespace BajajDocumentProcessing.API.Controllers;
[ApiController]
[Route("api/messages")]
[AllowAnonymous] // Bot Framework handles its own auth via App ID/Password
public class BotController : ControllerBase
{
    private readonly IBotFrameworkHttpAdapter _adapter;
    private readonly IBot _bot;
    public BotController(IBotFrameworkHttpAdapter adapter, IBot bot)
    {
        _adapter = adapter;
        _bot = bot;
    }
    [HttpPost]
    public async Task PostAsync()
    {
        await _adapter.ProcessAsync(Request, Response, _bot);
    }
}
Program.cs Registration (MODIFY)
// Add to existing service registration in Program.cs or DependencyInjection.cs
// Bot Framework
builder.Services.AddSingleton<BotFrameworkAuthentication, ConfigurationBotFrameworkAuthentication>();
builder.Services.AddSingleton<IBotFrameworkHttpAdapter, BotAdapterWithErrorHandler>();
builder.Services.AddSingleton<IBot, TeamsBotService>();
// Teams services
builder.Services.Configure<TeamsBotOptions>(builder.Configuration.GetSection("TeamsBot"));
builder.Services.AddScoped<ITeamsCardService, TeamsCardService>();
builder.Services.AddScoped<ITeamsNotificationService, TeamsNotificationService>();
builder.Services.AddScoped<INotificationDispatcher, NotificationDispatcher>();
builder.Services.AddScoped<INotificationDataService, NotificationDataService>();
TeamsBotOptions (NEW)
namespace BajajDocumentProcessing.Infrastructure.Services.Teams;
public class TeamsBotOptions
{
    public string MicrosoftAppId { get; set; } = string.Empty;
    public string MicrosoftAppPassword { get; set; } = string.Empty;
    public string MicrosoftAppTenantId { get; set; } = string.Empty;
    public string PortalBaseUrl { get; set; } = string.Empty;
    public int NotificationDelayBetweenUsersMs { get; set; } = 2000;
    public int MaxRetryAttempts { get; set; } = 3;
    public int[] RetryDelaysSeconds { get; set; } = { 5, 15, 45 };
}
INotificationDispatcher (NEW)
namespace BajajDocumentProcessing.Application.Common.Interfaces;
public interface INotificationDispatcher
{
    /// <summary>
    /// Dispatches a new-submission notification to ASM users.
    /// Current implementation: broadcast to ALL ASM-role users (temporary).
    /// Future: send to assigned ASM only (requires ASM assignment prerequisite).
    /// For each ASM: selects Teams or Email channel based on TeamsConversation availability.
    /// Called by WorkflowOrchestrator after PendingASM state transition.
    /// </summary>
    Task DispatchNewSubmissionNotificationAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);
}
INotificationDataService (NEW)
namespace BajajDocumentProcessing.Application.Common.Interfaces;
public interface INotificationDataService
{
    /// <summary>
    /// Loads all submission data needed to populate the adaptive card or email template.
    /// Includes: Package, PO, Teams.Invoices, Teams.Photos, EnquiryDocument,
    /// ConfidenceScore, Recommendation, ValidationResult, Agency.
    /// </summary>
    Task<SubmissionCardData> GetSubmissionCardDataAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);
    /// <summary>
    /// Loads per-document validation breakdown for the Review Details flow.
    /// Groups validation checks by type (SAP, Amount, LineItem, Completeness, Date, Vendor).
    /// </summary>
    Task<ValidationBreakdownData> GetValidationBreakdownAsync(
        Guid packageId,
        CancellationToken cancellationToken = default);
}
ITeamsCardService (NEW)
namespace BajajDocumentProcessing.Application.Common.Interfaces;
public interface ITeamsCardService
{
    /// <summary>
    /// Builds the new-submission adaptive card from template + data.
    /// Template: Templates/TeamsCards/new-submission-card.json
    /// Uses AdaptiveCards.Templating for token expansion.
    /// </summary>
    string BuildNewSubmissionCard(SubmissionCardData data);
    /// <summary>
    /// Builds the review details card with per-check validation breakdown.
    /// Template: Templates/TeamsCards/review-details-card.json
    /// </summary>
    string BuildReviewDetailsCard(ValidationBreakdownData data);
}
ITeamsNotificationService (NEW)
namespace BajajDocumentProcessing.Application.Common.Interfaces;
public interface ITeamsNotificationService
{
    /// <summary>
    /// Sends an adaptive card to a specific user via proactive messaging.
    /// Uses BotAdapter.ContinueConversationAsync with the stored ConversationReference.
    /// </summary>
    Task<ProactiveMessageResult> SendProactiveCardToUserAsync(
        TeamsConversation conversation,
        string cardJson,
        CancellationToken cancellationToken = default);
}
ProactiveMessageResult (NEW)
namespace BajajDocumentProcessing.Application.DTOs.Notifications;
public class ProactiveMessageResult
{
    public bool Success { get; set; }
    public int HttpStatusCode { get; set; }
    public string? ErrorMessage { get; set; }
    public string? ActivityId { get; set; }  // Teams message ID for tracking
}
TeamsBotService (NEW)
// NEW — implements IBot (Microsoft.Bot.Builder)
// Handles:
// - OnMembersAddedAsync: capture + persist ConversationReference to TeamsConversation table
// - OnMembersRemovedAsync: set TeamsConversation.IsActive = false
// - OnMessageActivityAsync: handle "show my pending" and help text
// - OnAdaptiveCardInvokeAsync: route card actions:
//     action = "quick_approve"       
→ Start Quick Approve dialog (load state, post confirmation card)
//     action = "confirm_approve"     
//     action = "cancel_approve"      
//     action = "review_details"      
→ Execute approval with optional comments
→ Post cancellation message
→ Load validation breakdown, post review card
//     action = "approve_from_review" → Approve after reviewing details
//     action = "reject_from_review"  → Start rejection flow from review
// User identity resolution:
// - On install, match Teams user to system User by email (Teams UPN)
// - Store UserId FK on TeamsConversation
// - For Quick Approve, resolve TeamsConversation.UserId to authenticate the approval call
// - Pilot phase: single ASM user, can match by role as fallback
// Idempotency:
// - Before any approval action, load DocumentPackage.State
// - If state ≠ PendingASM (and not RARejected for re-approval), return "already processed" message
// - The existing asm-approve endpoint also guards (returns 400), so bot handles 400 gracefully
// Channel tracking:
// - All RequestApprovalHistory records created via bot set Channel = "TeamsBot"
Data Models
TeamsConversation Entity (NEW)
namespace BajajDocumentProcessing.Domain.Entities;
/// <summary>
/// Stores Teams conversation references for proactive messaging.
/// One record per user-bot conversation.
/// Deviation from Req 8.1: uses separate entity instead of columns on Users table.
/// See Key Design Decision #4 for rationale.
/// </summary>
public class TeamsConversation : BaseEntity
{
    public Guid? UserId { get; set; }                              // FK to User (nullable until identity resolved)
    public string TeamsUserId { get; set; } = string.Empty;        // Teams channel account ID
    public string ConversationId { get; set; } = string.Empty;     // Teams conversation ID
    public string ServiceUrl { get; set; } = string.Empty;         // Bot Framework service URL
    public string ChannelId { get; set; } = string.Empty;          // "msteams"
    public string? TenantId { get; set; }                          // M365 tenant ID
    public string ConversationReferenceJson { get; set; } = string.Empty; // Full serialized ConversationReference
    public bool IsActive { get; set; } = true;                     // Set false on 403/404 or uninstall
    public DateTime? LastActivityAt { get; set; }                  // Updated on each interaction
    // Navigation
    public User? User { get; set; }
}
Extended Notification Entity (MODIFY existing)
public class Notification : BaseEntity
{
    // === Existing fields (unchanged) ===
    public Guid UserId { get; set; }
    public NotificationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public DateTime? ReadAt { get; set; }
    public Guid? RelatedEntityId { get; set; }
    public User User { get; set; } = null!;
    public DocumentPackage? RelatedPackage { get; set; }
    // === NEW fields for multi-channel delivery tracking ===
    /// <summary>Channel: InApp=1, Teams=2, Email=3. Maps to Req 7.5 string values.</summary>
    public NotificationChannel Channel { get; set; } = NotificationChannel.InApp;
    /// <summary>Status: Pending=1, Sent=2, Failed=3, FallbackSent=4. Maps to Req 7.5 string values.</summary>
    public NotificationDeliveryStatus DeliveryStatus { get; set; } = NotificationDeliveryStatus.Sent;
    public int RetryCount { get; set; } = 0;
    public DateTime? SentAt { get; set; }
    public string? ExternalMessageId { get; set; }  // Teams activity ID or email message ID
    public string? FailureReason { get; set; }       // Error details on failure
}
New Enums
/// <summary>Maps to Req 7.5: 'InApp', 'Teams', 'Email'</summary>
public enum NotificationChannel
{
    InApp = 1,
    Teams = 2,
    Email = 3
}
/// <summary>Maps to Req 7.5: 'Pending', 'Sent', 'Failed' + design addition 'FallbackSent'</summary>
public enum NotificationDeliveryStatus
{
}
    Pending = 1,
    Sent = 2,
    Failed = 3,
    FallbackSent = 4
Extended NotificationType (MODIFY existing)
public enum NotificationType
{
    SubmissionReceived = 1,
    FlaggedForReview = 2,
    Approved = 3,
    Rejected = 4,
    ReuploadRequested = 5,
    ReadyForReview = 6       // NEW: ASM notification when submission reaches PendingASM
}
Extended RequestApprovalHistory (MODIFY existing)
public class RequestApprovalHistory : BaseEntity
{
    // === Existing fields (unchanged) ===
    public Guid PackageId { get; set; }
    public Guid ApproverId { get; set; }
    public UserRole ApproverRole { get; set; }
    public ApprovalAction Action { get; set; }
    public string? Comments { get; set; }
    public DateTime ActionDate { get; set; }
    public int VersionNumber { get; set; }
    public DocumentPackage DocumentPackage { get; set; } = null!;
    public User Approver { get; set; } = null!;
    // === NEW field ===
    /// <summary>
    /// Source channel: "Portal", "TeamsBot", or null (legacy/portal default).
    /// </summary>
    public string? Channel { get; set; }
}
SubmissionCardData DTO (NEW)
namespace BajajDocumentProcessing.Application.DTOs.Notifications;
public class SubmissionCardData
{
    // Identifiers
    public Guid SubmissionId { get; set; }
    public string SubmissionNumber { get; set; } = string.Empty;  // "FAP-{Id[..8].ToUpper()}"
    public DateTime NotificationTimestamp { get; set; }
    // Key Facts (Req 2.2)
    public string AgencyName { get; set; } = string.Empty;
    public string PoNumber { get; set; } = "N/A";
    public string InvoiceNumber { get; set; } = "N/A";
    public string InvoiceAmount { get; set; } = "₹0";            // Formatted with ₹ and Indian notation
    public decimal InvoiceAmountRaw { get; set; }                 // Raw decimal for email subject
    public string State { get; set; } = "N/A";
    public DateTime SubmittedAt { get; set; }
    public string SubmittedAtFormatted { get; set; } = string.Empty;
    public int TeamCount { get; set; }
    public int PhotoCount { get; set; }
    public string TeamPhotoSummary { get; set; } = string.Empty;  // "3 teams | 19 photos"
    public string InquirySummary { get; set; } = "N/A";
    // AI Recommendation (Req 3)
    public string Recommendation { get; set; } = string.Empty;    // "Approve", "Review", "Reject"
    public string RecommendationEmoji { get; set; } = string.Empty;
    public string CardStyle { get; set; } = "default";            // Always "default" — no background color changes on cards
    public double ConfidenceScore { get; set; }
    public string ConfidenceScoreFormatted { get; set; } = string.Empty;
    public int PassedChecks { get; set; }
    public int TotalChecks { get; set; }
    public string ChecksSummary { get; set; } = string.Empty;
    public bool AllChecksPassed { get; set; }
    public List<ValidationIssueItem> TopIssues { get; set; } = new();
    public int RemainingIssueCount { get; set; }
    public string RemainingIssueText { get; set; } = string.Empty;
    // PO Balance (Req 4 — deferred)
    public string PoBalanceMessage { get; set; } = "PO balance check available in portal";
    // Action Buttons (Req 5)
    public bool ShowQuickApprove { get; set; }
    public string PortalUrl { get; set; } = string.Empty;
}
public class ValidationIssueItem
{
    public string Severity { get; set; } = string.Empty;  // "Fail" or "Warning"
    public string Description { get; set; } = string.Empty;
}
ValidationBreakdownData DTO (NEW)
namespace BajajDocumentProcessing.Application.DTOs.Notifications;
public class ValidationBreakdownData
{
    public Guid SubmissionId { get; set; }
    public string SubmissionNumber { get; set; } = string.Empty;
    public string CurrentStatus { get; set; } = string.Empty;
    public DateTime? ProcessedAt { get; set; }
    public string? ProcessedBy { get; set; }
    public bool IsAlreadyProcessed { get; set; }
    public List<ValidationCheckGroup> CheckGroups { get; set; } = new();
    public string PortalUrl { get; set; } = string.Empty;
}
public class ValidationCheckGroup
{
    public string GroupName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;     // "Pass" or "Fail"
    public string? Details { get; set; }
}
Database Schema Changes (EF Core Migration)-- 1. NEW: TeamsConversation table
CREATE TABLE TeamsConversations (
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
    UserId UNIQUEIDENTIFIER NULL,                           -- FK to Users (nullable until identity resolved)
    TeamsUserId NVARCHAR(200) NOT NULL,
    ConversationId NVARCHAR(500) NOT NULL,
    ServiceUrl NVARCHAR(500) NOT NULL,
    ChannelId NVARCHAR(100) NOT NULL DEFAULT 'msteams',
    TenantId NVARCHAR(200) NULL,
    ConversationReferenceJson NVARCHAR(MAX) NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    LastActivityAt DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0,
    CONSTRAINT FK_TeamsConversations_Users FOREIGN KEY (UserId) REFERENCES Users(Id)
);
CREATE UNIQUE INDEX IX_TeamsConversations_TeamsUserId ON TeamsConversations (TeamsUserId) WHERE IsDeleted = 0;
CREATE INDEX IX_TeamsConversations_UserId ON TeamsConversations (UserId) WHERE IsActive = 1;-- 2. MODIFY: Extend Notifications table
ALTER TABLE Notifications ADD Channel INT NOT NULL DEFAULT 1;              -- NotificationChannel.InApp
ALTER TABLE Notifications ADD DeliveryStatus INT NOT NULL DEFAULT 2;       -- NotificationDeliveryStatus.Sent
ALTER TABLE Notifications ADD RetryCount INT NOT NULL DEFAULT 0;
ALTER TABLE Notifications ADD SentAt DATETIME2 NULL;
ALTER TABLE Notifications ADD ExternalMessageId NVARCHAR(500) NULL;
ALTER TABLE Notifications ADD FailureReason NVARCHAR(2000) NULL;-- 3. MODIFY: Extend RequestApprovalHistory table
ALTER TABLE RequestApprovalHistory ADD Channel NVARCHAR(50) NULL;-- 4. Indexes for notification queries
CREATE INDEX IX_Notifications_UserId_Channel_DeliveryStatus
    ON Notifications (UserId, Channel, DeliveryStatus);
CREATE INDEX IX_Notifications_RelatedEntityId_Channel
    ON Notifications (RelatedEntityId, Channel);
Existing Components Reused (No Changes Needed)
Component
Location
How It’s Reused
Trigger point — add
WorkflowOrchestrator
NotificationAgent
Infrastructure/Services/WorkflowOrchestrator.cs
Infrastructure/Services/NotificationAgent.cs
DispatchNewSubmissionNotificationAsync
call after PendingASM transition
Existing agency in-app notifications —
unchanged per Req 1.6
EmailAgent
Infrastructure/Services/EmailAgent.cs
Email fallback delivery with existing retry
logic
ResiliencePolicies
Infrastructure/Resilience/ResiliencePolicies.cs
Reference for retry patterns (but Teams
retry is implemented in
NotificationDispatcher, not via Polly HTTP
policies)
SubmissionsController
API/Controllers/SubmissionsController.cs
Existing ASM approve/reject endpoints with
state guards — called via service layer from
bot
Integration Points
WorkflowOrchestrator Integration (MODIFY)
The WorkflowOrchestrator.ProcessSubmissionAsync currently does the following after setting PendingASM :
1. _notificationAgent.NotifySubmissionReceivedAsync(package.SubmittedByUserId, ...) — agency notification
Add a new call after step 1: 2. _notificationDispatcher.DispatchNewSubmissionNotificationAsync(package.Id,
cancellationToken) — ASM notification (Teams or email)
The existing agency notification (step 1) remains unchanged per Requirement 1.6.
Note on CompensateAsync: The existing CompensateAsync sets state to ASMRejected and calls NotifyRejectedAsync
to the agency. The NotificationDispatcher is NOT called here because the state is not PendingASM . This is correct
behavior — CH should not be notified about failed pipeline runs.
TeamsBotService — User Identity Resolution (NEW)
For the Quick Approve flow to call the approval service logic, the bot must map the Teams identity to a system user:
1. On bot install ( OnMembersAddedAsync ), store TeamsConversation with TeamsUserId
2. Attempt to match Teams user to system User by email (Teams provides UPN via
turnContext.Activity.From.Properties or Graph API)
3. Store matched UserId FK on TeamsConversation
4. For Quick Approve, resolve TeamsConversation.UserId to authenticate the approval call
5. Pilot fallback: With single ASM seed user, match by UserRole.ASM if email match fails
NotificationDataService — Data Assembly Logic (NEW)
// Pseudo-code for GetSubmissionCardDataAsync
var package = await _context.DocumentPackages
    .Include(p => p.PO)
    .Include(p => p.Agency)
    .Include(p => p.Teams.Where(t => !t.IsDeleted))
        .ThenInclude(t => t.Invoices.Where(i => !i.IsDeleted))
    .Include(p => p.Teams.Where(t => !t.IsDeleted))
        .ThenInclude(t => t.Photos.Where(ph => !ph.IsDeleted))
    .Include(p => p.EnquiryDocument)
    .Include(p => p.ConfidenceScore)
    .Include(p => p.Recommendation)
    .Include(p => p.ValidationResult)
    .AsSplitQuery()
    .AsNoTracking()
    .FirstOrDefaultAsync(p => p.Id == packageId, ct);
// Derivation rules:
// FAP ID: "FAP-" + package.Id.ToString()[..8].ToUpper()
// Agency: package.Agency.SupplierName
// PO Number: package.PO?.PONumber ?? TryParseFromExtractedDataJson(package.PO?.ExtractedDataJson) ?? "N/A"
// Invoice Number: package.Teams.SelectMany(t => t.Invoices).FirstOrDefault()?.InvoiceNumber ?? "N/A"
// Invoice Amount: package.Teams.SelectMany(t => t.Invoices).Sum(i => i.TotalAmount ?? 0)
// State: package.Teams.FirstOrDefault()?.State ?? "N/A"
// Team Count: package.Teams.Count(t => !t.IsDeleted)
// Photo Count: package.Teams.SelectMany(t => t.Photos).Count(p => !p.IsDeleted)
//
// Recommendation: Recommendation.Type → Always "default" style (no background color). Emoji conveys type: Approve=✅, Review=⚠️, Reject=❌
// Confidence: ConfidenceScore.OverallConfidence
// Validation: Count 6 boolean fields on ValidationResult, parse ValidationDetailsJson for descriptions
// ShowQuickApprove: true only when Recommendation.Type == Approve
// PortalUrl: _options.PortalBaseUrl + "/fap/" + package.Id + "/review"
Adaptive Card Template Structure (new-submission-card.json)
┌─────────────────────────────────────────┐
│ Section 1: Header                       │
│   "New Claim Submitted"    12:34 PM     │
├─────────────────────────────────────────┤
│ Section 2: Key Facts (FactSet)          │
│   FAP ID:     FAP-28C9823C             │
│   Agency:     Acme Corp                 │
│   PO Number:  PO-2026-001              │
│   Invoice:    INV-001                   │
│   Amount:     ₹1,25,000                │
│   State:      Maharashtra               │
│   Submitted:  12-Mar-2026, 10:30 AM    │
│   Teams:      3 teams | 19 photos       │
│   Inquiries:  87 records (84 complete)  │
├─────────────────────────────────────────┤
│ Section 3: AI Recommendation            │
│    Recommended: Approve (85/100)      │
│   12/14 checks passed                   │
│   • Fail: Amount mismatch              │
│   • Warning: Date discrepancy          │
├─────────────────────────────────────────┤
│ Section 4: PO Balance (placeholder)     │
│   PO balance check available in portal  │
│   [Open in Portal]                      │
├─────────────────────────────────────────┤
│ Section 5: Action Buttons               │
│   [Quick Approve] [Review Details]      │
│   [Open in Portal]                      │
└─────────────────────────────────────────┘
Token placeholders use ${property} syntax from AdaptiveCards.Templating:
Header: ${notificationTimestamp}
Key Facts: ${submissionNumber}, ${agencyName}, ${poNumber}, ${invoiceNumber}, ${invoiceAmount}, ${state},
${submittedAtFormatted}, ${teamPhotoSummary}, ${inquirySummary}
AI Section: ${recommendationEmoji}, ${recommendation}, ${confidenceScoreFormatted},
${checksSummary}, ${allChecksPassed}, ${topIssues} (array), ${remainingIssueText}
Note: ${cardStyle} is always "default" — no container background color changes on any card.
PO Balance: ${poBalanceMessage}
Actions: ${showQuickApprove} (conditional visibility), ${submissionId} (in Action.Submit data), ${portalUrl}
(Action.OpenUrl)
Correctness Properties
All 20 properties from v1 are retained unchanged. They correctly validate the requirements regardless of whether
components are new or existing.
(Properties 1–20 identical to v1 — omitted here for brevity. See v1 design for full list.)
Error Handling
Error handling tables from v1 are retained unchanged. The error handling logic is correct regardless of component
status (new vs existing).
Proactive Messaging Errors
Error Action Retry?
403 Forbidden (bot uninstalled) Set TeamsConversation.IsActive = false, fall back to email, log
WARNING No
404 Not Found (conversation
gone) Same as 403 No
503 Service Unavailable Retry with exponential backoff (5s, 15s, 45s) Yes,
3×
Timeout (>30s) Same as 503 Yes,
3×
429 Too Many Requests Respect Retry-After header, delay and retry Yes
All retries exhausted Fall back to email, log Teams attempt as Failed N/A
Retry Implementation
// In NotificationDispatcher — internal retry (not Polly HTTP, since BotAdapter is not HTTP client)
private static readonly TimeSpan[] RetryDelays = {
    TimeSpan.FromSeconds(5),
    TimeSpan.FromSeconds(15),
    TimeSpan.FromSeconds(45)
};
for (int attempt = 0; attempt <= MaxRetries; attempt++)
{
    var result = await _teamsNotificationService.SendProactiveCardToUserAsync(conversation, cardJson, ct);
    if (result.Success) break;
    if (result.HttpStatusCode is 403 or 404) { /* invalidate + email fallback, no retry */ break; }
    if (attempt < MaxRetries) await Task.Delay(RetryDelays[attempt], ct);
}
Card Building Errors
Error Action
Template not found Log CRITICAL, fall back to email with basic text content
Token resolution failure Use fallback values (“N/A”, “—”). Never show raw ${placeholder}
Card JSON exceeds 4KB Truncate issue list, remove optional sections. Log WARNING
Approval Flow Errors
Error Action
Submission not in PendingASM Return “FAP-{shortId} has already been processed.”
Concurrent approval (400 from endpoint) Handle gracefully: “already actioned” message
Service throws “Something went wrong. Please try again or use the portal.” Log ERROR
User not authorized “You don’t have permission to approve this submission.”
Testing Strategy
Testing strategy from v1 retained with updated component names marked as NEW.
Test Organization
backend/tests/BajajDocumentProcessing.Tests/
├── Infrastructure/
│   
├── Properties/
│   
│   
│   
│   
│   
│   
│   
│   
│   
│   
│   
│   
│   
├── NotificationDispatcherProperties.cs    # Properties 1, 2, 9, 10, 13, 20
├── NotificationDataServiceProperties.cs   # Properties 3, 7, 15, 19
├── TeamsCardServiceProperties.cs          # Properties 4, 5, 6, 14
└── ApprovalFlowProperties.cs              # Properties 8, 12, 16, 17
├── NotificationDispatcherTests.cs
├── NotificationDataServiceTests.cs
├── TeamsCardServiceTests.cs
├── ProactiveMessagingServiceTests.cs
└── EmailFallbackTests.cs
├── Infrastructure/Teams/
│   
├── TeamsBotServiceTests.cs
│   
└── QuickApproveFlowTests.cs
Manual Testing Required
Cross-platform card rendering (Requirements 13.1–13.4)
Mobile readability and touch targets (Requirement 2.3)
Bot installation flow via Teams admin center (Requirements 8.2, 8.3)
Quick Approve conversational flow end-to-end (Requirement 6)
Proactive messaging delivery timing (Requirement 1.1 — within 2 minutes)