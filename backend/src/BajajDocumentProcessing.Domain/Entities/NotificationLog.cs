using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a log entry for a notification delivery attempt.
/// Tracks the status, channel, platform, and error details for audit and debugging
/// </summary>
public class NotificationLog : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the user who received this notification
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// Gets or sets the device token used for push delivery, if applicable
    /// </summary>
    public Guid? DeviceTokenId { get; set; }

    /// <summary>
    /// Gets or sets the notification type
    /// (SubmissionStatusUpdate, ApprovalDecision, ValidationFailure, Recommendation)
    /// </summary>
    public string NotificationType { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the delivery channel (Push, Email)
    /// </summary>
    public string Channel { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the target platform (iOS, Android, Web, Email)
    /// </summary>
    public string Platform { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the delivery status (Sent, Failed, Retrying)
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the error message if delivery failed
    /// </summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    /// Gets or sets the timestamp when the notification was sent or attempted
    /// </summary>
    public DateTime SentAt { get; set; }

    /// <summary>
    /// Gets or sets the correlation identifier for tracing this notification across services
    /// </summary>
    public string CorrelationId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the user who received this notification
    /// </summary>
    public User User { get; set; } = null!;

    /// <summary>
    /// Gets or sets the device token used for push delivery, if applicable
    /// </summary>
    public DeviceToken? DeviceToken { get; set; }
}
