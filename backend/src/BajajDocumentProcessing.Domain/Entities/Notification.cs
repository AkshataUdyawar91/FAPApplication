using BajajDocumentProcessing.Domain.Common;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Notification entity for in-app notifications
/// </summary>
public class Notification : BaseEntity
{
    public Guid UserId { get; set; }
    public NotificationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public DateTime? ReadAt { get; set; }
    public Guid? RelatedEntityId { get; set; }

    // Navigation properties
    public User User { get; set; } = null!;
    public DocumentPackage? RelatedPackage { get; set; }
}
