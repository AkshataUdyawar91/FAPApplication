namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Response for notification list
/// </summary>
public class NotificationListResponse
{
    public List<NotificationDto> Notifications { get; set; } = new();
    public int UnreadCount { get; set; }
}
