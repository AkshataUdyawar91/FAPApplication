namespace BajajDocumentProcessing.Domain.Enums;

/// <summary>
/// Represents the delivery channel used for a notification.
/// Used to track how each notification was delivered to the user.
/// </summary>
public enum NotificationChannel
{
    /// <summary>
    /// In-app notification displayed within the FieldIQ portal.
    /// </summary>
    InApp = 1,

    /// <summary>
    /// Microsoft Teams Adaptive Card notification sent via the FieldIQ bot.
    /// </summary>
    Teams = 2,

    /// <summary>
    /// Email notification sent via Azure Communication Services.
    /// </summary>
    Email = 3
}
