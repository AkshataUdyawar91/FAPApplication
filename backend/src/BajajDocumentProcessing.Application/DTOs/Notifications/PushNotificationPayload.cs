namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Payload for a push notification containing title, body, type, custom data, and deep link
/// </summary>
public record PushNotificationPayload(
    string Title,
    string Body,
    string NotificationType,
    Dictionary<string, string> Data,
    string DeepLink
);
