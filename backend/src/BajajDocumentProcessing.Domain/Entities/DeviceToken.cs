using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents a registered device token for push notification delivery.
/// Each token is associated with a user and platform (iOS, Android, Web)
/// </summary>
public class DeviceToken : BaseEntity
{
    /// <summary>
    /// Gets or sets the unique identifier of the user who owns this device token
    /// </summary>
    public Guid UserId { get; set; }

    /// <summary>
    /// Gets or sets the platform for this device token (iOS, Android, Web)
    /// </summary>
    public string Platform { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the platform-issued push notification token
    /// </summary>
    public string Token { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the timestamp when this device token was first registered
    /// </summary>
    public DateTime RegisteredAt { get; set; }

    /// <summary>
    /// Gets or sets the timestamp when this device token was last used for notification delivery
    /// </summary>
    public DateTime LastUsedAt { get; set; }

    /// <summary>
    /// Gets or sets whether this device token is currently active and eligible for notification delivery
    /// </summary>
    public bool IsActive { get; set; }

    /// <summary>
    /// Gets or sets the user who owns this device token
    /// </summary>
    public User User { get; set; } = null!;
}
