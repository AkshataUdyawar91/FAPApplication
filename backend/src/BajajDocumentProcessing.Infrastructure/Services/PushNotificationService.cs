using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Orchestrates push notification delivery across platforms (APNs for iOS, FCM for Android/Web).
/// Checks user preferences, formats payloads per platform, handles invalid tokens, and logs all attempts.
/// </summary>
public class PushNotificationService : IPushNotificationService
{
    private const int ApnsTitleMaxLength = 65;
    private const int ApnsBodyMaxLength = 240;
    private const int FcmTitleMaxLength = 200;
    private const int FcmBodyMaxLength = 4000;
    private const string PushChannel = "Push";

    private readonly IDeviceTokenService _deviceTokenService;
    private readonly INotificationPreferenceService _notificationPreferenceService;
    private readonly IApnsService _apnsService;
    private readonly IFcmService _fcmService;
    private readonly IApplicationDbContext _dbContext;
    private readonly ICorrelationIdService _correlationIdService;
    private readonly ILogger<PushNotificationService> _logger;

    public PushNotificationService(
        IDeviceTokenService deviceTokenService,
        INotificationPreferenceService notificationPreferenceService,
        IApnsService apnsService,
        IFcmService fcmService,
        IApplicationDbContext dbContext,
        ICorrelationIdService correlationIdService,
        ILogger<PushNotificationService> logger)
    {
        _deviceTokenService = deviceTokenService;
        _notificationPreferenceService = notificationPreferenceService;
        _apnsService = apnsService;
        _fcmService = fcmService;
        _dbContext = dbContext;
        _correlationIdService = correlationIdService;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task SendAsync(Guid userId, PushNotificationPayload payload, CancellationToken cancellationToken)
    {
        var correlationId = _correlationIdService.GetCorrelationId();

        _logger.LogInformation(
            "SendAsync started for UserId={UserId}, NotificationType={NotificationType}, CorrelationId={CorrelationId}",
            userId, payload.NotificationType, correlationId);

        // Step 1: Check if push is enabled for this user and notification type
        var isPushEnabled = await _notificationPreferenceService.IsNotificationEnabledAsync(
            userId, payload.NotificationType, PushChannel, cancellationToken);

        if (!isPushEnabled)
        {
            _logger.LogInformation(
                "Push notifications disabled for UserId={UserId}, NotificationType={NotificationType}, CorrelationId={CorrelationId}",
                userId, payload.NotificationType, correlationId);
            return;
        }

        // Step 2: Get user's active device tokens
        var deviceTokens = await _deviceTokenService.GetUserDeviceTokensAsync(userId, cancellationToken);
        var tokenList = deviceTokens.ToList();

        if (tokenList.Count == 0)
        {
            _logger.LogInformation(
                "No active devices for UserId={UserId}, skipping push delivery. CorrelationId={CorrelationId}",
                userId, correlationId);
            return;
        }

        // Step 3: Send to each device
        var successCount = 0;
        var failureCount = 0;

        foreach (var deviceToken in tokenList)
        {
            var result = await SendToDeviceAsync(deviceToken, payload, cancellationToken);
            if (result.Success)
                successCount++;
            else
                failureCount++;
        }

        _logger.LogInformation(
            "SendAsync completed for UserId={UserId}, NotificationType={NotificationType}, Devices={DeviceCount}, Success={SuccessCount}, Failed={FailureCount}, CorrelationId={CorrelationId}",
            userId, payload.NotificationType, tokenList.Count, successCount, failureCount, correlationId);
    }

    /// <inheritdoc />
    public async Task<NotificationResult> SendToDeviceAsync(
        DeviceToken deviceToken, PushNotificationPayload payload, CancellationToken cancellationToken)
    {
        var correlationId = _correlationIdService.GetCorrelationId();

        _logger.LogInformation(
            "SendToDeviceAsync started for DeviceTokenId={DeviceTokenId}, Platform={Platform}, CorrelationId={CorrelationId}",
            deviceToken.Id, deviceToken.Platform, correlationId);

        NotificationResult result;

        try
        {
            // Format payload and send via the appropriate platform service
            if (string.Equals(deviceToken.Platform, "iOS", StringComparison.OrdinalIgnoreCase))
            {
                var apnsPayload = FormatApnsPayload(payload);
                result = await _apnsService.SendAsync(deviceToken.Token, apnsPayload, cancellationToken);
            }
            else
            {
                // Android and Web both use FCM
                var fcmPayload = FormatFcmPayload(payload);
                result = await _fcmService.SendAsync(deviceToken.Token, fcmPayload, cancellationToken);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Exception sending to DeviceTokenId={DeviceTokenId}, Platform={Platform}, CorrelationId={CorrelationId}",
                deviceToken.Id, deviceToken.Platform, correlationId);

            result = NotificationResult.Failed(ex.Message, errorCode: "SEND_EXCEPTION");
        }

        // Handle invalid token: remove from active tokens
        if (result.IsInvalidToken)
        {
            _logger.LogWarning(
                "Invalid token detected for DeviceTokenId={DeviceTokenId}, removing. CorrelationId={CorrelationId}",
                deviceToken.Id, correlationId);

            await _deviceTokenService.RemoveInvalidTokenAsync(
                deviceToken.Id, $"Invalid token: {result.ErrorMessage}", cancellationToken);
        }

        // Log notification attempt to NotificationLogs table
        await LogNotificationAttemptAsync(deviceToken, payload, result, correlationId, cancellationToken);

        _logger.LogInformation(
            "SendToDeviceAsync completed for DeviceTokenId={DeviceTokenId}, Success={Success}, CorrelationId={CorrelationId}",
            deviceToken.Id, result.Success, correlationId);

        return result;
    }

    /// <inheritdoc />
    public async Task SendBatchAsync(
        IEnumerable<DeviceToken> deviceTokens, PushNotificationPayload payload, CancellationToken cancellationToken)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        var tokenList = deviceTokens.ToList();

        _logger.LogInformation(
            "SendBatchAsync started for {DeviceCount} devices, NotificationType={NotificationType}, CorrelationId={CorrelationId}",
            tokenList.Count, payload.NotificationType, correlationId);

        // Group tokens by platform
        var grouped = tokenList.GroupBy(t => t.Platform, StringComparer.OrdinalIgnoreCase);

        foreach (var group in grouped)
        {
            var platform = group.Key;
            var tokens = group.ToList();

            if (string.Equals(platform, "iOS", StringComparison.OrdinalIgnoreCase))
            {
                // APNs does not support multicast; send individually
                foreach (var token in tokens)
                {
                    var apnsPayload = FormatApnsPayload(payload);
                    NotificationResult result;

                    try
                    {
                        result = await _apnsService.SendAsync(token.Token, apnsPayload, cancellationToken);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex,
                            "Exception in batch send to APNs DeviceTokenId={DeviceTokenId}, CorrelationId={CorrelationId}",
                            token.Id, correlationId);
                        result = NotificationResult.Failed(ex.Message, errorCode: "SEND_EXCEPTION");
                    }

                    if (result.IsInvalidToken)
                    {
                        await _deviceTokenService.RemoveInvalidTokenAsync(
                            token.Id, $"Invalid token: {result.ErrorMessage}", cancellationToken);
                    }

                    await LogNotificationAttemptAsync(token, payload, result, correlationId, cancellationToken);
                }
            }
            else
            {
                // Android and Web use FCM multicast
                var fcmPayload = FormatFcmPayload(payload);
                var tokenStrings = tokens.Select(t => t.Token).ToList();

                IEnumerable<NotificationResult> results;

                try
                {
                    results = await _fcmService.SendMulticastAsync(tokenStrings, fcmPayload, cancellationToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "Exception in batch FCM multicast for Platform={Platform}, CorrelationId={CorrelationId}",
                        platform, correlationId);

                    // Create failed results for all tokens in this group
                    results = tokens.Select(_ => NotificationResult.Failed(ex.Message, errorCode: "SEND_EXCEPTION"));
                }

                // Match results to tokens and handle invalid tokens
                var resultList = results.ToList();
                for (var i = 0; i < tokens.Count && i < resultList.Count; i++)
                {
                    var result = resultList[i];

                    if (result.IsInvalidToken)
                    {
                        await _deviceTokenService.RemoveInvalidTokenAsync(
                            tokens[i].Id, $"Invalid token: {result.ErrorMessage}", cancellationToken);
                    }

                    await LogNotificationAttemptAsync(tokens[i], payload, result, correlationId, cancellationToken);
                }
            }
        }

        _logger.LogInformation(
            "SendBatchAsync completed for {DeviceCount} devices, CorrelationId={CorrelationId}",
            tokenList.Count, correlationId);
    }

    /// <summary>
    /// Formats a PushNotificationPayload into an APNs-specific payload with content truncation
    /// </summary>
    private static ApnsPayload FormatApnsPayload(PushNotificationPayload payload)
    {
        var title = Truncate(payload.Title, ApnsTitleMaxLength);
        var body = Truncate(payload.Body, ApnsBodyMaxLength);

        var customData = new Dictionary<string, string>(payload.Data)
        {
            ["deepLink"] = payload.DeepLink,
            ["notificationType"] = payload.NotificationType
        };

        return new ApnsPayload(
            Title: title,
            Body: body,
            Sound: "default",
            Badge: 1,
            CustomData: customData
        );
    }

    /// <summary>
    /// Formats a PushNotificationPayload into an FCM-specific payload with content truncation
    /// </summary>
    private static FcmPayload FormatFcmPayload(PushNotificationPayload payload)
    {
        var title = Truncate(payload.Title, FcmTitleMaxLength);
        var body = Truncate(payload.Body, FcmBodyMaxLength);

        var data = new Dictionary<string, string>(payload.Data)
        {
            ["deepLink"] = payload.DeepLink,
            ["notificationType"] = payload.NotificationType
        };

        var androidConfig = new FcmAndroidConfig(
            Priority: "high",
            Data: data
        );

        var webpushConfig = new FcmWebpushConfig(
            Headers: new Dictionary<string, string> { ["TTL"] = "3600" },
            Data: data
        );

        return new FcmPayload(
            Title: title,
            Body: body,
            Data: data,
            AndroidConfig: androidConfig,
            WebpushConfig: webpushConfig
        );
    }

    /// <summary>
    /// Truncates a string to the specified max length, appending "..." if truncated
    /// </summary>
    private static string Truncate(string value, int maxLength)
    {
        if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
            return value;

        return string.Concat(value.AsSpan(0, maxLength - 3), "...");
    }

    /// <summary>
    /// Logs a notification attempt to the NotificationLogs table
    /// </summary>
    private async Task LogNotificationAttemptAsync(
        DeviceToken deviceToken,
        PushNotificationPayload payload,
        NotificationResult result,
        string correlationId,
        CancellationToken cancellationToken)
    {
        var log = new NotificationLog
        {
            Id = Guid.NewGuid(),
            UserId = deviceToken.UserId,
            DeviceTokenId = deviceToken.Id,
            NotificationType = payload.NotificationType,
            Channel = PushChannel,
            Platform = deviceToken.Platform,
            Status = result.Success ? "Sent" : "Failed",
            ErrorMessage = result.ErrorMessage,
            SentAt = DateTime.UtcNow,
            CorrelationId = correlationId,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.NotificationLogs.Add(log);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }
}
