using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
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
    /// Handles text messages sent to the bot.
    /// Detects pending-related keywords and returns a summary of pending submissions.
    /// Otherwise returns help text with portal link.
    /// </summary>
    protected override async Task OnMessageActivityAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        // Handle Action.Submit from adaptive cards (emulator + web chat send these as message activities)
        if (turnContext.Activity.Value != null)
        {
            await HandleCardSubmitActionAsync(turnContext, cancellationToken);
            return;
        }

        var text = turnContext.Activity.Text?.Trim().ToLowerInvariant() ?? "";

        _logger.LogInformation("Received message from Teams user: {Text}", text);

        // Check if the message is asking about pending submissions
        if (IsPendingSubmissionsQuery(text))
        {
            await HandlePendingSubmissionsQueryAsync(turnContext, cancellationToken);
            return;
        }

        // For greetings (hi, hello, hey, start), show welcome + pending submissions
        if (IsGreeting(text))
        {
            var welcomeMessage = "👋 Hi! I'm the ClaimsIQ Review Bot.\n\n" +
                                 "I'll send you adaptive cards when FAPs are ready for review. " +
                                 "You can **Approve** or **Reject** directly from the card.\n\n" +
                                 $"[Open Portal]({_portalBaseUrl})";

            await turnContext.SendActivityAsync(MessageFactory.Text(welcomeMessage), cancellationToken);

            // Also show pending submissions automatically
            await HandlePendingSubmissionsQueryAsync(turnContext, cancellationToken);
            return;
        }

        var helpMessage = "I can help you with pending FAP requests.\n\n" +
                          "Try typing **pending** to see requests awaiting your review.\n\n" +
                          $"[Open Portal]({_portalBaseUrl})";

        await turnContext.SendActivityAsync(MessageFactory.Text(helpMessage), cancellationToken);
    }

    /// <summary>
    /// Handles Action.Submit from adaptive cards sent as message activities.
    /// This is the path used by Bot Framework Emulator and Web Chat (not Teams).
    /// Teams uses Action.Execute which routes to OnAdaptiveCardInvokeAsync instead.
    /// Reuses the same logic but sends responses as message attachments.
    /// </summary>
    private async Task HandleCardSubmitActionAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        try
        {
            var data = JObject.FromObject(turnContext.Activity.Value);
            var action = data["action"]?.ToString();
            var fapIdStr = data["fapId"]?.ToString() ?? data["submissionId"]?.ToString();
            var cardVersion = data["cardVersion"]?.ToString();

            _logger.LogInformation(
                "Card submit action received via message: {Action} for FAP {FapId}",
                action, fapIdStr);

            if (cardVersion != "1.0")
            {
                await SendTextReplyAsync(turnContext,
                    "This card is outdated. Please check the portal for the latest status.", cancellationToken);
                return;
            }

            // Handle login action (no fapId required)
            if (action == "bot_login")
            {
                await HandleBotLoginAsync(turnContext, data, cancellationToken);
                return;
            }

            if (string.IsNullOrEmpty(action) || string.IsNullOrEmpty(fapIdStr) || !Guid.TryParse(fapIdStr, out var fapId))
            {
                await SendTextReplyAsync(turnContext, "Missing action or FAP ID.", cancellationToken);
                return;
            }

            AdaptiveCardInvokeResponse response;

            // Route to the same handlers used by OnAdaptiveCardInvokeAsync
            if (action is "quick_approve" or "confirm_approve" or "submit_approval" or "cancel_approve")
            {
                response = await ProcessQuickApproveFlowAsync(turnContext, fapId, action, data, cancellationToken);
            }
            else if (action is "review_details" or "approve_from_review" or "reject_from_review" or "submit_rejection_from_review")
            {
                response = await ProcessReviewDetailsFlowAsync(turnContext, fapId, action, data, cancellationToken);
            }
            else if (action is "approve" or "reject")
            {
                var rejectionReason = data["rejectionReason"]?.ToString();
                if (action == "reject" && (string.IsNullOrWhiteSpace(rejectionReason) || rejectionReason.Length < 10))
                {
                    await SendTextReplyAsync(turnContext,
                        "❌ Rejection reason must be at least 10 characters.", cancellationToken);
                    return;
                }
                response = await ProcessCardActionAsync(turnContext, fapId, action, rejectionReason, cancellationToken);
            }
            else if (action == "view_full_card")
            {
                await HandleViewFullCardAsync(turnContext, fapId, cancellationToken);
                return;
            }
            else
            {
                await SendTextReplyAsync(turnContext, $"Unknown action: {action}", cancellationToken);
                return;
            }

            // Convert AdaptiveCardInvokeResponse to a message attachment
            await SendInvokeResponseAsMessageAsync(turnContext, response, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling card submit action via message activity: {Message}", ex.Message);
            try
            {
                await SendTextReplyAsync(turnContext,
                    "Something went wrong. Please try again or check the portal.", cancellationToken);
            }
            catch (Exception sendEx)
            {
                _logger.LogError(sendEx, "Failed to send error message back to user");
            }
        }
    }

    /// <summary>
    /// Handles the "View Full Card" action from the pending submissions summary.
    /// Loads the full submission data and sends the rich notification card with all action buttons.
    /// </summary>
    private async Task HandleViewFullCardAsync(
        ITurnContext turnContext,
        Guid fapId,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("HandleViewFullCardAsync START for FAP {FapId}", fapId);

            using var scope = _scopeFactory.CreateScope();
            var notificationDataService = scope.ServiceProvider.GetRequiredService<INotificationDataService>();
            var teamsCardService = scope.ServiceProvider.GetRequiredService<ITeamsCardService>();

            _logger.LogInformation("HandleViewFullCardAsync: loading card data");
            var cardData = await notificationDataService.GetSubmissionCardDataAsync(fapId, cancellationToken);

            _logger.LogInformation("HandleViewFullCardAsync: building card JSON");
            var cardJson = teamsCardService.BuildNewSubmissionCard(cardData);
            _logger.LogInformation("HandleViewFullCardAsync: card JSON built, length={Length}", cardJson.Length);

            var cardObject = Newtonsoft.Json.JsonConvert.DeserializeObject(cardJson);
            var attachment = new Attachment
            {
                ContentType = "application/vnd.microsoft.card.adaptive",
                Content = cardObject
            };

            _logger.LogInformation("HandleViewFullCardAsync: sending card attachment");
            await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), cancellationToken);
            _logger.LogInformation("HandleViewFullCardAsync: card sent successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HandleViewFullCardAsync FAILED for FAP {FapId}: {Message}", fapId, ex.Message);
            throw;
        }
    }

    /// <summary>
    /// Converts an AdaptiveCardInvokeResponse (used by Teams invoke path) into a
    /// message activity with an adaptive card attachment (used by emulator/web chat).
    /// </summary>
    private static async Task SendInvokeResponseAsMessageAsync(
        ITurnContext turnContext,
        AdaptiveCardInvokeResponse response,
        CancellationToken cancellationToken)
    {
        if (response.Value != null && response.Type == "application/vnd.microsoft.card.adaptive")
        {
            // All cards are now built as JObject with schema 1.3 — pass through directly.
            var attachment = new Attachment
            {
                ContentType = "application/vnd.microsoft.card.adaptive",
                Content = response.Value
            };
            await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), cancellationToken);
        }
        else
        {
            // Fallback: extract text from the card body if possible
            var cardObj = response.Value as JObject;
            var bodyText = cardObj?["body"]?[0]?["text"]?.ToString();
            await turnContext.SendActivityAsync(
                MessageFactory.Text(bodyText ?? "Action completed."), cancellationToken);
        }
    }

    /// <summary>
    /// Sends a simple text reply.
    /// </summary>
    private static async Task SendTextReplyAsync(
        ITurnContext turnContext,
        string message,
        CancellationToken cancellationToken)
    {
        await turnContext.SendActivityAsync(MessageFactory.Text(message), cancellationToken);
    }

    /// <summary>
    /// Detects whether the user message is asking about pending submissions.
    /// Uses simple keyword matching on the lowercased message text.
    /// </summary>
    private static bool IsPendingSubmissionsQuery(string text)
    {
        return text.Contains("pending")
            || text.Contains("show my pending")
            || text.Contains("what's pending")
            || text.Contains("whats pending");
    }

    /// <summary>
    /// Detects whether the user message is a greeting (hi, hello, hey, start, etc.).
    /// </summary>
    private static bool IsGreeting(string text)
    {
        return text is "hi" or "hello" or "hey" or "start" or "help"
            || text.StartsWith("hi ")
            || text.StartsWith("hello ")
            || text.StartsWith("hey ");
    }

    /// <summary>
    /// Queries DocumentPackages in PendingASM state and returns a summary Adaptive Card.
    /// Each submission in the list has a "View" button that triggers the review_details flow.
    /// Limited to 10 most recent submissions to keep the card manageable.
    /// </summary>
    private async Task HandlePendingSubmissionsQueryAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

            // Resolve the Teams user to a system user for role-based filtering
            var teamsUserId = turnContext.Activity.From?.AadObjectId
                              ?? turnContext.Activity.From?.Id
                              ?? string.Empty;
            var systemUser = await ResolveSystemUserAsync(context, teamsUserId, cancellationToken, turnContext);

            if (systemUser == null)
            {
                _logger.LogWarning("Could not resolve Teams user {TeamsUserId} to a system user", teamsUserId);
                // Show login card so the user can link their ClaimsIQ account
                await SendLoginCardAsync(turnContext, cancellationToken);
                return;
            }

            _logger.LogInformation(
                "Resolved Teams user to {UserId} ({UserName}), Role: {Role}",
                systemUser.Id, systemUser.FullName, systemUser.Role);

            // Determine which state to filter and how to scope by user
            IQueryable<Domain.Entities.DocumentPackage> query;

            if (systemUser.Role == UserRole.RA)
            {
                // RA users see PendingRA submissions for their assigned states
                var raStates = await context.StateMappings
                    .Where(sm => sm.RAUserId == systemUser.Id && sm.IsActive)
                    .Select(sm => sm.State)
                    .ToListAsync(cancellationToken);

                query = context.DocumentPackages
                    .Where(p => p.State == PackageState.PendingRA)
                    .Where(p => !p.IsDeleted)
                    .Where(p => p.AssignedRAUserId == systemUser.Id
                                || (p.ActivityState != null && raStates.Contains(p.ActivityState)));
            }
            else
            {
                // ASM/Circle Head users see PendingASM submissions for their assigned states
                var asmStates = await context.StateMappings
                    .Where(sm => sm.CircleHeadUserId == systemUser.Id && sm.IsActive)
                    .Select(sm => sm.State)
                    .ToListAsync(cancellationToken);

                query = context.DocumentPackages
                    .Where(p => p.State == PackageState.PendingCH)
                    .Where(p => !p.IsDeleted)
                    .Where(p => p.AssignedCircleHeadUserId == systemUser.Id
                                || (p.ActivityState != null && asmStates.Contains(p.ActivityState)));
            }

            var pendingPackages = await query
                .Include(p => p.Agency)
                .Include(p => p.Invoices)
                .Include(p => p.Teams.Where(t => !t.IsDeleted))
                    .ThenInclude(t => t.Invoices)
                .Include(p => p.ConfidenceScore)
                .Include(p => p.PO)
                .OrderByDescending(p => p.CreatedAt)
                .Take(10)
                .AsSplitQuery()
                .AsNoTracking()
                .ToListAsync(cancellationToken);

            if (pendingPackages.Count == 0)
            {
                await turnContext.SendActivityAsync(
                    MessageFactory.Text("No pending requests assigned to you at this time."),
                    cancellationToken);
                return;
            }

            var card = BuildPendingSubmissionsSummaryCard(pendingPackages);

            var attachment = new Attachment
            {
                ContentType = "application/vnd.microsoft.card.adaptive",
                Content = card
            };

            var activity = MessageFactory.Attachment(attachment);
            await turnContext.SendActivityAsync(activity, cancellationToken);

            _logger.LogInformation(
                "Returned {Count} pending submission(s) to Teams user {UserId}",
                pendingPackages.Count, systemUser?.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error querying pending submissions");
            await turnContext.SendActivityAsync(
                MessageFactory.Text(
                    "Something went wrong while fetching pending requests. " +
                    $"Please try again or check the portal. [Open Portal]({_portalBaseUrl})"),
                cancellationToken);
        }
    }

    /// <summary>
    /// Builds an Adaptive Card listing pending submissions with key facts and a "View" button per item.
    /// The "View" button triggers the existing review_details action handler.
    /// </summary>
    private JObject BuildPendingSubmissionsSummaryCard(
        List<DocumentPackage> packages)
    {
        var body = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"📋 Pending Requests ({packages.Count})",
                ["size"] = "Medium",
                ["weight"] = "Bolder",
                ["wrap"] = true
            }
        };

        foreach (var package in packages)
        {
            var shortId = package.Id.ToString()[..8].ToUpper();
            var agencyName = package.Agency?.SupplierName ?? "Unknown Agency";
            var poNumber = package.PO?.PONumber ?? "N/A";
            var amount = package.Teams?.SelectMany(t => t.Invoices).Sum(i => i.TotalAmount ?? 0m) ?? 0m;
            var formattedAmount = $"₹{amount:N0}";
            var confidence = package.ConfidenceScore?.OverallConfidence ?? 0;
            var confidenceFormatted = $"{confidence:F0}/100";

            // Container per submission for visual grouping
            body.Add(new JObject
            {
                ["type"] = "Container",
                ["separator"] = true,
                ["spacing"] = "Medium",
                ["items"] = new JArray
                {
                    new JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = $"**FAP-{shortId}** — {agencyName}",
                        ["wrap"] = true,
                        ["weight"] = "Bolder"
                    },
                    new JObject
                    {
                        ["type"] = "FactSet",
                        ["facts"] = new JArray
                        {
                            new JObject { ["title"] = "PO Number", ["value"] = poNumber },
                            new JObject { ["title"] = "Invoice Amount", ["value"] = formattedAmount },
                            new JObject { ["title"] = "Confidence", ["value"] = confidenceFormatted }
                        }
                    }
                }
            });

            // "View" button per submission
            body.Add(new JObject
            {
                ["type"] = "ActionSet",
                ["actions"] = new JArray
                {
                    new JObject
                    {
                        ["type"] = "Action.Submit",
                        ["title"] = $"View FAP-{shortId}",
                        ["data"] = new JObject
                        {
                            ["action"] = "view_full_card",
                            ["submissionId"] = package.Id.ToString(),
                            ["fapId"] = package.Id.ToString(),
                            ["cardVersion"] = "1.0"
                        }
                    }
                }
            });
        }

        var card = BuildCardWithWhiteBackground(body);

        return card;
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

            // Attempt to match Teams user to system User by email/UPN or name
            Guid? matchedUserId = null;
            var teamsUserName = member.Name ?? "";
            
            // Try matching by AadObjectId first (most reliable), then by name/email
            var aadObjectId = member.AadObjectId;
            if (!string.IsNullOrEmpty(aadObjectId))
            {
                // Future: match by AAD object ID if stored on User entity
            }
            
            // Match by email-like name or display name against system users
            if (!string.IsNullOrEmpty(teamsUserName))
            {
                var matchedUser = await context.Users
                    .FirstOrDefaultAsync(u =>
                        u.Email.ToLower() == teamsUserName.ToLower() ||
                        u.FullName.ToLower() == teamsUserName.ToLower(),
                        cancellationToken);
                matchedUserId = matchedUser?.Id;
            }

            if (existing != null)
            {
                existing.ConversationReferenceJson = referenceJson;
                existing.ServiceUrl = reference.ServiceUrl ?? "";
                existing.IsActive = true;
                existing.TeamsUserName = teamsUserName;
                existing.LastActivityAt = DateTime.UtcNow;
                existing.UpdatedAt = DateTime.UtcNow;
                if (matchedUserId != null)
                    existing.UserId = matchedUserId;
            }
            else
            {
                context.TeamsConversations.Add(new Domain.Entities.TeamsConversation
                {
                    Id = Guid.NewGuid(),
                    UserId = matchedUserId,
                    TeamsUserId = teamsUserId,
                    TeamsUserName = teamsUserName,
                    ConversationId = conversationId,
                    ServiceUrl = reference.ServiceUrl ?? "",
                    ChannelId = reference.ChannelId ?? "msteams",
                    BotId = reference.Bot?.Id ?? "",
                    BotName = reference.Bot?.Name ?? "",
                    TenantId = reference.Conversation?.TenantId,
                    ConversationReferenceJson = referenceJson,
                    IsActive = true,
                    LastActivityAt = DateTime.UtcNow,
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
            var fapIdStr = data["fapId"]?.ToString() ?? data["submissionId"]?.ToString();
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

            // Route Quick Approve conversational flow actions
            if (action is "quick_approve" or "confirm_approve" or "submit_approval" or "cancel_approve")
            {
                return await ProcessQuickApproveFlowAsync(turnContext, fapId, action, data, cancellationToken);
            }

            // Route Review Details flow actions
            if (action is "review_details" or "approve_from_review" or "reject_from_review" or "submit_rejection_from_review")
            {
                return await ProcessReviewDetailsFlowAsync(turnContext, fapId, action, data, cancellationToken);
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

    /// <summary>
    /// Handles the 4-step Quick Approve conversational flow:
    /// 1. quick_approve → confirmation card
    /// 2. confirm_approve → ask for comments
    /// 3. submit_approval → execute approval + success message
    /// 4. cancel_approve → cancellation message
    /// </summary>
    private async Task<AdaptiveCardInvokeResponse> ProcessQuickApproveFlowAsync(
        ITurnContext turnContext,
        Guid fapId,
        string action,
        JObject data,
        CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

        var shortId = fapId.ToString()[..8].ToUpper();

        try
        {
            switch (action)
            {
                case "quick_approve":
                    return await HandleQuickApproveStartAsync(context, fapId, shortId, cancellationToken);

                case "confirm_approve":
                    return HandleConfirmApproveStep(fapId, shortId);

                case "submit_approval":
                    return await HandleSubmitApprovalAsync(
                        context, turnContext, fapId, shortId, data, cancellationToken);

                case "cancel_approve":
                    return CreateAdaptiveCardResponse("Approval cancelled. No changes made.");

                default:
                    return CreateAdaptiveCardResponse("Unknown action.", 400);
            }
        }
        catch (DbUpdateConcurrencyException)
        {
            _logger.LogWarning(
                "Concurrency conflict during Quick Approve for FAP-{ShortId} — already actioned", shortId);
            return CreateAdaptiveCardResponse(
                $"FAP-{shortId} has already been actioned by another user.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error in Quick Approve flow for FAP-{ShortId}, action={Action}", shortId, action);
            return CreateAdaptiveCardResponse(
                "Something went wrong. Please try again or use the portal.");
        }
    }

    /// <summary>
    /// Step 1: Validates state is PendingASM, then posts confirmation card.
    /// </summary>
    private async Task<AdaptiveCardInvokeResponse> HandleQuickApproveStartAsync(
        IApplicationDbContext context,
        Guid fapId,
        string shortId,
        CancellationToken cancellationToken)
    {
        var package = await context.DocumentPackages
            .Include(p => p.Agency)
            .Include(p => p.Teams).ThenInclude(t => t.Invoices)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == fapId, cancellationToken);

        if (package == null)
            return CreateAdaptiveCardResponse($"FAP-{shortId} not found.");

        // Idempotency: only PendingCH or RARejected can be approved
        if (package.State != PackageState.PendingCH && package.State != PackageState.RARejected)
        {
            return CreateAdaptiveCardResponse(
                $"FAP-{shortId} has already been processed. No further action needed.");
        }

        var agencyName = package.Agency?.SupplierName ?? "Unknown Agency";
        var amount = package.Teams?.SelectMany(t => t.Invoices).Sum(i => i.TotalAmount ?? 0m) ?? 0m;
        var formattedAmount = $"₹{amount:N0}";

        // Build confirmation card with Approve Invoice and Cancel buttons
        var confirmCard = BuildQuickApproveConfirmationCard(fapId, shortId, agencyName, formattedAmount);
        return confirmCard;
    }

    /// <summary>
    /// Step 2: Ask for optional comments.
    /// </summary>
    private AdaptiveCardInvokeResponse HandleConfirmApproveStep(Guid fapId, string shortId)
    {
        return BuildCommentsCard(fapId, shortId);
    }

    /// <summary>
    /// Step 3: Execute the approval with optional comments.
    /// Replicates the logic from SubmissionsController.ASMApproveSubmission as a direct service call.
    /// </summary>
    private async Task<AdaptiveCardInvokeResponse> HandleSubmitApprovalAsync(
        IApplicationDbContext context,
        ITurnContext turnContext,
        Guid fapId,
        string shortId,
        JObject data,
        CancellationToken cancellationToken)
    {
        var comments = data["comments"]?.ToString();
        // If user clicked Skip, comments will be empty or "skip"
        if (string.IsNullOrWhiteSpace(comments) ||
            comments.Equals("skip", StringComparison.OrdinalIgnoreCase))
        {
            comments = null;
        }

        // Resolve Teams user identity to system User
        var teamsUserId = turnContext.Activity.From?.AadObjectId
                          ?? turnContext.Activity.From?.Id ?? "unknown";
        var asmName = turnContext.Activity.From?.Name ?? "Unknown ASM";
        var systemUser = await ResolveSystemUserAsync(context, teamsUserId, cancellationToken, turnContext);

        // Load the package with required navigations for the success message
        var package = await context.DocumentPackages
            .Include(p => p.Agency)
            .Include(p => p.Teams).ThenInclude(t => t.Invoices)
            .FirstOrDefaultAsync(p => p.Id == fapId, cancellationToken);

        if (package == null)
            return CreateAdaptiveCardResponse($"FAP-{shortId} not found.");

        // Idempotency check: only PendingCH or RARejected can be approved
        if (package.State != PackageState.PendingCH && package.State != PackageState.RARejected)
        {
            return CreateAdaptiveCardResponse(
                $"FAP-{shortId} has already been processed. No further action needed.");
        }

        var agencyName = package.Agency?.SupplierName ?? "Unknown Agency";
        var amount = package.Teams?.SelectMany(t => t.Invoices).Sum(i => i.TotalAmount ?? 0m) ?? 0m;
        var formattedAmount = $"₹{amount:N0}";
        var approverId = systemUser?.Id ?? Guid.Empty;

        // Execute approval: state transition + RequestApprovalHistory (same as ASMApproveSubmission)
        package.State = PackageState.PendingRA;
        package.UpdatedAt = DateTime.UtcNow;

        var approvalHistory = new RequestApprovalHistory
        {
            Id = Guid.NewGuid(),
            PackageId = package.Id,
            ApproverId = approverId,
            ApproverRole = UserRole.ASM,
            Action = ApprovalAction.Approved,
            Comments = comments ?? $"Approved via Teams Bot by {asmName}",
            ActionDate = DateTime.UtcNow,
            VersionNumber = package.VersionNumber,
            Channel = "TeamsBot",
            CreatedAt = DateTime.UtcNow
        };
        context.RequestApprovalHistories.Add(approvalHistory);

        await context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "FAP-{ShortId} approved via Quick Approve by {AsmName} (TeamsUserId={TeamsUserId})",
            shortId, asmName, teamsUserId);

        // Build success message
        var successMessage =
            $"✅ Approved! FAP-{shortId} forwarded to RA. " +
            $"{agencyName} will be notified. Payable amount: {formattedAmount}";

        return CreateAdaptiveCardResponse(successMessage);
    }

    /// <summary>
    /// Resolves a Teams user ID to a system User by looking up TeamsConversation → User.
    /// <summary>
    /// Resolves a Teams user to a system User using a 3-tier strategy:
    ///   Tier 1: Teams SSO — silently acquire Azure AD token, extract email/oid, match to User
    ///   Tier 2: AadObjectId pre-link — match Activity.From.AadObjectId to Users.AadObjectId
    ///   Tier 3: TeamsConversation FK — existing linked conversation record
    /// Falls back to name matching as a last resort before returning null.
    /// </summary>
    private async Task<User?> ResolveSystemUserAsync(
        IApplicationDbContext context,
        string teamsUserId,
        CancellationToken cancellationToken,
        ITurnContext? turnContext = null)
    {
        _logger.LogInformation(
            "Auth resolution started for Teams user {TeamsUserId}",
            teamsUserId);

        // --- Tier 1: Teams SSO (silent token acquisition) ---
        _logger.LogInformation("Tier 1 (SSO): Attempting silent token acquisition for {TeamsUserId}", teamsUserId);
        if (turnContext != null)
        {
            var ssoUser = await TryResolveBySsoAsync(context, turnContext, cancellationToken);
            if (ssoUser != null)
            {
                _logger.LogInformation(
                    "Tier 1 (SSO): ✓ Resolved Teams user {TeamsUserId} to {Email}",
                    teamsUserId, ssoUser.Email);
                return ssoUser;
            }
            _logger.LogInformation("Tier 1 (SSO): ✗ Failed — no token or no matching user. Falling through to Tier 2");
        }
        else
        {
            _logger.LogInformation("Tier 1 (SSO): ✗ Skipped — turnContext is null. Falling through to Tier 2");
        }

        // --- Tier 2: AadObjectId pre-link (admin script populated Users.AadObjectId) ---
        var aadObjectId = turnContext?.Activity?.From?.AadObjectId;
        _logger.LogInformation(
            "Tier 2 (Pre-link): Attempting AadObjectId lookup for {TeamsUserId}, AadObjectId: {AadObjectId}",
            teamsUserId, aadObjectId ?? "(null)");

        if (!string.IsNullOrEmpty(aadObjectId))
        {
            var prelinkedUser = await context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    u => u.AadObjectId == aadObjectId && u.IsActive && !u.IsDeleted,
                    cancellationToken);

            if (prelinkedUser != null)
            {
                _logger.LogInformation(
                    "Tier 2 (Pre-link): ✓ Resolved Teams user {TeamsUserId} via AadObjectId {AadObjectId} to {Email}",
                    teamsUserId, aadObjectId, prelinkedUser.Email);

                await EnsureTeamsConversationLinkedAsync(
                    context, teamsUserId, prelinkedUser.Id, turnContext, cancellationToken);

                return prelinkedUser;
            }
            _logger.LogInformation(
                "Tier 2 (Pre-link): ✗ No user found with AadObjectId {AadObjectId}. Falling through to Tier 3",
                aadObjectId);
        }
        else
        {
            _logger.LogInformation("Tier 2 (Pre-link): ✗ Skipped — AadObjectId not available. Falling through to Tier 3");
        }

        // --- Tier 3: TeamsConversation FK (existing linked record from login card or prior SSO) ---
        _logger.LogInformation("Tier 3 (Conversation FK): Looking up TeamsConversation for {TeamsUserId}", teamsUserId);
        var teamsConversation = await context.TeamsConversations
            .AsNoTracking()
            .FirstOrDefaultAsync(
                tc => tc.TeamsUserId == teamsUserId && tc.IsActive,
                cancellationToken);

        if (teamsConversation?.UserId != null)
        {
            var linkedUser = await context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    u => u.Id == teamsConversation.UserId.Value && u.IsActive && !u.IsDeleted,
                    cancellationToken);
            if (linkedUser != null)
            {
                _logger.LogInformation(
                    "Tier 3 (Conversation FK): ✓ Resolved Teams user {TeamsUserId} to {Email}",
                    teamsUserId, linkedUser.Email);
                return linkedUser;
            }
            _logger.LogInformation(
                "Tier 3 (Conversation FK): ✗ Conversation found but linked user {UserId} is inactive/deleted. Falling through to fallback",
                teamsConversation.UserId.Value);
        }
        else
        {
            _logger.LogInformation(
                "Tier 3 (Conversation FK): ✗ No linked conversation found for {TeamsUserId}. Falling through to fallback",
                teamsUserId);
        }

        // --- Fallback: Match by Teams display name against system user FullName or Email ---
        var teamsUserName = teamsConversation?.TeamsUserName ?? "";
        _logger.LogInformation(
            "Fallback (Name match): Attempting display name match for {TeamsUserId}, name: {Name}",
            teamsUserId, teamsUserName);

        if (!string.IsNullOrEmpty(teamsUserName))
        {
            var user = await context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    u => u.IsActive && !u.IsDeleted &&
                         (u.FullName.ToLower() == teamsUserName.ToLower() ||
                          u.Email.ToLower() == teamsUserName.ToLower()),
                    cancellationToken);

            if (user != null)
            {
                _logger.LogInformation(
                    "Fallback (Name match): ✓ Resolved Teams user {TeamsUserId} by name/email match to {Email}",
                    teamsUserId, user.Email);
                return user;
            }
            _logger.LogInformation(
                "Fallback (Name match): ✗ No user matched display name '{Name}'",
                teamsUserName);
        }

        // No match found — caller will show login card
        _logger.LogWarning(
            "All tiers exhausted for Teams user {TeamsUserId} (name: {Name}). Login card will be shown",
            teamsUserId, teamsUserName);
        return null;
    }

    /// <summary>
    /// Tier 1: Attempts silent Teams SSO token acquisition.
    /// Uses OAuthPrompt-style token exchange to get an Azure AD token without user interaction.
    /// Extracts email/oid from the token and matches to a system user.
    /// Returns null if SSO is not configured, token acquisition fails, or no user match.
    /// </summary>
    private async Task<User?> TryResolveBySsoAsync(
        IApplicationDbContext context,
        ITurnContext turnContext,
        CancellationToken cancellationToken)
    {
        try
        {
            // Attempt silent token exchange using the Teams SSO token
            // Teams sends a token in the Activity when SSO is configured in the bot manifest
            var tokenExchangeResource = turnContext.Activity?.Value as JObject;
            var ssoToken = tokenExchangeResource?["token"]?.ToString();

            // Also check for token in the channelData (Teams sends it here for SSO)
            if (string.IsNullOrEmpty(ssoToken))
            {
                var channelData = turnContext.Activity?.ChannelData as JObject;
                ssoToken = channelData?["ssoToken"]?.ToString();
            }

            if (string.IsNullOrEmpty(ssoToken))
            {
                // No SSO token available — this is normal when SSO isn't configured yet
                _logger.LogDebug("No SSO token available for Teams user");
                return null;
            }

            // Decode the JWT token to extract claims (without validation — 
            // the Bot Framework already validated it)
            var claims = DecodeJwtClaims(ssoToken);
            if (claims == null)
                return null;

            var email = claims.GetValueOrDefault("preferred_username")
                        ?? claims.GetValueOrDefault("upn")
                        ?? claims.GetValueOrDefault("email");
            var oid = claims.GetValueOrDefault("oid");

            if (string.IsNullOrEmpty(email) && string.IsNullOrEmpty(oid))
            {
                _logger.LogDebug("SSO token has no email or oid claim");
                return null;
            }

            // Try matching by OID first (most reliable), then by email
            User? user = null;
            if (!string.IsNullOrEmpty(oid))
            {
                user = await context.Users
                    .AsNoTracking()
                    .FirstOrDefaultAsync(
                        u => u.AadObjectId == oid && u.IsActive && !u.IsDeleted,
                        cancellationToken);
            }

            if (user == null && !string.IsNullOrEmpty(email))
            {
                user = await context.Users
                    .AsNoTracking()
                    .FirstOrDefaultAsync(
                        u => u.Email.ToLower() == email.ToLower() && u.IsActive && !u.IsDeleted,
                        cancellationToken);

                // If matched by email but AadObjectId not set, populate it for future Tier 2 matches
                if (user != null && string.IsNullOrEmpty(user.AadObjectId) && !string.IsNullOrEmpty(oid))
                {
                    var trackedUser = await context.Users
                        .FirstOrDefaultAsync(u => u.Id == user.Id, cancellationToken);
                    if (trackedUser != null)
                    {
                        trackedUser.AadObjectId = oid;
                        trackedUser.UpdatedAt = DateTime.UtcNow;
                        await context.SaveChangesAsync(cancellationToken);
                        _logger.LogInformation(
                            "Auto-populated AadObjectId {Oid} for user {Email} via SSO",
                            oid, user.Email);
                    }
                }
            }

            if (user != null)
            {
                // Auto-link TeamsConversation for faster future resolution
                var teamsUserId = turnContext.Activity?.From?.AadObjectId
                                  ?? turnContext.Activity?.From?.Id
                                  ?? string.Empty;
                await EnsureTeamsConversationLinkedAsync(
                    context, teamsUserId, user.Id, turnContext, cancellationToken);
            }

            return user;
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "SSO token resolution failed — falling through to next tier");
            return null;
        }
    }

    /// <summary>
    /// Decodes JWT claims from a token without signature validation.
    /// The Bot Framework has already validated the token — we just need the claims.
    /// </summary>
    private static Dictionary<string, string>? DecodeJwtClaims(string token)
    {
        try
        {
            var parts = token.Split('.');
            if (parts.Length < 2) return null;

            var payload = parts[1];
            // Pad base64 if needed
            switch (payload.Length % 4)
            {
                case 2: payload += "=="; break;
                case 3: payload += "="; break;
            }

            var bytes = Convert.FromBase64String(
                payload.Replace('-', '+').Replace('_', '/'));
            var json = System.Text.Encoding.UTF8.GetString(bytes);

            using var doc = JsonDocument.Parse(json);
            var claims = new Dictionary<string, string>();
            foreach (var prop in doc.RootElement.EnumerateObject())
            {
                claims[prop.Name] = prop.Value.ToString();
            }
            return claims;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Ensures a TeamsConversation record exists and is linked to the given system user.
    /// Creates a new record if none exists, or updates the UserId if unlinked.
    /// </summary>
    private async Task EnsureTeamsConversationLinkedAsync(
        IApplicationDbContext context,
        string teamsUserId,
        Guid systemUserId,
        ITurnContext? turnContext,
        CancellationToken cancellationToken)
    {
        try
        {
            var existing = await context.TeamsConversations
                .FirstOrDefaultAsync(
                    tc => tc.TeamsUserId == teamsUserId && tc.IsActive,
                    cancellationToken);

            if (existing != null)
            {
                if (existing.UserId == null || existing.UserId != systemUserId)
                {
                    existing.UserId = systemUserId;
                    existing.UpdatedAt = DateTime.UtcNow;
                    existing.LastActivityAt = DateTime.UtcNow;
                    await context.SaveChangesAsync(cancellationToken);
                    _logger.LogInformation(
                        "Auto-linked TeamsConversation {TeamsUserId} to system user {UserId}",
                        teamsUserId, systemUserId);
                }
            }
            else if (turnContext != null)
            {
                context.TeamsConversations.Add(new TeamsConversation
                {
                    Id = Guid.NewGuid(),
                    UserId = systemUserId,
                    TeamsUserId = teamsUserId,
                    TeamsUserName = turnContext.Activity?.From?.Name ?? "",
                    ConversationId = turnContext.Activity?.Conversation?.Id ?? "",
                    ServiceUrl = turnContext.Activity?.ServiceUrl ?? "",
                    ChannelId = turnContext.Activity?.ChannelId ?? "msteams",
                    BotId = turnContext.Activity?.Recipient?.Id ?? "",
                    BotName = turnContext.Activity?.Recipient?.Name ?? "",
                    TenantId = turnContext.Activity?.Conversation?.TenantId,
                    ConversationReferenceJson = "{}",
                    IsActive = true,
                    LastActivityAt = DateTime.UtcNow,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                });
                await context.SaveChangesAsync(cancellationToken);
                _logger.LogInformation(
                    "Created and linked TeamsConversation for {TeamsUserId} to system user {UserId}",
                    teamsUserId, systemUserId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to auto-link TeamsConversation for {TeamsUserId}", teamsUserId);
            // Non-fatal — user resolution still succeeded
        }
    }

    /// <summary>
    /// Sends an Adaptive Card with email/password inputs so the user can link their ClaimsIQ account.
    /// Password is masked using Input.Text with style=password.
    /// </summary>
    private async Task SendLoginCardAsync(
        ITurnContext turnContext,
        CancellationToken cancellationToken)
    {
        var card = new JObject
        {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.3",
            ["body"] = new JArray
            {
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = "🔐 Sign in to ClaimsIQ",
                    ["size"] = "Medium",
                    ["weight"] = "Bolder"
                },
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = "I couldn't match your Teams account automatically. Please enter your ClaimsIQ credentials to link your account.",
                    ["wrap"] = true,
                    ["size"] = "Small",
                    ["color"] = "Default"
                },
                new JObject
                {
                    ["type"] = "Input.Text",
                    ["id"] = "loginEmail",
                    ["label"] = "Email",
                    ["placeholder"] = "your.email@bajaj.com",
                    ["isRequired"] = true,
                    ["errorMessage"] = "Email is required",
                    ["style"] = "Email"
                },
                new JObject
                {
                    ["type"] = "Input.Text",
                    ["id"] = "loginPassword",
                    ["label"] = "Password",
                    ["placeholder"] = "••••••••",
                    ["isRequired"] = true,
                    ["errorMessage"] = "Password is required",
                    ["style"] = "Password"
                }
            },
            ["actions"] = new JArray
            {
                new JObject
                {
                    ["type"] = "Action.Submit",
                    ["title"] = "Sign In",
                    ["style"] = "positive",
                    ["data"] = new JObject
                    {
                        ["action"] = "bot_login",
                        ["cardVersion"] = "1.0"
                    }
                }
            }
        };

        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };

        await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), cancellationToken);
    }

    /// <summary>
    /// Handles the bot_login action: authenticates the user via AuthService,
    /// links the TeamsConversation to the system user, and shows pending submissions.
    /// </summary>
    private async Task HandleBotLoginAsync(
        ITurnContext<IMessageActivity> turnContext,
        JObject data,
        CancellationToken cancellationToken)
    {
        var email = data["loginEmail"]?.ToString()?.Trim();
        var password = data["loginPassword"]?.ToString();

        if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(password))
        {
            await SendTextReplyAsync(turnContext, "❌ Please enter both email and password.", cancellationToken);
            return;
        }

        try
        {
            using var scope = _scopeFactory.CreateScope();
            var authService = scope.ServiceProvider.GetRequiredService<IAuthService>();
            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

            // Authenticate against the existing auth service
            var loginResult = await authService.LoginAsync(new Application.DTOs.Auth.LoginRequest
            {
                Email = email,
                Password = password
            });

            if (loginResult == null)
            {
                _logger.LogWarning("Teams bot login failed for email {Email}", email);
                await SendTextReplyAsync(turnContext, "❌ Invalid email or password. Please try again.", cancellationToken);
                return;
            }

            // Find the system user
            var systemUser = await context.Users
                .FirstOrDefaultAsync(u => u.Email.ToLower() == email.ToLower() && u.IsActive, cancellationToken);

            if (systemUser == null)
            {
                await SendTextReplyAsync(turnContext, "❌ Account not found or inactive.", cancellationToken);
                return;
            }

            // Auto-populate AadObjectId for future Tier 2 resolution
            var aadOid = turnContext.Activity.From?.AadObjectId;
            if (!string.IsNullOrEmpty(aadOid) && string.IsNullOrEmpty(systemUser.AadObjectId))
            {
                systemUser.AadObjectId = aadOid;
                systemUser.UpdatedAt = DateTime.UtcNow;
                _logger.LogInformation(
                    "Auto-populated AadObjectId {Oid} for user {Email} via login card",
                    aadOid, systemUser.Email);
            }

            // Link the TeamsConversation to this system user
            var teamsUserId = turnContext.Activity.From?.AadObjectId
                              ?? turnContext.Activity.From?.Id
                              ?? string.Empty;
            var conversationId = turnContext.Activity.Conversation?.Id ?? "";

            var teamsConv = await context.TeamsConversations
                .FirstOrDefaultAsync(
                    tc => tc.TeamsUserId == teamsUserId && tc.IsActive,
                    cancellationToken);

            if (teamsConv != null)
            {
                teamsConv.UserId = systemUser.Id;
                teamsConv.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                // Create a new TeamsConversation record linked to this user
                context.TeamsConversations.Add(new Domain.Entities.TeamsConversation
                {
                    Id = Guid.NewGuid(),
                    UserId = systemUser.Id,
                    TeamsUserId = teamsUserId,
                    TeamsUserName = turnContext.Activity.From?.Name ?? email,
                    ConversationId = conversationId,
                    ServiceUrl = turnContext.Activity.ServiceUrl ?? "",
                    ChannelId = turnContext.Activity.ChannelId ?? "emulator",
                    BotId = turnContext.Activity.Recipient?.Id ?? "",
                    BotName = turnContext.Activity.Recipient?.Name ?? "",
                    TenantId = turnContext.Activity.Conversation?.TenantId,
                    ConversationReferenceJson = "{}",
                    IsActive = true,
                    LastActivityAt = DateTime.UtcNow,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                });
            }

            await context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Teams bot login successful: linked Teams user {TeamsUserId} to system user {Email} ({Role})",
                teamsUserId, systemUser.Email, systemUser.Role);

            await SendTextReplyAsync(turnContext,
                $"✅ Signed in as **{systemUser.FullName}** ({systemUser.Role}).\n\nFetching your pending requests...",
                cancellationToken);

            // Now show their pending submissions
            await HandlePendingSubmissionsQueryAsync(turnContext, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during Teams bot login for {Email}", email);
            await SendTextReplyAsync(turnContext,
                "Something went wrong during sign-in. Please try again.", cancellationToken);
        }
    }

    /// <summary>
    /// Builds the Step 1 confirmation card: "You're about to approve FAP-{shortId}..."
    /// with [Approve Invoice] and [Cancel] buttons.
    /// </summary>
    private AdaptiveCardInvokeResponse BuildQuickApproveConfirmationCard(
        Guid fapId, string shortId, string agencyName, string formattedAmount)
    {
        var body = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"You're about to approve FAP-{shortId} ({agencyName}, {formattedAmount}). Do you want to continue?",
                ["wrap"] = true,
                ["weight"] = "Bolder"
            }
        };
        var actions = new JArray
        {
            new JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Approve Invoice",
                ["style"] = "positive",
                ["data"] = new JObject
                {
                    ["action"] = "confirm_approve",
                    ["fapId"] = fapId.ToString(),
                    ["cardVersion"] = "1.0"
                }
            },
            new JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Cancel",
                ["data"] = new JObject
                {
                    ["action"] = "cancel_approve",
                    ["fapId"] = fapId.ToString(),
                    ["cardVersion"] = "1.0"
                }
            }
        };

        return new AdaptiveCardInvokeResponse
        {
            StatusCode = 200,
            Type = "application/vnd.microsoft.card.adaptive",
            Value = BuildCardWithWhiteBackground(body, actions)
        };
    }

    /// <summary>
    /// Builds the Step 2 comments card: "Any comments? (optional — type or tap Skip)"
    /// with a text input and [Skip] button.
    /// </summary>
    private AdaptiveCardInvokeResponse BuildCommentsCard(Guid fapId, string shortId)
    {
        var body = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "Any comments? (optional — type or tap Skip)",
                ["wrap"] = true
            },
            new JObject
            {
                ["type"] = "Input.Text",
                ["id"] = "comments",
                ["placeholder"] = "Enter comments (optional)",
                ["isMultiline"] = true,
                ["maxLength"] = 500
            }
        };
        var actions = new JArray
        {
            new JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Submit",
                ["style"] = "positive",
                ["data"] = new JObject
                {
                    ["action"] = "submit_approval",
                    ["fapId"] = fapId.ToString(),
                    ["cardVersion"] = "1.0"
                }
            },
            new JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Skip",
                ["data"] = new JObject
                {
                    ["action"] = "submit_approval",
                    ["fapId"] = fapId.ToString(),
                    ["cardVersion"] = "1.0"
                }
            }
        };

        return new AdaptiveCardInvokeResponse
        {
            StatusCode = 200,
            Type = "application/vnd.microsoft.card.adaptive",
            Value = BuildCardWithWhiteBackground(body, actions)
        };
    }

    /// <summary>
    /// Handles the Review Details flow:
    /// - review_details → show validation breakdown card (read-only if already processed)
    /// - approve_from_review → start approval flow (same as confirm_approve step)
    /// - reject_from_review → ask for rejection reason
    /// - submit_rejection_from_review → execute rejection with reason
    /// </summary>
    private async Task<AdaptiveCardInvokeResponse> ProcessReviewDetailsFlowAsync(
        ITurnContext turnContext,
        Guid fapId,
        string action,
        JObject data,
        CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var shortId = fapId.ToString()[..8].ToUpper();

        try
        {
            switch (action)
            {
                case "review_details":
                    return await HandleReviewDetailsAsync(scope, fapId, shortId, cancellationToken);

                case "approve_from_review":
                    return HandleConfirmApproveStep(fapId, shortId);

                case "reject_from_review":
                    return BuildRejectionReasonCard(fapId, shortId);

                case "submit_rejection_from_review":
                    return await HandleSubmitRejectionAsync(
                        scope, turnContext, fapId, shortId, data, cancellationToken);

                default:
                    return CreateAdaptiveCardResponse("Unknown action.", 400);
            }
        }
        catch (DbUpdateConcurrencyException)
        {
            _logger.LogWarning(
                "Concurrency conflict during Review Details flow for FAP-{ShortId} — already actioned", shortId);
            return CreateAdaptiveCardResponse(
                $"FAP-{shortId} has already been actioned by another user.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error in Review Details flow for FAP-{ShortId}, action={Action}", shortId, action);
            return CreateAdaptiveCardResponse(
                "Something went wrong. Please try again or use the portal.");
        }
    }

    /// <summary>
    /// Loads validation breakdown data and builds the review details card.
    /// If the submission is already processed, the card shows a read-only breakdown
    /// with a status banner (controlled by IsAlreadyProcessed flag on the card template).
    /// </summary>
    private async Task<AdaptiveCardInvokeResponse> HandleReviewDetailsAsync(
        IServiceScope scope,
        Guid fapId,
        string shortId,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("HandleReviewDetailsAsync START for FAP-{ShortId}", shortId);

            var notificationDataService = scope.ServiceProvider.GetRequiredService<INotificationDataService>();
            var teamsCardService = scope.ServiceProvider.GetRequiredService<ITeamsCardService>();

            _logger.LogInformation("HandleReviewDetailsAsync: calling GetValidationBreakdownAsync");
            var breakdownData = await notificationDataService.GetValidationBreakdownAsync(fapId, cancellationToken);

            _logger.LogInformation(
                "HandleReviewDetailsAsync: breakdown loaded — CheckGroups={Count}, IsProcessed={IsProcessed}",
                breakdownData.CheckGroups?.Count ?? 0, breakdownData.IsAlreadyProcessed);

            var cardJson = teamsCardService.BuildReviewDetailsCard(breakdownData);
            _logger.LogInformation("HandleReviewDetailsAsync: card JSON built, length={Length}", cardJson.Length);

            // Parse the card JSON into an adaptive card object for the invoke response
            var cardObject = Newtonsoft.Json.JsonConvert.DeserializeObject<JObject>(cardJson);

            _logger.LogInformation("HandleReviewDetailsAsync: card parsed successfully, returning response");

            return new AdaptiveCardInvokeResponse
            {
                StatusCode = 200,
                Type = "application/vnd.microsoft.card.adaptive",
                Value = cardObject
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HandleReviewDetailsAsync FAILED for FAP-{ShortId}: {Message}", shortId, ex.Message);
            throw;
        }
    }

    /// <summary>
    /// Builds a card asking for the rejection reason with a text input and Submit button.
    /// </summary>
    private AdaptiveCardInvokeResponse BuildRejectionReasonCard(Guid fapId, string shortId)
    {
        var body = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"Rejecting FAP-{shortId}. Please provide a reason (minimum 10 characters):",
                ["wrap"] = true,
                ["weight"] = "Bolder"
            },
            new JObject
            {
                ["type"] = "Input.Text",
                ["id"] = "rejectionReason",
                ["placeholder"] = "Enter rejection reason (required, min 10 characters)",
                ["isMultiline"] = true,
                ["maxLength"] = 500
            }
        };
        var actions = new JArray
        {
            new JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Submit Rejection",
                ["style"] = "destructive",
                ["data"] = new JObject
                {
                    ["action"] = "submit_rejection_from_review",
                    ["fapId"] = fapId.ToString(),
                    ["cardVersion"] = "1.0"
                }
            },
            new JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Cancel",
                ["data"] = new JObject
                {
                    ["action"] = "review_details",
                    ["fapId"] = fapId.ToString(),
                    ["cardVersion"] = "1.0"
                }
            }
        };

        return new AdaptiveCardInvokeResponse
        {
            StatusCode = 200,
            Type = "application/vnd.microsoft.card.adaptive",
            Value = BuildCardWithWhiteBackground(body, actions)
        };
    }

    /// <summary>
    /// Executes the rejection with the provided reason.
    /// Validates reason length, checks idempotency, transitions state, and creates audit trail.
    /// </summary>
    private async Task<AdaptiveCardInvokeResponse> HandleSubmitRejectionAsync(
        IServiceScope scope,
        ITurnContext turnContext,
        Guid fapId,
        string shortId,
        JObject data,
        CancellationToken cancellationToken)
    {
        var rejectionReason = data["rejectionReason"]?.ToString();

        if (string.IsNullOrWhiteSpace(rejectionReason) || rejectionReason.Length < 10)
        {
            return CreateAdaptiveCardResponse(
                "❌ Rejection reason must be at least 10 characters. Please try again.");
        }

        var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

        var teamsUserId = turnContext.Activity.From?.AadObjectId
                          ?? turnContext.Activity.From?.Id ?? "unknown";
        var asmName = turnContext.Activity.From?.Name ?? "Unknown ASM";
        var systemUser = await ResolveSystemUserAsync(context, teamsUserId, cancellationToken, turnContext);

        var package = await context.DocumentPackages
            .Include(p => p.Agency)
            .Include(p => p.Teams).ThenInclude(t => t.Invoices)
            .FirstOrDefaultAsync(p => p.Id == fapId, cancellationToken);

        if (package == null)
            return CreateAdaptiveCardResponse($"FAP-{shortId} not found.");

        // Idempotency: only PendingCH or RARejected can be rejected
        if (package.State != PackageState.PendingCH && package.State != PackageState.RARejected)
        {
            return CreateAdaptiveCardResponse(
                $"FAP-{shortId} has already been processed. No further action needed.");
        }

        var approverId = systemUser?.Id ?? Guid.Empty;

        // Execute rejection: state transition + RequestApprovalHistory
        package.State = PackageState.CHRejected;
        package.UpdatedAt = DateTime.UtcNow;

        var rejectionHistory = new RequestApprovalHistory
        {
            Id = Guid.NewGuid(),
            PackageId = package.Id,
            ApproverId = approverId,
            ApproverRole = UserRole.ASM,
            Action = ApprovalAction.Rejected,
            Comments = rejectionReason,
            ActionDate = DateTime.UtcNow,
            VersionNumber = package.VersionNumber,
            Channel = "TeamsBot",
            CreatedAt = DateTime.UtcNow
        };
        context.RequestApprovalHistories.Add(rejectionHistory);

        await context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "FAP-{ShortId} rejected via Review Details by {AsmName} (TeamsUserId={TeamsUserId}). Reason: {Reason}",
            shortId, asmName, teamsUserId, rejectionReason);

        var agencyName = package.Agency?.SupplierName ?? "Unknown Agency";
        return CreateAdaptiveCardResponse(
            $"❌ Rejected. FAP-{shortId} ({agencyName}) has been rejected. Reason: {rejectionReason}");
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
        if (package.State == PackageState.PendingRA ||
            package.State == PackageState.Approved ||
            package.State == PackageState.CHRejected ||
            package.State == PackageState.RARejected)
        {
            return CreateAdaptiveCardResponse($"This FAP has already been {package.State}. No action taken.");
        }

        // Validate state allows approval
        if (package.State != PackageState.PendingCH)
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
                package.State = PackageState.PendingRA;
                package.UpdatedAt = now;
            }
            else if (action == "reject")
            {
                package.State = PackageState.CHRejected;
                package.UpdatedAt = now;
            }

            // Record approval history via RequestApprovalHistory (replaces deprecated direct fields)
            var approvalHistory = new RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = fapId,
                ApproverId = asmUserId,
                ApproverRole = UserRole.ASM,
                Action = action == "approve" ? ApprovalAction.Approved : ApprovalAction.Rejected,
                Comments = action == "approve"
                    ? $"Approved via Teams Bot by {asmName}"
                    : rejectionReason ?? $"Rejected via Teams Bot by {asmName}",
                ActionDate = now,
                VersionNumber = package.VersionNumber,
                Channel = "TeamsBot",
                CreatedAt = now,
                CreatedBy = asmName
            };
            context.RequestApprovalHistories.Add(approvalHistory);

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
        var body = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = message,
                ["wrap"] = true
            }
        };
        var cardJson = BuildCardWithWhiteBackground(body);

        return new AdaptiveCardInvokeResponse
        {
            StatusCode = statusCode,
            Type = "application/vnd.microsoft.card.adaptive",
            Value = cardJson
        };
    }

    /// <summary>
    /// Wraps a body JArray and optional actions JArray into a complete Adaptive Card
    /// with a full-bleed white Container to override the emulator's gold background.
    /// </summary>
    private static JObject BuildCardWithWhiteBackground(JArray bodyItems, JArray? actions = null)
    {
        var card = new JObject
        {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.3",
            ["body"] = new JArray
            {
                new JObject
                {
                    ["type"] = "Container",
                    ["style"] = "default",
                    ["bleed"] = true,
                    ["items"] = bodyItems
                }
            }
        };

        if (actions != null)
        {
            card["actions"] = actions;
        }

        return card;
    }
}
