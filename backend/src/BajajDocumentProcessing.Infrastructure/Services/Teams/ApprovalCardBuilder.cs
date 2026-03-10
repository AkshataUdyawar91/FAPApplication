using AdaptiveCards;
using Microsoft.Bot.Schema;
using Newtonsoft.Json;

namespace BajajDocumentProcessing.Infrastructure.Services.Teams;

/// <summary>
/// Builds adaptive cards for ASM approval workflow in Teams.
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
        var confidenceColor = confidenceScore > 85 ? "good" : confidenceScore >= 70 ? "warning" : "attention";
        var recommendationColor = recommendation == "APPROVE" ? "good" : recommendation == "REVIEW" ? "warning" : "attention";
        var deepLink = $"{portalBaseUrl}/fap/{fapId}/review";

        var card = new AdaptiveCard(new AdaptiveSchemaVersion(1, 5))
        {
            Body = new List<AdaptiveElement>
            {
                new AdaptiveTextBlock
                {
                    Text = "New FAP Submission for Review",
                    Weight = AdaptiveTextWeight.Bolder,
                    Size = AdaptiveTextSize.Medium
                },
                new AdaptiveFactSet
                {
                    Facts = new List<AdaptiveFact>
                    {
                        new("FAP #", fapNumber),
                        new("Agency", agencyName),
                        new("PO #", poNumber),
                        new("Amount", $"₹{amount:N2}"),
                        new("Submitted", submittedDate.ToString("dd-MMM-yyyy"))
                    }
                },
                new AdaptiveColumnSet
                {
                    Columns = new List<AdaptiveColumn>
                    {
                        new()
                        {
                            Width = "auto",
                            Items = new List<AdaptiveElement>
                            {
                                new AdaptiveTextBlock { Text = "AI Confidence", Weight = AdaptiveTextWeight.Bolder }
                            }
                        },
                        new()
                        {
                            Width = "auto",
                            Items = new List<AdaptiveElement>
                            {
                                new AdaptiveTextBlock
                                {
                                    Text = $"{confidenceScore:F0}%",
                                    Color = confidenceColor == "good" ? AdaptiveTextColor.Good
                                          : confidenceColor == "warning" ? AdaptiveTextColor.Warning
                                          : AdaptiveTextColor.Attention,
                                    Weight = AdaptiveTextWeight.Bolder,
                                    Size = AdaptiveTextSize.ExtraLarge
                                }
                            }
                        }
                    }
                },
                new AdaptiveTextBlock
                {
                    Text = $"Recommendation: {recommendation}",
                    Weight = AdaptiveTextWeight.Bolder,
                    Color = recommendationColor == "good" ? AdaptiveTextColor.Good
                          : recommendationColor == "warning" ? AdaptiveTextColor.Warning
                          : AdaptiveTextColor.Attention
                },
                new AdaptiveTextBlock
                {
                    Text = recommendationSummary,
                    Wrap = true,
                    Size = AdaptiveTextSize.Small
                }
            },
            Actions = new List<AdaptiveAction>
            {
                new AdaptiveSubmitAction
                {
                    Title = "✅ Approve",
                    Style = "positive",
                    Data = new { action = "approve", fapId = fapId.ToString(), cardVersion = CardVersion }
                },
                new AdaptiveShowCardAction
                {
                    Title = "❌ Reject",
                    Card = new AdaptiveCard(new AdaptiveSchemaVersion(1, 5))
                    {
                        Body = new List<AdaptiveElement>
                        {
                            new AdaptiveTextInput
                            {
                                Id = "rejectionReason",
                                Placeholder = "Enter rejection reason (min 10 characters)...",
                                IsMultiline = true,
                                IsRequired = true,
                                Label = "Rejection Reason"
                            }
                        },
                        Actions = new List<AdaptiveAction>
                        {
                            new AdaptiveSubmitAction
                            {
                                Title = "Confirm Reject",
                                Style = "destructive",
                                Data = new { action = "reject", fapId = fapId.ToString(), cardVersion = CardVersion }
                            }
                        }
                    }
                },
                new AdaptiveOpenUrlAction
                {
                    Title = "📋 View in Portal",
                    Url = new Uri(deepLink)
                }
            }
        };

        return new Attachment
        {
            ContentType = AdaptiveCard.ContentType,
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
        var statusText = action == "approve"
            ? $"✅ Approved by {actorName} at {actionTimestamp:dd-MMM-yyyy HH:mm} UTC"
            : $"❌ Rejected by {actorName} at {actionTimestamp:dd-MMM-yyyy HH:mm} UTC";

        var body = new List<AdaptiveElement>
        {
            new AdaptiveTextBlock
            {
                Text = $"FAP #{fapNumber} — Action Completed",
                Weight = AdaptiveTextWeight.Bolder,
                Size = AdaptiveTextSize.Medium
            },
            new AdaptiveTextBlock
            {
                Text = statusText,
                Wrap = true,
                Color = action == "approve" ? AdaptiveTextColor.Good : AdaptiveTextColor.Attention
            }
        };

        if (!string.IsNullOrEmpty(reason))
        {
            body.Add(new AdaptiveTextBlock
            {
                Text = $"Reason: {reason}",
                Wrap = true,
                Size = AdaptiveTextSize.Small
            });
        }

        var card = new AdaptiveCard(new AdaptiveSchemaVersion(1, 5)) { Body = body };

        return new Attachment
        {
            ContentType = AdaptiveCard.ContentType,
            Content = card
        };
    }
}
