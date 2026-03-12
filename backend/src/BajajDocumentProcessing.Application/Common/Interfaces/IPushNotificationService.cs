using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for sending push notifications to users across all registered devices and platforms
/// </summary>
public interface IPushNotificationService
{
    /// <summary>
    /// Sends a push notification to all active devices for a user, respecting notification preferences
    /// </summary>
    /// <param name="userId">The target user's identifier</param>
    /// <param name="payload">The notification payload containing title, body, and metadata</param>
    /// <param name="cancellationToken">Cancellation token</param>
    Task SendAsync(Guid userId, PushNotificationPayload payload, CancellationToken cancellationToken);

    /// <summary>
    /// Sends a push notification to a specific device, formatting the payload per platform
    /// </summary>
    /// <param name="deviceToken">The target device token entity</param>
    /// <param name="payload">The notification payload</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Result indicating success or failure with error details</returns>
    Task<NotificationResult> SendToDeviceAsync(DeviceToken deviceToken, PushNotificationPayload payload, CancellationToken cancellationToken);

    /// <summary>
    /// Sends a push notification to multiple devices efficiently, batching by platform
    /// </summary>
    /// <param name="deviceTokens">The target device tokens</param>
    /// <param name="payload">The notification payload</param>
    /// <param name="cancellationToken">Cancellation token</param>
    Task SendBatchAsync(IEnumerable<DeviceToken> deviceTokens, PushNotificationPayload payload, CancellationToken cancellationToken);
}
