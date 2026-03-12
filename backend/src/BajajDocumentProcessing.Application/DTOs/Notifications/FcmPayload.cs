namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Payload for Firebase Cloud Messaging (FCM) delivery
/// </summary>
public record FcmPayload(
    string Title,
    string Body,
    Dictionary<string, string> Data,
    FcmAndroidConfig? AndroidConfig = null,
    FcmWebpushConfig? WebpushConfig = null
);

/// <summary>
/// Android-specific FCM configuration
/// </summary>
public record FcmAndroidConfig(
    string Priority,
    Dictionary<string, string>? Data = null
);

/// <summary>
/// Web push-specific FCM configuration
/// </summary>
public record FcmWebpushConfig(
    Dictionary<string, string>? Headers = null,
    Dictionary<string, string>? Data = null
);
