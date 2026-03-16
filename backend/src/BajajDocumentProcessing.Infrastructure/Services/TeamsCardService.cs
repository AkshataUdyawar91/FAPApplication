using System.Reflection;
using AdaptiveCards.Templating;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Builds Adaptive Card JSON from templates and data context using AdaptiveCards.Templating.
/// Templates are loaded as embedded resources from the Infrastructure assembly.
/// </summary>
public class TeamsCardService : ITeamsCardService
{
    private const string TemplateResourcePrefix = "BajajDocumentProcessing.Infrastructure.Templates.TeamsCards.";
    private const string NewSubmissionTemplateResource = TemplateResourcePrefix + "new-submission-card.json";
    private const string ReviewDetailsTemplateResource = TemplateResourcePrefix + "review-details-card.json";

    private readonly ILogger<TeamsCardService> _logger;
    private readonly string _newSubmissionCardTemplate;
    private readonly string _reviewDetailsCardTemplate;

    /// <summary>
    /// Initializes a new instance of <see cref="TeamsCardService"/>.
    /// Loads card templates once at construction time.
    /// </summary>
    /// <param name="logger">Logger instance.</param>
    public TeamsCardService(ILogger<TeamsCardService> logger)
    {
        _logger = logger;
        _newSubmissionCardTemplate = LoadEmbeddedTemplate(NewSubmissionTemplateResource);
        _reviewDetailsCardTemplate = LoadEmbeddedTemplate(ReviewDetailsTemplateResource);
    }

    /// <inheritdoc />
    public string BuildNewSubmissionCard(SubmissionCardData data)
    {
        _logger.LogInformation(
            "Building new-submission adaptive card for SubmissionId={SubmissionId}",
            data.SubmissionId);

        var dataContext = new
        {
            notificationTimestamp = data.NotificationTimestamp.ToString("dd-MMM-yyyy, hh:mm tt"),
            submissionNumber = data.SubmissionNumber ?? "N/A",
            submissionId = data.SubmissionId.ToString(),
            agencyName = NullFallback(data.AgencyName),
            poNumber = NullFallback(data.PoNumber),
            invoiceNumber = NullFallback(data.InvoiceNumber),
            invoiceAmount = NullFallback(data.InvoiceAmount, "₹0"),
            state = NullFallback(data.State),
            submittedAtFormatted = NullFallback(data.SubmittedAtFormatted),
            teamPhotoSummary = NullFallback(data.TeamPhotoSummary, "0 teams | 0 photos"),
            inquirySummary = NullFallback(data.InquirySummary),
            recommendation = NullFallback(data.Recommendation),
            recommendationEmoji = NullFallback(data.RecommendationEmoji),
            cardStyle = NullFallback(data.CardStyle, "default"),
            confidenceScoreFormatted = NullFallback(data.ConfidenceScoreFormatted, "0/100"),
            checksSummary = NullFallback(data.ChecksSummary, "0/0 checks passed"),
            allChecksPassed = data.AllChecksPassed,
            topIssues = data.TopIssues?.Select(i => new
            {
                severity = NullFallback(i.Severity),
                description = NullFallback(i.Description)
            }).ToArray() ?? Array.Empty<object>(),
            remainingIssueCount = data.RemainingIssueCount,
            remainingIssueText = NullFallback(data.RemainingIssueText),
            poBalanceMessage = NullFallback(data.PoBalanceMessage, "PO balance check available in portal"),
            showQuickApprove = data.ShowQuickApprove,
            portalUrl = NullFallback(data.PortalUrl, "#")
        };

        var template = new AdaptiveCardTemplate(_newSubmissionCardTemplate);
        var cardJson = template.Expand(dataContext);

        _logger.LogDebug(
            "Adaptive card built for SubmissionId={SubmissionId}, length={Length}",
            data.SubmissionId,
            cardJson.Length);

        return cardJson;
    }

    /// <inheritdoc />
    public string BuildReviewDetailsCard(ValidationBreakdownData data)
    {
        _logger.LogInformation(
            "Building review-details adaptive card for SubmissionId={SubmissionId}",
            data.SubmissionId);

        // Build the card entirely via JObject to avoid Adaptive Cards Templating
        // serialization issues with dynamic arrays (FactSet facts).
        var card = new Newtonsoft.Json.Linq.JObject
        {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.3"
        };

        var body = new Newtonsoft.Json.Linq.JArray();

        // Header row: title + status
        body.Add(new Newtonsoft.Json.Linq.JObject
        {
            ["type"] = "ColumnSet",
            ["columns"] = new Newtonsoft.Json.Linq.JArray
            {
                new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "Column",
                    ["width"] = "stretch",
                    ["items"] = new Newtonsoft.Json.Linq.JArray
                    {
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "TextBlock",
                            ["text"] = $"Review Details — {NullFallback(data.SubmissionNumber)}",
                            ["size"] = "Medium",
                            ["weight"] = "Bolder",
                            ["color"] = "Accent"
                        }
                    }
                },
                new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "Column",
                    ["width"] = "auto",
                    ["items"] = new Newtonsoft.Json.Linq.JArray
                    {
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "TextBlock",
                            ["text"] = $"Status: {NullFallback(data.CurrentStatus)}",
                            ["size"] = "Small",
                            ["isSubtle"] = true,
                            ["horizontalAlignment"] = "Right"
                        }
                    }
                }
            }
        });

        // Already-processed banner
        if (data.IsAlreadyProcessed)
        {
            var processedBy = NullFallback(data.ProcessedBy, "Unknown");
            var processedAt = data.ProcessedAt?.ToString("dd-MMM-yyyy, hh:mm tt") ?? "N/A";
            body.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "Container",
                ["separator"] = true,
                ["items"] = new Newtonsoft.Json.Linq.JArray
                {
                    new Newtonsoft.Json.Linq.JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = $"⚠️ Already processed by {processedBy} on {processedAt}",
                        ["wrap"] = true,
                        ["weight"] = "Bolder",
                        ["size"] = "Small"
                    }
                }
            });
        }

        // Validation Checks header
        body.Add(new Newtonsoft.Json.Linq.JObject
        {
            ["type"] = "TextBlock",
            ["text"] = "Validation Checks",
            ["weight"] = "Bolder",
            ["separator"] = true,
            ["spacing"] = "Medium"
        });

        // Build facts array from check groups
        var factsArray = new Newtonsoft.Json.Linq.JArray();
        if (data.CheckGroups != null)
        {
            foreach (var g in data.CheckGroups)
            {
                var groupName = NullFallback(g.GroupName);
                var statusText = NullFallback(g.Status, "Fail") == "Pass" ? "✅ Pass" : "❌ Fail";

                // Append failure reason if available
                if (!string.IsNullOrWhiteSpace(g.Details) && g.Status != "Pass")
                {
                    statusText += $" — {g.Details}";
                }

                factsArray.Add(new Newtonsoft.Json.Linq.JObject
                {
                    ["title"] = groupName,
                    ["value"] = statusText
                });
            }
        }

        // If no facts, add a fallback
        if (factsArray.Count == 0)
        {
            factsArray.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["title"] = "No validation data",
                ["value"] = "N/A"
            });
        }

        body.Add(new Newtonsoft.Json.Linq.JObject
        {
            ["type"] = "FactSet",
            ["facts"] = factsArray
        });

        // Action buttons — Approve, Reject, Open in Portal
        var actions = new Newtonsoft.Json.Linq.JArray();
        var submissionId = data.SubmissionId.ToString();
        var portalUrl = NullFallback(data.PortalUrl, "#");

        if (!data.IsAlreadyProcessed)
        {
            actions.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Approve",
                ["style"] = "positive",
                ["data"] = new Newtonsoft.Json.Linq.JObject
                {
                    ["action"] = "approve_from_review",
                    ["submissionId"] = submissionId,
                    ["fapId"] = submissionId,
                    ["cardVersion"] = "1.0"
                }
            });
            actions.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Reject",
                ["style"] = "destructive",
                ["data"] = new Newtonsoft.Json.Linq.JObject
                {
                    ["action"] = "reject_from_review",
                    ["submissionId"] = submissionId,
                    ["fapId"] = submissionId,
                    ["cardVersion"] = "1.0"
                }
            });
        }

        actions.Add(new Newtonsoft.Json.Linq.JObject
        {
            ["type"] = "Action.OpenUrl",
            ["title"] = "Open in Portal",
            ["url"] = portalUrl
        });

        body.Add(new Newtonsoft.Json.Linq.JObject
        {
            ["type"] = "ActionSet",
            ["separator"] = true,
            ["actions"] = actions
        });

        card["body"] = body;

        var cardJson = card.ToString(Newtonsoft.Json.Formatting.None);

        _logger.LogDebug(
            "Review details card built for SubmissionId={SubmissionId}, length={Length}",
            data.SubmissionId,
            cardJson.Length);

        return cardJson;
    }

    /// <summary>
    /// Returns the input string, or a fallback value if null or whitespace.
    /// </summary>
    /// <param name="value">The value to check.</param>
    /// <param name="fallback">The fallback value (defaults to "N/A").</param>
    /// <returns>The original value or the fallback.</returns>
    private static string NullFallback(string? value, string fallback = "N/A")
    {
        return string.IsNullOrWhiteSpace(value) ? fallback : value;
    }

    /// <summary>
    /// Loads a card template from an embedded resource in the Infrastructure assembly.
    /// </summary>
    /// <param name="resourceName">The fully-qualified embedded resource name.</param>
    /// <returns>The raw JSON template string.</returns>
    private string LoadEmbeddedTemplate(string resourceName)
    {
        var assembly = Assembly.GetExecutingAssembly();
        using var stream = assembly.GetManifestResourceStream(resourceName);

        if (stream is null)
        {
            _logger.LogCritical(
                "Embedded adaptive card template not found: {ResourceName}. Available resources: {Resources}",
                resourceName,
                string.Join(", ", assembly.GetManifestResourceNames()));
            throw new FileNotFoundException($"Embedded adaptive card template not found: {resourceName}");
        }

        using var reader = new StreamReader(stream);
        var json = reader.ReadToEnd();

        _logger.LogInformation("Loaded embedded adaptive card template: {ResourceName}", resourceName);
        return json;
    }
}
