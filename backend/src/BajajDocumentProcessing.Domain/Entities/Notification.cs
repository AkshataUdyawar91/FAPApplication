using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents an in-app notification sent to users about submission status changes, approvals, or rejections
/// </summary>
public class Notification : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the user who should receive this notification
    /// </summary>
    public Guid UserId { get; set; }
    
    /// <summary>
    /// Gets or sets the type of notification (SubmissionReceived, ApprovalRequired, Approved, Rejected, etc.)
    /// </summary>
    public NotificationType Type { get; set; }
    
    /// <summary>
    /// Gets or sets the notification title displayed to the user
    /// </summary>
    public string Title { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets the notification message body displayed to the user
    /// </summary>
    public string Message { get; set; } = string.Empty;
    
    /// <summary>
    /// Gets or sets whether the user has read this notification
    /// </summary>
    public bool IsRead { get; set; }
    
    /// <summary>
    /// Gets or sets the timestamp when the user read this notification
    /// </summary>
    public DateTime? ReadAt { get; set; }
    
    /// <summary>
    /// Gets or sets the unique identifier of the related entity (typically a DocumentPackage ID)
    /// </summary>
    public Guid? RelatedEntityId { get; set; }

    /// <summary>
    /// Gets or sets the user who should receive this notification
    /// </summary>
    public User User { get; set; } = null!;
    
    /// <summary>
    /// Gets or sets the document package related to this notification, if applicable
    /// </summary>
    public DocumentPackage? RelatedPackage { get; set; }

    // === Multi-channel delivery tracking fields ===

    /// <summary>
    /// Gets or sets the delivery channel used for this notification (InApp, Teams, or Email).
    /// Defaults to InApp for backward compatibility with existing notifications.
    /// </summary>
    public NotificationChannel Channel { get; set; } = NotificationChannel.InApp;

    /// <summary>
    /// Gets or sets the delivery status of this notification attempt.
    /// Defaults to Sent for backward compatibility with existing notifications.
    /// </summary>
    public NotificationDeliveryStatus DeliveryStatus { get; set; } = NotificationDeliveryStatus.Sent;

    /// <summary>
    /// Gets or sets the number of delivery retry attempts made for this notification.
    /// </summary>
    public int RetryCount { get; set; } = 0;

    /// <summary>
    /// Gets or sets the timestamp when this notification was successfully sent.
    /// </summary>
    public DateTime? SentAt { get; set; }

    /// <summary>
    /// Gets or sets the external message identifier (Teams activity ID or email message ID) for tracking.
    /// </summary>
    public string? ExternalMessageId { get; set; }

    /// <summary>
    /// Gets or sets the reason for delivery failure, if applicable.
    /// </summary>
    public string? FailureReason { get; set; }
}
