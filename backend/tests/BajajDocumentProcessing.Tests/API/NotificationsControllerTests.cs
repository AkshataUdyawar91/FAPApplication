using BajajDocumentProcessing.API.Controllers;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using System.Security.Claims;
using Xunit;

namespace BajajDocumentProcessing.Tests.API;

/// <summary>
/// Tests for NotificationsController API endpoints
/// </summary>
public class NotificationsControllerTests
{
    private readonly Mock<INotificationAgent> _mockNotificationAgent;
    private readonly Mock<ILogger<NotificationsController>> _mockLogger;
    private readonly NotificationsController _controller;
    private readonly Guid _testUserId = Guid.NewGuid();

    public NotificationsControllerTests()
    {
        _mockNotificationAgent = new Mock<INotificationAgent>();
        _mockLogger = new Mock<ILogger<NotificationsController>>();
        _controller = new NotificationsController(_mockNotificationAgent.Object, _mockLogger.Object);

        // Setup user claims
        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, _testUserId.ToString()),
            new Claim(ClaimTypes.Email, "test@example.com"),
            new Claim(ClaimTypes.Role, "ASM")
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var claimsPrincipal = new ClaimsPrincipal(identity);
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = claimsPrincipal }
        };
    }

    [Fact]
    public async Task GetNotifications_ShouldReturnNotifications()
    {
        // Arrange
        var notifications = new List<Notification>
        {
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = _testUserId,
                Type = NotificationType.SubmissionReceived,
                Title = "New Submission",
                Message = "A new document package has been submitted",
                IsRead = false,
                CreatedAt = DateTime.UtcNow
            }
        };

        _mockNotificationAgent
            .Setup(x => x.GetUserNotificationsAsync(_testUserId, false, It.IsAny<CancellationToken>()))
            .ReturnsAsync(notifications);

        _mockNotificationAgent
            .Setup(x => x.GetUnreadCountAsync(_testUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        // Act
        var result = await _controller.GetNotifications(unreadOnly: false);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationListResponse>(okResult.Value);
        Assert.Single(response.Notifications);
        Assert.Equal(1, response.UnreadCount);
    }

    [Fact]
    public async Task GetNotifications_UnreadOnly_ShouldFilterUnread()
    {
        // Arrange
        var unreadNotifications = new List<Notification>
        {
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = _testUserId,
                Type = NotificationType.FlaggedForReview,
                Title = "Flagged",
                Message = "Package flagged for review",
                IsRead = false,
                CreatedAt = DateTime.UtcNow
            }
        };

        _mockNotificationAgent
            .Setup(x => x.GetUserNotificationsAsync(_testUserId, true, It.IsAny<CancellationToken>()))
            .ReturnsAsync(unreadNotifications);

        _mockNotificationAgent
            .Setup(x => x.GetUnreadCountAsync(_testUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        // Act
        var result = await _controller.GetNotifications(unreadOnly: true);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<NotificationListResponse>(okResult.Value);
        Assert.Single(response.Notifications);
        Assert.False(response.Notifications[0].IsRead);
    }

    [Fact]
    public async Task GetUnreadCount_ShouldReturnCount()
    {
        // Arrange
        _mockNotificationAgent
            .Setup(x => x.GetUnreadCountAsync(_testUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(5);

        // Act
        var result = await _controller.GetUnreadCount();

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var value = okResult.Value;
        Assert.NotNull(value);
        
        // Use reflection to get the unreadCount property
        var unreadCountProperty = value.GetType().GetProperty("unreadCount");
        Assert.NotNull(unreadCountProperty);
        var unreadCount = (int)unreadCountProperty.GetValue(value)!;
        Assert.Equal(5, unreadCount);
    }

    [Fact]
    public async Task MarkAsRead_ShouldMarkNotificationAsRead()
    {
        // Arrange
        var notificationId = Guid.NewGuid();
        _mockNotificationAgent
            .Setup(x => x.MarkAsReadAsync(notificationId, It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _controller.MarkAsRead(notificationId);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        _mockNotificationAgent.Verify(
            x => x.MarkAsReadAsync(notificationId, It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task MarkAsRead_NotFound_ShouldReturn404()
    {
        // Arrange
        var notificationId = Guid.NewGuid();
        _mockNotificationAgent
            .Setup(x => x.MarkAsReadAsync(notificationId, It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Notification not found"));

        // Act
        var result = await _controller.MarkAsRead(notificationId);

        // Assert
        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task GetNotifications_Unauthorized_ShouldReturn401()
    {
        // Arrange - Remove user claims
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal() }
        };

        // Act
        var result = await _controller.GetNotifications();

        // Assert
        Assert.IsType<UnauthorizedObjectResult>(result);
    }
}
