using BajajDocumentProcessing.Application.DTOs.Notifications;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for sending push notifications via Firebase Cloud Messaging (FCM) for Android and Web
/// </summary>
public interface IFcmService
{
    /// <summary>
    /// Sends a push notification to a single device via FCM
    /// </summary>
    /// <param name="deviceToken">The FCM registration token</param>
    /// <param name="payload">The notification payload</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Result indicating success or failure with error details</returns>
    Task<NotificationResult> SendAsync(string deviceToken, FcmPayload payload, CancellationToken cancellationToken);

    /// <summary>
    /// Sends a push notification to multiple devices via FCM (up to 500 tokens per batch)
    /// </summary>
    /// <param name="deviceTokens">The FCM registration tokens</param>
    /// <param name="payload">The notification payload</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Results indicating success or failure per token</returns>
    Task<IEnumerable<NotificationResult>> SendMulticastAsync(IEnumerable<string> deviceTokens, FcmPayload payload, CancellationToken cancellationToken);

    /// <summary>
    /// Validates FCM credentials (service account JSON, project ID) during service initialization
    /// </summary>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Result indicating whether credentials are valid</returns>
    Task<NotificationResult> ValidateCredentialsAsync(CancellationToken cancellationToken);
}
