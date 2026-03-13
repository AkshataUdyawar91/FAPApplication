using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Teams;
using Microsoft.Bot.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;

namespace BajajDocumentProcessing.Infrastructure.Services.Teams;

/// <summary>
/// Teams bot service extending TeamsActivityHandler.
/// Handles messages, adaptive card actions (approve/reject), and install/uninstall events.
/// Singleton lifetime (Bot Framework requirement) — uses IServiceScopeFactory for scoped deps.
/// </summary>
public class TeamsBotService : TeamsActivityHandler
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<TeamsBotService> _logger;
    private readonly PilotTeamsConfig _pilotConfig;
    private readonly string _portalBaseUrl;

    public TeamsBotService(
        IServiceScopeFactory scopeFactory,
        ILogger<TeamsBotService> logger,
        PilotTeamsConfig pilotConfig,
        IConfiguration configuration)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _pilotConfig = pilotConfig;
        _portalBaseUrl = configuration["TeamsBot:PortalBaseUrl"] ?? "http://localhost:8080";
    }

    /// <summary>
    /// Handles text messages sent to the bot. Returns help text with portal link.
    /// </summary>
    protected override async Task OnMessageActivityAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        var text = turnContext.Activity.Text?.Trim().ToLowerInvariant() ?? "";

        _logger.LogInformation("Received message from Teams user: {Text}", text);

        var helpMessage = "👋 Hi! I'm the Bajaj Document Processing Bot.\n\n" +
                          "I'll send you adaptive cards when FAPs are ready for review. " +
                          "You can **Approve** or **Reject** directly from the card.\n\n" +
                          $"[Open Portal]({_portalBaseUrl})";

        await turnContext.SendActivityAsync(MessageFactory.Text(helpMessage), cancellationToken);
    }

    /// <summary>
    /// Handles bot installation — captures conversation reference for proactive messaging.
    /// Persists to database so references survive app restarts.
    /// </summary>
    protected override async Task OnMembersAddedAsync(
        IList<ChannelAccount> membersAdded,
        ITurnContext<IConversationUpdateActivity> turnContext,
        CancellationToken cancellationToken)
    {
        foreach (var member in membersAdded)
        {
            if (member.Id == turnContext.Activity.Recipient.Id)
                continue; // Skip the bot itself

            _logger.LogInformation(
                "Bot installed by user {UserId} in conversation {ConversationId}",
                member.Id, turnContext.Activity.Conversation.Id);

            var reference = turnContext.Activity.GetConversationReference();

            // In pilot mode, capture in-memory reference for immediate use
            if (_pilotConfig.IsPilotMode)
            {
                _pilotConfig.CaptureReference(reference);
                _logger.LogInformation("Pilot mode: captured conversation reference for proactive messaging");
            }

            // Persist to database for durability across restarts
            await PersistConversationReferenceAsync(member, reference, cancellationToken);

            await turnContext.SendActivityAsync(
                MessageFactory.Text(
                    "✅ Bot installed successfully!\n\n" +
                    "You'll receive adaptive cards here when FAPs are ready for review. " +
                    "You can approve or reject directly from the card."),
                cancellationToken);
        }
    }

    /// <summary>
    /// Handles bot uninstall — marks conversation as inactive in the database.
    /// </summary>
    protected override async Task OnMembersRemovedAsync(
        IList<ChannelAccount> membersRemoved,
        ITurnContext<IConversationUpdateActivity> turnContext,
        CancellationToken cancellationToken)
    {
        foreach (var member in membersRemoved)
        {
            if (member.Id == turnContext.Activity.Recipient.Id)
                continue; // Skip the bot itself

            _logger.LogInformation(
                "Bot uninstalled by user {UserId} from conversation {ConversationId}",
                member.Id, turnContext.Activity.Conversation.Id);

            await DeactivateConversationAsync(
                turnContext.Activity.Conversation.Id, cancellationToken);
        }
    }

    /// <summary>
    /// Persists or updates a conversation reference in the database.
    /// Uses upsert pattern: update if exists, insert if new.
    /// </summary>
    private async Task PersistConversationReferenceAsync(
        ChannelAccount member,
        ConversationReference reference,
        CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

            var conversationId = reference.Conversation?.Id ?? "";
            var teamsUserId = member.Id;

            // Upsert: find existing or create new
            var existing = await context.TeamsConversations
                .FirstOrDefaultAsync(
                    c => c.ConversationId == conversationId && c.TeamsUserId == teamsUserId,
                    cancellationToken);

            var referenceJson = Newtonsoft.Json.JsonConvert.SerializeObject(reference);

            if (existing != null)
            {
                existing.ConversationReferenceJson = referenceJson;
                existing.ServiceUrl = reference.ServiceUrl ?? "";
                existing.IsActive = true;
                existing.TeamsUserName = member.Name ?? "";
                existing.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                context.TeamsConversations.Add(new Domain.Entities.TeamsConversation
                {
                    Id = Guid.NewGuid(),
                    TeamsUserId = teamsUserId,
                    TeamsUserName = member.Name ?? "",
                    ConversationId = conversationId,
                    ServiceUrl = reference.ServiceUrl ?? "",
                    ChannelId = reference.ChannelId ?? "msteams",
                    BotId = reference.Bot?.Id ?? "",
                    BotName = reference.Bot?.Name ?? "",
                    TenantId = reference.Conversation?.TenantId,
                    ConversationReferenceJson = referenceJson,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                });
            }

            await context.SaveChangesAsync(cancellationToken);
            _logger.LogInformation(
                "Persisted conversation reference for user {UserId} in conversation {ConversationId}",
                teamsUserId, conversationId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to persist conversation reference for user {UserId}",
                member.Id);
        }
    }

    /// <summary>
    /// Marks a conversation as inactive when the bot is uninstalled.
    /// </summary>
    private async Task DeactivateConversationAsync(
        string conversationId, CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

            var conversations = await context.TeamsConversations
                .Where(c => c.ConversationId == conversationId && c.IsActive)
                .ToListAsync(cancellationToken);

            foreach (var conv in conversations)
            {
                conv.IsActive = false;
                conv.UpdatedAt = DateTime.UtcNow;
            }

            if (conversations.Count > 0)
            {
                await context.SaveChangesAsync(cancellationToken);
                _logger.LogInformation(
                    "Deactivated {Count} conversation(s) for {ConversationId}",
                    conversations.Count, conversationId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to deactivate conversation {ConversationId}", conversationId);
        }
    }

    /// <summary>
    /// Handles adaptive card submit actions (approve/reject from the card).
    /// Creates a scope to resolve scoped services (DbContext, AuditLogService).
    /// </summary>
    protected override async Task<AdaptiveCardInvokeResponse> OnAdaptiveCardInvokeAsync(
        ITurnContext<IInvokeActivity> turnContext,
        AdaptiveCardInvokeValue invokeValue,
        CancellationToken cancellationToken)
    {
        try
        {
            var data = invokeValue.Action?.Data as JObject;
            if (data == null)
            {
                return CreateAdaptiveCardResponse("Invalid card action data.", 400);
            }

            var action = data["action"]?.ToString();
            var fapIdStr = data["fapId"]?.ToString();
            var cardVersion = data["cardVersion"]?.ToString();
            var rejectionReason = data["rejectionReason"]?.ToString();

            _logger.LogInformation(
                "Card action received: {Action} for FAP {FapId}, cardVersion={CardVersion}",
                action, fapIdStr, cardVersion);

            // Validate card version
            if (cardVersion != "1.0")
            {
                return CreateAdaptiveCardResponse(
                    "This card is outdated. Please check the portal for the latest status. " +
                    $"[Open Portal]({_portalBaseUrl})");
            }

            if (string.IsNullOrEmpty(action) || string.IsNullOrEmpty(fapIdStr) || !Guid.TryParse(fapIdStr, out var fapId))
            {
                return CreateAdaptiveCardResponse("Missing action or FAP ID.", 400);
            }

            // Validate rejection reason
            if (action == "reject" && (string.IsNullOrWhiteSpace(rejectionReason) || rejectionReason.Length < 10))
            {
                return CreateAdaptiveCardResponse("❌ Rejection reason must be at least 10 characters.");
            }

            return await ProcessCardActionAsync(turnContext, fapId, action, rejectionReason, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing adaptive card action");
            return CreateAdaptiveCardResponse(
                "Action failed. Please try again or use the portal. " +
                $"[Open Portal]({_portalBaseUrl})");
        }
    }

    private async Task<AdaptiveCardInvokeResponse> ProcessCardActionAsync(
        ITurnContext turnContext,
        Guid fapId,
        string action,
        string? rejectionReason,
        CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
        var auditService = scope.ServiceProvider.GetRequiredService<IAuditLogService>();

        var package = await context.DocumentPackages
            .Include(p => p.ConfidenceScore)
            .Include(p => p.SubmittedBy)
            .FirstOrDefaultAsync(p => p.Id == fapId, cancellationToken);

        if (package == null)
        {
            return CreateAdaptiveCardResponse($"FAP not found (ID: {fapId}).");
        }

        // Check if already actioned (idempotency)
        if (package.State == PackageState.ASMApproved ||
            package.State == PackageState.PendingHQApproval ||
            package.State == PackageState.Approved ||
            package.State == PackageState.RejectedByASM ||
            package.State == PackageState.RejectedByHQ)
        {
            return CreateAdaptiveCardResponse($"This FAP has already been {package.State}. No action taken.");
        }

        // Validate state allows approval
        if (package.State != PackageState.PendingASMApproval)
        {
            return CreateAdaptiveCardResponse(
                $"This FAP is in state '{package.State}' and cannot be actioned from Teams right now.");
        }

        // Get ASM identity from Teams activity
        var asmName = turnContext.Activity.From?.Name ?? "Unknown ASM";
        var asmTeamsId = turnContext.Activity.From?.Id ?? "unknown";
        var now = DateTime.UtcNow;

        // In pilot mode, we trust the Teams user identity without DB lookup
        // Production would validate ASM owns this PO
        var asmUserId = Guid.Empty; // Pilot: no DB user lookup

        try
        {
            if (action == "approve")
            {
                package.State = PackageState.PendingHQApproval;
                package.ASMReviewedAt = now;
                package.ASMReviewNotes = $"Approved via Teams Bot by {asmName}";
                package.UpdatedAt = now;
            }
            else if (action == "reject")
            {
                package.State = PackageState.RejectedByASM;
                package.ASMReviewedAt = now;
                package.ASMReviewNotes = rejectionReason;
                package.UpdatedAt = now;
            }

            await context.SaveChangesAsync(cancellationToken);

            // Audit log
            await auditService.LogActionAsync(
                asmUserId,
                action == "approve" ? "ASM_APPROVE_VIA_TEAMS" : "ASM_REJECT_VIA_TEAMS",
                "DocumentPackage",
                fapId,
                details: $"Source: Teams Bot. ASM: {asmName} ({asmTeamsId}). Reason: {rejectionReason ?? "N/A"}",
                cancellationToken: cancellationToken);

            _logger.LogInformation(
                "FAP {FapId} {Action} by {AsmName} via Teams Bot",
                fapId, action, asmName);

            // Build confirmation card
            var fapNumber = package.Id.ToString()[..8].ToUpper();
            var confirmCard = ApprovalCardBuilder.BuildActionConfirmationCard(
                fapNumber, action, asmName, now, rejectionReason);

            return new AdaptiveCardInvokeResponse
            {
                StatusCode = 200,
                Type = "application/vnd.microsoft.card.adaptive",
                Value = confirmCard.Content
            };
        }
        catch (DbUpdateConcurrencyException)
        {
            _logger.LogWarning("Concurrency conflict on FAP {FapId} — already actioned", fapId);
            return CreateAdaptiveCardResponse("This FAP has already been actioned by another user.");
        }
    }

    private static AdaptiveCardInvokeResponse CreateAdaptiveCardResponse(string message, int statusCode = 200)
    {
        var card = new AdaptiveCards.AdaptiveCard(new AdaptiveCards.AdaptiveSchemaVersion(1, 5))
        {
            Body = new List<AdaptiveCards.AdaptiveElement>
            {
                new AdaptiveCards.AdaptiveTextBlock
                {
                    Text = message,
                    Wrap = true
                }
            }
        };

        return new AdaptiveCardInvokeResponse
        {
            StatusCode = statusCode,
            Type = "application/vnd.microsoft.card.adaptive",
            Value = card
        };
    }
}
