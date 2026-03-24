namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Represents the delivery status of a notification attempt.
/// Tracks the outcome of each notification delivery across all channels.
/// </summary>
public enum NotificationDeliveryStatus
{
    /// <summary>
    /// Notification is queued and awaiting delivery.
    /// </summary>
    Pending = 1,

    /// <summary>
    /// Notification was successfully delivered to the target channel.
    /// </summary>
    Sent = 2,

    /// <summary>
    /// Notification delivery failed after all retry attempts.
    /// </summary>
    Failed = 3,

    /// <summary>
    /// Primary channel failed; notification was delivered via fallback channel (e.g., Teams failed, email sent).
    /// </summary>
    FallbackSent = 4
}
