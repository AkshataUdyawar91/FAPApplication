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
/// Unit tests for PushNotificationService
/// </summary>
public class PushNotificationServiceTests : IDisposable
{
    private readonly Mock<IDeviceTokenService> _mockDeviceTokenService;
    private readonly Mock<INotificationPreferenceService> _mockPreferenceService;
    private readonly Mock<IApnsService> _mockApnsService;
    private readonly Mock<IFcmService> _mockFcmService;
    private readonly Mock<ICorrelationIdService> _mockCorrelationIdService;
    private readonly Mock<ILogger<PushNotificationService>> _mockLogger;
    private readonly TestDbContext _dbContext;
    private readonly PushNotificationService _service;
    private readonly PushNotificationPayload _testPayload;

    public PushNotificationServiceTests()
    {
        _mockDeviceTokenService = new Mock<IDeviceTokenService>();
        _mockPreferenceService = new Mock<INotificationPreferenceService>();
        _mockApnsService = new Mock<IApnsService>();
        _mockFcmService = new Mock<IFcmService>();
        _mockCorrelationIdService = new Mock<ICorrelationIdService>();
        _mockLogger = new Mock<ILogger<PushNotificationService>>();

        _mockCorrelationIdService.Setup(c => c.GetCorrelationId()).Returns("test-correlation-id");

        var options = new DbContextOptionsBuilder<TestDbContext>()
            .UseInMemoryDatabase(databaseName: $"PushNotifTests_{Guid.NewGuid()}")
            .Options;
        _dbContext = new TestDbContext(options);

        _service = new PushNotificationService(
            _mockDeviceTokenService.Object,
            _mockPreferenceService.Object,
            _mockApnsService.Object,
            _mockFcmService.Object,
            _dbContext,
            _mockCorrelationIdService.Object,
            _mockLogger.Object);

        _testPayload = new PushNotificationPayload(
            "Test Title",
            "Test Body",
            "SubmissionStatusUpdate",
            new Dictionary<string, string> { ["packageId"] = "pkg-123" },
            "app://submissions/pkg-123");
    }

    public void Dispose()
    {
        _dbContext.Dispose();
    }

    // ── SendAsync ──

    [Fact]
    public async Task SendAsync_SingleDevice_ShouldSendNotification()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var device = CreateDeviceToken(userId, "Android", "fcm-token-1");

        _mockPreferenceService
            .Setup(p => p.IsNotificationEnabledAsync(userId, "SubmissionStatusUpdate", "Push", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _mockDeviceTokenService
            .Setup(d => d.GetUserDeviceTokensAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { device });
        _mockFcmService
            .Setup(f => f.SendAsync("fcm-token-1", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        await _service.SendAsync(userId, _testPayload, CancellationToken.None);

        // Assert
        _mockFcmService.Verify(f => f.SendAsync("fcm-token-1", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendAsync_MultipleDevices_ShouldSendToAll()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var devices = new[]
        {
            CreateDeviceToken(userId, "iOS", "apns-token"),
            CreateDeviceToken(userId, "Android", "fcm-token")
        };

        _mockPreferenceService
            .Setup(p => p.IsNotificationEnabledAsync(userId, It.IsAny<string>(), "Push", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _mockDeviceTokenService
            .Setup(d => d.GetUserDeviceTokensAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(devices);
        _mockApnsService
            .Setup(a => a.SendAsync("apns-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());
        _mockFcmService
            .Setup(f => f.SendAsync("fcm-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        await _service.SendAsync(userId, _testPayload, CancellationToken.None);

        // Assert
        _mockApnsService.Verify(a => a.SendAsync("apns-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()), Times.Once);
        _mockFcmService.Verify(f => f.SendAsync("fcm-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendAsync_NoDevices_ShouldSkipDelivery()
    {
        // Arrange
        var userId = Guid.NewGuid();

        _mockPreferenceService
            .Setup(p => p.IsNotificationEnabledAsync(userId, It.IsAny<string>(), "Push", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _mockDeviceTokenService
            .Setup(d => d.GetUserDeviceTokensAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(Enumerable.Empty<DeviceToken>());

        // Act
        await _service.SendAsync(userId, _testPayload, CancellationToken.None);

        // Assert
        _mockApnsService.Verify(a => a.SendAsync(It.IsAny<string>(), It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()), Times.Never);
        _mockFcmService.Verify(f => f.SendAsync(It.IsAny<string>(), It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SendAsync_PushDisabled_ShouldSkipDelivery()
    {
        // Arrange
        var userId = Guid.NewGuid();

        _mockPreferenceService
            .Setup(p => p.IsNotificationEnabledAsync(userId, It.IsAny<string>(), "Push", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        // Act
        await _service.SendAsync(userId, _testPayload, CancellationToken.None);

        // Assert
        _mockDeviceTokenService.Verify(d => d.GetUserDeviceTokensAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    // ── SendToDeviceAsync ──

    [Fact]
    public async Task SendToDeviceAsync_iOS_ShouldCallApnsService()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "iOS", "apns-token-123");
        _mockApnsService
            .Setup(a => a.SendAsync("apns-token-123", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        var result = await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
        _mockApnsService.Verify(a => a.SendAsync("apns-token-123", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()), Times.Once);
        _mockFcmService.Verify(f => f.SendAsync(It.IsAny<string>(), It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SendToDeviceAsync_Android_ShouldCallFcmService()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "Android", "fcm-android-token");
        _mockFcmService
            .Setup(f => f.SendAsync("fcm-android-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        var result = await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
        _mockFcmService.Verify(f => f.SendAsync("fcm-android-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendToDeviceAsync_Web_ShouldCallFcmService()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "Web", "fcm-web-token");
        _mockFcmService
            .Setup(f => f.SendAsync("fcm-web-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        var result = await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
        _mockFcmService.Verify(f => f.SendAsync("fcm-web-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    // ── Invalid token detection ──

    [Fact]
    public async Task SendToDeviceAsync_InvalidToken_ShouldRemoveToken()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "Android", "bad-token");
        _mockFcmService
            .Setup(f => f.SendAsync("bad-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Failed("Invalid token", "UNREGISTERED", isInvalidToken: true));

        // Act
        var result = await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsInvalidToken);
        _mockDeviceTokenService.Verify(
            d => d.RemoveInvalidTokenAsync(device.Id, It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    // ── Payload formatting tests ──

    [Fact]
    public async Task SendToDeviceAsync_iOS_ShouldFormatApnsPayload()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "iOS", "apns-token");
        ApnsPayload? capturedPayload = null;
        
        _mockApnsService
            .Setup(a => a.SendAsync("apns-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .Callback<string, ApnsPayload, CancellationToken>((token, payload, ct) => capturedPayload = payload)
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.NotNull(capturedPayload);
        Assert.Equal("Test Title", capturedPayload.Title);
        Assert.Equal("Test Body", capturedPayload.Body);
        Assert.Equal("default", capturedPayload.Sound);
        Assert.Equal(1, capturedPayload.Badge);
        Assert.Equal("app://submissions/pkg-123", capturedPayload.CustomData["deepLink"]);
        Assert.Equal("SubmissionStatusUpdate", capturedPayload.CustomData["notificationType"]);
        Assert.Equal("pkg-123", capturedPayload.CustomData["packageId"]);
    }

    [Fact]
    public async Task SendToDeviceAsync_Android_ShouldFormatFcmPayload()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "Android", "fcm-token");
        FcmPayload? capturedPayload = null;
        
        _mockFcmService
            .Setup(f => f.SendAsync("fcm-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .Callback<string, FcmPayload, CancellationToken>((token, payload, ct) => capturedPayload = payload)
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.NotNull(capturedPayload);
        Assert.Equal("Test Title", capturedPayload.Title);
        Assert.Equal("Test Body", capturedPayload.Body);
        Assert.Equal("app://submissions/pkg-123", capturedPayload.Data["deepLink"]);
        Assert.Equal("SubmissionStatusUpdate", capturedPayload.Data["notificationType"]);
        Assert.Equal("pkg-123", capturedPayload.Data["packageId"]);
        
        // Android config
        Assert.NotNull(capturedPayload.AndroidConfig);
        Assert.Equal("high", capturedPayload.AndroidConfig.Priority);
        
        // Web config
        Assert.NotNull(capturedPayload.WebpushConfig);
        Assert.Equal("3600", capturedPayload.WebpushConfig.Headers!["TTL"]);
    }

    [Fact]
    public async Task SendToDeviceAsync_LongTitle_ShouldTruncateApnsPayload()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "iOS", "apns-token");
        var longTitle = new string('A', 70); // Exceeds APNs limit of 65
        var longPayload = _testPayload with { Title = longTitle };
        ApnsPayload? capturedPayload = null;
        
        _mockApnsService
            .Setup(a => a.SendAsync("apns-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .Callback<string, ApnsPayload, CancellationToken>((token, payload, ct) => capturedPayload = payload)
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        await _service.SendToDeviceAsync(device, longPayload, CancellationToken.None);

        // Assert
        Assert.NotNull(capturedPayload);
        Assert.Equal(65, capturedPayload.Title.Length);
        Assert.EndsWith("...", capturedPayload.Title);
    }

    [Fact]
    public async Task SendToDeviceAsync_LongBody_ShouldTruncateFcmPayload()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "Android", "fcm-token");
        var longBody = new string('B', 4005); // Exceeds FCM limit of 4000
        var longPayload = _testPayload with { Body = longBody };
        FcmPayload? capturedPayload = null;
        
        _mockFcmService
            .Setup(f => f.SendAsync("fcm-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .Callback<string, FcmPayload, CancellationToken>((token, payload, ct) => capturedPayload = payload)
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        await _service.SendToDeviceAsync(device, longPayload, CancellationToken.None);

        // Assert
        Assert.NotNull(capturedPayload);
        Assert.Equal(4000, capturedPayload.Body.Length);
        Assert.EndsWith("...", capturedPayload.Body);
    }

    // ── Exception handling and retry logic ──

    [Fact]
    public async Task SendToDeviceAsync_ServiceException_ShouldReturnFailedResult()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "iOS", "exception-token");
        _mockApnsService
            .Setup(a => a.SendAsync("exception-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Network error"));

        // Act
        var result = await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("Network error", result.ErrorMessage);
        Assert.Equal("SEND_EXCEPTION", result.ErrorCode);
    }

    [Fact]
    public async Task SendToDeviceAsync_TransientFailure_ShouldReturnTransientResult()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "Android", "transient-token");
        _mockFcmService
            .Setup(f => f.SendAsync("transient-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Failed("Rate limited", "RATE_LIMITED", isTransient: true));

        // Act
        var result = await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsTransient);
        Assert.Equal("Rate limited", result.ErrorMessage);
        Assert.Equal("RATE_LIMITED", result.ErrorCode);
    }

    [Fact]
    public async Task SendToDeviceAsync_NonRetryableError_ShouldReturnNonTransientResult()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "iOS", "bad-payload-token");
        _mockApnsService
            .Setup(a => a.SendAsync("bad-payload-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Failed("Bad payload", "BAD_PAYLOAD", isTransient: false));

        // Act
        var result = await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.False(result.IsTransient);
        Assert.Equal("Bad payload", result.ErrorMessage);
        Assert.Equal("BAD_PAYLOAD", result.ErrorCode);
    }

    // ── SendBatchAsync tests ──

    [Fact]
    public async Task SendBatchAsync_MixedPlatforms_ShouldGroupByPlatform()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var devices = new[]
        {
            CreateDeviceToken(userId, "iOS", "apns-token-1"),
            CreateDeviceToken(userId, "iOS", "apns-token-2"),
            CreateDeviceToken(userId, "Android", "fcm-android-token-1"),
            CreateDeviceToken(userId, "Android", "fcm-android-token-2")
        };

        _mockApnsService
            .Setup(a => a.SendAsync(It.IsAny<string>(), It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());
        _mockFcmService
            .Setup(f => f.SendMulticastAsync(It.IsAny<IEnumerable<string>>(), It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { NotificationResult.Succeeded(), NotificationResult.Succeeded() });

        // Act
        await _service.SendBatchAsync(devices, _testPayload, CancellationToken.None);

        // Assert
        // iOS devices sent individually via APNs (APNs doesn't support multicast)
        _mockApnsService.Verify(a => a.SendAsync("apns-token-1", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()), Times.Once);
        _mockApnsService.Verify(a => a.SendAsync("apns-token-2", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()), Times.Once);
        
        // Android devices sent via FCM multicast (grouped by platform)
        _mockFcmService.Verify(f => f.SendMulticastAsync(
            It.Is<IEnumerable<string>>(tokens => tokens.Contains("fcm-android-token-1") && tokens.Contains("fcm-android-token-2")),
            It.IsAny<FcmPayload>(),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendBatchAsync_AndroidAndWebSeparately_ShouldGroupByPlatform()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var devices = new[]
        {
            CreateDeviceToken(userId, "Android", "fcm-android-token"),
            CreateDeviceToken(userId, "Web", "fcm-web-token")
        };

        _mockFcmService
            .Setup(f => f.SendMulticastAsync(It.IsAny<IEnumerable<string>>(), It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { NotificationResult.Succeeded() });

        // Act
        await _service.SendBatchAsync(devices, _testPayload, CancellationToken.None);

        // Assert
        // Android and Web are different platforms, so they get separate multicast calls
        _mockFcmService.Verify(f => f.SendMulticastAsync(
            It.Is<IEnumerable<string>>(tokens => tokens.Contains("fcm-android-token") && tokens.Count() == 1),
            It.IsAny<FcmPayload>(),
            It.IsAny<CancellationToken>()), Times.Once);
        _mockFcmService.Verify(f => f.SendMulticastAsync(
            It.Is<IEnumerable<string>>(tokens => tokens.Contains("fcm-web-token") && tokens.Count() == 1),
            It.IsAny<FcmPayload>(),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendBatchAsync_FcmException_ShouldCreateFailedResults()
    {
        // Arrange
        var devices = new[]
        {
            CreateDeviceToken(Guid.NewGuid(), "Android", "fcm-token-1"),
            CreateDeviceToken(Guid.NewGuid(), "Android", "fcm-token-2")
        };

        _mockFcmService
            .Setup(f => f.SendMulticastAsync(It.IsAny<IEnumerable<string>>(), It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("FCM service unavailable"));

        // Act
        await _service.SendBatchAsync(devices, _testPayload, CancellationToken.None);

        // Assert
        // Should log failed attempts for both devices
        var logs = await _dbContext.NotificationLogs.ToListAsync();
        Assert.Equal(2, logs.Count);
        Assert.All(logs, log => Assert.Equal("Failed", log.Status));
    }

    [Fact]
    public async Task SendBatchAsync_ApnsException_ShouldLogFailedAttempt()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "iOS", "apns-exception-token");
        _mockApnsService
            .Setup(a => a.SendAsync("apns-exception-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("APNs connection failed"));

        // Act
        await _service.SendBatchAsync(new[] { device }, _testPayload, CancellationToken.None);

        // Assert
        var log = await _dbContext.NotificationLogs.FirstOrDefaultAsync();
        Assert.NotNull(log);
        Assert.Equal("Failed", log.Status);
        Assert.Contains("APNs connection failed", log.ErrorMessage);
    }

    [Fact]
    public async Task SendBatchAsync_InvalidTokensInBatch_ShouldRemoveInvalidTokens()
    {
        // Arrange
        var devices = new[]
        {
            CreateDeviceToken(Guid.NewGuid(), "Android", "valid-token"),
            CreateDeviceToken(Guid.NewGuid(), "Android", "invalid-token")
        };

        _mockFcmService
            .Setup(f => f.SendMulticastAsync(It.IsAny<IEnumerable<string>>(), It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[]
            {
                NotificationResult.Succeeded(),
                NotificationResult.Failed("Invalid token", "UNREGISTERED", isInvalidToken: true)
            });

        // Act
        await _service.SendBatchAsync(devices, _testPayload, CancellationToken.None);

        // Assert
        _mockDeviceTokenService.Verify(
            d => d.RemoveInvalidTokenAsync(devices[1].Id, It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Once);
        _mockDeviceTokenService.Verify(
            d => d.RemoveInvalidTokenAsync(devices[0].Id, It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    // ── Edge cases ──

    [Fact]
    public async Task SendAsync_CaseInsensitivePlatform_ShouldWork()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var device = CreateDeviceToken(userId, "ios", "lowercase-platform-token"); // lowercase

        _mockPreferenceService
            .Setup(p => p.IsNotificationEnabledAsync(userId, It.IsAny<string>(), "Push", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _mockDeviceTokenService
            .Setup(d => d.GetUserDeviceTokensAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new[] { device });
        _mockApnsService
            .Setup(a => a.SendAsync("lowercase-platform-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        await _service.SendAsync(userId, _testPayload, CancellationToken.None);

        // Assert
        _mockApnsService.Verify(a => a.SendAsync("lowercase-platform-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendToDeviceAsync_EmptyPayloadData_ShouldHandleGracefully()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "Android", "empty-data-token");
        var emptyDataPayload = new PushNotificationPayload(
            "Title", "Body", "TestType", new Dictionary<string, string>(), "app://test");
        
        _mockFcmService
            .Setup(f => f.SendAsync("empty-data-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        var result = await _service.SendToDeviceAsync(device, emptyDataPayload, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
        _mockFcmService.Verify(f => f.SendAsync("empty-data-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendBatchAsync_EmptyDeviceList_ShouldCompleteWithoutError()
    {
        // Arrange
        var emptyDevices = Enumerable.Empty<DeviceToken>();

        // Act & Assert - should not throw
        await _service.SendBatchAsync(emptyDevices, _testPayload, CancellationToken.None);

        // Verify no service calls were made
        _mockApnsService.Verify(a => a.SendAsync(It.IsAny<string>(), It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()), Times.Never);
        _mockFcmService.Verify(f => f.SendMulticastAsync(It.IsAny<IEnumerable<string>>(), It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    // ── Notification logging ──

    [Fact]
    public async Task SendToDeviceAsync_Success_ShouldLogNotificationAttempt()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "iOS", "log-test-token");
        _mockApnsService
            .Setup(a => a.SendAsync("log-test-token", It.IsAny<ApnsPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Succeeded());

        // Act
        await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        var log = await _dbContext.NotificationLogs.FirstOrDefaultAsync();
        Assert.NotNull(log);
        Assert.Equal(device.UserId, log.UserId);
        Assert.Equal(device.Id, log.DeviceTokenId);
        Assert.Equal("SubmissionStatusUpdate", log.NotificationType);
        Assert.Equal("Push", log.Channel);
        Assert.Equal("iOS", log.Platform);
        Assert.Equal("Sent", log.Status);
        Assert.Null(log.ErrorMessage);
        Assert.Equal("test-correlation-id", log.CorrelationId);
    }

    [Fact]
    public async Task SendToDeviceAsync_Failure_ShouldLogFailedAttempt()
    {
        // Arrange
        var device = CreateDeviceToken(Guid.NewGuid(), "Android", "failed-log-token");
        _mockFcmService
            .Setup(f => f.SendAsync("failed-log-token", It.IsAny<FcmPayload>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(NotificationResult.Failed("Service unavailable", "SERVICE_UNAVAILABLE"));

        // Act
        await _service.SendToDeviceAsync(device, _testPayload, CancellationToken.None);

        // Assert
        var log = await _dbContext.NotificationLogs.FirstOrDefaultAsync();
        Assert.NotNull(log);
        Assert.Equal("Failed", log.Status);
        Assert.Equal("Service unavailable", log.ErrorMessage);
        Assert.Equal("test-correlation-id", log.CorrelationId);
    }

    // ── Helper ──

    private static DeviceToken CreateDeviceToken(Guid userId, string platform, string token)
    {
        return new DeviceToken
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Platform = platform,
            Token = token,
            RegisteredAt = DateTime.UtcNow,
            LastUsedAt = DateTime.UtcNow,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
    }
}
