using BajajDocumentProcessing.API.Controllers;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using System.Security.Claims;
using Xunit;

namespace BajajDocumentProcessing.Tests.API;

/// <summary>
/// Unit tests for PushNotificationsController
/// </summary>
public class PushNotificationsControllerTests : IDisposable
{
    private readonly Mock<IDeviceTokenService> _mockDeviceTokenService;
    private readonly Mock<INotificationPreferenceService> _mockPreferenceService;
    private readonly Mock<ICorrelationIdService> _mockCorrelationIdService;
    private readonly Mock<ILogger<PushNotificationsController>> _mockLogger;
    private readonly Infrastructure.TestDbContext _dbContext;
    private readonly PushNotificationsController _controller;
    private readonly Guid _testUserId = Guid.NewGuid();

    public PushNotificationsControllerTests()
    {
        _mockDeviceTokenService = new Mock<IDeviceTokenService>();
        _mockPreferenceService = new Mock<INotificationPreferenceService>();
        _mockCorrelationIdService = new Mock<ICorrelationIdService>();
        _mockLogger = new Mock<ILogger<PushNotificationsController>>();

        _mockCorrelationIdService.Setup(c => c.GetCorrelationId()).Returns("test-corr-id");

        var options = new DbContextOptionsBuilder<Infrastructure.TestDbContext>()
            .UseInMemoryDatabase(databaseName: $"ControllerTests_{Guid.NewGuid()}")
            .Options;
        _dbContext = new Infrastructure.TestDbContext(options);

        _controller = new PushNotificationsController(
            _mockDeviceTokenService.Object,
            _mockPreferenceService.Object,
            _dbContext,
            _mockCorrelationIdService.Object,
            _mockLogger.Object);

        SetupAuthenticatedUser(_testUserId);
    }

    public void Dispose()
    {
        _dbContext.Dispose();
    }

    // ── RegisterDeviceTokenAsync ──

    [Fact]
    public async Task RegisterDeviceTokenAsync_ValidRequest_ShouldReturn201()
    {
        // Arrange
        var request = new RegisterDeviceTokenRequest("valid-token", "iOS");
        var response = new DeviceTokenResponse(Guid.NewGuid(), "iOS", DateTime.UtcNow, DateTime.UtcNow, true);

        _mockDeviceTokenService
            .Setup(s => s.RegisterAsync(_testUserId, request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);

        // Act
        var result = await _controller.RegisterDeviceTokenAsync(request);

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status201Created, objectResult.StatusCode);
    }

    [Fact]
    public async Task RegisterDeviceTokenAsync_InvalidPlatform_ShouldReturn500WhenServiceThrows()
    {
        // Arrange
        var request = new RegisterDeviceTokenRequest("token", "BlackBerry");

        _mockDeviceTokenService
            .Setup(s => s.RegisterAsync(_testUserId, request, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new ArgumentException("Invalid platform"));

        // Act
        var result = await _controller.RegisterDeviceTokenAsync(request);

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    [Fact]
    public async Task RegisterDeviceTokenAsync_DuplicateToken_ShouldReturn201WithUpdatedRecord()
    {
        // Arrange - simulate duplicate token registration (service handles the update logic)
        var request = new RegisterDeviceTokenRequest("duplicate-token", "iOS");
        var response = new DeviceTokenResponse(Guid.NewGuid(), "iOS", DateTime.UtcNow.AddDays(-1), DateTime.UtcNow, true);

        _mockDeviceTokenService
            .Setup(s => s.RegisterAsync(_testUserId, request, It.IsAny<CancellationToken>()))
            .ReturnsAsync(response);

        // Act
        var result = await _controller.RegisterDeviceTokenAsync(request);

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status201Created, objectResult.StatusCode);
        var returnedResponse = Assert.IsType<DeviceTokenResponse>(objectResult.Value);
        Assert.Equal("iOS", returnedResponse.Platform);
        Assert.True(returnedResponse.IsActive);
    }

    [Fact]
    public async Task RegisterDeviceTokenAsync_Unauthorized_ShouldReturn401()
    {
        // Arrange
        SetupUnauthenticatedUser();
        var request = new RegisterDeviceTokenRequest("token", "iOS");

        // Act
        var result = await _controller.RegisterDeviceTokenAsync(request);

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    // ── DeregisterDeviceTokenAsync ──

    [Fact]
    public async Task DeregisterDeviceTokenAsync_ExistingToken_ShouldReturn204()
    {
        // Arrange
        var tokenId = Guid.NewGuid();
        _mockDeviceTokenService
            .Setup(s => s.DeregisterAsync(_testUserId, tokenId, It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.DeregisterDeviceTokenAsync(tokenId);

        // Assert
        Assert.IsType<NoContentResult>(result);
    }

    [Fact]
    public async Task DeregisterDeviceTokenAsync_NonExistentToken_ShouldReturn404()
    {
        // Arrange
        var tokenId = Guid.NewGuid();
        _mockDeviceTokenService
            .Setup(s => s.DeregisterAsync(_testUserId, tokenId, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Not found"));

        // Act
        var result = await _controller.DeregisterDeviceTokenAsync(tokenId);

        // Assert
        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task DeregisterDeviceTokenAsync_Unauthorized_ShouldReturn401()
    {
        // Arrange
        SetupUnauthenticatedUser();
        var tokenId = Guid.NewGuid();

        // Act
        var result = await _controller.DeregisterDeviceTokenAsync(tokenId);

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    [Fact]
    public async Task DeregisterDeviceTokenAsync_ServiceException_ShouldReturn500()
    {
        // Arrange
        var tokenId = Guid.NewGuid();
        _mockDeviceTokenService
            .Setup(s => s.DeregisterAsync(_testUserId, tokenId, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _controller.DeregisterDeviceTokenAsync(tokenId);

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    // ── GetPreferencesAsync ──

    [Fact]
    public async Task GetPreferencesAsync_ShouldReturnPreferences()
    {
        // Arrange
        var prefs = new NotificationPreferenceResponse(
            _testUserId,
            new[]
            {
                new NotificationTypePreference("SubmissionStatusUpdate", true, true),
                new NotificationTypePreference("ApprovalDecision", false, true)
            });

        _mockPreferenceService
            .Setup(s => s.GetPreferencesAsync(_testUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(prefs);

        // Act
        var result = await _controller.GetPreferencesAsync();

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationPreferenceResponse>(okResult.Value);
        Assert.Equal(2, response.Preferences.Count());
    }

    [Fact]
    public async Task GetPreferencesAsync_NoExistingPreferences_ShouldReturnDefaults()
    {
        // Arrange - service returns default preferences when none exist
        var defaultPrefs = new NotificationPreferenceResponse(
            _testUserId,
            new[]
            {
                new NotificationTypePreference("SubmissionStatusUpdate", true, true),
                new NotificationTypePreference("ApprovalDecision", true, true),
                new NotificationTypePreference("ValidationFailure", true, true),
                new NotificationTypePreference("Recommendation", true, true)
            });

        _mockPreferenceService
            .Setup(s => s.GetPreferencesAsync(_testUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(defaultPrefs);

        // Act
        var result = await _controller.GetPreferencesAsync();

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationPreferenceResponse>(okResult.Value);
        Assert.Equal(4, response.Preferences.Count());
        Assert.All(response.Preferences, p => Assert.True(p.IsPushEnabled && p.IsEmailEnabled));
    }

    [Fact]
    public async Task GetPreferencesAsync_Unauthorized_ShouldReturn401()
    {
        // Arrange
        SetupUnauthenticatedUser();

        // Act
        var result = await _controller.GetPreferencesAsync();

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    [Fact]
    public async Task GetPreferencesAsync_ServiceException_ShouldReturn500()
    {
        // Arrange
        _mockPreferenceService
            .Setup(s => s.GetPreferencesAsync(_testUserId, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _controller.GetPreferencesAsync();

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    // ── UpdatePreferencesAsync ──

    [Fact]
    public async Task UpdatePreferencesAsync_ValidUpdate_ShouldReturnOk()
    {
        // Arrange
        var request = new UpdateNotificationPreferenceRequest("SubmissionStatusUpdate", false, true);
        var updatedPrefs = new NotificationPreferenceResponse(
            _testUserId,
            new[] { new NotificationTypePreference("SubmissionStatusUpdate", false, true) });

        _mockPreferenceService
            .Setup(s => s.UpdatePreferencesAsync(_testUserId, request, It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _mockPreferenceService
            .Setup(s => s.GetPreferencesAsync(_testUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(updatedPrefs);

        // Act
        var result = await _controller.UpdatePreferencesAsync(request);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.IsType<NotificationPreferenceResponse>(okResult.Value);
    }

    [Fact]
    public async Task UpdatePreferencesAsync_InvalidNotificationType_ShouldReturn500WhenServiceThrows()
    {
        // Arrange
        var request = new UpdateNotificationPreferenceRequest("InvalidType", true, true);

        _mockPreferenceService
            .Setup(s => s.UpdatePreferencesAsync(_testUserId, request, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new ArgumentException("Invalid notification type"));

        // Act
        var result = await _controller.UpdatePreferencesAsync(request);

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    [Fact]
    public async Task UpdatePreferencesAsync_Unauthorized_ShouldReturn401()
    {
        // Arrange
        SetupUnauthenticatedUser();
        var request = new UpdateNotificationPreferenceRequest("SubmissionStatusUpdate", false, true);

        // Act
        var result = await _controller.UpdatePreferencesAsync(request);

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    [Fact]
    public async Task UpdatePreferencesAsync_ServiceException_ShouldReturn500()
    {
        // Arrange
        var request = new UpdateNotificationPreferenceRequest("SubmissionStatusUpdate", false, true);
        
        _mockPreferenceService
            .Setup(s => s.UpdatePreferencesAsync(_testUserId, request, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _controller.UpdatePreferencesAsync(request);

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    // ── GetNotificationHistoryAsync ──

    [Fact]
    public async Task GetNotificationHistoryAsync_ShouldReturnPaginatedResults()
    {
        // Arrange
        for (int i = 0; i < 5; i++)
        {
            _dbContext.NotificationLogs.Add(new NotificationLog
            {
                Id = Guid.NewGuid(),
                UserId = _testUserId,
                NotificationType = "SubmissionStatusUpdate",
                Channel = "Push",
                Platform = "iOS",
                Status = "Sent",
                SentAt = DateTime.UtcNow.AddMinutes(-i),
                CorrelationId = $"corr-{i}",
                CreatedAt = DateTime.UtcNow
            });
        }
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _controller.GetNotificationHistoryAsync(pageNumber: 1, pageSize: 3);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationHistoryResponse>(okResult.Value);
        Assert.Equal(3, response.Items.Count());
        Assert.Equal(5, response.TotalCount);
        Assert.Equal(1, response.PageNumber);
        Assert.Equal(3, response.PageSize);
    }

    [Fact]
    public async Task GetNotificationHistoryAsync_WithTypeFilter_ShouldFilterResults()
    {
        // Arrange
        _dbContext.NotificationLogs.Add(new NotificationLog
        {
            Id = Guid.NewGuid(),
            UserId = _testUserId,
            NotificationType = "ApprovalDecision",
            Channel = "Push",
            Platform = "Android",
            Status = "Sent",
            SentAt = DateTime.UtcNow,
            CorrelationId = "corr-1",
            CreatedAt = DateTime.UtcNow
        });
        _dbContext.NotificationLogs.Add(new NotificationLog
        {
            Id = Guid.NewGuid(),
            UserId = _testUserId,
            NotificationType = "ValidationFailure",
            Channel = "Push",
            Platform = "iOS",
            Status = "Failed",
            SentAt = DateTime.UtcNow,
            CorrelationId = "corr-2",
            CreatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _controller.GetNotificationHistoryAsync(notificationType: "ApprovalDecision");

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationHistoryResponse>(okResult.Value);
        Assert.Single(response.Items);
        Assert.Equal("ApprovalDecision", response.Items.First().NotificationType);
    }

    [Fact]
    public async Task GetNotificationHistoryAsync_InvalidPageNumber_ShouldReturn400()
    {
        // Act
        var result = await _controller.GetNotificationHistoryAsync(pageNumber: 0);

        // Assert
        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task GetNotificationHistoryAsync_InvalidPageSize_ShouldReturn400()
    {
        // Act
        var result = await _controller.GetNotificationHistoryAsync(pageSize: 101);

        // Assert
        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task GetNotificationHistoryAsync_WithDateRangeFilter_ShouldFilterResults()
    {
        // Arrange
        var baseDate = DateTime.UtcNow.Date;
        _dbContext.NotificationLogs.Add(new NotificationLog
        {
            Id = Guid.NewGuid(),
            UserId = _testUserId,
            NotificationType = "SubmissionStatusUpdate",
            Channel = "Push",
            Platform = "iOS",
            Status = "Sent",
            SentAt = baseDate.AddDays(-1), // Within range
            CorrelationId = "corr-1",
            CreatedAt = DateTime.UtcNow
        });
        _dbContext.NotificationLogs.Add(new NotificationLog
        {
            Id = Guid.NewGuid(),
            UserId = _testUserId,
            NotificationType = "ApprovalDecision",
            Channel = "Push",
            Platform = "Android",
            Status = "Sent",
            SentAt = baseDate.AddDays(-5), // Outside range
            CorrelationId = "corr-2",
            CreatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _controller.GetNotificationHistoryAsync(
            startDate: baseDate.AddDays(-2),
            endDate: baseDate);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationHistoryResponse>(okResult.Value);
        Assert.Single(response.Items);
        Assert.Equal("SubmissionStatusUpdate", response.Items.First().NotificationType);
    }

    [Fact]
    public async Task GetNotificationHistoryAsync_WithStatusFilter_ShouldFilterResults()
    {
        // Arrange
        _dbContext.NotificationLogs.Add(new NotificationLog
        {
            Id = Guid.NewGuid(),
            UserId = _testUserId,
            NotificationType = "SubmissionStatusUpdate",
            Channel = "Push",
            Platform = "iOS",
            Status = "Sent",
            SentAt = DateTime.UtcNow,
            CorrelationId = "corr-1",
            CreatedAt = DateTime.UtcNow
        });
        _dbContext.NotificationLogs.Add(new NotificationLog
        {
            Id = Guid.NewGuid(),
            UserId = _testUserId,
            NotificationType = "ApprovalDecision",
            Channel = "Push",
            Platform = "Android",
            Status = "Failed",
            SentAt = DateTime.UtcNow,
            CorrelationId = "corr-2",
            CreatedAt = DateTime.UtcNow
        });
        await _dbContext.SaveChangesAsync();

        // Act
        var result = await _controller.GetNotificationHistoryAsync(status: "Failed");

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationHistoryResponse>(okResult.Value);
        Assert.Single(response.Items);
        Assert.Equal("Failed", response.Items.First().Status);
    }

    [Fact]
    public async Task GetNotificationHistoryAsync_EmptyResults_ShouldReturnEmptyList()
    {
        // Act - no data in database
        var result = await _controller.GetNotificationHistoryAsync();

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationHistoryResponse>(okResult.Value);
        Assert.Empty(response.Items);
        Assert.Equal(0, response.TotalCount);
    }

    [Fact]
    public async Task GetNotificationHistoryAsync_Unauthorized_ShouldReturn401()
    {
        // Arrange
        SetupUnauthenticatedUser();

        // Act
        var result = await _controller.GetNotificationHistoryAsync();

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }

    [Fact]
    public async Task GetNotificationHistoryAsync_DatabaseException_ShouldReturn500()
    {
        // Arrange - force database exception by disposing context
        _dbContext.Dispose();

        // Act
        var result = await _controller.GetNotificationHistoryAsync();

        // Assert
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    // ── Helpers ──

    private void SetupAuthenticatedUser(Guid userId)
    {
        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Email, "test@example.com"),
            new Claim(ClaimTypes.Role, "Agency")
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var claimsPrincipal = new ClaimsPrincipal(identity);
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = claimsPrincipal }
        };
    }

    private void SetupUnauthenticatedUser()
    {
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal() }
        };
    }
}
