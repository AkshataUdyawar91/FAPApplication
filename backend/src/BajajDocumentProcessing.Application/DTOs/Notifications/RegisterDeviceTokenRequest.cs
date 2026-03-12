using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Request to register a device token for push notifications
/// </summary>
public record RegisterDeviceTokenRequest(
    [Required]
    [StringLength(4096, MinimumLength = 1, ErrorMessage = "Token must be between 1 and 4096 characters")]
    string Token,

    [Required]
    [RegularExpression("^(iOS|Android|Web)$", ErrorMessage = "Platform must be 'iOS', 'Android', or 'Web'")]
    string Platform
);
