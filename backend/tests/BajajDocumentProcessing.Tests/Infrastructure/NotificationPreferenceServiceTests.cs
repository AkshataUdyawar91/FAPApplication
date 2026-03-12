using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// Unit tests for NotificationPreferenceService
/// Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6
/// </summary>
public class NotificationPreferenceServiceTests : IDisposable
{
    private readonly Mock<ILogger<NotificationPreferenceService>> _mockLogger;
    private readonly TestDbContext _dbContext;
    private readonly NotificationPreferenceService _service;

    public NotificationPreferenceServiceTests()
    {
        _mockLogger = new Mock<ILogger<NotificationPreferenceService>>();

        var options = new DbContextOptionsBuilder<TestDbContext>()
            .UseInMemoryDatabase(databaseName: $"NotificationPreferenceTests_{Guid.NewGuid()}")
            .Options;

        _dbContext = new TestDbContext(options);
        _service = new NotificationPreferenceService(_dbContext, _mockLogger.Object);
    }

    public void Dispose()
    {
        _dbContext.Dispose();
    }

    // ── GetPreferencesAsync ──

    [Fact]
    public async Task GetPreferencesAsync_ExistingPreferences_ShouldReturnAll()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var preferences = new[]
        {
            new NotificationPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                NotificationType = "SubmissionStatusUpdate",
                IsPushEnabled = true,
                IsEmailEnabled = true,
                CreatedAt = now,
                UpdatedAt = now
            },
            new NotificationPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                NotificationType = "ApprovalDecision",
                IsPushEnabled = false,
                IsEmailEnabled = true,
                CreatedAt = now,
                UpdatedAt = now
            }
        };

        _dbContext.NotificationPreferences.AddRange(preferences);
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _service.GetPreferencesAsync(userId, CancellationToken.None);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(userId, result.UserId);
        Assert.Equal(2, result.Preferences.Count());

        var submissionPref = result.Preferences.First(p => p.NotificationType == "SubmissionStatusUpdate");
        Assert.True(submissionPref.IsPushEnabled);
        Assert.True(submissionPref.IsEmailEnabled);

        var approvalPref = result.Preferences.First(p => p.NotificationType == "ApprovalDecision");
        Assert.False(approvalPref.IsPushEnabled);
        Assert.True(approvalPref.IsEmailEnabled);
    }

    [Fact]
    public async Task GetPreferencesAsync_MissingPreferences_ShouldCreateDefaults()
    {
        // Arrange
        var userId = Guid.NewGuid();

        // Act
        var result = await _service.GetPreferencesAsync(userId, CancellationToken.None);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(userId, result.UserId);
        Assert.Equal(4, result.Preferences.Count()); // All 4 notification types

        // Verify all defaults are enabled
        foreach (var pref in result.Preferences)
        {
            Assert.True(pref.IsPushEnabled);
            Assert.True(pref.IsEmailEnabled);
        }

        // Verify all valid notification types are present
        var types = result.Preferences.Select(p => p.NotificationType).ToHashSet();
        Assert.Contains("SubmissionStatusUpdate", types);
        Assert.Contains("ApprovalDecision", types);
        Assert.Contains("ValidationFailure", types);
        Assert.Contains("Recommendation", types);
    }

    [Fact]
    public async Task GetPreferencesAsync_ShouldNotReturnDeletedPreferences()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var preferences = new[]
        {
            new NotificationPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                NotificationType = "SubmissionStatusUpdate",
                IsPushEnabled = true,
                IsEmailEnabled = true,
                IsDeleted = false,
                CreatedAt = now,
                UpdatedAt = now
            },
            new NotificationPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                NotificationType = "ApprovalDecision",
                IsPushEnabled = true,
                IsEmailEnabled = true,
                IsDeleted = true, // Soft deleted
                CreatedAt = now,
                UpdatedAt = now
            }
        };

        _dbContext.NotificationPreferences.AddRange(preferences);
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _service.GetPreferencesAsync(userId, CancellationToken.None);

        // Assert
        Assert.NotNull(result);
        // Should return 1 existing preference (excluding deleted)
        Assert.Single(result.Preferences);
        Assert.Single(result.Preferences.Where(p => p.NotificationType == "SubmissionStatusUpdate"));
    }

    // ── UpdatePreferencesAsync ──

    [Fact]
    public async Task UpdatePreferencesAsync_ValidUpdate_ShouldUpdateExistingPreference()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var existing = new NotificationPreference
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            NotificationType = "SubmissionStatusUpdate",
            IsPushEnabled = true,
            IsEmailEnabled = true,
            CreatedAt = now,
            UpdatedAt = now
        };

        _dbContext.NotificationPreferences.Add(existing);
        await _dbContext.SaveChangesAsync();

        var request = new UpdateNotificationPreferenceRequest(
            "SubmissionStatusUpdate",
            false, // Disable push
            true   // Keep email enabled
        );

        // Act
        await _service.UpdatePreferencesAsync(userId, request, CancellationToken.None);

        // Assert
        var updated = await _dbContext.NotificationPreferences
            .FirstAsync(p => p.Id == existing.Id);

        Assert.False(updated.IsPushEnabled);
        Assert.True(updated.IsEmailEnabled);
        Assert.True(updated.UpdatedAt > now);
    }

    [Fact]
    public async Task UpdatePreferencesAsync_NonExistentPreference_ShouldCreateNew()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new UpdateNotificationPreferenceRequest(
            "ValidationFailure",
            false,
            true
        );

        // Act
        await _service.UpdatePreferencesAsync(userId, request, CancellationToken.None);

        // Assert
        var created = await _dbContext.NotificationPreferences
            .FirstOrDefaultAsync(p => p.UserId == userId && p.NotificationType == "ValidationFailure");

        Assert.NotNull(created);
        Assert.False(created.IsPushEnabled);
        Assert.True(created.IsEmailEnabled);
    }

    [Fact]
    public async Task UpdatePreferencesAsync_InvalidNotificationType_ShouldThrowArgumentException()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new UpdateNotificationPreferenceRequest(
            "InvalidType",
            true,
            true
        );

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(
            () => _service.UpdatePreferencesAsync(userId, request, CancellationToken.None));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public async Task UpdatePreferencesAsync_EmptyNotificationType_ShouldThrowArgumentException(string notificationType)
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new UpdateNotificationPreferenceRequest(
            notificationType,
            true,
            true
        );

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(
            () => _service.UpdatePreferencesAsync(userId, request, CancellationToken.None));
    }

    [Fact]
    public async Task UpdatePreferencesAsync_CaseInsensitiveNotificationType_ShouldNormalize()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new UpdateNotificationPreferenceRequest(
            "submissionstatusupdate", // lowercase
            true,
            false
        );

        // Act
        await _service.UpdatePreferencesAsync(userId, request, CancellationToken.None);

        // Assert
        var created = await _dbContext.NotificationPreferences
            .FirstOrDefaultAsync(p => p.UserId == userId);

        Assert.NotNull(created);
        Assert.Equal("SubmissionStatusUpdate", created.NotificationType); // Normalized to PascalCase
    }

    // ── IsNotificationEnabledAsync ──

    [Fact]
    public async Task IsNotificationEnabledAsync_PushEnabled_ShouldReturnTrue()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var preference = new NotificationPreference
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            NotificationType = "ApprovalDecision",
            IsPushEnabled = true,
            IsEmailEnabled = false,
            CreatedAt = now,
            UpdatedAt = now
        };

        _dbContext.NotificationPreferences.Add(preference);
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _service.IsNotificationEnabledAsync(
            userId,
            "ApprovalDecision",
            "push",
            CancellationToken.None);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task IsNotificationEnabledAsync_PushDisabled_ShouldReturnFalse()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var preference = new NotificationPreference
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            NotificationType = "ValidationFailure",
            IsPushEnabled = false,
            IsEmailEnabled = true,
            CreatedAt = now,
            UpdatedAt = now
        };

        _dbContext.NotificationPreferences.Add(preference);
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _service.IsNotificationEnabledAsync(
            userId,
            "ValidationFailure",
            "push",
            CancellationToken.None);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task IsNotificationEnabledAsync_EmailEnabled_ShouldReturnTrue()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var preference = new NotificationPreference
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            NotificationType = "Recommendation",
            IsPushEnabled = false,
            IsEmailEnabled = true,
            CreatedAt = now,
            UpdatedAt = now
        };

        _dbContext.NotificationPreferences.Add(preference);
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _service.IsNotificationEnabledAsync(
            userId,
            "Recommendation",
            "email",
            CancellationToken.None);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task IsNotificationEnabledAsync_NoPreference_ShouldDefaultToEnabled()
    {
        // Arrange
        var userId = Guid.NewGuid();

        // Act
        var result = await _service.IsNotificationEnabledAsync(
            userId,
            "SubmissionStatusUpdate",
            "push",
            CancellationToken.None);

        // Assert
        Assert.True(result); // Default is enabled
    }

    [Fact]
    public async Task IsNotificationEnabledAsync_UnknownChannel_ShouldDefaultToEnabled()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var preference = new NotificationPreference
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            NotificationType = "ApprovalDecision",
            IsPushEnabled = false,
            IsEmailEnabled = false,
            CreatedAt = now,
            UpdatedAt = now
        };

        _dbContext.NotificationPreferences.Add(preference);
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _service.IsNotificationEnabledAsync(
            userId,
            "ApprovalDecision",
            "sms", // Unknown channel
            CancellationToken.None);

        // Assert
        Assert.True(result); // Unknown channels default to enabled
    }

    [Fact]
    public async Task IsNotificationEnabledAsync_CaseInsensitiveChannel_ShouldWork()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var preference = new NotificationPreference
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            NotificationType = "SubmissionStatusUpdate",
            IsPushEnabled = true,
            IsEmailEnabled = false,
            CreatedAt = now,
            UpdatedAt = now
        };

        _dbContext.NotificationPreferences.Add(preference);
        await _dbContext.SaveChangesAsync();

        // Act
        var resultLower = await _service.IsNotificationEnabledAsync(
            userId, "SubmissionStatusUpdate", "push", CancellationToken.None);
        var resultUpper = await _service.IsNotificationEnabledAsync(
            userId, "SubmissionStatusUpdate", "PUSH", CancellationToken.None);
        var resultMixed = await _service.IsNotificationEnabledAsync(
            userId, "SubmissionStatusUpdate", "Push", CancellationToken.None);

        // Assert
        Assert.True(resultLower);
        Assert.True(resultUpper);
        Assert.True(resultMixed);
    }

    // ── GetOrCreateDefaultAsync ──

    [Fact]
    public async Task GetOrCreateDefaultAsync_NoExistingPreferences_ShouldCreateAll()
    {
        // Arrange
        var userId = Guid.NewGuid();

        // Act
        await _service.GetOrCreateDefaultAsync(userId, CancellationToken.None);

        // Assert
        var preferences = await _dbContext.NotificationPreferences
            .Where(p => p.UserId == userId && !p.IsDeleted)
            .ToListAsync();

        Assert.Equal(4, preferences.Count);

        foreach (var pref in preferences)
        {
            Assert.True(pref.IsPushEnabled);
            Assert.True(pref.IsEmailEnabled);
        }
    }

    [Fact]
    public async Task GetOrCreateDefaultAsync_PartialPreferences_ShouldCreateMissing()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        // Create only 2 preferences
        var existing = new[]
        {
            new NotificationPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                NotificationType = "SubmissionStatusUpdate",
                IsPushEnabled = false,
                IsEmailEnabled = true,
                CreatedAt = now,
                UpdatedAt = now
            },
            new NotificationPreference
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                NotificationType = "ApprovalDecision",
                IsPushEnabled = true,
                IsEmailEnabled = false,
                CreatedAt = now,
                UpdatedAt = now
            }
        };

        _dbContext.NotificationPreferences.AddRange(existing);
        await _dbContext.SaveChangesAsync();

        // Act
        await _service.GetOrCreateDefaultAsync(userId, CancellationToken.None);

        // Assert
        var allPreferences = await _dbContext.NotificationPreferences
            .Where(p => p.UserId == userId && !p.IsDeleted)
            .ToListAsync();

        Assert.Equal(4, allPreferences.Count);

        // Verify existing preferences were not modified
        var submission = allPreferences.First(p => p.NotificationType == "SubmissionStatusUpdate");
        Assert.False(submission.IsPushEnabled);
        Assert.True(submission.IsEmailEnabled);

        // Verify new preferences have defaults
        var validation = allPreferences.First(p => p.NotificationType == "ValidationFailure");
        Assert.True(validation.IsPushEnabled);
        Assert.True(validation.IsEmailEnabled);
    }

    [Fact]
    public async Task GetOrCreateDefaultAsync_AllPreferencesExist_ShouldNotCreateDuplicates()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var allTypes = new[] { "SubmissionStatusUpdate", "ApprovalDecision", "ValidationFailure", "Recommendation" };
        var preferences = allTypes.Select(type => new NotificationPreference
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            NotificationType = type,
            IsPushEnabled = true,
            IsEmailEnabled = true,
            CreatedAt = now,
            UpdatedAt = now
        });

        _dbContext.NotificationPreferences.AddRange(preferences);
        await _dbContext.SaveChangesAsync();

        // Act
        await _service.GetOrCreateDefaultAsync(userId, CancellationToken.None);

        // Assert
        var count = await _dbContext.NotificationPreferences
            .Where(p => p.UserId == userId && !p.IsDeleted)
            .CountAsync();

        Assert.Equal(4, count); // No duplicates created
    }
}
