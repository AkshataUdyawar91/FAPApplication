using BajajDocumentProcessing.Infrastructure.Services.Teams;
using Microsoft.Bot.Schema;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Teams;

/// <summary>
/// Tests for PilotTeamsConfig — validates thread-safe conversation reference capture.
/// </summary>
public class PilotTeamsConfigTests
{
    [Fact]
    public void HasReference_ReturnsFalse_WhenNoCaptured()
    {
        var config = new PilotTeamsConfig();
        Assert.False(config.HasReference);
    }

    [Fact]
    public void CaptureReference_StoresReference()
    {
        var config = new PilotTeamsConfig();
        var reference = CreateTestReference("conv-1");

        config.CaptureReference(reference);

        Assert.True(config.HasReference);
        var retrieved = config.GetReference();
        Assert.NotNull(retrieved);
        Assert.Equal("conv-1", retrieved.Conversation.Id);
    }

    [Fact]
    public void CaptureReference_OverwritesPreviousReference()
    {
        var config = new PilotTeamsConfig();
        config.CaptureReference(CreateTestReference("conv-1"));
        config.CaptureReference(CreateTestReference("conv-2"));

        var retrieved = config.GetReference();
        Assert.NotNull(retrieved);
        Assert.Equal("conv-2", retrieved.Conversation.Id);
    }

    [Fact]
    public void GetReference_ReturnsNull_WhenNoCaptured()
    {
        var config = new PilotTeamsConfig();
        Assert.Null(config.GetReference());
    }

    [Fact]
    public void IsPilotMode_DefaultsToTrue()
    {
        var config = new PilotTeamsConfig();
        Assert.True(config.IsPilotMode);
    }

    [Fact]
    public void CaptureReference_IsThreadSafe()
    {
        var config = new PilotTeamsConfig();
        var tasks = Enumerable.Range(0, 100)
            .Select(i => Task.Run(() => config.CaptureReference(CreateTestReference($"conv-{i}"))))
            .ToArray();

        Task.WaitAll(tasks);

        Assert.True(config.HasReference);
        Assert.NotNull(config.GetReference());
    }

    private static ConversationReference CreateTestReference(string conversationId)
    {
        return new ConversationReference
        {
            Conversation = new ConversationAccount { Id = conversationId },
            Bot = new ChannelAccount { Id = "bot-id" },
            ServiceUrl = "https://smba.trafficmanager.net/teams/"
        };
    }
}
