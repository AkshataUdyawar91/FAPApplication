using Microsoft.Bot.Schema;
using Newtonsoft.Json.Linq;

namespace BajajDocumentProcessing.Infrastructure.Services.Teams;

/// <summary>
/// Builds adaptive cards for ASM approval workflow in Teams.
/// Uses raw JObject construction with schema version 1.3 for maximum compatibility
/// with Bot Framework Emulator (v1.5 causes yellow/gold background rendering).
/// </summary>
public static class ApprovalCardBuilder
{
    private const string CardVersion = "1.0";

    /// <summary>
    /// Builds the ASM approval adaptive card with FAP details and approve/reject actions.
    /// </summary>
    public static Attachment BuildApprovalCard(
        Guid fapId,
        string fapNumber,
        string agencyName,
        string poNumber,
        decimal amount,
        DateTime submittedDate,
        double confidenceScore,
        string recommendation,
        string recommendationSummary,
        string portalBaseUrl)
    {
        var confidenceEmoji = confidenceScore > 85 ? "🟢" : confidenceScore >= 70 ? "🟡" : "🔴";
        var recommendationEmoji = recommendation == "APPROVE" ? "✅" : recommendation == "REVIEW" ? "⚠️" : "❌";
        var deepLink = $"{portalBaseUrl}/fap/{fapId}/review";

        var card = new JObject
        {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.3",
            ["body"] = new JArray
            {
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = "New FAP Submission for Review",
                    ["weight"] = "Bolder",
                    ["size"] = "Medium"
                },
                new JObject
                {
                    ["type"] = "FactSet",
                    ["facts"] = new JArray
                    {
                        new JObject { ["title"] = "FAP #", ["value"] = fapNumber },
                        new JObject { ["title"] = "Agency", ["value"] = agencyName },
                        new JObject { ["title"] = "PO #", ["value"] = poNumber },
                        new JObject { ["title"] = "Amount", ["value"] = $"₹{amount:N2}" },
                        new JObject { ["title"] = "Submitted", ["value"] = submittedDate.ToString("dd-MMM-yyyy") }
                    }
                },
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = $"{confidenceEmoji} AI Confidence: {confidenceScore:F0}%",
                    ["weight"] = "Bolder",
                    ["size"] = "Large"
                },
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = $"{recommendationEmoji} Recommendation: {recommendation}",
                    ["weight"] = "Bolder"
                },
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = recommendationSummary,
                    ["wrap"] = true,
                    ["size"] = "Small"
                }
            },
            ["actions"] = new JArray
            {
                new JObject
                {
                    ["type"] = "Action.Submit",
                    ["title"] = "✅ Approve",
                    ["style"] = "positive",
                    ["data"] = new JObject
                    {
                        ["action"] = "approve",
                        ["fapId"] = fapId.ToString(),
                        ["cardVersion"] = CardVersion
                    }
                },
                new JObject
                {
                    ["type"] = "Action.Submit",
                    ["title"] = "❌ Reject",
                    ["data"] = new JObject
                    {
                        ["action"] = "review_details",
                        ["fapId"] = fapId.ToString(),
                        ["cardVersion"] = CardVersion
                    }
                },
                new JObject
                {
                    ["type"] = "Action.OpenUrl",
                    ["title"] = "📋 View in Portal",
                    ["url"] = deepLink
                }
            }
        };

        return new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };
    }

    /// <summary>
    /// Builds a confirmation card shown after an action is taken (approve/reject).
    /// Replaces the original card with a read-only status.
    /// </summary>
    public static Attachment BuildActionConfirmationCard(
        string fapNumber,
        string action,
        string actorName,
        DateTime actionTimestamp,
        string? reason = null)
    {
        var statusEmoji = action == "approve" ? "✅" : "❌";
        var actionWord = action == "approve" ? "Approved" : "Rejected";
        var statusText = $"{statusEmoji} {actionWord} by {actorName} at {actionTimestamp:dd-MMM-yyyy HH:mm} UTC";

        var body = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"FAP #{fapNumber} — Action Completed",
                ["weight"] = "Bolder",
                ["size"] = "Medium"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = statusText,
                ["wrap"] = true
            }
        };

        if (!string.IsNullOrEmpty(reason))
        {
            body.Add(new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"Reason: {reason}",
                ["wrap"] = true,
                ["size"] = "Small"
            });
        }

        var card = new JObject
        {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.3",
            ["body"] = body
        };

        return new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };
    }
}
