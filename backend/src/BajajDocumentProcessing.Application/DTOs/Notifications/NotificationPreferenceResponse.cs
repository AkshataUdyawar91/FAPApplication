namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Response containing a user's notification preferences grouped by notification type
/// </summary>
public record NotificationPreferenceResponse(
    Guid UserId,
    IEnumerable<NotificationTypePreference> Preferences
);

/// <summary>
/// Preference settings for a single notification type
/// </summary>
public record NotificationTypePreference(
    string NotificationType,
    bool IsPushEnabled,
    bool IsEmailEnabled
);
