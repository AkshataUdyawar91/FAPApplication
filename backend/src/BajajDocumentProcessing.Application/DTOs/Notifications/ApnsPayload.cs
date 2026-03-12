namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Payload for Apple Push Notification service (APNs) delivery
/// </summary>
public record ApnsPayload(
    string Title,
    string Body,
    string? Sound,
    int Badge,
    Dictionary<string, string>? CustomData
);
