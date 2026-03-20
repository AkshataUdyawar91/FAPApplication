using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Infrastructure.Services.Teams;
using BajajDocumentProcessing.Tests.Infrastructure.Properties;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Teams;

/// <summary>
/// Tests for TeamsBotService conversation persistence:
/// - OnMembersAddedAsync persists conversation reference to DB
/// - OnMembersRemovedAsync deactivates conversation in DB
/// - Pilot mode captures in-memory reference alongside DB persistence
/// Uses SimpleAdapter (from TeamsBotServiceTests) to avoid TestAdapter's
/// conversation ID rewriting and TeamsActivityHandler connector requirements.
/// </summary>
public class TeamsBotConversationTests
{
    private readonly Mock<IServiceScopeFactory> _scopeFactoryMock;
    private readonly Mock<IServiceScope> _scopeMock;
    private readonly Mock<IServiceProvider> _serviceProviderMock;
    private readonly Mock<IApplicationDbContext> _dbContextMock;
    private readonly Mock<IAuditLogService> _auditLogMock;
    private readonly Mock<ILogger<TeamsBotService>> _loggerMock;
    private readonly PilotTeamsConfig _pilotConfig;
    private readonly IConfiguration _configuration;
    private readonly TeamsBotService _bot;
    private readonly List<TeamsConversation> _addedConversations;

    public TeamsBotConversationTests()
    {
        _scopeFactoryMock = new Mock<IServiceScopeFactory>();
        _scopeMock = new Mock<IServiceScope>();
        _serviceProviderMock = new Mock<IServiceProvider>();
        _dbContextMock = new Mock<IApplicationDbContext>();
        _auditLogMock = new Mock<IAuditLogService>();
        _loggerMock = new Mock<ILogger<TeamsBotService>>();
        _pilotConfig = new PilotTeamsConfig { IsPilotMode = true };
        _addedConversations = new List<TeamsConversation>();

        var configData = new Dictionary<string, string?>
        {
            ["TeamsBot:PortalBaseUrl"] = "http://localhost:8080"
        };
        _configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(configData)
            .Build();

        // Wire up scope factory
        _serviceProviderMock
            .Setup(sp => sp.GetService(typeof(IApplicationDbContext)))
            .Returns(_dbContextMock.Object);
        _serviceProviderMock
            .Setup(sp => sp.GetService(typeof(IAuditLogService)))
            .Returns(_auditLogMock.Object);
        _scopeMock.Setup(s => s.ServiceProvider).Returns(_serviceProviderMock.Object);
        _scopeFactoryMock.Setup(f => f.CreateScope()).Returns(_scopeMock.Object);

        SetupEmptyConversationsDbSet();

        _dbContextMock.Setup(c => c.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        _bot = new TeamsBotService(
            _scopeFactoryMock.Object,
            _loggerMock.Object,
            _pilotConfig,
            _configuration);
    }

    private void SetupEmptyConversationsDbSet()
    {
        var emptyConversations = new List<TeamsConversation>().AsQueryable();
        var mockConvSet = CreateMockDbSet(emptyConversations);
        mockConvSet.Setup(s => s.Add(It.IsAny<TeamsConversation>()))
            .Callback<TeamsConversation>(c => _addedConversations.Add(c));
        _dbContextMock.Setup(c => c.TeamsConversations).Returns(mockConvSet.Object);
    }

    [Fact]
    public async Task OnMembersAdded_PersistsConversationToDatabase()
    {
        var adapter = new SimpleAdapter();
        var activity = CreateConversationUpdateActivity(
            membersAdded: new List<ChannelAccount> { new("user1", "Test ASM") });

        var turnContext = new TurnContext(adapter, activity);
        await _bot.OnTurnAsync(turnContext, CancellationToken.None);

        Assert.Single(_addedConversations);
        var persisted = _addedConversations[0];
        Assert.Equal("user1", persisted.TeamsUserId);
        Assert.Equal("Test ASM", persisted.TeamsUserName);
        Assert.Equal("conv1", persisted.ConversationId);
        Assert.True(persisted.IsActive);
        Assert.NotEmpty(persisted.ConversationReferenceJson);
    }

    [Fact]
    public async Task OnMembersAdded_CapturesPilotReference_InPilotMode()
    {
        Assert.False(_pilotConfig.HasReference);

        var adapter = new SimpleAdapter();
        var activity = CreateConversationUpdateActivity(
            membersAdded: new List<ChannelAccount> { new("user1", "Test ASM") });

        var turnContext = new TurnContext(adapter, activity);
        await _bot.OnTurnAsync(turnContext, CancellationToken.None);

        Assert.True(_pilotConfig.HasReference);
        var reference = _pilotConfig.GetReference();
        Assert.NotNull(reference);
        Assert.Equal("conv1", reference!.Conversation?.Id);
    }

    [Fact]
    public async Task OnMembersAdded_SkipsBotItself()
    {
        var adapter = new SimpleAdapter();
        var activity = CreateConversationUpdateActivity(
            membersAdded: new List<ChannelAccount> { new("bot1", "Bot") }); // same as Recipient

        var turnContext = new TurnContext(adapter, activity);
        await _bot.OnTurnAsync(turnContext, CancellationToken.None);

        Assert.Empty(_addedConversations);
    }

    [Fact]
    public async Task OnMembersAdded_SendsWelcomeMessage()
    {
        var adapter = new SimpleAdapter();
        var activity = CreateConversationUpdateActivity(
            membersAdded: new List<ChannelAccount> { new("user1", "Test ASM") });

        var turnContext = new TurnContext(adapter, activity);
        await _bot.OnTurnAsync(turnContext, CancellationToken.None);

        var reply = adapter.SentActivities.FirstOrDefault(a => a.Type == "message");
        Assert.NotNull(reply);
        Assert.Contains("Bot installed successfully", reply.Text);
    }

    [Fact]
    public async Task OnMembersRemoved_DeactivatesConversation()
    {
        // Arrange: existing active conversation in DB
        var existingConv = new TeamsConversation
        {
            Id = Guid.NewGuid(),
            TeamsUserId = "user1",
            ConversationId = "conv1",
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };
        var conversations = new List<TeamsConversation> { existingConv }.AsQueryable();
        var mockConvSet = CreateMockDbSet(conversations);
        _dbContextMock.Setup(c => c.TeamsConversations).Returns(mockConvSet.Object);

        var adapter = new SimpleAdapter();
        var activity = CreateConversationUpdateActivity(
            membersRemoved: new List<ChannelAccount> { new("user1", "Test ASM") });

        var turnContext = new TurnContext(adapter, activity);
        await _bot.OnTurnAsync(turnContext, CancellationToken.None);

        // The mock DbSet's Where/ToListAsync returns the original object reference,
        // so IsActive should have been set to false by our handler
        Assert.False(existingConv.IsActive);
        _dbContextMock.Verify(c => c.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.AtLeastOnce);
    }

    /// <summary>
    /// Creates a ConversationUpdate activity for testing.
    /// Uses ChannelId "emulator" to avoid TeamsActivityHandler's Teams-specific dispatch.
    /// </summary>
    private static Activity CreateConversationUpdateActivity(
        IList<ChannelAccount>? membersAdded = null,
        IList<ChannelAccount>? membersRemoved = null)
    {
        return new Activity
        {
            Type = ActivityTypes.ConversationUpdate,
            ChannelId = "emulator",
            MembersAdded = membersAdded,
            MembersRemoved = membersRemoved,
            From = new ChannelAccount("user1", "Test ASM"),
            Recipient = new ChannelAccount("bot1", "Bot"),
            Conversation = new ConversationAccount(id: "conv1"),
            ServiceUrl = "https://smba.trafficmanager.net/teams/"
        };
    }

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

    /// <summary>
    /// Minimal adapter that captures sent activities. Reused from TeamsBotServiceTests.
    /// </summary>
    private class SimpleAdapter : BotAdapter
    {
        public List<Activity> SentActivities { get; } = new();

        public override Task<ResourceResponse[]> SendActivitiesAsync(
            ITurnContext turnContext, Activity[] activities, CancellationToken cancellationToken)
        {
            foreach (var a in activities)
                SentActivities.Add(a);
            return Task.FromResult(activities.Select(a =>
                new ResourceResponse(a.Id ?? Guid.NewGuid().ToString())).ToArray());
        }

        public override Task DeleteActivityAsync(
            ITurnContext turnContext, ConversationReference reference, CancellationToken cancellationToken)
            => Task.CompletedTask;

        public override Task<ResourceResponse> UpdateActivityAsync(
            ITurnContext turnContext, Activity activity, CancellationToken cancellationToken)
            => Task.FromResult(new ResourceResponse(activity.Id));
    }
}
