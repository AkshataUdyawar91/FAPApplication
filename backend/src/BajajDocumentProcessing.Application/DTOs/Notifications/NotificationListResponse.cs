namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Response for notification list
/// </summary>
public class NotificationListResponse
{
    /// <summary>
    /// List of notifications for the user
    /// </summary>
    public List<NotificationDto> Notifications { get; set; } = new();
    
    /// <summary>
    /// Count of unread notifications
    /// </summary>
    public int UnreadCount { get; set; }
}
