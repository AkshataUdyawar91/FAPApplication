using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for managing in-app and email notifications
/// </summary>
public interface INotificationAgent
{
    /// <summary>
    /// Sends a notification to a user (in-app and optionally email)
    /// </summary>
    Task SendNotificationAsync(
        Guid userId,
        NotificationType type,
        string title,
        string message,
        Guid? relatedEntityId = null,
        bool sendEmail = false,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Gets notifications for a user
    /// </summary>
    Task<List<Notification>> GetUserNotificationsAsync(
        Guid userId,
        bool unreadOnly = false,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Marks a notification as read
    /// </summary>
    Task MarkAsReadAsync(Guid notificationId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Gets the count of unread notifications for a user
    /// </summary>
    Task<int> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Notifies user that their submission was received
    /// </summary>
    Task NotifySubmissionReceivedAsync(Guid userId, Guid packageId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Notifies user that their submission was approved
    /// </summary>
    Task NotifyApprovedAsync(Guid userId, Guid packageId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Notifies user that their submission was rejected
    /// </summary>
    Task NotifyRejectedAsync(Guid userId, Guid packageId, string reason, CancellationToken cancellationToken = default);

    /// <summary>
    /// Notifies user that re-upload is requested
    /// </summary>
    Task NotifyReuploadRequestedAsync(Guid userId, Guid packageId, string reason, CancellationToken cancellationToken = default);
}
