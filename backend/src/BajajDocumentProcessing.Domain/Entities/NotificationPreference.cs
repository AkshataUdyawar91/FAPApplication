using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a user's notification preference for a specific notification type.
/// Controls whether push and email notifications are enabled per notification type
/// </summary>
public class NotificationPreference : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the user who owns this preference
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// Gets or sets the notification type this preference applies to
    /// (SubmissionStatusUpdate, ApprovalDecision, ValidationFailure, Recommendation)
    /// </summary>
    public string NotificationType { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets whether push notifications are enabled for this notification type
    /// </summary>
    public bool IsPushEnabled { get; set; }

    /// <summary>
    /// Gets or sets whether email notifications are enabled for this notification type
    /// </summary>
    public bool IsEmailEnabled { get; set; }

    /// <summary>
    /// Gets or sets the user who owns this preference
    /// </summary>
    public User User { get; set; } = null!;
}
