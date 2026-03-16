using BajajDocumentProcessing.Infrastructure.Services.Teams;
using Microsoft.Bot.Schema;
using Newtonsoft.Json.Linq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Teams;

/// <summary>
/// Tests for ApprovalCardBuilder — validates adaptive card structure and content.
/// Cards are built as JObject (schema 1.3) for Bot Framework Emulator compatibility.
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
        var attachment = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 90, "APPROVE", "All checks passed.", PortalBaseUrl);

        Assert.NotNull(attachment);
        Assert.Equal("application/vnd.microsoft.card.adaptive", attachment.ContentType);
        Assert.IsType<JObject>(attachment.Content);

        var card = (JObject)attachment.Content;
        Assert.Equal("1.3", card["version"]?.ToString());
        Assert.Equal("AdaptiveCard", card["type"]?.ToString());
    }

    [Fact]
    public void BuildApprovalCard_ContainsFactSetWithRequiredFields()
    {
        var attachment = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 85, "APPROVE", "Summary", PortalBaseUrl);

        var card = (JObject)attachment.Content;
        var body = (JArray)card["body"]!;

        // Find the FactSet element in the body
        var factSet = body.Children<JObject>()
            .FirstOrDefault(e => e["type"]?.ToString() == "FactSet");

        Assert.NotNull(factSet);
        var facts = (JArray)factSet["facts"]!;
        var factTitles = facts.Children<JObject>().Select(f => f["title"]?.ToString()).ToList();

        Assert.Contains("FAP #", factTitles);
        Assert.Contains("Agency", factTitles);
        Assert.Contains("PO #", factTitles);
        Assert.Contains("Amount", factTitles);
        Assert.Contains("Submitted", factTitles);
    }

    [Fact]
    public void BuildApprovalCard_ContainsApproveRejectAndPortalActions()
    {
        var attachment = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 75, "REVIEW", "Needs review.", PortalBaseUrl);

        var card = (JObject)attachment.Content;
        var actions = (JArray)card["actions"]!;

        Assert.Equal(3, actions.Count);

        // Approve button
        Assert.Contains("Approve", actions[0]["title"]?.ToString());
        Assert.Equal("Action.Submit", actions[0]["type"]?.ToString());

        // Reject button (routes to review_details)
        Assert.Contains("Reject", actions[1]["title"]?.ToString());
        Assert.Equal("Action.Submit", actions[1]["type"]?.ToString());

        // View in Portal button
        Assert.Contains("Portal", actions[2]["title"]?.ToString());
        Assert.Equal("Action.OpenUrl", actions[2]["type"]?.ToString());
        Assert.Contains(_fapId.ToString(), actions[2]["url"]?.ToString());
    }

    [Theory]
    [InlineData(90, "🟢")]
    [InlineData(75, "🟡")]
    [InlineData(50, "🔴")]
    public void BuildApprovalCard_ConfidenceScoreEmojiIndicator(double score, string expectedEmoji)
    {
        var attachment = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, score, "REVIEW", "Summary", PortalBaseUrl);

        var card = (JObject)attachment.Content;
        var body = (JArray)card["body"]!;

        // Find the confidence text block
        var confidenceBlock = body.Children<JObject>()
            .FirstOrDefault(e => e["text"]?.ToString()?.Contains("Confidence") == true);

        Assert.NotNull(confidenceBlock);
        Assert.Contains(expectedEmoji, confidenceBlock["text"]?.ToString());
    }

    [Fact]
    public void BuildApprovalCard_IncludesCardVersionInActionData()
    {
        var attachment = ApprovalCardBuilder.BuildApprovalCard(
            _fapId, FapNumber, AgencyName, PoNumber, Amount,
            _submittedDate, 80, "APPROVE", "Summary", PortalBaseUrl);

        var card = (JObject)attachment.Content;
        var actions = (JArray)card["actions"]!;
        var approveData = (JObject)actions[0]["data"]!;

        Assert.Equal("1.0", approveData["cardVersion"]?.ToString());
        Assert.Equal("approve", approveData["action"]?.ToString());
    }

    [Fact]
    public void BuildActionConfirmationCard_ApproveShowsApprovedStatus()
    {
        var attachment = ApprovalCardBuilder.BuildActionConfirmationCard(
            FapNumber, "approve", "John ASM", DateTime.UtcNow);

        var card = (JObject)attachment.Content;
        var body = (JArray)card["body"]!;

        var statusBlock = body.Children<JObject>()
            .FirstOrDefault(e => e["text"]?.ToString()?.Contains("Approved") == true);

        Assert.NotNull(statusBlock);
        Assert.Contains("✅", statusBlock["text"]?.ToString());
    }

    [Fact]
    public void BuildActionConfirmationCard_RejectShowsRejectedStatusWithReason()
    {
        var reason = "Documents are incomplete and need revision.";
        var attachment = ApprovalCardBuilder.BuildActionConfirmationCard(
            FapNumber, "reject", "Jane ASM", DateTime.UtcNow, reason);

        var card = (JObject)attachment.Content;
        var body = (JArray)card["body"]!;

        var statusBlock = body.Children<JObject>()
            .FirstOrDefault(e => e["text"]?.ToString()?.Contains("Rejected") == true);
        Assert.NotNull(statusBlock);
        Assert.Contains("❌", statusBlock["text"]?.ToString());

        var reasonBlock = body.Children<JObject>()
            .FirstOrDefault(e => e["text"]?.ToString()?.Contains(reason) == true);
        Assert.NotNull(reasonBlock);
    }

    [Fact]
    public void BuildActionConfirmationCard_NoActionsOnConfirmationCard()
    {
        var attachment = ApprovalCardBuilder.BuildActionConfirmationCard(
            FapNumber, "approve", "John ASM", DateTime.UtcNow);

        var card = (JObject)attachment.Content;
        Assert.Null(card["actions"]);
    }

    [Fact]
    public void BuildActionConfirmationCard_UsesSchemaVersion13()
    {
        var attachment = ApprovalCardBuilder.BuildActionConfirmationCard(
            FapNumber, "approve", "John ASM", DateTime.UtcNow);

        var card = (JObject)attachment.Content;
        Assert.Equal("1.3", card["version"]?.ToString());
    }
}
