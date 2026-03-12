using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for managing device tokens used in push notification delivery
/// </summary>
public interface IDeviceTokenService
{
    /// <summary>
    /// Registers a device token for a user. Updates existing record if token already exists for user+platform.
    /// </summary>
    Task<DeviceTokenResponse> RegisterAsync(
        Guid userId,
        RegisterDeviceTokenRequest request,
        CancellationToken cancellationToken);

    /// <summary>
    /// Deregisters a device token by ID (e.g., on user logout)
    /// </summary>
    Task DeregisterAsync(
        Guid userId,
        Guid deviceTokenId,
        CancellationToken cancellationToken);

    /// <summary>
    /// Deregisters a device token by its token value and user ID
    /// </summary>
    Task DeregisterByTokenAsync(
        Guid userId,
        string token,
        CancellationToken cancellationToken);

    /// <summary>
    /// Retrieves all active device tokens for a user
    /// </summary>
    Task<IEnumerable<DeviceToken>> GetUserDeviceTokensAsync(
        Guid userId,
        CancellationToken cancellationToken);

    /// <summary>
    /// Marks a device token as inactive after a failed delivery attempt
    /// </summary>
    Task RemoveInvalidTokenAsync(
        Guid deviceTokenId,
        string reason,
        CancellationToken cancellationToken);
}
