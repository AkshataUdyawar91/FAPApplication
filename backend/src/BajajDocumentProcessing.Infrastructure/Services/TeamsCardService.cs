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
                    new Newtonsoft.Json.Linq.JObject { ["title"] = "EnquiriesDoc:", ["value"] = NullFallback(data.InquirySummary) }
                }
            });

            // Recommendation header + evidence
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

            // Confidence score
            if (data.ConfidenceScore > 0)
            {
                recommendationItems.Add(new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = $"Confidence: {NullFallback(data.ConfidenceScoreFormatted, "Pending")}",
                    ["size"] = "Small",
                    ["isSubtle"] = true,
                    ["wrap"] = true
                });
            }

            // AI evidence
            if (!string.IsNullOrWhiteSpace(data.RecommendationEvidence))
            {
                recommendationItems.Add(new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = data.RecommendationEvidence,
                    ["size"] = "Small",
                    ["wrap"] = true,
                    ["isSubtle"] = true
                });
            }

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

        // Validation Checks — grouped by document type
        if (data.CheckGroups != null && data.CheckGroups.Count > 0)
        {
            // Group checks by document type (GroupName)
            var grouped = new List<(string DocName, List<ValidationCheckGroup> Checks)>();
            string? currentDoc = null;
            List<ValidationCheckGroup>? currentList = null;

            foreach (var g in data.CheckGroups)
            {
                if (g.GroupName != currentDoc)
                {
                    currentDoc = g.GroupName;
                    currentList = new List<ValidationCheckGroup>();
                    grouped.Add((currentDoc, currentList));
                }
                currentList!.Add(g);
            }

            foreach (var (docName, checks) in grouped)
            {
                var passCount = checks.Count(c => c.Status == "Pass");
                var failCount = checks.Count - passCount;

                // Document header: name on left, pass/fail summary on right
                var summaryParts = new Newtonsoft.Json.Linq.JArray();
                summaryParts.Add(new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = $"{passCount}/{checks.Count} passed",
                    ["size"] = "Small",
                    ["color"] = "Good",
                    ["weight"] = "Bolder"
                });
                // Issue count badge removed per requirement

                body.Add(new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "ColumnSet",
                    ["separator"] = true,
                    ["spacing"] = "Medium",
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
                                    ["text"] = NullFallback(docName),
                                    ["weight"] = "Bolder",
                                    ["size"] = "Small"
                                }
                            }
                        },
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "auto",
                            ["items"] = summaryParts
                        }
                    }
                });

                // Column headers: #, WHAT WAS CHECKED, RESULT, WHAT WAS FOUND
                body.Add(new Newtonsoft.Json.Linq.JObject
                {
                    ["type"] = "ColumnSet",
                    ["spacing"] = "Small",
                    ["columns"] = new Newtonsoft.Json.Linq.JArray
                    {
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "25px",
                            ["items"] = new Newtonsoft.Json.Linq.JArray
                            {
                                new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = "#", ["weight"] = "Bolder", ["size"] = "Small", ["isSubtle"] = true }
                            }
                        },
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "stretch",
                            ["items"] = new Newtonsoft.Json.Linq.JArray
                            {
                                new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = "WHAT WAS CHECKED", ["weight"] = "Bolder", ["size"] = "Small", ["isSubtle"] = true }
                            }
                        },
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "55px",
                            ["items"] = new Newtonsoft.Json.Linq.JArray
                            {
                                new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = "RESULT", ["weight"] = "Bolder", ["size"] = "Small", ["isSubtle"] = true }
                            }
                        },
                        new Newtonsoft.Json.Linq.JObject
                        {
                            ["type"] = "Column",
                            ["width"] = "stretch",
                            ["items"] = new Newtonsoft.Json.Linq.JArray
                            {
                                new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = "WHAT WAS FOUND", ["weight"] = "Bolder", ["size"] = "Small", ["isSubtle"] = true }
                            }
                        }
                    }
                });

                // Data rows
                for (var i = 0; i < checks.Count; i++)
                {
                    var c = checks[i];
                    var statusText = c.Status == "Pass" ? "PASS" : "FAIL";
                    var statusColor = c.Status == "Pass" ? "Good" : "Attention";
                    var checkName = NullFallback(c.Details, "Check");

                    body.Add(new Newtonsoft.Json.Linq.JObject
                    {
                        ["type"] = "ColumnSet",
                        ["spacing"] = "None",
                        ["columns"] = new Newtonsoft.Json.Linq.JArray
                        {
                            new Newtonsoft.Json.Linq.JObject
                            {
                                ["type"] = "Column",
                                ["width"] = "25px",
                                ["items"] = new Newtonsoft.Json.Linq.JArray
                                {
                                    new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = (i + 1).ToString(), ["size"] = "Small" }
                                }
                            },
                            new Newtonsoft.Json.Linq.JObject
                            {
                                ["type"] = "Column",
                                ["width"] = "stretch",
                                ["items"] = new Newtonsoft.Json.Linq.JArray
                                {
                                    new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = checkName, ["size"] = "Small", ["wrap"] = true }
                                }
                            },
                            new Newtonsoft.Json.Linq.JObject
                            {
                                ["type"] = "Column",
                                ["width"] = "55px",
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
                                    new Newtonsoft.Json.Linq.JObject { ["type"] = "TextBlock", ["text"] = NullFallback(c.Evidence, "—"), ["size"] = "Small", ["wrap"] = true }
                                }
                            }
                        }
                    });
                }
            }
        }
        else
        {
            body.Add(new Newtonsoft.Json.Linq.JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "No validation data available",
                ["size"] = "Small",
                ["isSubtle"] = true,
                ["separator"] = true
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
