using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for managing in-app and email notifications
/// </summary>
public class NotificationAgent : INotificationAgent
{
    private readonly IApplicationDbContext _context;
    private readonly IEmailAgent _emailAgent;
    private readonly ILogger<NotificationAgent> _logger;

    public NotificationAgent(
        IApplicationDbContext context,
        IEmailAgent emailAgent,
        ILogger<NotificationAgent> logger)
    {
        _context = context;
        _emailAgent = emailAgent;
        _logger = logger;
    }

    public async Task SendNotificationAsync(
        Guid userId,
        NotificationType type,
        string title,
        string message,
        Guid? relatedEntityId = null,
        bool sendEmail = false,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Sending notification to user {UserId}: Type={Type}, Title={Title}",
            userId,
            type,
            title);

        try
        {
            // Create in-app notification
            var notification = new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = type,
                Title = title,
                Message = message,
                IsRead = false,
                RelatedEntityId = relatedEntityId,
                CreatedAt = DateTime.UtcNow
            };

            _context.Notifications.Add(notification);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "In-app notification created: {NotificationId} for user {UserId}",
                notification.Id,
                userId);

            // Send email notification if requested
            if (sendEmail)
            {
                await SendEmailNotificationAsync(userId, type, title, message, relatedEntityId, cancellationToken);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error sending notification to user {UserId}: Type={Type}",
                userId,
                type);
            throw;
        }
    }

    public async Task<List<Notification>> GetUserNotificationsAsync(
        Guid userId,
        bool unreadOnly = false,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Getting notifications for user {UserId}, UnreadOnly={UnreadOnly}",
            userId,
            unreadOnly);

        try
        {
            var query = _context.Notifications
                .Where(n => n.UserId == userId);

            if (unreadOnly)
            {
                query = query.Where(n => !n.IsRead);
            }

            // Order by unread first, then by creation date descending
            var notifications = await query
                .OrderBy(n => n.IsRead)
                .ThenByDescending(n => n.CreatedAt)
                .ToListAsync(cancellationToken);

            _logger.LogInformation(
                "Retrieved {Count} notifications for user {UserId}",
                notifications.Count,
                userId);

            return notifications;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error getting notifications for user {UserId}",
                userId);
            throw;
        }
    }

    public async Task MarkAsReadAsync(Guid notificationId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Marking notification {NotificationId} as read", notificationId);

        try
        {
            var notification = await _context.Notifications
                .FirstOrDefaultAsync(n => n.Id == notificationId, cancellationToken);

            if (notification == null)
            {
                _logger.LogWarning("Notification {NotificationId} not found", notificationId);
                throw new InvalidOperationException($"Notification {notificationId} not found");
            }

            if (!notification.IsRead)
            {
                notification.IsRead = true;
                notification.ReadAt = DateTime.UtcNow;

                await _context.SaveChangesAsync(cancellationToken);

                _logger.LogInformation(
                    "Notification {NotificationId} marked as read for user {UserId}",
                    notificationId,
                    notification.UserId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error marking notification {NotificationId} as read",
                notificationId);
            throw;
        }
    }

    public async Task<int> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        try
        {
            var count = await _context.Notifications
                .Where(n => n.UserId == userId && !n.IsRead)
                .CountAsync(cancellationToken);

            return count;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error getting unread count for user {UserId}",
                userId);
            throw;
        }
    }

    /// <summary>
    /// Sends email notification based on notification type
    /// </summary>
    private async Task SendEmailNotificationAsync(
        Guid userId,
        NotificationType type,
        string title,
        string message,
        Guid? relatedEntityId,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get user email
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

            if (user == null)
            {
                _logger.LogWarning("User {UserId} not found for email notification", userId);
                return;
            }

            // Send email based on notification type
            switch (type)
            {
                case NotificationType.SubmissionReceived:
                    // ASM notification - data pass scenario
                    if (relatedEntityId.HasValue)
                    {
                        await _emailAgent.SendDataPassEmailAsync(
                            relatedEntityId.Value,
                            user.Email,
                            cancellationToken);
                    }
                    break;

                case NotificationType.FlaggedForReview:
                    // ASM notification - low confidence or validation issues
                    _logger.LogInformation(
                        "Flagged for review notification sent to {Email}",
                        user.Email);
                    break;

                case NotificationType.Approved:
                    // Agency notification - approved
                    if (relatedEntityId.HasValue)
                    {
                        await _emailAgent.SendApprovedEmailAsync(
                            relatedEntityId.Value,
                            user.Email,
                            cancellationToken);
                    }
                    break;

                case NotificationType.Rejected:
                    // Agency notification - rejected
                    if (relatedEntityId.HasValue)
                    {
                        await _emailAgent.SendRejectedEmailAsync(
                            relatedEntityId.Value,
                            user.Email,
                            message,
                            cancellationToken);
                    }
                    break;

                case NotificationType.ReuploadRequested:
                    // Agency notification - re-upload requested
                    _logger.LogInformation(
                        "Re-upload requested notification sent to {Email}",
                        user.Email);
                    break;

                default:
                    _logger.LogWarning(
                        "Unknown notification type {Type} for email notification",
                        type);
                    break;
            }

            _logger.LogInformation(
                "Email notification sent to user {UserId} ({Email}) for type {Type}",
                userId,
                user.Email,
                type);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error sending email notification to user {UserId} for type {Type}",
                userId,
                type);
            // Don't throw - email failure shouldn't prevent in-app notification
        }
    }

    public async Task NotifySubmissionReceivedAsync(
        Guid userId,
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        await SendNotificationAsync(
            userId,
            NotificationType.SubmissionReceived,
            "Submission Received",
            "Your document submission has been received and is being processed.",
            packageId,
            sendEmail: true,
            cancellationToken);
    }

    public async Task NotifyApprovedAsync(
        Guid userId,
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        await SendNotificationAsync(
            userId,
            NotificationType.Approved,
            "Submission Approved",
            "Your document submission has been approved.",
            packageId,
            sendEmail: true,
            cancellationToken);
    }

    public async Task NotifyRejectedAsync(
        Guid userId,
        Guid packageId,
        string reason,
        CancellationToken cancellationToken = default)
    {
        await SendNotificationAsync(
            userId,
            NotificationType.Rejected,
            "Submission Rejected",
            $"Your document submission has been rejected. Reason: {reason}",
            packageId,
            sendEmail: true,
            cancellationToken);
    }

    public async Task NotifyReuploadRequestedAsync(
        Guid userId,
        Guid packageId,
        string reason,
        CancellationToken cancellationToken = default)
    {
        await SendNotificationAsync(
            userId,
            NotificationType.ReuploadRequested,
            "Re-upload Requested",
            $"Please re-upload your documents. Reason: {reason}",
            packageId,
            sendEmail: true,
            cancellationToken);
    }
}
