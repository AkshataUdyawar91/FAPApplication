namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Response containing device token registration details
/// </summary>
public record DeviceTokenResponse(
    Guid Id,
    string Platform,
    DateTime RegisteredAt,
    DateTime LastUsedAt,
    bool IsActive
);
