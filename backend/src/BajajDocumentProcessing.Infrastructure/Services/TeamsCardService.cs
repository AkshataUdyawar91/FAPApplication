using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Builds Adaptive Card JSON via JObject construction for Teams notifications.
/// </summary>
public class TeamsCardService : ITeamsCardService
{
    private readonly ILogger<TeamsCardService> _logger;

    /// <summary>
    /// Initializes a new instance of <see cref="TeamsCardService"/>.
    /// </summary>
    /// <param name="logger">Logger instance.</param>
    public TeamsCardService(ILogger<TeamsCardService> logger)
    {
        _logger = logger;
    }

    /// <inheritdoc />
        public string BuildNewSubmissionCard(SubmissionCardData data)
        {
            _logger.LogInformation(
                "Building new-submission adaptive card for SubmissionId={SubmissionId}",
                data.SubmissionId);

            var submissionId = data.SubmissionId.ToString();
            var timestamp = data.NotificationTimestamp.ToString("dd-MMM-yyyy, hh:mm tt");

            var card = new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "AdaptiveCard",
                ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
                ["version"] = "1.3"
            };

            var bodyItems = new Newtonsoft.Json.Linq.JArray();

            // Header row: title + timestamp
            bodyItems.Add(new Newtonsoft.Json.Linq.JObject
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
                                ["text"] = "New Claim Submitted",
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
                                ["text"] = timestamp,
                                ["size"] = "Small",
                                ["isSubtle"] = true,
                                ["horizontalAlignment"] = "Right"
                            }
                        }
                    }
                }
            });

            // Key facts
            bodyItems.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "FactSet",
                ["separator"] = true,
                ["facts"] = new Newtonsoft.Json.Linq.JArray
                {
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "FAP ID:", ["value"] = NullFallback(data.SubmissionNumber) },
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "Agency:", ["value"] = NullFallback(data.AgencyName) },
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "PO Number:", ["value"] = NullFallback(data.PoNumber) },
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "Invoice:", ["value"] = NullFallback(data.InvoiceNumber) },
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "Amount:", ["value"] = NullFallback(data.InvoiceAmount, "₹0") },
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "State:", ["value"] = NullFallback(data.State) },
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "Submitted:", ["value"] = NullFallback(data.SubmittedAtFormatted) },
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "Teams:", ["value"] = NullFallback(data.TeamPhotoSummary, "0 teams | 0 photos") },
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "Inquiries:", ["value"] = NullFallback(data.InquirySummary) }
                }
            });

            // Recommendation header
            var recommendationItems = new Newtonsoft.Json.Linq.JArray
            {
                new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = $"Recommended: **{NullFallback(data.Recommendation)}**",
                    ["weight"] = "Bolder",
                    ["wrap"] = true
                }
            };

            bodyItems.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "Container",
                ["separator"] = true,
                ["style"] = "default",
                ["items"] = recommendationItems
            });

            // PO balance message
            bodyItems.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "Container",
                ["separator"] = true,
                ["items"] = new Newtonsoft.Json.Linq.JArray
                {
                    new Newtonsoft.Json.Linq.JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = NullFallback(data.PoBalanceMessage, "PO balance check available in portal"),
                        ["size"] = "Small",
                        ["isSubtle"] = true,
                        ["wrap"] = true
                    }
                }
            });

            // Action buttons
            var actions = new Newtonsoft.Json.Linq.JArray();

            if (data.ShowQuickApprove)
            {
                actions.Add(new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "Action.Submit",
                    ["title"] = "Quick Approve",
                    ["style"] = "positive",
                    ["data"] = new Newtonsoft.Json.Linq.JObject
                    {
                        ["action"] = "quick_approve",
                        ["submissionId"] = submissionId,
                        ["fapId"] = submissionId,
                        ["cardVersion"] = "1.0"
                    }
                });
            }

            actions.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Review Details",
                ["data"] = new Newtonsoft.Json.Linq.JObject
                {
                    ["action"] = "review_details",
                    ["submissionId"] = submissionId,
                    ["fapId"] = submissionId,
                    ["cardVersion"] = "1.0"
                }
            });

            actions.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "Action.OpenUrl",
                ["title"] = "Open in Portal",
                ["url"] = NullFallback(data.PortalUrl, "#")
            });

            bodyItems.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "ActionSet",
                ["separator"] = true,
                ["actions"] = actions
            });

            // Wrap in default-style container for white background in emulator
            card["body"] = new Newtonsoft.Json.Linq.JArray
            {
                new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "Container",
                    ["style"] = "default",
                    ["bleed"] = true,
                    ["items"] = bodyItems
                }
            };

            var cardJson = card.ToString(Newtonsoft.Json.Formatting.None);

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

        // Build validation table rows from check groups
        var factsArray = new Newtonsoft.Json.Linq.JArray();
        if (data.CheckGroups != null && data.CheckGroups.Count > 0)
        {
            // Table header row
            body.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "ColumnSet",
                ["spacing"] = "Small",
                ["columns"] = new Newtonsoft.Json.Linq.JArray
                {
                    new Newtonsoft.Json.Linq.JObject
                    {
                        ["type"] = "Column",
                        ["width"] = "30px",
                        ["items"] = new Newtonsoft.Json.Linq.JArray
                        {
                            new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = "#", ["weight"] = "Bolder", ["size"] = "Small" }
                        }
                    },
                    new Newtonsoft.Json.Linq.JObject
                    {
                        ["type"] = "Column",
                        ["width"] = "80px",
                        ["items"] = new Newtonsoft.Json.Linq.JArray
                        {
                            new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = "Doc Type", ["weight"] = "Bolder", ["size"] = "Small" }
                        }
                    },
                    new Newtonsoft.Json.Linq.JObject
                    {
                        ["type"] = "Column",
                        ["width"] = "50px",
                        ["items"] = new Newtonsoft.Json.Linq.JArray
                        {
                            new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = "Status", ["weight"] = "Bolder", ["size"] = "Small" }
                        }
                    },
                    new Newtonsoft.Json.Linq.JObject
                    {
                        ["type"] = "Column",
                        ["width"] = "stretch",
                        ["items"] = new Newtonsoft.Json.Linq.JArray
                        {
                            new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = "Evidence", ["weight"] = "Bolder", ["size"] = "Small" }
                        }
                    }
                }
            });

            var rowNum = 1;
            foreach (var g in data.CheckGroups)
            {
                var statusText = NullFallback(g.Status, "Fail") == "Pass" ? "PASS" : "FAIL";
                var statusColor = g.Status == "Pass" ? "Good" : "Attention";

                body.Add(new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "ColumnSet",
                    ["spacing"] = "None",
                    ["columns"] = new Newtonsoft.Json.Linq.JArray
                    {
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "30px",
                            ["items"] = new Newtonsoft.Json.Linq.JArray
                            {
                                new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = rowNum.ToString(), ["size"] = "Small" }
                            }
                        },
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "80px",
                            ["items"] = new Newtonsoft.Json.Linq.JArray
                            {
                                new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = NullFallback(g.GroupName), ["size"] = "Small", ["wrap"] = true }
                            }
                        },
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "50px",
                            ["items"] = new Newtonsoft.Json.Linq.JArray
                            {
                                new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = statusText, ["size"] = "Small", ["color"] = statusColor, ["weight"] = "Bolder" }
                            }
                        },
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "stretch",
                            ["items"] = new Newtonsoft.Json.Linq.JArray
                            {
                                new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = NullFallback(g.Evidence, "—"), ["size"] = "Small", ["wrap"] = true }
                            }
                        }
                    }
                });
                rowNum++;
            }
        }

        // If no check groups, show fallback
        if (data.CheckGroups == null || data.CheckGroups.Count == 0)
        {
            body.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "No validation data available",
                ["size"] = "Small",
                ["isSubtle"] = true
            });
        }

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

        // Wrap all body items in a full-bleed default Container to override
        // the Bot Framework Emulator's gold/yellow background theme.
        card["body"] = new Newtonsoft.Json.Linq.JArray
        {
            new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "Container",
                ["style"] = "default",
                ["bleed"] = true,
                ["items"] = body
            }
        };

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
}
