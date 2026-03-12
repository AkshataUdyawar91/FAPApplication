using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Query;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 36: Submission Notification Creation
/// Validates: Requirements 8.1, 8.2
/// 
/// Property: When a submission is received, a notification should be created for the ASM
/// </summary>
public class NotificationAgentProperties
{
    /// <summary>
    /// Property: Submission received notification should be created for ASM
    /// </summary>
    [Property(MaxTest = 10)]
    public Property SubmissionNotification_ShouldBeCreatedForASM()
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            Arb.Default.Guid().Generator.ToArbitrary(),
            (userId, packageId) =>
            {
                // Arrange
                var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
                SetupMockUser(mockContext, userId, UserRole.ASM);
                SetupMockNotifications(mockContext, new List<Notification>());

                // Act
                agent.SendNotificationAsync(
                    userId,
                    NotificationType.SubmissionReceived,
                    "New Submission",
                    "A new document package has been submitted",
                    packageId,
                    sendEmail: false,
                    CancellationToken.None
                ).GetAwaiter().GetResult();

                // Assert - notification should be added
                mockContext.Verify(
                    c => c.SaveChangesAsync(It.IsAny<CancellationToken>()),
                    Times.Once);

                return true.ToProperty()
                    .Label("Notification should be created for ASM");
            });
    }

    /// <summary>
    /// Unit test: Notification should be created with correct properties
    /// </summary>
    [Fact]
    public async Task SubmissionNotification_ShouldHaveCorrectProperties()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();
        var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
        SetupMockUser(mockContext, userId, UserRole.ASM);
        
        var notifications = new List<Notification>();
        var mockNotificationSet = CreateMockDbSet(notifications);
        
        mockNotificationSet.Setup(m => m.Add(It.IsAny<Notification>()))
            .Callback<Notification>(n => notifications.Add(n));
        
        mockContext.Setup(c => c.Notifications).Returns(mockNotificationSet.Object);
        mockContext.Setup(c => c.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        // Act
        await agent.SendNotificationAsync(
            userId,
            NotificationType.SubmissionReceived,
            "New Submission",
            "A new document package has been submitted",
            packageId,
            sendEmail: false,
            CancellationToken.None);

        // Assert
        Assert.Single(notifications);
        var notification = notifications[0];
        Assert.Equal(userId, notification.UserId);
        Assert.Equal(NotificationType.SubmissionReceived, notification.Type);
        Assert.Equal("New Submission", notification.Title);
        Assert.Equal(packageId, notification.RelatedEntityId);
        Assert.False(notification.IsRead);
    }

    /// <summary>
    /// Unit test: Flagged notification should be created for ASM
    /// </summary>
    [Fact]
    public async Task FlaggedNotification_ShouldBeCreatedForASM()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();
        var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
        SetupMockUser(mockContext, userId, UserRole.ASM);
        SetupMockNotifications(mockContext, new List<Notification>());

        // Act
        await agent.SendNotificationAsync(
            userId,
            NotificationType.FlaggedForReview,
            "Package Flagged",
            "Low confidence score detected",
            packageId,
            sendEmail: false,
            CancellationToken.None);

        // Assert
        mockContext.Verify(
            c => c.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Once);
    }

    /// <summary>
    /// Unit test: Approved notification should be created for Agency
    /// </summary>
    [Fact]
    public async Task ApprovedNotification_ShouldBeCreatedForAgency()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();
        var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
        SetupMockUser(mockContext, userId, UserRole.Agency);
        SetupMockNotifications(mockContext, new List<Notification>());

        // Act
        await agent.SendNotificationAsync(
            userId,
            NotificationType.Approved,
            "Package Approved",
            "Your submission has been approved",
            packageId,
            sendEmail: false,
            CancellationToken.None);

        // Assert
        mockContext.Verify(
            c => c.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Once);
    }

    /// <summary>
    /// Unit test: Rejected notification should be created for Agency
    /// </summary>
    [Fact]
    public async Task RejectedNotification_ShouldBeCreatedForAgency()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();
        var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
        SetupMockUser(mockContext, userId, UserRole.Agency);
        SetupMockNotifications(mockContext, new List<Notification>());

        // Act
        await agent.SendNotificationAsync(
            userId,
            NotificationType.Rejected,
            "Package Rejected",
            "Your submission has been rejected",
            packageId,
            sendEmail: false,
            CancellationToken.None);

        // Assert
        mockContext.Verify(
            c => c.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Once);
    }

    /// <summary>
    /// Property 41: Notification Read State Update
    /// Validates: Requirements 8.7
    /// 
    /// Unit test: Marking notification as read should update IsRead and ReadAt
    /// </summary>
    [Fact]
    public async Task MarkAsRead_ShouldUpdateNotificationState()
    {
        // Arrange
        var notificationId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var notification = new Notification
        {
            Id = notificationId,
            UserId = userId,
            Type = NotificationType.SubmissionReceived,
            Title = "Test",
            Message = "Test message",
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        };

        var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
        SetupMockNotifications(mockContext, new List<Notification> { notification });

        // Act
        await agent.MarkAsReadAsync(notificationId, CancellationToken.None);

        // Assert
        Assert.True(notification.IsRead);
        Assert.NotNull(notification.ReadAt);
        mockContext.Verify(
            c => c.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Once);
    }

    /// <summary>
    /// Unit test: Get notifications should return unread first
    /// </summary>
    [Fact]
    public async Task GetNotifications_ShouldReturnUnreadFirst()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var notifications = new List<Notification>
        {
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = NotificationType.SubmissionReceived,
                Title = "Read Notification",
                Message = "This is read",
                IsRead = true,
                CreatedAt = DateTime.UtcNow.AddHours(-2)
            },
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = NotificationType.FlaggedForReview,
                Title = "Unread Notification",
                Message = "This is unread",
                IsRead = false,
                CreatedAt = DateTime.UtcNow.AddHours(-1)
            }
        };

        var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
        SetupMockNotifications(mockContext, notifications);

        // Act
        var result = await agent.GetUserNotificationsAsync(userId, unreadOnly: false, CancellationToken.None);

        // Assert
        Assert.Equal(2, result.Count);
        // Unread should come first
        Assert.False(result[0].IsRead);
        Assert.True(result[1].IsRead);
    }

    /// <summary>
    /// Unit test: Get unread notifications should filter correctly
    /// </summary>
    [Fact]
    public async Task GetNotifications_UnreadOnly_ShouldFilterCorrectly()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var notifications = new List<Notification>
        {
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = NotificationType.SubmissionReceived,
                Title = "Read Notification",
                Message = "This is read",
                IsRead = true,
                CreatedAt = DateTime.UtcNow.AddHours(-2)
            },
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = NotificationType.FlaggedForReview,
                Title = "Unread Notification",
                Message = "This is unread",
                IsRead = false,
                CreatedAt = DateTime.UtcNow.AddHours(-1)
            }
        };

        var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
        SetupMockNotifications(mockContext, notifications);

        // Act
        var result = await agent.GetUserNotificationsAsync(userId, unreadOnly: true, CancellationToken.None);

        // Assert
        Assert.Single(result);
        Assert.False(result[0].IsRead);
    }

    /// <summary>
    /// Unit test: Get unread count should return correct count
    /// </summary>
    [Fact]
    public async Task GetUnreadCount_ShouldReturnCorrectCount()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var notifications = new List<Notification>
        {
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                IsRead = false,
                CreatedAt = DateTime.UtcNow
            },
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                IsRead = false,
                CreatedAt = DateTime.UtcNow
            },
            new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                IsRead = true,
                CreatedAt = DateTime.UtcNow
            }
        };

        var (agent, mockContext, mockEmailAgent) = CreateNotificationAgent();
        SetupMockNotifications(mockContext, notifications);

        // Act
        var count = await agent.GetUnreadCountAsync(userId, CancellationToken.None);

        // Assert
        Assert.Equal(2, count);
    }

    private (INotificationAgent, Mock<IApplicationDbContext>, Mock<IEmailAgent>) CreateNotificationAgent()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockEmailAgent = new Mock<IEmailAgent>();
        var mockPushNotificationService = new Mock<IPushNotificationService>();
        var mockLogger = new Mock<ILogger<NotificationAgent>>();

        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        var agent = new NotificationAgent(mockContext.Object, mockEmailAgent.Object, mockPushNotificationService.Object, mockLogger.Object, mockCorrelationIdService.Object);

        return (agent, mockContext, mockEmailAgent);
    }

    private void SetupMockUser(Mock<IApplicationDbContext> mockContext, Guid userId, UserRole role)
    {
        var user = new User
        {
            Id = userId,
            Email = "test@example.com",
            FullName = "Test User",
            Role = role,
            CreatedAt = DateTime.UtcNow
        };

        var users = new List<User> { user };
        var mockUserSet = CreateMockDbSet(users);
        mockContext.Setup(c => c.Users).Returns(mockUserSet.Object);
    }

    private void SetupMockNotifications(Mock<IApplicationDbContext> mockContext, List<Notification> notifications)
    {
        var mockNotificationSet = CreateMockDbSet(notifications);
        mockContext.Setup(c => c.Notifications).Returns(mockNotificationSet.Object);

        // Setup SaveChangesAsync
        mockContext.Setup(c => c.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);
    }

    private Mock<DbSet<T>> CreateMockDbSet<T>(List<T> data) where T : class
    {
        var queryable = data.AsQueryable();
        var mockSet = new Mock<DbSet<T>>();

        mockSet.As<IQueryable<T>>().Setup(m => m.Provider).Returns(new TestAsyncQueryProvider<T>(queryable.Provider));
        mockSet.As<IQueryable<T>>().Setup(m => m.Expression).Returns(queryable.Expression);
        mockSet.As<IQueryable<T>>().Setup(m => m.ElementType).Returns(queryable.ElementType);
        mockSet.As<IQueryable<T>>().Setup(m => m.GetEnumerator()).Returns(queryable.GetEnumerator());

        mockSet.As<IAsyncEnumerable<T>>()
            .Setup(m => m.GetAsyncEnumerator(It.IsAny<CancellationToken>()))
            .Returns(new TestAsyncEnumerator<T>(queryable.GetEnumerator()));

        return mockSet;
    }
}
