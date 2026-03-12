using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for managing user notification preferences.
/// Handles retrieval, updates, defaults, and channel-level preference checks.
/// </summary>
public class NotificationPreferenceService : INotificationPreferenceService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<NotificationPreferenceService> _logger;

    /// <summary>
    /// Valid notification types supported by the system
    /// </summary>
    private static readonly HashSet<string> ValidNotificationTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "SubmissionStatusUpdate",
        "ApprovalDecision",
        "ValidationFailure",
        "Recommendation"
    };

    public NotificationPreferenceService(
        IApplicationDbContext context,
        ILogger<NotificationPreferenceService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<NotificationPreferenceResponse> GetPreferencesAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Retrieving notification preferences for user {UserId}",
            userId);

        var preferences = await _context.NotificationPreferences
            .AsNoTracking()
            .Where(p => p.UserId == userId && !p.IsDeleted)
            .ToListAsync(cancellationToken);

        // Create defaults if no preferences exist for this user
        if (preferences.Count == 0)
        {
            _logger.LogInformation(
                "No preferences found for user {UserId}, creating defaults",
                userId);

            await CreateDefaultPreferencesAsync(userId, cancellationToken);

            preferences = await _context.NotificationPreferences
                .AsNoTracking()
                .Where(p => p.UserId == userId && !p.IsDeleted)
                .ToListAsync(cancellationToken);
        }

        var typePreferences = preferences.Select(p => new NotificationTypePreference(
            p.NotificationType,
            p.IsPushEnabled,
            p.IsEmailEnabled));

        _logger.LogDebug(
            "Retrieved {PreferenceCount} preferences for user {UserId}",
            preferences.Count, userId);

        return new NotificationPreferenceResponse(userId, typePreferences);
    }

    /// <inheritdoc />
    public async Task UpdatePreferencesAsync(
        Guid userId,
        UpdateNotificationPreferenceRequest request,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Updating notification preference for user {UserId}, type {NotificationType}",
            userId, request.NotificationType);

        ValidateNotificationType(request.NotificationType);

        var normalizedType = NormalizeNotificationType(request.NotificationType);
        var now = DateTime.UtcNow;

        // Find existing preference for this user and notification type
        var existing = await _context.NotificationPreferences
            .FirstOrDefaultAsync(
                p => p.UserId == userId
                    && p.NotificationType == normalizedType
                    && !p.IsDeleted,
                cancellationToken);

        if (existing is not null)
        {
            // Log old and new values for audit trail
            _logger.LogInformation(
                "Preference change for user {UserId}, type {NotificationType}: " +
                "IsPushEnabled {OldPush} -> {NewPush}, IsEmailEnabled {OldEmail} -> {NewEmail}",
                userId, normalizedType,
                existing.IsPushEnabled, request.IsPushEnabled,
                existing.IsEmailEnabled, request.IsEmailEnabled);

            existing.IsPushEnabled = request.IsPushEnabled;
            existing.IsEmailEnabled = request.IsEmailEnabled;
            existing.UpdatedAt = now;
        }
        else
        {
            // Create new preference record
            var preference = new NotificationPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                NotificationType = normalizedType,
                IsPushEnabled = request.IsPushEnabled,
                IsEmailEnabled = request.IsEmailEnabled,
                CreatedAt = now,
                UpdatedAt = now
            };

            _context.NotificationPreferences.Add(preference);

            _logger.LogInformation(
                "Created new preference for user {UserId}, type {NotificationType}: " +
                "IsPushEnabled {PushEnabled}, IsEmailEnabled {EmailEnabled}",
                userId, normalizedType, request.IsPushEnabled, request.IsEmailEnabled);
        }

        await _context.SaveChangesAsync(cancellationToken);
    }

    /// <inheritdoc />
    public async Task<bool> IsNotificationEnabledAsync(
        Guid userId,
        string notificationType,
        string channel,
        CancellationToken cancellationToken)
    {
        _logger.LogDebug(
            "Checking if notification is enabled for user {UserId}, type {NotificationType}, channel {Channel}",
            userId, notificationType, channel);

        var normalizedType = NormalizeNotificationType(notificationType);

        var preference = await _context.NotificationPreferences
            .AsNoTracking()
            .FirstOrDefaultAsync(
                p => p.UserId == userId
                    && p.NotificationType == normalizedType
                    && !p.IsDeleted,
                cancellationToken);

        // Default to enabled if no preference exists
        if (preference is null)
        {
            _logger.LogDebug(
                "No preference found for user {UserId}, type {NotificationType}. Defaulting to enabled",
                userId, normalizedType);
            return true;
        }

        var isEnabled = channel.ToLowerInvariant() switch
        {
            "push" => preference.IsPushEnabled,
            "email" => preference.IsEmailEnabled,
            _ => true
        };

        _logger.LogDebug(
            "Notification enabled check for user {UserId}, type {NotificationType}, channel {Channel}: {IsEnabled}",
            userId, normalizedType, channel, isEnabled);

        return isEnabled;
    }

    /// <inheritdoc />
    public async Task GetOrCreateDefaultAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Ensuring default preferences exist for user {UserId}",
            userId);

        var existingTypes = await _context.NotificationPreferences
            .AsNoTracking()
            .Where(p => p.UserId == userId && !p.IsDeleted)
            .Select(p => p.NotificationType)
            .ToListAsync(cancellationToken);

        var missingTypes = ValidNotificationTypes
            .Where(t => !existingTypes.Contains(t, StringComparer.OrdinalIgnoreCase))
            .ToList();

        if (missingTypes.Count == 0)
        {
            _logger.LogDebug(
                "All default preferences already exist for user {UserId}",
                userId);
            return;
        }

        await CreatePreferencesForTypesAsync(userId, missingTypes, cancellationToken);

        _logger.LogInformation(
            "Created {Count} default preferences for user {UserId}",
            missingTypes.Count, userId);
    }

    /// <summary>
    /// Creates default preferences for all notification types (all channels enabled)
    /// </summary>
    private async Task CreateDefaultPreferencesAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        await CreatePreferencesForTypesAsync(
            userId,
            ValidNotificationTypes.ToList(),
            cancellationToken);
    }

    /// <summary>
    /// Creates preference records for the specified notification types with all channels enabled
    /// </summary>
    private async Task CreatePreferencesForTypesAsync(
        Guid userId,
        List<string> notificationTypes,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;

        foreach (var type in notificationTypes)
        {
            var preference = new NotificationPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                NotificationType = type,
                IsPushEnabled = true,
                IsEmailEnabled = true,
                CreatedAt = now,
                UpdatedAt = now
            };

            _context.NotificationPreferences.Add(preference);
        }

        await _context.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Validates that the notification type is one of the supported values
    /// </summary>
    private static void ValidateNotificationType(string notificationType)
    {
        if (string.IsNullOrWhiteSpace(notificationType))
        {
            throw new ArgumentException(
                "Notification type cannot be empty.",
                nameof(notificationType));
        }

        if (!ValidNotificationTypes.Contains(notificationType))
        {
            throw new ArgumentException(
                $"Invalid notification type '{notificationType}'. " +
                $"Valid types: {string.Join(", ", ValidNotificationTypes)}.",
                nameof(notificationType));
        }
    }

    /// <summary>
    /// Normalizes notification type to canonical form
    /// </summary>
    private static string NormalizeNotificationType(string notificationType)
    {
        return ValidNotificationTypes
            .FirstOrDefault(t => t.Equals(notificationType, StringComparison.OrdinalIgnoreCase))
            ?? notificationType;
    }
}
