using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.Extensions.Logging;
using Moq;
using System.Text.Json;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// Unit tests for TeamsCardService — validates Adaptive Card header rendering (AC 2.1).
/// </summary>
public class TeamsCardServiceTests
{
    private readonly TeamsCardService _sut;

    public TeamsCardServiceTests()
    {
        var logger = new Mock<ILogger<TeamsCardService>>();
        _sut = new TeamsCardService(logger.Object);
    }

    [Fact]
    public void BuildNewSubmissionCard_ContainsNewClaimSubmittedTitle()
    {
        // Arrange
        var data = CreateSampleCardData();

        // Act
        var cardJson = _sut.BuildNewSubmissionCard(data);

        // Assert
        Assert.Contains("New Claim Submitted", cardJson);
    }

    [Fact]
    public void BuildNewSubmissionCard_TitleHasCorrectStyling()
    {
        // Arrange
        var data = CreateSampleCardData();

        // Act
        var cardJson = _sut.BuildNewSubmissionCard(data);
        var doc = JsonDocument.Parse(cardJson);
        var body = doc.RootElement.GetProperty("body");
        // Body items are wrapped in a Container with style=default and bleed=true
        var container = body[0];
        var items = container.GetProperty("items");
        var columnSet = items[0];
        var leftColumn = columnSet.GetProperty("columns")[0];
        var titleBlock = leftColumn.GetProperty("items")[0];

        // Assert — size=medium, weight=bolder, color=accent
        Assert.Equal("Medium", titleBlock.GetProperty("size").GetString());
        Assert.Equal("Bolder", titleBlock.GetProperty("weight").GetString());
        Assert.Equal("Accent", titleBlock.GetProperty("color").GetString());
    }

    [Fact]
    public void BuildNewSubmissionCard_TimestampIsFormattedAndRightAligned()
    {
        // Arrange
        var data = CreateSampleCardData();
        data.NotificationTimestamp = new DateTime(2026, 3, 14, 14, 30, 0);

        // Act
        var cardJson = _sut.BuildNewSubmissionCard(data);
        var doc = JsonDocument.Parse(cardJson);
        var body = doc.RootElement.GetProperty("body");
        // Body items are wrapped in a Container with style=default and bleed=true
        var container = body[0];
        var items = container.GetProperty("items");
        var columnSet = items[0];
        var rightColumn = columnSet.GetProperty("columns")[1];
        var timestampBlock = rightColumn.GetProperty("items")[0];

        // Assert — formatted timestamp, size=small, isSubtle=true, right-aligned
        Assert.Equal("14-Mar-2026, 02:30 PM", timestampBlock.GetProperty("text").GetString());
        Assert.Equal("Small", timestampBlock.GetProperty("size").GetString());
        Assert.True(timestampBlock.GetProperty("isSubtle").GetBoolean());
        Assert.Equal("Right", timestampBlock.GetProperty("horizontalAlignment").GetString());
    }

    [Fact]
    public void BuildNewSubmissionCard_NoRawPlaceholderTokens()
    {
        // Arrange
        var data = CreateSampleCardData();

        // Act
        var cardJson = _sut.BuildNewSubmissionCard(data);

        // Assert — no unresolved ${...} or {{...}} tokens
        Assert.DoesNotContain("${", cardJson);
        Assert.DoesNotContain("{{", cardJson);
    }

    [Fact]
    public void BuildNewSubmissionCard_ReturnsValidJson()
    {
        // Arrange
        var data = CreateSampleCardData();

        // Act
        var cardJson = _sut.BuildNewSubmissionCard(data);

        // Assert — parseable JSON with AdaptiveCard type
        var doc = JsonDocument.Parse(cardJson);
        Assert.Equal("AdaptiveCard", doc.RootElement.GetProperty("type").GetString());
        Assert.Equal("1.3", doc.RootElement.GetProperty("version").GetString());
    }

    [Fact]
    public void BuildNewSubmissionCard_DefaultTimestamp_ProducesFallbackValue()
    {
        // Arrange — default DateTime (0001-01-01) should still produce valid output
        var data = new SubmissionCardData
        {
            SubmissionId = Guid.NewGuid(),
            SubmissionNumber = "CIQ-test1234",
            NotificationTimestamp = default
        };

        // Act
        var cardJson = _sut.BuildNewSubmissionCard(data);

        // Assert — no raw placeholders, valid JSON
        Assert.DoesNotContain("${", cardJson);
        var doc = JsonDocument.Parse(cardJson);
        Assert.NotNull(doc);
    }

    private static SubmissionCardData CreateSampleCardData()
    {
        return new SubmissionCardData
        {
            SubmissionId = Guid.Parse("a1b2c3d4-e5f6-7890-abcd-ef1234567890"),
            SubmissionNumber = "CIQ-a1b2c3d4",
            NotificationTimestamp = new DateTime(2026, 3, 12, 10, 30, 0)
        };
    }
}
