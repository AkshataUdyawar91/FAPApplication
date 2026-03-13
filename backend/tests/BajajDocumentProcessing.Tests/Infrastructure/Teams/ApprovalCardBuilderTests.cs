using AdaptiveCards;
using BajajDocumentProcessing.Infrastructure.Services.Teams;
using Microsoft.Bot.Schema;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Teams;

/// <summary>
/// Tests for ApprovalCardBuilder — validates adaptive card structure and content.
/// </summary>
public class ApprovalCardBuilderTests
{
    private readonly Guid _fapId = Guid.NewGuid();
    private const string FapNumber = "ABC12345";
    private const string AgencyName = "Test Agency";
    private const string PoNumber = "PO-001";
    private const decimal Amount = 150000.50m;
    private readonly DateTime _submittedDate = new(2026, 3, 1);
    private const string PortalBaseUrl = "https://localhost:7001";

    [Fact]
    public void BuildApprovalCard_ReturnsAdaptiveCardAttachment()
    {
        var card = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 90, "APPROVE", "All checks passed.", PortalBaseUrl);

        Assert.NotNull(card);
        Assert.Equal(AdaptiveCard.ContentType, card.ContentType);
        Assert.IsType<AdaptiveCard>(card.Content);
    }

    [Fact]
    public void BuildApprovalCard_ContainsFactSetWithRequiredFields()
    {
        var card = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 85, "APPROVE", "Summary", PortalBaseUrl);

        var adaptive = (AdaptiveCard)card.Content;
        var factSet = adaptive.Body.OfType<AdaptiveFactSet>().FirstOrDefault();

        Assert.NotNull(factSet);
        var factTitles = factSet.Facts.Select(f => f.Title).ToList();
        Assert.Contains("FAP #", factTitles);
        Assert.Contains("Agency", factTitles);
        Assert.Contains("PO #", factTitles);
        Assert.Contains("Amount", factTitles);
        Assert.Contains("Submitted", factTitles);
    }

    [Fact]
    public void BuildApprovalCard_ContainsApproveRejectAndPortalActions()
    {
        var card = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 75, "REVIEW", "Needs review.", PortalBaseUrl);

        var adaptive = (AdaptiveCard)card.Content;

        Assert.Equal(3, adaptive.Actions.Count);

        // Approve button
        var approve = adaptive.Actions[0] as AdaptiveSubmitAction;
        Assert.NotNull(approve);
        Assert.Contains("Approve", approve.Title);

        // Reject button (ShowCard with nested input)
        var reject = adaptive.Actions[1] as AdaptiveShowCardAction;
        Assert.NotNull(reject);
        Assert.Contains("Reject", reject.Title);
        Assert.NotEmpty(reject.Card.Actions);

        // View in Portal button
        var portal = adaptive.Actions[2] as AdaptiveOpenUrlAction;
        Assert.NotNull(portal);
        Assert.Contains("Portal", portal.Title);
        Assert.Contains(_fapId.ToString(), portal.Url.ToString());
    }

    [Theory]
    [InlineData(90, AdaptiveTextColor.Good)]
    [InlineData(75, AdaptiveTextColor.Warning)]
    [InlineData(50, AdaptiveTextColor.Attention)]
    public void BuildApprovalCard_ConfidenceScoreColorCoding(double score, AdaptiveTextColor expectedColor)
    {
        var card = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, score, "REVIEW", "Summary", PortalBaseUrl);

        var adaptive = (AdaptiveCard)card.Content;
        var columnSet = adaptive.Body.OfType<AdaptiveColumnSet>().FirstOrDefault();
        Assert.NotNull(columnSet);

        // Second column has the score text
        var scoreBlock = columnSet.Columns[1].Items.OfType<AdaptiveTextBlock>().FirstOrDefault();
        Assert.NotNull(scoreBlock);
        Assert.Equal(expectedColor, scoreBlock.Color);
    }

    [Fact]
    public void BuildApprovalCard_IncludesCardVersionInActionData()
    {
        var card = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 80, "APPROVE", "Summary", PortalBaseUrl);

        var adaptive = (AdaptiveCard)card.Content;
        var approveAction = adaptive.Actions[0] as AdaptiveSubmitAction;
        Assert.NotNull(approveAction);

        // Data should contain cardVersion
        var dataJson = System.Text.Json.JsonSerializer.Serialize(approveAction.Data);
        Assert.Contains("cardVersion", dataJson);
        Assert.Contains("1.0", dataJson);
    }

    [Fact]
    public void BuildActionConfirmationCard_ApproveShowsGreenStatus()
    {
        var card = ApprovalCardBuilder.BuildActionConfirmationCard(
            FapNumber, "approve", "John ASM", DateTime.UtcNow);

        var adaptive = (AdaptiveCard)card.Content;
        var statusBlock = adaptive.Body.OfType<AdaptiveTextBlock>()
            .FirstOrDefault(b => b.Text.Contains("Approved"));

        Assert.NotNull(statusBlock);
        Assert.Equal(AdaptiveTextColor.Good, statusBlock.Color);
    }

    [Fact]
    public void BuildActionConfirmationCard_RejectShowsRedStatusWithReason()
    {
        var reason = "Documents are incomplete and need revision.";
        var card = ApprovalCardBuilder.BuildActionConfirmationCard(
            FapNumber, "reject", "Jane ASM", DateTime.UtcNow, reason);

        var adaptive = (AdaptiveCard)card.Content;
        var statusBlock = adaptive.Body.OfType<AdaptiveTextBlock>()
            .FirstOrDefault(b => b.Text.Contains("Rejected"));
        var reasonBlock = adaptive.Body.OfType<AdaptiveTextBlock>()
            .FirstOrDefault(b => b.Text.Contains(reason));

        Assert.NotNull(statusBlock);
        Assert.Equal(AdaptiveTextColor.Attention, statusBlock.Color);
        Assert.NotNull(reasonBlock);
    }

    [Fact]
    public void BuildActionConfirmationCard_NoActionsOnConfirmationCard()
    {
        var card = ApprovalCardBuilder.BuildActionConfirmationCard(
            FapNumber, "approve", "John ASM", DateTime.UtcNow);

        var adaptive = (AdaptiveCard)card.Content;
        Assert.Empty(adaptive.Actions);
    }

    [Fact]
    public void BuildApprovalCard_RejectShowCardContainsReasonInput()
    {
        var card = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 60, "REJECT", "Reject recommended.", PortalBaseUrl);

        var adaptive = (AdaptiveCard)card.Content;
        var rejectAction = adaptive.Actions[1] as AdaptiveShowCardAction;
        Assert.NotNull(rejectAction);

        var textInput = rejectAction.Card.Body.OfType<AdaptiveTextInput>().FirstOrDefault();
        Assert.NotNull(textInput);
        Assert.Equal("rejectionReason", textInput.Id);
        Assert.True(textInput.IsMultiline);
        Assert.True(textInput.IsRequired);
    }
}
