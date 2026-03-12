using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Request to update a user's notification preference for a specific notification type
/// </summary>
public record UpdateNotificationPreferenceRequest(
    [Required]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "NotificationType must be between 1 and 100 characters")]
    string NotificationType,

    [Required]
    bool IsPushEnabled,

    [Required]
    bool IsEmailEnabled
);
