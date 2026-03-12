using BajajDocumentProcessing.Application.DTOs.Notifications;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for sending push notifications via Apple Push Notification service (APNs)
/// </summary>
public interface IApnsService
{
    /// <summary>
    /// Sends a push notification to an iOS device via APNs
    /// </summary>
    /// <param name="deviceToken">The APNs device token</param>
    /// <param name="payload">The notification payload</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Result indicating success or failure with error details</returns>
    Task<NotificationResult> SendAsync(string deviceToken, ApnsPayload payload, CancellationToken cancellationToken);

    /// <summary>
    /// Validates APNs credentials (P8 key, team ID, key ID) during service initialization
    /// </summary>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Result indicating whether credentials are valid</returns>
    Task<NotificationResult> ValidateCredentialsAsync(CancellationToken cancellationToken);
}
