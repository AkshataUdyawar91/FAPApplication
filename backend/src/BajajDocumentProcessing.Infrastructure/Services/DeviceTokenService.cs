using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for managing device tokens used in push notification delivery.
/// Handles registration, deregistration, and cleanup of invalid tokens.
/// </summary>
public class DeviceTokenService : IDeviceTokenService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<DeviceTokenService> _logger;

    private static readonly HashSet<string> ValidPlatforms = new(StringComparer.OrdinalIgnoreCase)
    {
        "iOS", "Android", "Web"
    };

    public DeviceTokenService(
        IApplicationDbContext context,
        ILogger<DeviceTokenService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<DeviceTokenResponse> RegisterAsync(
        Guid userId,
        RegisterDeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Registering device token for user {UserId}, platform {Platform}",
            userId, request.Platform);

        ValidatePlatform(request.Platform);
        ValidateToken(request.Token);

        var normalizedPlatform = NormalizePlatform(request.Platform);
        var now = DateTime.UtcNow;

        // Check for existing token for this user+platform+token combination
        var existingToken = await _context.DeviceTokens
            .FirstOrDefaultAsync(
                dt => dt.UserId == userId
                    && dt.Platform == normalizedPlatform
                    && dt.Token == request.Token
                    && !dt.IsDeleted,
                cancellationToken);

        if (existingToken is not null)
        {
            // Update existing record instead of creating a duplicate
            existingToken.LastUsedAt = now;
            existingToken.IsActive = true;
            existingToken.UpdatedAt = now;

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Updated existing device token {DeviceTokenId} for user {UserId}, platform {Platform}",
                existingToken.Id, userId, normalizedPlatform);

            return MapToResponse(existingToken);
        }

        // Create new device token record
        var deviceToken = new DeviceToken
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Platform = normalizedPlatform,
            Token = request.Token,
            RegisteredAt = now,
            LastUsedAt = now,
            IsActive = true,
            CreatedAt = now
        };

        _context.DeviceTokens.Add(deviceToken);
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Registered new device token {DeviceTokenId} for user {UserId}, platform {Platform}",
            deviceToken.Id, userId, normalizedPlatform);

        return MapToResponse(deviceToken);
    }

    /// <inheritdoc />
    public async Task DeregisterAsync(
        Guid userId,
        Guid deviceTokenId,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Deregistering device token {DeviceTokenId} for user {UserId}",
            deviceTokenId, userId);

        var deviceToken = await _context.DeviceTokens
            .FirstOrDefaultAsync(
                dt => dt.Id == deviceTokenId
                    && dt.UserId == userId
                    && !dt.IsDeleted,
                cancellationToken);

        if (deviceToken is null)
        {
            _logger.LogWarning(
                "Device token {DeviceTokenId} not found for user {UserId}",
                deviceTokenId, userId);
            return;
        }

        deviceToken.IsActive = false;
        deviceToken.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Deregistered device token {DeviceTokenId} for user {UserId}, platform {Platform}. Reason: User logout",
            deviceTokenId, userId, deviceToken.Platform);
    }

    /// <inheritdoc />
    public async Task DeregisterByTokenAsync(
        Guid userId,
        string token,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation(
            "Deregistering device token by value for user {UserId}",
            userId);

        var deviceToken = await _context.DeviceTokens
            .FirstOrDefaultAsync(
                dt => dt.UserId == userId
                    && dt.Token == token
                    && !dt.IsDeleted,
                cancellationToken);

        if (deviceToken is null)
        {
            _logger.LogWarning(
                "Device token not found by value for user {UserId}",
                userId);
            return;
        }

        deviceToken.IsActive = false;
        deviceToken.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Deregistered device token {DeviceTokenId} by value for user {UserId}, platform {Platform}",
            deviceToken.Id, userId, deviceToken.Platform);
    }

    /// <inheritdoc />
    public async Task<IEnumerable<DeviceToken>> GetUserDeviceTokensAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        _logger.LogDebug(
            "Retrieving active device tokens for user {UserId}",
            userId);

        var tokens = await _context.DeviceTokens
            .AsNoTracking()
            .Where(dt => dt.UserId == userId && dt.IsActive && !dt.IsDeleted)
            .ToListAsync(cancellationToken);

        _logger.LogDebug(
            "Found {TokenCount} active device tokens for user {UserId}",
            tokens.Count, userId);

        return tokens;
    }

    /// <inheritdoc />
    public async Task RemoveInvalidTokenAsync(
        Guid deviceTokenId,
        string reason,
        CancellationToken cancellationToken)
    {
        _logger.LogWarning(
            "Removing invalid device token {DeviceTokenId}. Reason: {Reason}",
            deviceTokenId, reason);

        var deviceToken = await _context.DeviceTokens
            .FirstOrDefaultAsync(
                dt => dt.Id == deviceTokenId && !dt.IsDeleted,
                cancellationToken);

        if (deviceToken is null)
        {
            _logger.LogWarning(
                "Invalid device token {DeviceTokenId} not found for removal",
                deviceTokenId);
            return;
        }

        deviceToken.IsActive = false;
        deviceToken.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Removed invalid device token {DeviceTokenId} for user {UserId}, platform {Platform}. Reason: {Reason}",
            deviceTokenId, deviceToken.UserId, deviceToken.Platform, reason);
    }

    /// <summary>
    /// Validates that the platform is one of the supported values
    /// </summary>
    private static void ValidatePlatform(string platform)
    {
        if (!ValidPlatforms.Contains(platform))
        {
            throw new ArgumentException(
                $"Invalid platform '{platform}'. Supported platforms: iOS, Android, Web.",
                nameof(platform));
        }
    }

    /// <summary>
    /// Validates that the token is not empty or whitespace
    /// </summary>
    private static void ValidateToken(string token)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            throw new ArgumentException("Device token cannot be empty.", nameof(token));
        }
    }

    /// <summary>
    /// Normalizes platform name to canonical form
    /// </summary>
    private static string NormalizePlatform(string platform)
    {
        return platform.ToLowerInvariant() switch
        {
            "ios" => "iOS",
            "android" => "Android",
            "web" => "Web",
            _ => platform
        };
    }

    /// <summary>
    /// Maps a DeviceToken entity to a DeviceTokenResponse DTO
    /// </summary>
    private static DeviceTokenResponse MapToResponse(DeviceToken deviceToken)
    {
        return new DeviceTokenResponse(
            deviceToken.Id,
            deviceToken.Platform,
            deviceToken.RegisteredAt,
            deviceToken.LastUsedAt,
            deviceToken.IsActive);
    }
}
