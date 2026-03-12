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
/// Unit tests for DeviceTokenService
/// </summary>
public class DeviceTokenServiceTests : IDisposable
{
    private readonly Mock<ILogger<DeviceTokenService>> _mockLogger;
    private readonly TestDbContext _dbContext;
    private readonly DeviceTokenService _service;

    public DeviceTokenServiceTests()
    {
        _mockLogger = new Mock<ILogger<DeviceTokenService>>();

        var options = new DbContextOptionsBuilder<TestDbContext>()
            .UseInMemoryDatabase(databaseName: $"DeviceTokenTests_{Guid.NewGuid()}")
            .Options;

        _dbContext = new TestDbContext(options);
        _service = new DeviceTokenService(_dbContext, _mockLogger.Object);
    }

    public void Dispose()
    {
        _dbContext.Dispose();
    }

    // ── RegisterAsync ──

    [Fact]
    public async Task RegisterAsync_ValidToken_ShouldCreateAndReturnResponse()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new RegisterDeviceTokenRequest("valid-token-abc123", "iOS");

        // Act
        var result = await _service.RegisterAsync(userId, request, CancellationToken.None);

        // Assert
        Assert.NotNull(result);
        Assert.Equal("iOS", result.Platform);
        Assert.True(result.IsActive);
        Assert.NotEqual(Guid.Empty, result.Id);

        var stored = await _dbContext.DeviceTokens.FirstOrDefaultAsync();
        Assert.NotNull(stored);
        Assert.Equal(userId, stored.UserId);
        Assert.Equal("valid-token-abc123", stored.Token);
    }

    [Fact]
    public async Task RegisterAsync_DuplicateToken_ShouldUpdateExistingRecord()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new RegisterDeviceTokenRequest("duplicate-token", "Android");

        var first = await _service.RegisterAsync(userId, request, CancellationToken.None);

        // Act
        var second = await _service.RegisterAsync(userId, request, CancellationToken.None);

        // Assert
        Assert.Equal(first.Id, second.Id);
        Assert.True(second.IsActive);
        Assert.True(second.LastUsedAt >= first.LastUsedAt);

        var count = await _dbContext.DeviceTokens.CountAsync();
        Assert.Equal(1, count);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task RegisterAsync_InvalidTokenFormat_ShouldThrowArgumentException(string token)
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new RegisterDeviceTokenRequest(token, "iOS");

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(
            () => _service.RegisterAsync(userId, request, CancellationToken.None));
    }

    [Fact]
    public async Task RegisterAsync_InvalidPlatform_ShouldThrowArgumentException()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new RegisterDeviceTokenRequest("valid-token", "BlackBerry");

        // Act & Assert
        await Assert.ThrowsAsync<ArgumentException>(
            () => _service.RegisterAsync(userId, request, CancellationToken.None));
    }

    // ── DeregisterAsync ──

    [Fact]
    public async Task DeregisterAsync_ExistingToken_ShouldMarkInactive()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new RegisterDeviceTokenRequest("token-to-deregister", "Web");
        var registered = await _service.RegisterAsync(userId, request, CancellationToken.None);

        // Act
        await _service.DeregisterAsync(userId, registered.Id, CancellationToken.None);

        // Assert
        var token = await _dbContext.DeviceTokens.FirstAsync(t => t.Id == registered.Id);
        Assert.False(token.IsActive);
    }

    [Fact]
    public async Task DeregisterAsync_NonExistentToken_ShouldNotThrow()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var nonExistentId = Guid.NewGuid();

        // Act & Assert — should complete without throwing
        await _service.DeregisterAsync(userId, nonExistentId, CancellationToken.None);
    }

    // ── GetUserDeviceTokensAsync ──

    [Fact]
    public async Task GetUserDeviceTokensAsync_MultipleDevices_ShouldReturnAll()
    {
        // Arrange
        var userId = Guid.NewGuid();
        await _service.RegisterAsync(userId, new RegisterDeviceTokenRequest("ios-token", "iOS"), CancellationToken.None);
        await _service.RegisterAsync(userId, new RegisterDeviceTokenRequest("android-token", "Android"), CancellationToken.None);
        await _service.RegisterAsync(userId, new RegisterDeviceTokenRequest("web-token", "Web"), CancellationToken.None);

        // Act
        var tokens = (await _service.GetUserDeviceTokensAsync(userId, CancellationToken.None)).ToList();

        // Assert
        Assert.Equal(3, tokens.Count);
    }

    [Fact]
    public async Task GetUserDeviceTokensAsync_NoDevices_ShouldReturnEmpty()
    {
        // Arrange
        var userId = Guid.NewGuid();

        // Act
        var tokens = (await _service.GetUserDeviceTokensAsync(userId, CancellationToken.None)).ToList();

        // Assert
        Assert.Empty(tokens);
    }

    [Fact]
    public async Task GetUserDeviceTokensAsync_ShouldNotReturnInactiveTokens()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var registered = await _service.RegisterAsync(userId, new RegisterDeviceTokenRequest("token-1", "iOS"), CancellationToken.None);
        await _service.RegisterAsync(userId, new RegisterDeviceTokenRequest("token-2", "Android"), CancellationToken.None);
        await _service.DeregisterAsync(userId, registered.Id, CancellationToken.None);

        // Act
        var tokens = (await _service.GetUserDeviceTokensAsync(userId, CancellationToken.None)).ToList();

        // Assert
        Assert.Single(tokens);
        Assert.Equal("Android", tokens[0].Platform);
    }

    // ── RemoveInvalidTokenAsync ──

    [Fact]
    public async Task RemoveInvalidTokenAsync_ShouldMarkTokenInactive()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var registered = await _service.RegisterAsync(userId, new RegisterDeviceTokenRequest("invalid-token", "iOS"), CancellationToken.None);

        // Act
        await _service.RemoveInvalidTokenAsync(registered.Id, "Token expired", CancellationToken.None);

        // Assert
        var token = await _dbContext.DeviceTokens.FirstAsync(t => t.Id == registered.Id);
        Assert.False(token.IsActive);
    }

    [Fact]
    public async Task RemoveInvalidTokenAsync_NonExistentToken_ShouldNotThrow()
    {
        // Act & Assert — should complete without throwing
        await _service.RemoveInvalidTokenAsync(Guid.NewGuid(), "Not found", CancellationToken.None);
    }
}
