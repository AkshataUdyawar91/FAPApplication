using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services.Teams;
using BajajDocumentProcessing.Tests.Infrastructure.Properties;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Integration.AspNet.Core;
using Microsoft.Bot.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Teams;

/// <summary>
/// Tests for TeamsNotificationService: proactive card sending, status updates,
/// conversation availability checks, and graceful failure handling.
/// </summary>
public class TeamsNotificationServiceTests
{
    private readonly Mock<IBotFrameworkHttpAdapter> _adapterMock;
    private readonly Mock<IServiceScopeFactory> _scopeFactoryMock;
    private readonly Mock<IServiceScope> _scopeMock;
    private readonly Mock<IServiceProvider> _serviceProviderMock;
    private readonly Mock<IApplicationDbContext> _dbContextMock;
    private readonly Mock<ILogger<TeamsNotificationService>> _loggerMock;
    private readonly PilotTeamsConfig _pilotConfig;
    private readonly IConfiguration _configuration;

    public TeamsNotificationServiceTests()
    {
        _adapterMock = new Mock<IBotFrameworkHttpAdapter>();
        _scopeFactoryMock = new Mock<IServiceScopeFactory>();
        _scopeMock = new Mock<IServiceScope>();
        _serviceProviderMock = new Mock<IServiceProvider>();
        _dbContextMock = new Mock<IApplicationDbContext>();
        _loggerMock = new Mock<ILogger<TeamsNotificationService>>();
        _pilotConfig = new PilotTeamsConfig { IsPilotMode = true };

        var configData = new Dictionary<string, string?>
        {
            ["MicrosoftAppId"] = "",
            ["TeamsBot:PortalBaseUrl"] = "http://localhost:8080"
        };
        _configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(configData)
            .Build();

        // Wire up scope factory
        _serviceProviderMock
            .Setup(sp => sp.GetService(typeof(IApplicationDbContext)))
            .Returns(_dbContextMock.Object);
        _scopeMock.Setup(s => s.ServiceProvider).Returns(_serviceProviderMock.Object);
        _scopeFactoryMock.Setup(f => f.CreateScope()).Returns(_scopeMock.Object);
    }

    private TeamsNotificationService CreateService() => new(
        _adapterMock.Object,
        _scopeFactoryMock.Object,
        _loggerMock.Object,
        _pilotConfig,
        _configuration);

    [Fact]
    public void IsAvailable_ReturnsFalse_WhenNoReferenceAndNoPersistedConversations()
    {
        // Arrange: empty conversations DbSet
        var emptyList = new List<TeamsConversation>().AsQueryable();
        var mockSet = CreateMockDbSet(emptyList);
        _dbContextMock.Setup(c => c.TeamsConversations).Returns(mockSet.Object);

        var service = CreateService();

        // Act & Assert
        Assert.False(service.IsAvailable);
    }

    [Fact]
    public void IsAvailable_ReturnsTrue_WhenPilotReferenceExists()
    {
        // Arrange
        var reference = new ConversationReference
        {
            Conversation = new ConversationAccount(id: "conv1"),
            ServiceUrl = "https://smba.trafficmanager.net/teams/"
        };
        _pilotConfig.CaptureReference(reference);

        var service = CreateService();

        // Act & Assert
        Assert.True(service.IsAvailable);
    }

    [Fact]
    public async Task SendApprovalCardAsync_ReturnsFalse_WhenPackageNotFound()
    {
        // Arrange: empty packages
        var emptyPackages = new List<DocumentPackage>().AsQueryable();
        var mockPackageSet = CreateMockDbSet(emptyPackages);
        _dbContextMock.Setup(c => c.DocumentPackages).Returns(mockPackageSet.Object);

        var service = CreateService();

        // Act
        var result = await service.SendApprovalCardAsync(Guid.NewGuid());

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task SendApprovalCardAsync_ReturnsFalse_WhenNoConversationsAvailable()
    {
        // Arrange: package exists but no conversations
        var packageId = Guid.NewGuid();
        var package = new DocumentPackage
        {
            Id = packageId,
            State = PackageState.PendingASM,
            CreatedAt = DateTime.UtcNow,
            SubmittedBy = new User { FullName = "Test Agency" }
        };

        var packages = new List<DocumentPackage> { package }.AsQueryable();
        var mockPackageSet = CreateMockDbSet(packages);
        _dbContextMock.Setup(c => c.DocumentPackages).Returns(mockPackageSet.Object);

        var emptyConversations = new List<TeamsConversation>().AsQueryable();
        var mockConvSet = CreateMockDbSet(emptyConversations);
        _dbContextMock.Setup(c => c.TeamsConversations).Returns(mockConvSet.Object);

        var service = CreateService();

        // Act
        var result = await service.SendApprovalCardAsync(packageId);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task SendStatusUpdateAsync_ReturnsFalse_WhenNoConversationsAvailable()
    {
        // Arrange
        var emptyConversations = new List<TeamsConversation>().AsQueryable();
        var mockConvSet = CreateMockDbSet(emptyConversations);
        _dbContextMock.Setup(c => c.TeamsConversations).Returns(mockConvSet.Object);

        var service = CreateService();

        // Act
        var result = await service.SendStatusUpdateAsync(
            Guid.NewGuid(), "Approved", "Test details");

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task SendStatusUpdateAsync_HandlesExceptionGracefully()
    {
        // Arrange: force an exception
        _scopeFactoryMock.Setup(f => f.CreateScope()).Throws(new InvalidOperationException("Test error"));

        var service = CreateService();

        // Act
        var result = await service.SendStatusUpdateAsync(Guid.NewGuid(), "Approved");

        // Assert: should return false, not throw
        Assert.False(result);
    }

    [Fact]
    public async Task SendApprovalCardAsync_HandlesExceptionGracefully()
    {
        // Arrange: force an exception
        _scopeFactoryMock.Setup(f => f.CreateScope()).Throws(new InvalidOperationException("Test error"));

        var service = CreateService();

        // Act
        var result = await service.SendApprovalCardAsync(Guid.NewGuid());

        // Assert: should return false, not throw
        Assert.False(result);
    }

    /// <summary>
    /// Creates a mock DbSet that supports IQueryable and async enumeration.
    /// </summary>
    private static Mock<DbSet<T>> CreateMockDbSet<T>(IQueryable<T> data) where T : class
    {
        var mockSet = new Mock<DbSet<T>>();
        mockSet.As<IQueryable<T>>().Setup(m => m.Provider).Returns(new TestAsyncQueryProvider<T>(data.Provider));
        mockSet.As<IQueryable<T>>().Setup(m => m.Expression).Returns(data.Expression);
        mockSet.As<IQueryable<T>>().Setup(m => m.ElementType).Returns(data.ElementType);
        mockSet.As<IQueryable<T>>().Setup(m => m.GetEnumerator()).Returns(data.GetEnumerator());
        mockSet.As<IAsyncEnumerable<T>>().Setup(m => m.GetAsyncEnumerator(It.IsAny<CancellationToken>()))
            .Returns(new TestAsyncEnumerator<T>(data.GetEnumerator()));
        return mockSet;
    }
}
