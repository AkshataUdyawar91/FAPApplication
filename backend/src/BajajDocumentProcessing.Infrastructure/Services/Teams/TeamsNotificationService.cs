using System.Collections.Concurrent;
using System.Diagnostics;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Integration.AspNet.Core;
using Microsoft.Bot.Connector;
using Microsoft.Bot.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace BajajDocumentProcessing.Infrastructure.Services.Teams;

/// <summary>
/// Sends proactive Teams notifications (approval cards, status updates).
/// Uses IServiceScopeFactory for scoped DB access since this is registered as Singleton.
/// </summary>
public class TeamsNotificationService : ITeamsNotificationService
{
    private readonly IBotFrameworkHttpAdapter _adapter;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<TeamsNotificationService> _logger;
    private readonly PilotTeamsConfig _pilotConfig;
    private readonly string _appId;
    private readonly string _portalBaseUrl;

    /// <summary>
    /// Tracks the last proactive send time per user for rate limiting (Req 9.3).
    /// Key = TeamsConversation.Id, Value = UTC timestamp of last send.
    /// </summary>
    private readonly ConcurrentDictionary<Guid, DateTime> _lastSendTimestamps = new();
    private static readonly TimeSpan RateLimitDelay = TimeSpan.FromSeconds(2);

    public TeamsNotificationService(
        IBotFrameworkHttpAdapter adapter,
        IServiceScopeFactory scopeFactory,
        ILogger<TeamsNotificationService> logger,
        PilotTeamsConfig pilotConfig,
        IConfiguration configuration)
    {
        _adapter = adapter;
        _scopeFactory = scopeFactory;
        _logger = logger;
        _pilotConfig = pilotConfig;
        _appId = configuration["MicrosoftAppId"]
                 ?? configuration["TeamsBot:MicrosoftAppId"]
                 ?? "";
        _portalBaseUrl = configuration["TeamsBot:PortalBaseUrl"] ?? "http://localhost:8080";
    }

    /// <inheritdoc />
    public bool IsAvailable => _pilotConfig.HasReference || HasPersistedConversations();

    /// <inheritdoc />
    public async Task<bool> SendApprovalCardAsync(Guid packageId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Sending Teams approval card for package {PackageId}", packageId);

        try
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

            var package = await context.DocumentPackages
                .Include(p => p.ConfidenceScore)
                .Include(p => p.Recommendation)
                .Include(p => p.SubmittedBy)
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogWarning("Package {PackageId} not found for Teams notification", packageId);
                return false;
            }

            var fapNumber = package.Id.ToString()[..8].ToUpper();
            var agencyName = package.SubmittedBy?.FullName ?? "Unknown Agency";
            var poNumber = fapNumber;
            var amount = 0m;
            var submittedDate = package.CreatedAt;
            var confidence = package.ConfidenceScore?.OverallConfidence ?? 0;
            var recType = package.Recommendation?.Type.ToString() ?? "REVIEW";
            var recSummary = package.Recommendation?.Evidence ?? "No AI recommendation available yet.";

            var card = ApprovalCardBuilder.BuildApprovalCard(
                packageId, fapNumber, agencyName, poNumber, amount,
                submittedDate, confidence, recType, recSummary, _portalBaseUrl);

            return await SendCardToAllConversationsAsync(card, context, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send Teams approval card for package {PackageId}", packageId);
            return false;
        }
    }

    /// <inheritdoc />
    public async Task<bool> SendStatusUpdateAsync(
        Guid packageId, string newState, string? details = null,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Sending Teams status update for package {PackageId}: {NewState}",
            packageId, newState);

        try
        {
            var message = $"📋 FAP {packageId.ToString()[..8].ToUpper()} status changed to **{newState}**";
            if (!string.IsNullOrEmpty(details))
                message += $"\n\n{details}";

            message += $"\n\n[View in Portal]({_portalBaseUrl}/fap/{packageId}/review)";

            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

            return await SendMessageToAllConversationsAsync(message, context, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send Teams status update for package {PackageId}", packageId);
            return false;
        }
    }

    /// <summary>
    /// Sends an adaptive card to all active conversations (pilot: in-memory reference + persisted).
    /// </summary>
    private async Task<bool> SendCardToAllConversationsAsync(
        Attachment card, IApplicationDbContext context, CancellationToken cancellationToken)
    {
        var sent = false;

        // Try pilot in-memory reference first
        if (_pilotConfig.HasReference)
        {
            var reference = _pilotConfig.GetReference();
            if (reference != null)
            {
                sent = await SendProactiveCardAsync(reference, card, cancellationToken);
            }
        }

        // Also try persisted conversation references
        var conversations = await context.TeamsConversations
            .Where(c => c.IsActive)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        foreach (var conv in conversations)
        {
            try
            {
                var reference = JsonConvert.DeserializeObject<ConversationReference>(
                    conv.ConversationReferenceJson);

                if (reference != null)
                {
                    var result = await SendProactiveCardAsync(reference, card, cancellationToken);
                    sent = sent || result;

                    // Update last message sent timestamp
                    var tracked = await context.TeamsConversations
                        .FirstOrDefaultAsync(c => c.Id == conv.Id, cancellationToken);
                    if (tracked != null)
                    {
                        tracked.LastMessageSentAt = DateTime.UtcNow;
                        await context.SaveChangesAsync(cancellationToken);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "Failed to send card to conversation {ConversationId}",
                    conv.ConversationId);
            }
        }

        if (!sent)
        {
            _logger.LogWarning("No Teams conversations available to send approval card");
        }

        return sent;
    }

    /// <summary>
    /// Sends a text message to all active conversations.
    /// </summary>
    private async Task<bool> SendMessageToAllConversationsAsync(
        string message, IApplicationDbContext context, CancellationToken cancellationToken)
    {
        var sent = false;

        if (_pilotConfig.HasReference)
        {
            var reference = _pilotConfig.GetReference();
            if (reference != null)
            {
                sent = await SendProactiveMessageAsync(reference, message, cancellationToken);
            }
        }

        var conversations = await context.TeamsConversations
            .Where(c => c.IsActive)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        foreach (var conv in conversations)
        {
            try
            {
                var reference = JsonConvert.DeserializeObject<ConversationReference>(
                    conv.ConversationReferenceJson);

                if (reference != null)
                {
                    var result = await SendProactiveMessageAsync(reference, message, cancellationToken);
                    sent = sent || result;
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "Failed to send message to conversation {ConversationId}",
                    conv.ConversationId);
            }
        }

        return sent;
    }

    /// <summary>
    /// Sends a proactive adaptive card using the Bot Framework ContinueConversationAsync.
    /// </summary>
    private async Task<bool> SendProactiveCardAsync(
        ConversationReference reference, Attachment card, CancellationToken cancellationToken)
    {
        try
        {
            await ((BotAdapter)_adapter).ContinueConversationAsync(
                _appId, reference,
                async (turnContext, ct) =>
                {
                    await turnContext.SendActivityAsync(
                        MessageFactory.Attachment(card), ct);
                },
                cancellationToken);

            _logger.LogInformation(
                "Proactive card sent to conversation {ConversationId}",
                reference.Conversation?.Id);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to send proactive card to conversation {ConversationId}",
                reference.Conversation?.Id);
            return false;
        }
    }

    /// <summary>
    /// Sends a proactive text message using the Bot Framework ContinueConversationAsync.
    /// </summary>
    private async Task<bool> SendProactiveMessageAsync(
        ConversationReference reference, string message, CancellationToken cancellationToken)
    {
        try
        {
            await ((BotAdapter)_adapter).ContinueConversationAsync(
                _appId, reference,
                async (turnContext, ct) =>
                {
                    await turnContext.SendActivityAsync(
                        MessageFactory.Text(message), ct);
                },
                cancellationToken);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to send proactive message to conversation {ConversationId}",
                reference.Conversation?.Id);
            return false;
        }
    }

    /// <inheritdoc />
    public async Task<ProactiveMessageResult> SendProactiveCardToUserAsync(
        TeamsConversation conversation,
        string cardJson,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Sending proactive card to user {TeamsUserId} via conversation {ConversationId}",
            conversation.TeamsUserId, conversation.ConversationId);

        // Step 1: Deserialize the stored conversation reference
        ConversationReference? reference;
        try
        {
            reference = JsonConvert.DeserializeObject<ConversationReference>(
                conversation.ConversationReferenceJson);

            if (reference == null)
            {
                _logger.LogWarning(
                    "Failed to deserialize ConversationReference for conversation {ConversationId}",
                    conversation.ConversationId);
                return new ProactiveMessageResult
                {
                    Success = false,
                    HttpStatusCode = 0,
                    ErrorMessage = "Invalid conversation reference JSON"
                };
            }
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex,
                "Malformed ConversationReferenceJson for conversation {ConversationId}",
                conversation.ConversationId);
            return new ProactiveMessageResult
            {
                Success = false,
                HttpStatusCode = 0,
                ErrorMessage = $"Failed to deserialize conversation reference: {ex.Message}"
            };
        }

        // Step 2: Enforce 2-second rate limit between sends to the same user (Req 9.3)
        await EnforceRateLimitAsync(conversation.Id, cancellationToken);

        // Step 3: Build the Adaptive Card attachment from the JSON string
        var cardAttachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = JsonConvert.DeserializeObject(cardJson)
        };

        // Step 4: Send via ContinueConversationAsync
        string? activityId = null;
        try
        {
            await ((BotAdapter)_adapter).ContinueConversationAsync(
                _appId, reference,
                async (turnContext, ct) =>
                {
                    var response = await turnContext.SendActivityAsync(
                        MessageFactory.Attachment(cardAttachment), ct);
                    activityId = response?.Id;
                },
                cancellationToken);

            // Record send timestamp for rate limiting
            _lastSendTimestamps[conversation.Id] = DateTime.UtcNow;

            _logger.LogInformation(
                "Proactive card sent to user {TeamsUserId}, ActivityId={ActivityId}",
                conversation.TeamsUserId, activityId);

            return new ProactiveMessageResult
            {
                Success = true,
                HttpStatusCode = 200,
                ActivityId = activityId
            };
        }
        catch (ErrorResponseException ex)
        {
            var statusCode = (int)(ex.Response?.StatusCode ?? System.Net.HttpStatusCode.InternalServerError);

            _logger.LogWarning(
                "Proactive send failed for user {TeamsUserId} with HTTP {StatusCode}: {ErrorMessage}",
                conversation.TeamsUserId, statusCode, ex.Message);

            return new ProactiveMessageResult
            {
                Success = false,
                HttpStatusCode = statusCode,
                ErrorMessage = ex.Message
            };
        }
        catch (TaskCanceledException ex) when (ex.InnerException is TimeoutException || !cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning(
                "Proactive send timed out for user {TeamsUserId}",
                conversation.TeamsUserId);

            return new ProactiveMessageResult
            {
                Success = false,
                HttpStatusCode = 408,
                ErrorMessage = "Request timed out"
            };
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            _logger.LogInformation(
                "Proactive send cancelled for user {TeamsUserId}",
                conversation.TeamsUserId);
            throw; // Let cancellation propagate
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Unexpected error sending proactive card to user {TeamsUserId}",
                conversation.TeamsUserId);

            return new ProactiveMessageResult
            {
                Success = false,
                HttpStatusCode = 500,
                ErrorMessage = ex.Message
            };
        }
    }

    /// <summary>
    /// Enforces a 2-second minimum delay between sequential sends to the same user (Req 9.3).
    /// </summary>
    private async Task EnforceRateLimitAsync(Guid conversationId, CancellationToken cancellationToken)
    {
        if (_lastSendTimestamps.TryGetValue(conversationId, out var lastSend))
        {
            var elapsed = DateTime.UtcNow - lastSend;
            if (elapsed < RateLimitDelay)
            {
                var waitTime = RateLimitDelay - elapsed;
                _logger.LogDebug(
                    "Rate limiting: waiting {WaitMs}ms before sending to conversation {ConversationId}",
                    waitTime.TotalMilliseconds, conversationId);
                await Task.Delay(waitTime, cancellationToken);
            }
        }
    }

    private bool HasPersistedConversations()
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
            return context.TeamsConversations.Any(c => c.IsActive);
        }
        catch
        {
            return false;
        }
    }
}
