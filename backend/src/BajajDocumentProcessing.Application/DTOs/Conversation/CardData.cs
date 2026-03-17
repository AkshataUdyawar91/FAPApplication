using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Conversation;

/// <summary>
/// Base class for rich card data rendered inline in the chat UI.
/// Uses JSON polymorphism so the frontend can determine the card type.
/// </summary>
[JsonPolymorphic(TypeDiscriminatorPropertyName = "cardType")]
[JsonDerivedType(typeof(POListCard), "poList")]
[JsonDerivedType(typeof(ValidationResultCard), "validationResult")]
[JsonDerivedType(typeof(TeamSummaryCard), "teamSummary")]
[JsonDerivedType(typeof(FinalReviewCard), "finalReview")]
public abstract class CardData;

/// <summary>
/// Card displaying a list of purchase orders for selection
/// </summary>
public class POListCard : CardData
{
    /// <summary>
    /// Purchase orders matching the search criteria
    /// </summary>
    [JsonPropertyName("items")]
    public required List<POSearchResult> Items { get; init; }
}

/// <summary>
/// Card displaying per-document proactive validation results
/// </summary>
public class ValidationResultCard : CardData
{
    /// <summary>
    /// Type of document validated (e.g. "Invoice", "CostSummary")
    /// </summary>
    [JsonPropertyName("documentType")]
    public required string DocumentType { get; init; }

    /// <summary>
    /// Per-rule validation results
    /// </summary>
    [JsonPropertyName("rules")]
    public required List<ProactiveRuleResult> Rules { get; init; }

    /// <summary>
    /// Whether all rules passed
    /// </summary>
    [JsonPropertyName("allPassed")]
    public required bool AllPassed { get; init; }
}

/// <summary>
/// Card displaying a team's details summary
/// </summary>
public class TeamSummaryCard : CardData
{
    /// <summary>
    /// Name of the team
    /// </summary>
    [JsonPropertyName("teamName")]
    public required string TeamName { get; init; }

    /// <summary>
    /// Dealer name for this team's activity
    /// </summary>
    [JsonPropertyName("dealerName")]
    public required string DealerName { get; init; }

    /// <summary>
    /// City where the activity was performed
    /// </summary>
    [JsonPropertyName("city")]
    public required string City { get; init; }

    /// <summary>
    /// Activity start date
    /// </summary>
    [JsonPropertyName("startDate")]
    public required DateTime StartDate { get; init; }

    /// <summary>
    /// Activity end date
    /// </summary>
    [JsonPropertyName("endDate")]
    public required DateTime EndDate { get; init; }

    /// <summary>
    /// Number of working days
    /// </summary>
    [JsonPropertyName("workingDays")]
    public required int WorkingDays { get; init; }

    /// <summary>
    /// Total number of photos uploaded for this team
    /// </summary>
    [JsonPropertyName("photoCount")]
    public required int PhotoCount { get; init; }

    /// <summary>
    /// Number of photos that passed AI vision validation
    /// </summary>
    [JsonPropertyName("photosValidated")]
    public required int PhotosValidated { get; init; }
}

/// <summary>
/// Comprehensive pre-submit summary card for final review
/// </summary>
public class FinalReviewCard : CardData
{
    /// <summary>
    /// Selected purchase order number
    /// </summary>
    [JsonPropertyName("poNumber")]
    public required string PONumber { get; init; }

    /// <summary>
    /// Activity state / region
    /// </summary>
    [JsonPropertyName("state")]
    public required string State { get; init; }

    /// <summary>
    /// Invoice validation status summary
    /// </summary>
    [JsonPropertyName("invoiceStatus")]
    public required string InvoiceStatus { get; init; }

    /// <summary>
    /// Cost summary validation status
    /// </summary>
    [JsonPropertyName("costSummaryStatus")]
    public required string CostSummaryStatus { get; init; }

    /// <summary>
    /// Activity summary validation status
    /// </summary>
    [JsonPropertyName("activitySummaryStatus")]
    public required string ActivitySummaryStatus { get; init; }

    /// <summary>
    /// Summary of all teams in the submission
    /// </summary>
    [JsonPropertyName("teams")]
    public required List<TeamSummaryCard> Teams { get; init; }

    /// <summary>
    /// Number of enquiry records extracted
    /// </summary>
    [JsonPropertyName("enquiryRecordCount")]
    public required int EnquiryRecordCount { get; init; }

    /// <summary>
    /// Total submission amount
    /// </summary>
    [JsonPropertyName("totalAmount")]
    public required decimal TotalAmount { get; init; }
}
