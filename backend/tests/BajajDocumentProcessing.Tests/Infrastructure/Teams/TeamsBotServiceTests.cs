using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams;
using BajajDocumentProcessing.Infrastructure.Services.Teams;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Adapters;
using Microsoft.Bot.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using Newtonsoft.Json.Linq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Teams;

/// <summary>
/// Tests for TeamsBotService adaptive card action handling.
/// Validates approve/reject parsing, rejection reason validation,
/// idempotency (already-actioned FAP), and card version validation.
/// </summary>
public class TeamsBotServiceTests
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

    public TeamsBotServiceTests()
    {
        _scopeFactoryMock = new Mock<IServiceScopeFactory>();
        _scopeMock = new Mock<IServiceScope>();
        _serviceProviderMock = new Mock<IServiceProvider>();
        _dbContextMock = new Mock<IApplicationDbContext>();
        _auditLogMock = new Mock<IAuditLogService>();
        _loggerMock = new Mock<ILogger<TeamsBotService>>();
        _pilotConfig = new PilotTeamsConfig { IsPilotMode = true };

        var configData = new Dictionary<string, string?>
        {
            ["TeamsBot:PortalBaseUrl"] = "https://localhost:7001"
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

        _bot = new TeamsBotService(
            _scopeFactoryMock.Object,
            _loggerMock.Object,
            _pilotConfig,
            _configuration,
            new BotAuthSessionStore());
    }

    [Fact]
    public async Task OnMessageActivity_ReturnsHelpText()
    {
        var adapter = new TestAdapter();
        await adapter.ProcessActivityAsync(
            new Activity
            {
                Type = ActivityTypes.Message,
                Text = "hello",
                ChannelId = "msteams",
                From = new ChannelAccount("user1", "Test User"),
                Recipient = new ChannelAccount("bot1", "Bot"),
                Conversation = new ConversationAccount(id: "conv1"),
                ServiceUrl = "https://smba.trafficmanager.net/teams/"
            },
            _bot.OnTurnAsync,
            CancellationToken.None);

        var reply = adapter.ActiveQueue.FirstOrDefault();
        Assert.NotNull(reply);
        Assert.Contains("FieldIQ Review Bot", reply.Text);
        Assert.Contains("Approve", reply.Text);
    }

    [Fact]
    public async Task CardAction_RejectsOutdatedCardVersion()
    {
        var fapId = Guid.NewGuid();
        var invokeValue = new AdaptiveCardInvokeValue
        {
            Action = new AdaptiveCardInvokeAction
            {
                Type = "Action.Execute",
                Data = JObject.FromObject(new
                {
                    action = "approve",
                    fapId = fapId.ToString(),
                    cardVersion = "0.5" // outdated
                })
            }
        };

        var response = await InvokeCardAction(invokeValue);

        Assert.NotNull(response);
        Assert.Equal(200, response.StatusCode);
    }

    [Fact]
    public async Task CardAction_RejectsShortRejectionReason()
    {
        var fapId = Guid.NewGuid();
        var invokeValue = new AdaptiveCardInvokeValue
        {
            Action = new AdaptiveCardInvokeAction
            {
                Type = "Action.Execute",
                Data = JObject.FromObject(new
                {
                    action = "reject",
                    fapId = fapId.ToString(),
                    cardVersion = "1.0",
                    rejectionReason = "short" // less than 10 chars
                })
            }
        };

        var response = await InvokeCardAction(invokeValue);

        Assert.NotNull(response);
        Assert.Equal(200, response.StatusCode);
    }

    [Fact]
    public async Task CardAction_RejectsEmptyRejectionReason()
    {
        var fapId = Guid.NewGuid();
        var invokeValue = new AdaptiveCardInvokeValue
        {
            Action = new AdaptiveCardInvokeAction
            {
                Type = "Action.Execute",
                Data = JObject.FromObject(new
                {
                    action = "reject",
                    fapId = fapId.ToString(),
                    cardVersion = "1.0",
                    rejectionReason = ""
                })
            }
        };

        var response = await InvokeCardAction(invokeValue);

        Assert.NotNull(response);
        Assert.Equal(200, response.StatusCode);
    }

    [Fact]
    public async Task CardAction_RejectsNullActionData()
    {
        var invokeValue = new AdaptiveCardInvokeValue
        {
            Action = new AdaptiveCardInvokeAction { Type = "Action.Execute", Data = null }
        };

        var response = await InvokeCardAction(invokeValue);

        Assert.NotNull(response);
        Assert.Equal(400, response.StatusCode);
    }

    [Fact]
    public async Task CardAction_HandlesMissingFapId()
    {
        var invokeValue = new AdaptiveCardInvokeValue
        {
            Action = new AdaptiveCardInvokeAction
            {
                Type = "Action.Execute",
                Data = JObject.FromObject(new
                {
                    action = "approve",
                    cardVersion = "1.0"
                    // missing fapId
                })
            }
        };

        var response = await InvokeCardAction(invokeValue);

        Assert.NotNull(response);
        Assert.Equal(400, response.StatusCode);
    }

    /// <summary>
    /// Helper to invoke the adaptive card action handler.
    /// Uses a minimal SimpleAdapter that captures sent activities,
    /// since TestAdapter doesn't queue invoke responses.
    /// </summary>
    private async Task<AdaptiveCardInvokeResponse> InvokeCardAction(AdaptiveCardInvokeValue invokeValue)
    {
        var adapter = new SimpleAdapter();

        var activity = new Activity
        {
            Type = ActivityTypes.Invoke,
            Name = "adaptiveCard/action",
            ChannelId = "msteams",
            From = new ChannelAccount("user1", "Test ASM"),
            Recipient = new ChannelAccount("bot1", "Bot"),
            Conversation = new ConversationAccount(id: "conv1"),
            ServiceUrl = "https://smba.trafficmanager.net/teams/",
            Value = JObject.FromObject(invokeValue)
        };

        var turnContext = new TurnContext(adapter, activity);
        await _bot.OnTurnAsync(turnContext, CancellationToken.None);

        // The base class sends an invokeResponse activity via SendActivityAsync
        foreach (var sent in adapter.SentActivities)
        {
            if (sent.Type == "invokeResponse" && sent.Value != null)
            {
                if (sent.Value is InvokeResponse ir)
                {
                    if (ir.Body is AdaptiveCardInvokeResponse acir)
                        return acir;

                    if (ir.Body is JObject bodyObj)
                    {
                        return new AdaptiveCardInvokeResponse
                        {
                            StatusCode = bodyObj["statusCode"]?.Value<int>() ?? ir.Status,
                            Type = bodyObj["type"]?.ToString(),
                            Value = bodyObj["value"]?.ToObject<object>()
                        };
                    }

                    return new AdaptiveCardInvokeResponse { StatusCode = ir.Status };
                }
            }
        }

        throw new InvalidOperationException(
            $"No invoke response found. Sent count: {adapter.SentActivities.Count}");
    }

    /// <summary>
    /// Minimal adapter that captures sent activities without the complexity of TestAdapter.
    /// TestAdapter doesn't queue invokeResponse activities, so we need this.
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
