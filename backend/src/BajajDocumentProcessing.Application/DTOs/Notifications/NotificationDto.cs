using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// DTO for notification data
/// </summary>
public class NotificationDto
{
    /// <summary>
    /// Unique identifier of the notification
    /// </summary>
    public Guid Id { get; set; }
    
    /// <summary>
    /// User ID this notification is for
    /// </summary>
    public Guid UserId { get; set; }
    
    /// <summary>
    /// Type of notification
    /// </summary>
    public NotificationType Type { get; set; }
    
    /// <summary>
    /// Notification title
    /// </summary>
    public string Title { get; set; } = string.Empty;
    
    /// <summary>
    /// Notification message content
    /// </summary>
    public string Message { get; set; } = string.Empty;
    
    /// <summary>
    /// Whether the notification has been read
    /// </summary>
    public bool IsRead { get; set; }
    
    /// <summary>
    /// ID of the related entity (e.g., submission ID)
    /// </summary>
    public Guid? RelatedEntityId { get; set; }
    
    /// <summary>
    /// UTC timestamp when the notification was created
    /// </summary>
    public DateTime CreatedAt { get; set; }
    
    /// <summary>
    /// UTC timestamp when the notification was read
    /// </summary>
    public DateTime? ReadAt { get; set; }
}
