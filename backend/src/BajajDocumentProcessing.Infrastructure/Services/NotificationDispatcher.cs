using System.Reflection;
using System.Text;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Orchestrates notification delivery for new submissions: channel selection
/// (Teams vs. Email), card building, proactive send, retry with exponential backoff,
/// fallback to email, and audit logging of all attempts.
/// </summary>
public class NotificationDispatcher : INotificationDispatcher
{
    private const string EmailTemplateResource =
        "BajajDocumentProcessing.Infrastructure.Templates.Email.new-submission.html";

    private readonly INotificationDataService _notificationDataService;
    private readonly ITeamsCardService _teamsCardService;
    private readonly ITeamsNotificationService _teamsNotificationService;
    private readonly IEmailAgent _emailAgent;
    private readonly IApplicationDbContext _context;
    private readonly ILogger<NotificationDispatcher> _logger;
    private readonly string _emailTemplate;

    /// <summary>
    /// Maximum number of retry attempts for transient Teams errors.
    /// </summary>
    private const int MaxRetryAttempts = 3;

    /// <summary>
    /// Exponential backoff delays: 5s, 15s, 45s (multiplier 3).
    /// </summary>
    private static readonly TimeSpan[] RetryDelays =
    {
        TimeSpan.FromSeconds(5),
        TimeSpan.FromSeconds(15),
        TimeSpan.FromSeconds(45)
    };

    public NotificationDispatcher(
        INotificationDataService notificationDataService,
        ITeamsCardService teamsCardService,
        ITeamsNotificationService teamsNotificationService,
        IEmailAgent emailAgent,
        IApplicationDbContext context,
        ILogger<NotificationDispatcher> logger)
    {
        _notificationDataService = notificationDataService;
        _teamsCardService = teamsCardService;
        _teamsNotificationService = teamsNotificationService;
        _emailAgent = emailAgent;
        _context = context;
        _logger = logger;
        _emailTemplate = LoadEmbeddedTemplate(EmailTemplateResource);
    }

    /// <inheritdoc />
    public async Task DispatchNewSubmissionNotificationAsync(
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Dispatching new submission notification for package {PackageId}",
            packageId);

        // Load all ASM-role users (broadcast model until ASM assignment exists)
        var asmUsers = await _context.Users
            .Where(u => u.Role == UserRole.ASM && u.IsActive)
            .AsNoTracking()
            .ToListAsync(cancellationToken);

        if (asmUsers.Count == 0)
        {
            _logger.LogWarning(
                "No active ASM users found to notify for package {PackageId}",
                packageId);
            return;
        }

        // Load all active TeamsConversation records for lookup
        var teamsConversations = await _context.TeamsConversations
            .Where(tc => tc.IsActive)
            .ToListAsync(cancellationToken);

        // Assemble card data once (shared across all ASM users)
        SubmissionCardData cardData;
        try
        {
            cardData = await _notificationDataService.GetSubmissionCardDataAsync(
                packageId, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Failed to assemble card data for package {PackageId}. Aborting notification dispatch",
                packageId);
            return;
        }

        _logger.LogInformation(
            "Dispatching notifications to {AsmCount} ASM users for package {PackageId}",
            asmUsers.Count, packageId);

        // Dispatch to each ASM user
        foreach (var asmUser in asmUsers)
        {
            await DispatchToUserAsync(
                asmUser, teamsConversations, cardData, packageId, cancellationToken);
        }
    }

    /// <summary>
    /// Dispatches a notification to a single ASM user via Teams or email fallback.
    /// </summary>
    private async Task DispatchToUserAsync(
        User asmUser,
        List<TeamsConversation> teamsConversations,
        SubmissionCardData cardData,
        Guid packageId,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Dispatching notification to ASM user {UserId} ({Email}) for package {PackageId}",
            asmUser.Id, asmUser.Email, packageId);

        // Find active TeamsConversation for this user by UserId FK (preferred) or fallback to name/email match
        var conversation = teamsConversations.FirstOrDefault(tc =>
            tc.UserId == asmUser.Id) ??
            teamsConversations.FirstOrDefault(tc =>
                tc.TeamsUserName.Equals(asmUser.Email, StringComparison.OrdinalIgnoreCase) ||
                tc.TeamsUserName.Equals(asmUser.FullName, StringComparison.OrdinalIgnoreCase));

        if (conversation != null && conversation.IsActive)
        {
            await SendViaTeamsWithRetryAsync(
                asmUser, conversation, cardData, packageId, cancellationToken);
        }
        else
        {
            _logger.LogInformation(
                "No active Teams conversation for user {UserId}. Sending email fallback",
                asmUser.Id);

            await SendNewSubmissionEmailAsync(
                asmUser, cardData, packageId, cancellationToken);
        }
    }

    /// <summary>
    /// Sends a Teams notification with retry logic for transient errors.
    /// Falls back to email on permanent errors (403/404) or after all retries exhausted.
    /// </summary>
    private async Task SendViaTeamsWithRetryAsync(
        User asmUser,
        TeamsConversation conversation,
        SubmissionCardData cardData,
        Guid packageId,
        CancellationToken cancellationToken)
    {
        // Build the adaptive card JSON
        string cardJson;
        try
        {
            cardJson = _teamsCardService.BuildNewSubmissionCard(cardData);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Failed to build adaptive card for package {PackageId}, user {UserId}. Falling back to email",
                packageId, asmUser.Id);

            await SendNewSubmissionEmailAsync(asmUser, cardData, packageId, cancellationToken);
            return;
        }

        // Attempt proactive send with retry
        ProactiveMessageResult? lastResult = null;
        int attemptCount = 0;

        for (int attempt = 0; attempt < MaxRetryAttempts; attempt++)
        {
            attemptCount = attempt + 1;
            cancellationToken.ThrowIfCancellationRequested();

            try
            {
                lastResult = await _teamsNotificationService.SendProactiveCardToUserAsync(
                    conversation, cardJson, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Teams send attempt {Attempt}/{MaxAttempts} threw exception for user {UserId}, package {PackageId}",
                    attemptCount, MaxRetryAttempts, asmUser.Id, packageId);

                lastResult = new ProactiveMessageResult
                {
                    Success = false,
                    HttpStatusCode = 0,
                    ErrorMessage = ex.Message
                };
            }

            // Success — log and return
            if (lastResult.Success)
            {
                _logger.LogInformation(
                    "Teams notification sent successfully to user {UserId} for package {PackageId} on attempt {Attempt}. ActivityId: {ActivityId}",
                    asmUser.Id, packageId, attemptCount, lastResult.ActivityId);

                await CreateNotificationRecordAsync(
                    asmUser.Id,
                    packageId,
                    NotificationChannel.Teams,
                    NotificationDeliveryStatus.Sent,
                    retryCount: attemptCount - 1,
                    externalMessageId: lastResult.ActivityId,
                    failureReason: null,
                    cancellationToken);
                return;
            }

            // Permanent error (403/404) — deactivate conversation, fall back to email, no retry
            if (lastResult.HttpStatusCode == 403 || lastResult.HttpStatusCode == 404)
            {
                _logger.LogWarning(
                    "Teams returned {StatusCode} for user {UserId}, package {PackageId}. Deactivating conversation and falling back to email",
                    lastResult.HttpStatusCode, asmUser.Id, packageId);

                await DeactivateConversationAsync(conversation, cancellationToken);

                await CreateNotificationRecordAsync(
                    asmUser.Id,
                    packageId,
                    NotificationChannel.Teams,
                    NotificationDeliveryStatus.Failed,
                    retryCount: 0,
                    externalMessageId: null,
                    failureReason: $"Teams API returned {lastResult.HttpStatusCode}: {lastResult.ErrorMessage}",
                    cancellationToken);

                await SendNewSubmissionEmailAsync(asmUser, cardData, packageId, cancellationToken);
                return;
            }

            // Transient error (503/timeout/other) — retry with backoff
            _logger.LogWarning(
                "Teams send attempt {Attempt}/{MaxAttempts} failed for user {UserId}, package {PackageId}. Status: {StatusCode}, Error: {Error}",
                attemptCount, MaxRetryAttempts, asmUser.Id, packageId,
                lastResult.HttpStatusCode, lastResult.ErrorMessage);

            if (attempt < MaxRetryAttempts - 1)
            {
                await Task.Delay(RetryDelays[attempt], cancellationToken);
            }
        }

        // All retries exhausted — log Teams failure and fall back to email
        _logger.LogError(
            "All {MaxAttempts} Teams send attempts exhausted for user {UserId}, package {PackageId}. Falling back to email",
            MaxRetryAttempts, asmUser.Id, packageId);

        await CreateNotificationRecordAsync(
            asmUser.Id,
            packageId,
            NotificationChannel.Teams,
            NotificationDeliveryStatus.Failed,
            retryCount: MaxRetryAttempts,
            externalMessageId: null,
            failureReason: $"All {MaxRetryAttempts} retries exhausted. Last error: {lastResult?.ErrorMessage}",
            cancellationToken);

        await SendNewSubmissionEmailAsync(asmUser, cardData, packageId, cancellationToken);
    }

    /// <summary>
    /// Sends a new submission email fallback notification using the HTML template.
    /// Loads the embedded email template, replaces all ${token} placeholders with
    /// values from SubmissionCardData, and sends via IEmailAgent.
    /// </summary>
    private async Task SendNewSubmissionEmailAsync(
        User asmUser,
        SubmissionCardData cardData,
        Guid packageId,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Email fallback: sending new submission email to {Email} for package {PackageId} (FAP {FapId})",
            asmUser.Email, packageId, cardData.SubmissionNumber);

        try
        {
            // Build subject line per Req 7.2
            var subject = $"ClaimsIQ: New claim from {cardData.AgencyName} — {cardData.InvoiceAmount}";

            // Build HTML body from template
            var htmlBody = BuildEmailBody(cardData);

            var emailResult = await _emailAgent.SendHtmlEmailAsync(
                asmUser.Email, subject, htmlBody, cancellationToken);

            var deliveryStatus = emailResult.Success
                ? NotificationDeliveryStatus.Sent
                : NotificationDeliveryStatus.Failed;

            await CreateNotificationRecordAsync(
                asmUser.Id,
                packageId,
                NotificationChannel.Email,
                deliveryStatus,
                retryCount: emailResult.AttemptsCount > 0 ? emailResult.AttemptsCount - 1 : 0,
                externalMessageId: emailResult.MessageId,
                failureReason: emailResult.Success ? null : emailResult.ErrorMessage,
                cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Failed to send email fallback to {Email} for package {PackageId}",
                asmUser.Email, packageId);

            await CreateNotificationRecordAsync(
                asmUser.Id,
                packageId,
                NotificationChannel.Email,
                NotificationDeliveryStatus.Failed,
                retryCount: 0,
                externalMessageId: null,
                failureReason: ex.Message,
                cancellationToken);
        }
    }

    /// <summary>
    /// Builds the email HTML body by replacing all ${token} placeholders in the
    /// embedded email template with values from SubmissionCardData.
    /// </summary>
    private string BuildEmailBody(SubmissionCardData cardData)
    {
        // Determine recommendation color scheme (green/amber/red)
        var (bgColor, borderColor, textColor) = GetRecommendationColors(cardData.Recommendation);

        // Build top issues HTML
        var topIssuesHtml = BuildTopIssuesHtml(cardData);

        // Replace all ${token} placeholders
        var html = _emailTemplate
            .Replace("${submissionNumber}", Sanitize(cardData.SubmissionNumber))
            .Replace("${agencyName}", Sanitize(cardData.AgencyName))
            .Replace("${poNumber}", Sanitize(cardData.PoNumber))
            .Replace("${invoiceNumber}", Sanitize(cardData.InvoiceNumber))
            .Replace("${invoiceAmount}", Sanitize(cardData.InvoiceAmount))
            .Replace("${state}", Sanitize(cardData.State))
            .Replace("${submittedAtFormatted}", Sanitize(cardData.SubmittedAtFormatted))
            .Replace("${teamPhotoSummary}", Sanitize(cardData.TeamPhotoSummary))
            .Replace("${inquirySummary}", Sanitize(cardData.InquirySummary))
            .Replace("${recommendation}", Sanitize(cardData.Recommendation))
            .Replace("${recommendationEmoji}", cardData.RecommendationEmoji)
            .Replace("${confidenceScoreFormatted}", Sanitize(cardData.ConfidenceScoreFormatted))
            .Replace("${checksSummary}", Sanitize(cardData.ChecksSummary))
            .Replace("${recommendationBgColor}", bgColor)
            .Replace("${recommendationBorderColor}", borderColor)
            .Replace("${recommendationTextColor}", textColor)
            .Replace("${topIssuesHtml}", topIssuesHtml)
            .Replace("${portalUrl}", Sanitize(cardData.PortalUrl));

        return html;
    }

    /// <summary>
    /// Returns inline CSS colors (background, border, text) based on recommendation type.
    /// Green for Approve, amber for Review, red for Reject.
    /// </summary>
    private static (string BgColor, string BorderColor, string TextColor) GetRecommendationColors(string recommendation)
    {
        return recommendation?.ToLowerInvariant() switch
        {
            "approve" => ("#e6f4ea", "#34a853", "#1e7e34"),
            "review"  => ("#fff8e1", "#fbbc04", "#b06d00"),
            "reject"  => ("#fce8e6", "#ea4335", "#c5221f"),
            _         => ("#f0f0f0", "#888888", "#333333")
        };
    }

    /// <summary>
    /// Builds HTML for the top validation issues list. Returns empty string if no issues.
    /// </summary>
    private static string BuildTopIssuesHtml(SubmissionCardData cardData)
    {
        if (cardData.AllChecksPassed)
        {
            return "<p style=\"margin:0;font-size:13px;color:#34a853;\">&#x2705; All checks passed.</p>";
        }

        if (cardData.TopIssues == null || cardData.TopIssues.Count == 0)
        {
            return string.Empty;
        }

        var sb = new StringBuilder();
        sb.Append("<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"border-collapse:collapse;\">");

        foreach (var issue in cardData.TopIssues)
        {
            var icon = issue.Severity == "Fail" ? "&#x274C;" : "&#x26A0;&#xFE0F;";
            var color = issue.Severity == "Fail" ? "#ea4335" : "#fbbc04";
            sb.Append($"<tr><td style=\"padding:4px 0;font-size:13px;color:{color};\">{icon} <strong>{Sanitize(issue.Severity)}</strong>: {Sanitize(issue.Description)}</td></tr>");
        }

        if (cardData.RemainingIssueCount > 0)
        {
            sb.Append($"<tr><td style=\"padding:4px 0;font-size:12px;color:#888;\">... and {cardData.RemainingIssueCount} more issue{(cardData.RemainingIssueCount > 1 ? "s" : "")}</td></tr>");
        }

        sb.Append("</table>");
        return sb.ToString();
    }

    /// <summary>
    /// Sanitizes a string for safe inclusion in HTML by encoding special characters.
    /// </summary>
    private static string Sanitize(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return "N/A";

        return System.Net.WebUtility.HtmlEncode(value);
    }

    /// <summary>
    /// Loads an HTML template from an embedded resource in the Infrastructure assembly.
    /// </summary>
    private string LoadEmbeddedTemplate(string resourceName)
    {
        var assembly = Assembly.GetExecutingAssembly();
        using var stream = assembly.GetManifestResourceStream(resourceName);

        if (stream is null)
        {
            _logger.LogCritical(
                "Embedded email template not found: {ResourceName}. Available resources: {Resources}",
                resourceName,
                string.Join(", ", assembly.GetManifestResourceNames()));
            throw new FileNotFoundException($"Embedded email template not found: {resourceName}");
        }

        using var reader = new StreamReader(stream);
        var html = reader.ReadToEnd();

        _logger.LogInformation("Loaded embedded email template: {ResourceName}", resourceName);
        return html;
    }

    /// <summary>
    /// Deactivates a stale Teams conversation reference after a 403/404 error.
    /// </summary>
    private async Task DeactivateConversationAsync(
        TeamsConversation conversation,
        CancellationToken cancellationToken)
    {
        try
        {
            // Re-attach the entity for tracking since it was loaded with AsNoTracking in the caller.
            // TeamsConversations were loaded with tracking (no AsNoTracking) so we can update directly.
            conversation.IsActive = false;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Deactivated Teams conversation {ConversationId} for user {TeamsUserId}",
                conversation.ConversationId, conversation.TeamsUserId);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Failed to deactivate Teams conversation {ConversationId}",
                conversation.ConversationId);
        }
    }

    /// <summary>
    /// Creates a Notification entity record for audit trail.
    /// </summary>
    private async Task CreateNotificationRecordAsync(
        Guid userId,
        Guid packageId,
        NotificationChannel channel,
        NotificationDeliveryStatus deliveryStatus,
        int retryCount,
        string? externalMessageId,
        string? failureReason,
        CancellationToken cancellationToken)
    {
        try
        {
            var notification = new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = NotificationType.ReadyForReview,
                Title = "New Claim Ready for Review",
                Message = $"A new claim submission is ready for your review.",
                IsRead = false,
                RelatedEntityId = packageId,
                Channel = channel,
                DeliveryStatus = deliveryStatus,
                RetryCount = retryCount,
                SentAt = deliveryStatus == NotificationDeliveryStatus.Sent ? DateTime.UtcNow : null,
                ExternalMessageId = externalMessageId,
                FailureReason = failureReason
            };

            _context.Notifications.Add(notification);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Created notification record {NotificationId}: Channel={Channel}, Status={Status}, RetryCount={RetryCount} for user {UserId}, package {PackageId}",
                notification.Id, channel, deliveryStatus, retryCount, userId, packageId);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Failed to create notification record for user {UserId}, package {PackageId}, channel {Channel}",
                userId, packageId, channel);
        }
    }
}
