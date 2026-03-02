using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// DTO for notification data
/// </summary>
public class NotificationDto
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public NotificationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public Guid? RelatedEntityId { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? ReadAt { get; set; }
}
