namespace BajajDocumentProcessing.Application.DTOs.Notifications;

/// <summary>
/// Strongly-typed DTO containing all token values for the Teams Adaptive Card
/// and email fallback template. Covers Header, Key Facts, AI Recommendation,
/// PO Balance, and Action Button sections.
/// </summary>
public class SubmissionCardData
{
    // === Header Section ===

    /// <summary>
    /// Unique identifier of the submission (DocumentPackage.Id).
    /// </summary>
    public Guid SubmissionId { get; set; }

    /// <summary>
    /// Human-readable submission number in the format "FAP-{Id[..8].ToUpper()}".
    /// </summary>
    public string SubmissionNumber { get; set; } = string.Empty;

    /// <summary>
    /// UTC timestamp when the notification was generated.
    /// </summary>
    public DateTime NotificationTimestamp { get; set; }

    // === Key Facts Section (Req 2.2) ===

    /// <summary>
    /// Agency name from Agency.SupplierName.
    /// </summary>
    public string AgencyName { get; set; } = string.Empty;

    /// <summary>
    /// PO number from PO.PONumber, or "N/A" if unavailable.
    /// </summary>
    public string PoNumber { get; set; } = "N/A";

    /// <summary>
    /// Invoice number from the first team invoice across Teams.
    /// </summary>
    public string InvoiceNumber { get; set; } = "N/A";

    /// <summary>
    /// Formatted invoice amount with ₹ currency symbol (e.g., "₹1,25,000").
    /// </summary>
    public string InvoiceAmount { get; set; } = "₹0";

    /// <summary>
    /// Raw decimal invoice amount for calculations and email subject formatting.
    /// </summary>
    public decimal InvoiceAmountRaw { get; set; }

    /// <summary>
    /// Geographic state from the Teams entity.
    /// </summary>
    public string State { get; set; } = "N/A";

    /// <summary>
    /// Submission timestamp from DocumentPackage.CreatedAt.
    /// </summary>
    public DateTime SubmittedAt { get; set; }

    /// <summary>
    /// Human-readable formatted submission timestamp (e.g., "12-Mar-2026, 10:30 AM").
    /// </summary>
    public string SubmittedAtFormatted { get; set; } = string.Empty;

    /// <summary>
    /// Number of teams in the submission.
    /// </summary>
    public int TeamCount { get; set; }

    /// <summary>
    /// Total number of photos across all teams.
    /// </summary>
    public int PhotoCount { get; set; }

    /// <summary>
    /// Summary string for teams and photos (e.g., "3 teams | 19 photos").
    /// </summary>
    public string TeamPhotoSummary { get; set; } = string.Empty;

    /// <summary>
    /// Inquiry summary from EnquiryDocument (e.g., "87 records (84 complete)") or "N/A".
    /// </summary>
    public string InquirySummary { get; set; } = "N/A";

    // === AI Recommendation Section (Req 3) ===

    /// <summary>
    /// Recommendation type as string: "Approve", "Review", or "Reject".
    /// </summary>
    public string Recommendation { get; set; } = string.Empty;

    /// <summary>
    /// Emoji indicator for the recommendation: "✅", "⚠️", or "❌".
    /// </summary>
    public string RecommendationEmoji { get; set; } = string.Empty;

    /// <summary>
    /// Adaptive Card container style: "good", "attention", or "warning".
    /// </summary>
    public string CardStyle { get; set; } = "default";

    /// <summary>
    /// Overall confidence score from ConfidenceScore.OverallConfidence.
    /// </summary>
    public double ConfidenceScore { get; set; }

    /// <summary>
    /// Formatted confidence score string (e.g., "85/100").
    /// </summary>
    public string ConfidenceScoreFormatted { get; set; } = string.Empty;

    /// <summary>
    /// Number of validation checks that passed.
    /// </summary>
    public int PassedChecks { get; set; }

    /// <summary>
    /// Total number of validation checks evaluated.
    /// </summary>
    public int TotalChecks { get; set; }

    /// <summary>
    /// Summary of checks (e.g., "12/14 checks passed").
    /// </summary>
    public string ChecksSummary { get; set; } = string.Empty;

    /// <summary>
    /// Whether all validation checks passed.
    /// </summary>
    public bool AllChecksPassed { get; set; }

    /// <summary>
    /// Top validation issues (up to 3), sorted by severity (Fail before Warning).
    /// </summary>
    public List<ValidationIssueItem> TopIssues { get; set; } = new();

    /// <summary>
    /// Number of remaining issues beyond the top 3.
    /// </summary>
    public int RemainingIssueCount { get; set; }

    /// <summary>
    /// Text for remaining issues (e.g., "... and 2 more issues") or empty.
    /// </summary>
    public string RemainingIssueText { get; set; } = string.Empty;

    /// <summary>
    /// AI-generated evidence text supporting the recommendation (from Recommendation.Evidence).
    /// </summary>
    public string RecommendationEvidence { get; set; } = string.Empty;

    /// <summary>
    /// Per-document validation check groups with individual check status and evidence.
    /// Used for the detailed validation table on the new submission card.
    /// </summary>
    public List<ValidationCheckGroup> CheckGroups { get; set; } = new();

    // === PO Balance Section (Req 4 — deferred) ===

    /// <summary>
    /// Placeholder message for PO balance section.
    /// </summary>
    public string PoBalanceMessage { get; set; } = "PO balance check available in portal";

    // === Action Buttons Section (Req 5) ===

    /// <summary>
    /// Whether to show the Quick Approve button. True only when Recommendation = Approve.
    /// </summary>
    public bool ShowQuickApprove { get; set; }

    /// <summary>
    /// Deep link URL to the portal review page for this submission.
    /// </summary>
    public string PortalUrl { get; set; } = string.Empty;
}

/// <summary>
/// Represents a single validation issue with severity and description.
/// </summary>
public class ValidationIssueItem
{
    /// <summary>
    /// Issue severity: "Fail" or "Warning".
    /// </summary>
    public string Severity { get; set; } = string.Empty;

    /// <summary>
    /// Human-readable description of the validation issue.
    /// </summary>
    public string Description { get; set; } = string.Empty;
}
