using BajajDocumentProcessing.Application.DTOs.Notifications;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for managing user notification preferences.
/// Controls which notification types and channels are enabled per user.
/// </summary>
public interface INotificationPreferenceService
{
    /// <summary>
    /// Retrieves all notification preferences for a user. Creates defaults if none exist.
    /// </summary>
    Task<NotificationPreferenceResponse> GetPreferencesAsync(
        Guid userId,
        CancellationToken cancellationToken);

    /// <summary>
    /// Updates a user's notification preference for a specific notification type.
    /// Creates the preference record if it does not exist.
    /// </summary>
    Task UpdatePreferencesAsync(
        Guid userId,
        UpdateNotificationPreferenceRequest request,
        CancellationToken cancellationToken);

    /// <summary>
    /// Checks whether a specific notification type is enabled for a given channel.
    /// Returns true if no preference exists (default: all enabled).
    /// </summary>
    Task<bool> IsNotificationEnabledAsync(
        Guid userId,
        string notificationType,
        string channel,
        CancellationToken cancellationToken);

    /// <summary>
    /// Ensures default preferences exist for a user across all notification types.
    /// Creates missing preferences with all channels enabled.
    /// </summary>
    Task GetOrCreateDefaultAsync(
        Guid userId,
        CancellationToken cancellationToken);
}
